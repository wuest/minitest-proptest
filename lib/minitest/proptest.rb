require 'minitest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'
require 'minitest/proptest/version'

module Minitest
  module Proptest
    DEFAULT_RANDOM = Random.method(:new)
    DEFAULT_MAX_SUCCESS = 100
    DEFAULT_MAX_DISCARD_RATIO = 10
    DEFAULT_MAX_SIZE = 0x100
    DEFAULT_MAX_SHRINKS = (((1 << (1.size * 8)) - 1) / 2)

    def self.set_seed(seed)
      self.instance_variable_set(:@_random_seed, seed)
    end
  end
end

module Kernel
  def generator_for(klass, &f)
    ::Minitest::Proptest::Gen.generator_for(klass, &f)
  end
  private :generator_for
end
