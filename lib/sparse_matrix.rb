require 'generator'

class Smatrix
  
  def self.swap_direction(direction)
    direction == :row ? :column : :row
  end
  
  class P
    
    attr_accessor :row, :column
    
    def initialize(row, column)
      @row = row
      @column = column
    end
    
    def self.[](row, column)
      P.new(row, column)
    end
    
    def compare(o, type = :row)
      case type
      when :row
        (s = @row <=> o.row) == 0 ? (@column <=> o.column) : s
      when :column
        (s = @column <=> o.column) == 0 ? (@row <=> o.row) : s
      else
        raise "type: #{type} unrecognized"
      end
    end
    
    def incr(direction, row_size, column_size)
      case direction
      when :row
        if @column >= column_size
          P[@row + 1, 1]
        elsif @column < column_size && @row <= row_size
          P[@row, @column + 1]
        else
          nil
        end
      when :column
        if @row >= row_size
          P[1, @column + 1]
        elsif @row < row_size && @column <= column_size
          P[@row + 1, @column]
        else
          nil
        end
      end
    end
     
    def reverse
      P[@column, @row]
    end

    def hash
      [@row, @column].hash
    end 

    def ==(p)
      p && (p.row == @row && p.column == @column)
    end

    def to_s
      "#{@row}, #{@column}"
    end
  end
  
  class InMemory
    
    attr_accessor :values
    
    def initialize(values = {})
      @values = {}
      values.each{|k,v| @values[P[k.first, k.last]] = v}
    end

    def by(direction)
      Generator.new(@values.keys.sort{|a,b| a.compare(b, direction)}.collect{|k| [k, @values[k]]})
    end
  end
  
  class SexpGenerator
    
    attr_reader :direction
    
    def swap_direction
      Smatrix.swap_direction(@direction)
    end
    
    def initialize(matrix, options = {})
      options[:direction] ||= :row

      @sexp = matrix.sexp
      @direction = options.delete(:direction)
      
      @current = nil
      @generators = []
      case @sexp.size
      when 1:
        @matrix = @sexp.first
        @generators << (@gen = @matrix.generator.by(direction))
      when 3:
        @op = @sexp.first
        case @op
        when :+, :-
          @lmatrix = @sexp[1]
          @generators << (@lgen = @lmatrix.by(direction))
          @rmatrix = @sexp[2]
          @generators << (@rgen = @rmatrix.by(direction))
        when :*, :/
          @lmatrix = @sexp[1]
          @generators << (@lgen = @lmatrix.by(direction))
          @rmatrix = @sexp[2]
          @generators << (@rgen = @rmatrix.by(swap_direction))
        end
      end
    end
    
    def current
      self.next unless @pos
      @current
    end
    
    def next
      if @op
        case @op
        when :+, :-
          if @lgen.end? || @rgen.end?
            if @lgen.end?
              @current = @rgen.next
            elsif @rgen.end?
              @current = @lgen.next
            end
          else
            case @lgen.current.first.compare(@rgen.current.first)
            when -1
              @current = @lgen.current
              @lgen.next if @lgen.next?
            when 1
              @current = @rgen.current
              @rgen.next if @rgen.next?
            when 0
              @current = [@lgen.current.first, @lgen.current.last.send(@op, @rgen.current.last)]
              @lgen.next if @lgen.next?
              @rgen.next if @rgen.next?
            end
          end
          @pos = @current.first
        when :*
          if !@lgen.end? && @rgen.end?
            @pos = @lgen.current.first
            @lgen.next
          elsif @lgen.end? && !@rgen.end?
            @pos = @rgen.current.first.reverse
            @rgen.next
          else
            case @lgen.current.first.compare(@rgen.current.first.reverse)
            when 1
              @pos = @rgen.current.first.reverse
              @rgen.next if @rgen.next?
            when -1
              @pos = @lgen.current.first
              @lgen.next if @lgen.next?
            when 0
              @pos = @lgen.current.first
              @lgen.next if @lgen.next?
              @rgen.next if @rgen.next?
            end
          end
          
          lgen_local = @lmatrix.by(direction)
          rgen_local = @rmatrix.by(swap_direction)
          lgen_local.next while lgen_local.current.first.row != @pos.row && lgen_local.next?
          rgen_local.next while rgen_local.current.first.column != @pos.column && rgen_local.next?
          
          val = 0
          
          while (lgen_local.current.first.row == @pos.row && rgen_local.current.first.column == @pos.column )
            case lgen_local.current.first.column <=> rgen_local.current.first.row
            when -1
              lgen_local.next if lgen_local.next?
            when 1
              rgen_local.next if rgen_local.next?
            when 0
              val += lgen_local.current.last * rgen_local.current.last
              lgen_local.next if lgen_local.next?
              rgen_local.next if rgen_local.next?
            end
          end
          
          @current = [@pos, val]
        end
      else
        @current = @gen.current
        @pos ||= @current.first 
        @gen.next if @gen.next?
      end
      current
    end
    
    def next?
      @generators.any?{|i| i.next?}
    end
    
    def end?
      @generators.all?{|i| i.end?}
    end
    
    def each
      while !end?
        yield self.current
        self.next
      end
    end
    
    def rewind
      @generators.each{|g| g.rewind}
    end
    
  end
  
  attr_reader :row_size, :column_size, :sexp, :generator
  
  def initialize(rows, columns = rows, options = {})
    @row_size = rows
    @column_size = columns
    @generator = options[:generator] || InMemory.new
    @sexp = if options[:operation]
      [options[:operation], options[:lval], options[:rval]]
    else
      [self]
    end
  end
  
  def singular?
    not regular?
  end
  
  def square?
    @row_size == @column_size
  end

  def *(m)
    raise unless column_size == m.row_size
    Smatrix.new(row_size, column_size, :operation => :*, :lval => self, :rval => m)
  end
  
  def +(m)
    raise unless row_size == m.row_size && column_size == m.column_size
    Smatrix.new(row_size, column_size, :operation => :+, :lval => self, :rval => m)
  end
  
  def -(m)
    raise unless row_size == m.row_size && column_size == m.column_size
    Smatrix.new(row_size, column_size, :-, self, m)
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
  
  def by(direction = :row)
    gen = SexpGenerator.new(self, :direction => direction)
    block_given? ? gen.each{|p, v| yield p, v} : gen
  end
  alias :result :by
  
end