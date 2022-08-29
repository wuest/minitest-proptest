require 'test_helper'

class PropertyTest < Minitest::Proptest
  def test_falsifiable
    property do
      n = arbitrary Integer
      m = arbitrary Integer
      n + m == 100
    end
  end
end
