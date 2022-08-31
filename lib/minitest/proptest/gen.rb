module Minitest
  class Proptest < Minitest::Test
    class Gen
      class Int8 < Integer; end
      class Int16 < Integer; end
      class Int32 < Integer; end
      class Int64 < Integer; end
      class UInt8 < Integer; end
      class UInt16 < Integer; end
      class UInt32 < Integer; end
      class UInt64 < Integer; end

      Result = Struct.new(:entropy, :value)

      instance_variable_set(:@_generators, {})

      def self.generator_for(klass, &f)
        instance_variable_get(:@_generators)[klass] = f
      end

      def initialize(random)
        @random = random
      end

      def for(*classes)
        generators = self.class.instance_variable_get(:@_generators)
        gen = classes.reduce(generators) do |g,c|
          case g
          when Hash
            g[c]
          when Proc
            g.call(c)
          else
            g
          end
        end

        unless gen.is_a?(Proc)
          raise(TypeError, "A generator for #{classes.join(' ')} is not known.  Try adding it with Gen.generator_for.")
        end

        gen.call(@random)
      end

      # Integer assumes the system's word size for max
      generator_for(Integer) do |r|
        @__arch_intsize ||= ((1 << (1.size * 8)) - 1)
        i = r.rand(@__arch_intsize) - (@__arch_intsize / 2 + 1)
        Result.new([i], i)
      end

      generator_for(Int8) do |r|
        i = r.rand(-0x80..0x7f)
        Result.new([i], i)
      end

      generator_for(Int16) do |r|
        i = r.rand(-0x8000..0x7fff)
        Result.new([i], i)
      end

      generator_for(Int32) do |r|
        i = r.rand(-0x80000000..0x7fffffff)
        Result.new([i], i)
      end

      generator_for(Int64) do |r|
        i = r.rand(0xffffffffffffffff) - 0x8000000000000000
        Result.new([i], i)
      end

      generator_for(UInt8) do |r|
        i = r.rand(0xff)
        Result.new([i], i)
      end

      generator_for(UInt16) do |r|
        i = r.rand(0xffff)
        Result.new([i], i)
      end

      generator_for(UInt32) do |r|
        i = r.rand(0xffffffff)
        Result.new([i], i)
      end

      generator_for(UInt64) do |r|
        i = r.rand(0xffffffffffffffff)
        Result.new([i], i)
      end

      generator_for(String) do |r|
        i = r.rand(0xff)
        Result.new([i], i.chr)
      end

      generator_for(Array) do |c|
        p 'hi2'
        k = instance_variable_get(:@_generators)[c]
        ->(r) do
          r1 = k.call(r)
          Result.new(r1.entropy, r1.value)
        end
      end

      generator_for(Hash) do |c|
        k1 = instance_variable_get(:@_generators)[c]
        ->(c2) do
          k2 = instance_variable_get(:@_generators)[c2]
          ->(r) do
            r1 = k1.call(r)
            r2 = k2.call(r)
            Result.new(r1.entropy + r2.entropy, { r1.value => r2.value })
          end
        end
      end
    end
  end
end
