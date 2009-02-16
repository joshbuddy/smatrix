require 'lib/sparse_matrix'

s = SparseMatrix.new(2,2)
s.in_memory.values = {[1,1] => 5, [1,2] => 8, [2,1] => 13, [2,2] => 1}

s2 = SparseMatrix.new(2,2)
s2.in_memory.values = {[1,1] => 7, [1,2] => 2, [2,1] => 33, [2,2] => 4}

s3 = SparseMatrix.new(2,2)
s3.in_memory.values = {[1,1] => 10, [1,2] => 12, [2,1] => 23, [2,2] => 14}

(s2 + s3).result do |p, v|
  puts "[#{p * ', '}] => #{v}"
end

puts (s * s2 + s3).sexp.inspect