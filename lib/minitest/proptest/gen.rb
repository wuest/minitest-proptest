module Minitest
  class Proptest < Minitest::Test
    class Gen
      class ValueGenerator
        attr_accessor :entropy, :value

        def self.force(v)
          temp = new(ArgumentError)
          temp.instance_variable_set(:@generated, v)
          temp.instance_variable_set(:@value, temp.generate_value)
          temp
        end

        def generate_value
          gen = @generated.reduce(@generator) do |gen, val|
            gen.call(val)
            gen
          end

          while gen.is_a?(Proc) || gen.is_a?(Method)
            gen = gen.call(@entropy.call())
            if gen.is_a?(ValueGenerator)
              gen = gen.value
            end
          end

          gen
        end

        def value
          @value ||= generate_value
        end

        def prefix_entropy_generation(vals)
          @generated = vals + @generated
        end
      end

      class Int8 < Integer; end
      class Int16 < Integer; end
      class Int32 < Integer; end
      class Int64 < Integer; end
      class UInt8 < Integer; end
      class UInt16 < Integer; end
      class UInt32 < Integer; end
      class UInt64 < Integer; end
      class Char < String; end

      # Default maximum random value size is the local architecture's word size
      MAX_SIZE = ((1 << (1.size * 8)) - 1)
      SIGN_BIT = (1 << ((1.size * 8) - 1))

      instance_variable_set(:@_generators, {})

      def self.generate_new(klass)
        instance_variable_get(:@_generators)[klass]
      end

      def self.create_type_constructor(arity, classes)
        constructor = ->(c1) do
          if classes.length == arity
            f.call(*classes)
          else
            ->(c2) { constructor.call(c2) }
          end
        end
      end

      def self.generator_for(klass, max_size = MAX_SIZE, &f)
        new_class = Class.new(ValueGenerator)
        new_class.define_method(:initialize) do |g, b = max_size|
          @entropy    = ->() { (@generated << g.rand(b)).last }
          @generated  = []
          @generator  = f.curry
          @parent_gen = g
          @value      = nil
        end

        instance_variable_get(:@_generators)[klass] = new_class.method(:new)
        self.const_set((klass.name + 'Gen').split('::').last, new_class)
      end

      def initialize(random)
        @random    = random
        @generated = []
      end

      def rand(max_size = MAX_SIZE)
        (@generated << @random.rand(max_size)).last
      end

      def for(*classes)
        generators = self.class.instance_variable_get(:@_generators)
        gen = case classes.length
        when 0
          raise(TypeError, "A generator for #{classes.join(' ')} is not known.  Try adding it with Gen.generator_for.")
        when 1
          generators[classes.first].call(self)
        else
          c = classes[1..-1].map do |c|
            if c.is_a?(Array)
              self.for(*c)
            else
              generators[c].call(self)
            end
          end
          gen = generators[classes.first].call(self)
          gen.prefix_entropy_generation(c)
          gen
        end
      end

      # Use two's complement for all signed integers in order to optimize for
      # random values to shrink towards 0.
      generator_for(Integer, MAX_SIZE + 1) do |r|
        r &= MAX_SIZE
        if (r & SIGN_BIT).zero?
          r
        else
          (r & (MAX_SIZE ^ SIGN_BIT) - 1) ^ (MAX_SIZE ^ SIGN_BIT)
        end
      end

      generator_for(Int8, 0x100) do |r|
        r &= 0xff
        (r & 0x80).zero? ? r : ((r & 0x7f) - 1) ^ 0x7f
      end

      generator_for(Int16, 0x10000) do |r|
        r &= 0xffff
        (r & 0x8000).zero? ? r : ((r & 0x7fff) - 1) ^ 0x7fff
      end

      generator_for(Int32, 0x100000000) do |r|
        r &= 0xffffffff
        (r & 0x80000000).zero? ? r : ((r & 0x7fffffff) - 1) ^ 0x7fffffff
      end

      generator_for(Int64, 0x10000000000000000) do |r|
        r &= 0xffffffffffffffff
        if (r & 0x8000000000000000).zero?
          r
        else
          ((r & 0x7fffffffffffffff) - 1) ^ 0x7fffffffffffffff
        end
      end

      generator_for(UInt8, 0x100) do |r|
        r & 0xff
      end

      generator_for(UInt16, 0x10000) do |r|
        r & 0xffff
      end

      generator_for(UInt32, 0x100000000) do |r|
        r & 0xffffffff
      end

      generator_for(UInt64, 0x10000000000000000) do |r|
        r & 0xffffffffffffffff
      end

      generator_for(Char, 0x100) do |r|
        (r & 0xff).chr
      end

      generator_for(String, 0x100) do |r|
        (r & 0xff).chr
      end

      generator_for(Array) do |r|
        [r]
      end

      generator_for(Hash) do |key, value|
        { key => value }
      end
    end
  end
end
