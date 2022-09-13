module Minitest
  module Proptest
    DEFAULT_RANDOM = Random.method(:new)
    DEFAULT_MAX_SUCCESS = 100
    DEFAULT_MAX_DISCARD_RATIO = 10
    DEFAULT_MAX_SIZE = 0x100
    DEFAULT_MAX_SHRINKS = (((1 << (1.size * 8)) - 1) / 2)
  end
end
