require 'minitest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'

module Minitest
  class Proptest < Minitest::Test
    # Convenience classes for type generators
    Int8      = ::Minitest::Proptest::Gen::Int8
    Int16     = ::Minitest::Proptest::Gen::Int16
    Int32     = ::Minitest::Proptest::Gen::Int32
    Int64     = ::Minitest::Proptest::Gen::Int64
    UInt8     = ::Minitest::Proptest::Gen::UInt8
    UInt16    = ::Minitest::Proptest::Gen::UInt16
    UInt32    = ::Minitest::Proptest::Gen::UInt32
    UInt64    = ::Minitest::Proptest::Gen::UInt64
    ASCIIChar = ::Minitest::Proptest::Gen::ASCIIChar
    Char      = ::Minitest::Proptest::Gen::Char

    def initialize(_)
      # Any class which provides `rand` accepting both an Integer and a Range
      # is acceptable.  The default value is Ruby's standard Mersenne Twister
      # implementation.
      @_random = Random.new
      # Maximum number of successful cases before considering the test a
      # success.
      @_max_success = 100
      # Maximum ratio of discarded tests per successful test before giving up.
      @_max_discard_ratio = 10
      # Maximum size for value generators to use (-max...max)
      @_max_size = 0x100
      # Maximum number of shrink attempts (default of half of max unsigned int
      # on the system architecture adopted from QuickCheck)
      @_max_shrinks = (((1 << (1.size * 8)) - 1) / 2).to_s(16)

      super
    end

    def property(&f)
      prop = Minitest::Proptest::Property.new(
        f,
        random: @_random,
        max_success: @_max_success,
        max_discard_ratio: @_max_discard_ratio,
        max_size: @_max_size,
        max_shrinks: @_max_shrinks
      )
      prop.run!

      assert (prop.status.valid? && !prop.trivial), ->() { prop.explain }
    end
  end
end
