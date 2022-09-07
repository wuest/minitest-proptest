require 'test_helper'

class PropertyTest < Minitest::Proptest
  def test_falsifiable
    property do
      n = arbitrary Int8
      m = arbitrary Int8
      (n + m).even?
    end
  end
end
