require 'generator'

class SparseMatrix
  
  Comparators = {
    :row => proc{|a,b| (s = a[0] <=> b[0]) == 0 ? (a[1] <=> b[1]) : s},
    :column => proc{|a,b| (s = a[1] <=> b[1]) == 0 ? (a[0] <=> b[0]) : s}
  }
  
  class InMemory
    
    attr_accessor :values
    
    def initialize(values = {})
      @values = values
    end

    def by_column
      Generator.new(@values.keys.sort(&Comparators[:column]).collect{|k| [k, @values[k]]})
    end
    
    def by_row
      Generator.new(@values.keys.sort(&Comparators[:row]).collect{|k| [k, @values[k]]})
    end
    
  end
  
  class MultiGeneratorGenerator
    def initialize(generators, direction = :rows)
      @generators = generators
      @direction = direction
    end
    
    def current
      @current || self.next
    end
    
    def next
      @generators.delete_if{|i| not i.next?}
      raise if @generators.empty?
      coords = @generators.collect{|i| @direction == :rows ? i.current.first : i.current.first.reverse }
      min = @direction == :rows ? coords.min : coords.min.reverse
      @generators.each do |i|
        if i.current.first == min
          @current = i.current
          i.next
          return @current
        end
      end
    end
    
    def next?
      @generators.any?{|i| i.next?}
    end
    
    def each
      while next?
        yield self.next
      end
    end
    
  end

  class SexpGenerator
    def initialize(matrix, direction = :rows)
      @generators = generators
      @direction = direction
    end
    
    def current
      @current || self.next
    end
    
    def next
      @generators.delete_if{|i| not i.next?}
      raise if @generators.empty?
      coords = @generators.collect{|i| @direction == :rows ? i.current.first : i.current.first.reverse }
      min = @direction == :rows ? coords.min : coords.min.reverse
      @generators.each do |i|
        if i.current.first == min
          @current = i.current
          i.next
          return @current
        end
      end
    end
    
    def next?
      @generators.any?{|i| i.next?}
    end
    
    def each
      while next?
        yield self.next
      end
    end
    
  end
  
  attr_accessor :in_memory
  attr_reader :row_size, :column_size, :sexp
  
  def initialize(rows, columns = rows, operation = nil, lval = nil, rval = nil)
    @row_size = rows
    @column_size = columns
    @generators = [@in_memory = InMemory.new]
    @sexp = if operation
      [operation, lval, rval]
    else
      [self]
    end
  end
  
  def add_generator(generator)
    @generators << generator
  end
  
  def all_by_row
    gen = MultiGeneratorGenerator.new(@generators.collect{|g| g.by_row }, :rows)
    block_given? ? gen.each{|p, v| yield p, v} : gen
  end
  
  def all_by_column
    gen = MultiGeneratorGenerator.new(@generators.collect{|g| g.by_column }, :columns)
    block_given? ? gen.each{|p, v| yield p, v} : gen
  end
  
  def row(r)
    if block_given?
      all_by_row{|i,j,v| yield j,v if i == r; break if r < i}
    else
      result = []
      row(r) {|j,v| result << [j, v]}
      result
    end
  end

  def column(c)
    if block_given?
      @in_memory.by_column.each{|i,j,v| yield i,v if j == r; break if r < j}
    else
      result = []
      column(c) {|i,v| result << [i, v]}
      result
    end
  end


  def regular?
    not determinant.zero?
  end

  def singular?
    not regular?
  end
  
  def square?
    @row_size == @column_size
  end

  def *(m)
    raise unless column_size == m.row_size
    SparseMatrix.new(row_size, m.column_size, :*, self, m)
  end
  
  def +(m)
    raise unless row_size == m.row_size && column_size == m.column_size
    SparseMatrix.new(row_size, column_size, :+, self, m)
  end
  
  def -(m)
    raise unless row_size == m.row_size && column_size == m.column_size
    SparseMatrix.new(row_size, column_size, :-, self, m)
  end
  
  def range(left,right, direction = :row)
    pos = left
    while Comparators[direction].call(pos, right) != 1
      yield pos
      pos = incr(pos)
    end
  end
  
  def incr(pos)
    pos = if pos.last >= column_size
      [pos.first + 1, 1]
    else
      [pos.first, pos.last + 1]
    end
  end
  
  def result(options = {})
    output = options.delete(:output)
    direction = options.delete(:direction)
    pos = [1, 1]
    case @sexp.size
    when 1
      rows = all_by_row
      while rows.next?
        (next_pos, next_val) = rows.next
        range(incr(pos), next_pos) do |intermediary_pos|
          yield intermediary_pos, 0
        end if output == :full
        yield rows.current
        pos = rows.current.first
      end
      range(incr(pos), [row_size, column_size]) do |intermediary_pos|
        yield intermediary_pos, 0
      end if output == :full
    when 3
      case @sexp.first
      when :+, :-
        rows1 = @sexp[1].result(:output => output, direction => :rows)
        rows2 = @sexp[2].result(:output => output, direction => :rows)
        while rows1.next? && rows2.next?
          (pos1, val1) = rows1.next
          (pos2, val2) = rows2.next
          case Comparators[:row].call(pos1, pos2)
          when -1:
            yield rows1.current
            pos = rows1.current.first
          when 1:
            yield rows2.current
            pos = rows2.current.first
          when 0:
            yield rows1.current.first, @sexp.first == :+ ? rows1.current.last + rows2.current.last : rows1.current.last - rows2.current.last
            pos = rows2.current.first
          end
          range(incr(pos), next_pos) do |intermediary_pos|
            yield intermediary_pos, 0
          end if output == :full
        end
        range(incr(pos), [row_size, column_size]) do |intermediary_pos|
          yield intermediary_pos, 0
        end if output == :full
      when :*, :/
        rows1 = @sexp[1].all_by_row
        rows2 = @sexp[2].all_by_column
        while rows1.next? && rows2.next?
          (pos1, val1) = rows1.next
          (pos2, val2) = rows2.next
          case Comparators[:row].call(pos1, pos2.reverse)
          when -1:
            yield pos1, 0 if output == :full
            pos = rows1.current.first
          when 1:
            raise if @sexp.first == :/
            yield pos2.current.first.reverse, 0 if output == :full
            pos = rows2.current.first.reverse
          when 0:
            yield rows1.current.first, @sexp.first == :* ? rows1.current.last * rows2.current.last : rows1.current.last / rows2.current.last
            pos = rows1.current.first
          end
          range(incr(pos), next_pos) do |intermediary_pos|
            yield intermediary_pos, 0
          end if output == :full
        end
        range(incr(pos), [row_size, column_size]) do |intermediary_pos|
          yield intermediary_pos, 0
        end if output == :full
      end
    end    
    #      
    #    end
    #  else
    #    raise "unsupported operation #{@sexp.first}"
    #  end
  end
  
#  def *(m)
#    result = SparseMatrix.new
#    self.by_column
#  end
#    
#      * *(m)
#      * +(m)
#      * -(m)
#      * #/(m)
#      * inverse
#      * inv
#      * **
#
#  Matrix functions:
#
#      * determinant
#      * det
#      * rank
#      * trace
#      * tr
#      * transpose
#      * t
#
#  Conversion to other data types:
#
#      * coerce(other)
#      * row_vectors
#      * column_vectors
#      * to_a
#
#  String representations:
#
#      * to_s
#      * inspect
#  
  
end