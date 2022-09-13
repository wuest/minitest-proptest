require 'minitest'
require 'minitest/proptest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'

module Minitest
  def self.plugin_proptest_init(_options)
    %i[Int8 Int16 Int32 Int64
       UInt8 UInt16 UInt32 UInt64
       ASCIIChar Char
       Bool
      ].each do |const|
      unless Minitest::Assertions.const_defined?(const)
        Minitest::Assertions.const_set(const, ::Minitest::Proptest::Gen.const_get(const))
      end
    end
  end

  module Assertions
    def property(&f)
      self.assertions += 1

      prop = Minitest::Proptest::Property.new(
        f,
        random: Proptest::DEFAULT_RANDOM,
        max_success: Proptest::DEFAULT_MAX_SUCCESS,
        max_discard_ratio: Proptest::DEFAULT_MAX_DISCARD_RATIO,
        max_size: Proptest::DEFAULT_MAX_SIZE,
        max_shrinks: Proptest::DEFAULT_MAX_SHRINKS
      )
      prop.run!

      unless prop.status.valid? && !prop.trivial
        raise Minitest::Assertion, prop.explain
      end
    end
  end
end
