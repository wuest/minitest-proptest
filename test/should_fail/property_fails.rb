require 'test_helper'

class PropertyTest < Minitest::Test
  def test_falsifiable
    property do
      n = arbitrary Int8
      m = arbitrary Int8
      (n + m).even?
    end
  end

  def test_also_falsifiable
    property do
      xs = arbitrary Array, Int8
      ys = arbitrary Array, UInt8

      xs.zip(ys).length > 1
    end
  end
end
