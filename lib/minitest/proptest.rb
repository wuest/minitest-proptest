require 'minitest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'

module Minitest
  class Proptest < Minitest::Test
    def property(&f)
      prop = Minitest::Proptest::Property.new(Random.new, 10_000)
      assert prop.run(&f)
    end
  end
end
