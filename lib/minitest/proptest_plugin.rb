# frozen_string_literal: true

require 'minitest'
require 'minitest/proptest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'
require 'minitest/proptest/version'

module Minitest
  def self.plugin_proptest_init(options)
    %i[Int8 Int16 Int32 Int64
       UInt8 UInt16 UInt32 UInt64
       Float32 Float64
       ASCIIChar Char
       Bool
      ].each do |const|
      unless Minitest::Assertions.const_defined?(const)
        ::Minitest::Assertions.const_set(const, ::Minitest::Proptest::Gen.const_get(const))
      end
    end

    Proptest.set_seed(options[:seed]) if options.key?(:seed)
  end

  def self.plugin_proptest_options(opts, options); end

  module Assertions
    def property(&f)
      self.assertions += 1

      random_thunk = if Proptest.instance_variable_defined?(:@_random_seed)
                       r = Proptest.instance_variable_get(:@_random_seed)
                       ->() { Proptest::DEFAULT_RANDOM.call(r) }
                     else
                       Proptest::DEFAULT_RANDOM
                     end

      prop = Minitest::Proptest::Property.new(
        f,
        random: random_thunk,
        max_success: Proptest::DEFAULT_MAX_SUCCESS,
        max_discard_ratio: Proptest::DEFAULT_MAX_DISCARD_RATIO,
        max_size: Proptest::DEFAULT_MAX_SIZE,
        max_shrinks: Proptest::DEFAULT_MAX_SHRINKS
      )
      prop.run!

      raise Minitest::Assertion, prop.explain unless prop.status.valid? && !prop.trivial
    end
  end
end
