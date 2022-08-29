module Minitest
  class Proptest < Minitest::Test
    class Gen
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

      generator_for(String) do |r|
        i = r.rand(0xff)
        Result.new([i], i.chr)
      end

      generator_for(Integer) do |r|
        i = r.rand(0xffffffffffffffff)
        Result.new([i], i)
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
