module Minitest
  class Proptest < Minitest::Test
    class Gen
      class ValueGenerator
        attr_accessor :entropy
        attr_writer :type_parameters

        def force(v)
          temp = self.class.new(ArgumentError)
          temp.instance_variable_set(:@value, v)
          temp.type_parameters = @type_parameters
          temp
        end

        def self.with_shrink_function(&f)
          define_method(:shrink_function, &f)
          self
        end

        def self.with_score_function(&f)
          define_method(:score_function, &f)
          self
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

        def score
          fs = @type_parameters.map { |x| x.method(:score_function) }
          score_function(*fs, value)
        end

        def score_function(v)
          v.to_i.abs
        end

        def shrink_candidates
          fs = @type_parameters.map { |x| x.method(:shrink_function) }
          candidates = shrink_function(*fs, value)
          candidates
            .map  { |c| [force(c).score, c] }
            .sort { |x, y| x.first <=> y.first }
            .uniq
        end

        def shrink_function(x)
          [x.itself]
        end

        def shrink_parameter(x)
          @shrink_parameter.call(x)
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
      class ASCIIChar < String; end
      class Char < String; end

      # Default maximum random value size is the local architecture's word size
      MAX_SIZE = ((1 << (1.size * 8)) - 1)
      SIGN_BIT = (1 << ((1.size * 8) - 1))

      attr_reader :generated

      instance_variable_set(:@_generators, {})

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
          @entropy         = ->() { (@generated << g.rand(b)).last }
          @generated       = []
          @generator       = f.curry
          @parent_gen      = g
          @value           = nil
          @type_parameters = []
        end

        instance_variable_get(:@_generators)[klass] = new_class.method(:new)
        self.const_set((klass.name + 'Gen').split('::').last, new_class)
        new_class
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
          cs = classes[1..-1].map do |c|
            if c.is_a?(Array)
              self.for(*c)
            else
              generators[c].call(self)
            end
          end
          gen = generators[classes.first].call(self)
          gen.type_parameters = cs
          gen.prefix_entropy_generation(cs)
          gen
        end
      end

      # Common shrinking machinery for all integral types.  This includes chars,
      # etc.
      integral_shrink = ->(x) do
        candidates = []
        candidates << -x if x < 0 && -x > x
        y = x

        until y == 0
          candidates << (x - y)
          candidates << y
          # Prevent negative integral from preventing termination
          y = (y / 2.0).to_i
        end

        candidates.flat_map { |x| [x - 1, x, x + 1] }
      end

      # List shrink adapted from QuickCheck
      list_remove = ->(k, n, xs) do
        xs1 = xs.take(k)
        xs2 = xs.drop(k)
        if k > n
          []
        elsif xs2.empty?
          [[]]
        else
          [xs2] + list_remove.call(k, (n-k), xs2).map { |ys| xs1 + ys }
        end
      end

      shrink_one = ->(f, xs) do
        if xs.empty?
          []
        else
          x  = xs.first
          xs = xs.drop(1)

          ys = f.call(x).map { |y| [y] + xs }
          zs = shrink_one.call(f, xs).map { |z| [x] + z }
          ys + zs
        end
      end

      list_shrink = ->(f, xs) do
        candidates = []
        n          = xs.length
        k          = n
        while k > 0
          candidates += list_remove.call(k, n, xs)
          k /= 2
        end
        candidates + shrink_one.call(f, xs)
      end

      hash_remove = ->(k, n, h) do
        xs = h.keys
        xs1 = xs.take(k)
        xs2 = xs.drop(k)

        if k > n
          []
        elsif xs2.empty?
          [{}]
        else
          h1 = xs1.reduce({}) { |c, e| c.merge(h[e]) }
          h2 = xs2.reduce({}) { |c, e| c.merge(h[e]) }
          [h1, h2] + list_remove.call(k, (n-k), xs2).map { |ys| h1.merge(ys) }
        end
      end

      hash_shrink = ->(fk, fv, h) do
        candidates = []
        n          = h.length
        k          = n
        while k > 0
          candidates += hash_remove.call(k, n, h)
          k /= 2
        end
        candidates
      end

      # Use two's complement for all signed integers in order to optimize for
      # random values to shrink towards 0.
      generator_for(Integer, MAX_SIZE + 1) do |r|
        r &= MAX_SIZE
        if (r & SIGN_BIT).zero?
          r
        else
          -(((r & (MAX_SIZE ^ SIGN_BIT)) - 1) ^ (MAX_SIZE ^ SIGN_BIT))
        end
      end.with_shrink_function do |i|
        i = if (i & SIGN_BIT).zero?
              i
            else
              -(((i & (MAX_SIZE ^ SIGN_BIT)) - 1) ^ (MAX_SIZE ^ SIGN_BIT))
            end
        integral_shrink.call(i)
      end

      generator_for(Int8, 0x100) do |r|
        r &= 0xff
        (r & 0x80).zero? ? r : -(((r & 0x7f) - 1) ^ 0x7f)
      end.with_shrink_function do |i|
        i = (i & 0x80).zero? ? i : -(((i & 0x7f) - 1) ^ 0x7f)
        integral_shrink.call(i)
      end

      generator_for(Int16, 0x10000) do |r|
        r &= 0xffff
        (r & 0x8000).zero? ? r : -(((r & 0x7fff) - 1) ^ 0x7fff)
      end.with_shrink_function do |i|
        i = (i & 0x8000).zero? ? r : -(((i & 0x7fff) - 1) ^ 0x7fff)
        integral_shrink.call(i)
      end

      generator_for(Int32, 0x100000000) do |r|
        r &= 0xffffffff
        (r & 0x80000000).zero? ? r : -(((r & 0x7fffffff) - 1) ^ 0x7fffffff)
      end.with_shrink_function do |i|
        i = if (i & 0x80000000).zero?
              i
            else
              -(((i & 0x7fffffff) - 1) ^ 0x7fffffff)
            end
        integral_shrink.call(i)
      end

      generator_for(Int64, 0x10000000000000000) do |r|
        r &= 0xffffffffffffffff
        if (r & 0x8000000000000000).zero?
          r
        else
          -(((r & 0x7fffffffffffffff) - 1) ^ 0x7fffffffffffffff)
        end
      end.with_shrink_function do |i|
        i = if (i & 0x8000000000000000).zero?
              i
            else
              -(((i & 0x7fffffffffffffff) - 1) ^ 0x7fffffffffffffff)
            end
        integral_shrink.call(i)
      end

      generator_for(UInt8, 0x100) do |r|
        r & 0xff
      end.with_shrink_function(&integral_shrink)

      generator_for(UInt16, 0x10000) do |r|
        r & 0xffff
      end.with_shrink_function(&integral_shrink)

      generator_for(UInt32, 0x100000000) do |r|
        r & 0xffffffff
      end.with_shrink_function(&integral_shrink)

      generator_for(UInt64, 0x10000000000000000) do |r|
        r & 0xffffffffffffffff
      end.with_shrink_function(&integral_shrink)

      generator_for(ASCIIChar, 0x80) do |r|
        (r & 0x7f).chr
      end.with_shrink_function do |c|
        integral_shrink.call(c.ord).abs
      end.with_score_function do |c|
        c.ord
      end


      generator_for(Char, 0x100) do |r|
        (r & 0xff).chr
      end.with_shrink_function do |c|
        integral_shrink.call(c.ord).abs
      end.with_score_function do |c|
        c.ord
      end

      generator_for(String, 0x100) do |r|
        (r & 0xff).chr
      end

      generator_for(Array) do |x|
        [x]
      end.with_shrink_function(&list_shrink).with_score_function do |f, xs|
        xs.reduce(1) do |c, x|
          y = f.call(x).abs
          c * (y > 0 ? y + 1 : 1)
        end.to_i * xs.length
      end

      generator_for(Hash) do |key, value|
        { key => value }
      end.with_shrink_function(&hash_shrink).with_score_function do |fk, fv, h|
        h.reduce(1) do |c, (k, v)|
          sk = fk.call(k).abs
          sv = fv.call(v).abs
          c * ((sk > 0 ? sk + 1 : 1) + (sv > 0 ? sv + 1 : 1))
        end
      end
    end
  end
end
