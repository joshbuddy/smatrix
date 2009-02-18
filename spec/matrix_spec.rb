require 'lib/sparse_matrix'

describe "Smatrix" do
  
  it "should should interate over rows" do
    s1 = Smatrix.new(3,3, :generator => Smatrix::InMemory.new({[1,1] => 5, [1,2] => 8, [2,1] => 13, [2,2] => 1}))
    expects = [
      [Smatrix::P[1,1], 5],
      [Smatrix::P[1,2], 8],
      [Smatrix::P[2,1], 13],
      [Smatrix::P[2,2], 1]
    ]
    
    s1.by(:row) do |p, v|
      [p, v].should==expects.shift
    end
  end

  it "should should interate over columns" do
    s1 = Smatrix.new(3,3, :generator => Smatrix::InMemory.new({[1,1] => 5, [1,2] => 8, [2,1] => 13, [2,2] => 1}))
    expects = [
      [Smatrix::P[1,1], 5],
      [Smatrix::P[2,1], 13],
      [Smatrix::P[1,2], 8],
      [Smatrix::P[2,2], 1]
    ]
    
    s1.by(:column) do |p, v|
      [p, v].should==expects.shift
    end
  end

  it "should add two matrixes" do
    s1 = Smatrix.new(3,3, :generator => Smatrix::InMemory.new({[1,1] => 5, [1,2] => 8, [2,1] => 13, [2,2] => 1}))
    s2 = Smatrix.new(3,3, :generator => Smatrix::InMemory.new({[2,1] => 5, [1,1] => 8, [2,2] => 13, [1,2] => 1}))
    expects = [
      [Smatrix::P[1,1], 13],
      [Smatrix::P[1,2], 9],
      [Smatrix::P[2,1], 18],
      [Smatrix::P[2,2], 9]
    ]

    (s1 + s2).by(:row) do |p, v|
      [p, v].should==expects.shift
    end

  end
  
  it "should multiple two matrixes" do
    s1 = Smatrix.new(3,3, :generator => Smatrix::InMemory.new({[1,1] => 7, [1,2] => 2, [2,1] => 33, [2,2] => 4, [3,2] => 78}))
    s2 = Smatrix.new(3,3, :generator => Smatrix::InMemory.new({[1,1] => 10, [1,2] => 12, [2,1] => 23, [2,2] => 14}))
    expects = [
      [Smatrix::P[1,1], 116],
      [Smatrix::P[1,2], 112],
      [Smatrix::P[2,1], 422],
      [Smatrix::P[2,2], 452],
      [Smatrix::P[3,1], 1794],
      [Smatrix::P[3,2], 1092]
    ]

    (s1 * s2).by(:row) do |p, v|
      #puts "p #{p}, v #{v}"
      [p, v].should == expects.shift
    end

  end

end