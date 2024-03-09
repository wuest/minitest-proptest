# frozen_string_literal: true

module Minitest
  module Proptest
    class Gen
      class ValueGenerator
        attr_accessor :entropy
        attr_writer :type_parameters

        def self.with_shrink_function(&f)
          define_method(:shrink_function, &f)
          self
        end

        def self.with_score_function(&f)
          define_method(:score_function, &f)
          self
        end

        def self.with_append(bound_min, bound_max, &f)
          define_singleton_method(:bound_max) { bound_max }
          define_singleton_method(:bound_min) { bound_min }
          define_method(:append) do |other|
            @value = f.call(value, other.value)
            self
          end
          self
        end

        def self.with_empty(&f)
          define_singleton_method(:empty) do |gen|
            temp = new(gen)
            temp.instance_variable_set(:@value, f.call)
            temp
          end
          self
        end

        def self.bound_max
          1
        end

        def self.bound_min
          0
        end

        # append is not expected to be called unless overridden
        def append(other)
          self
        end

        def self.empty(gen)
          self.new(gen)
        end

        def force(v)
          temp = self.class.new(ArgumentError)
          temp.instance_variable_set(:@value, v)
          temp.type_parameters = @type_parameters
          temp
        end

        def generate_value
          gen = @generated.reduce(@generator) do |gen, val|
            gen.call(val)
            gen
          end

          while gen.is_a?(Proc) || gen.is_a?(Method)
            gen = gen.call(*@type_parameters.map(&:value))
            if gen.is_a?(ValueGenerator)
              gen = gen.value
            end
          end

          gen
        end

        def value
          return false if @value == false

          @value ||= generate_value
        end

        def prefix_entropy_generation(vals)
          @generated = vals + @generated
        end

        def score
          value
          fs = @type_parameters.map { |x| x.method(:score_function) }
          score_function(*fs, value)
        end

        def score_function(v)
          v.to_i.abs
        end

        def shrink_candidates
          fs = @type_parameters.map { |x| x.method(:shrink_function) }
          os = score
          candidates = shrink_function(*fs, value)
          candidates
            .map    { |c| [force(c).score, c] }
            .reject { |(s, _)| s > os }
            .sort   { |x, y| x.first <=> y.first }
            .uniq
        end

        def shrink_function(x)
          [x.itself]
        end

        def shrink_parameter(x)
          @shrink_parameter.call(x)
        end

        # Generator helpers

        def sized(n)
          entropy.call(n + 1)
        end

        def one_of(r)
          r.to_a[sized(r.to_a.length - 1)]
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
      class Float32 < Float; end
      class Float64 < Float; end
      class ASCIIChar < String; end
      class Char < String; end
      class Bool < TrueClass; end

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

      def self.generator_for(klass, &f)
        new_class = Class.new(ValueGenerator)
        new_class.define_method(:initialize) do |g|
          @entropy         = ->(b = MAX_SIZE) { (@generated << g.rand(b)).last }
          @generated       = []
          @generator       = self.method(:generator).curry
          @parent_gen      = g
          @value           = nil
          @type_parameters = []
        end

        new_class.define_method(:generator, &f)

        instance_variable_get(:@_generators)[klass] = new_class #.method(:new)
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
        case classes.length
        when 0
          raise(TypeError, "A generator for #{classes.join(' ')} is not known.  Try adding it with Gen.generator_for.")
        when 1
          gen = generators[classes.first]
          if gen.bound_max > 1
            c = rand(gen.bound_max - gen.bound_min + 1) + gen.bound_min
            c.times.reduce(gen.empty(self)) { |g, _| g.append(gen.new(self)) }
          else
            gen.new(self)
          end
        else
          classgen = ->() do
            classes[1..-1].map do |c|
              if c.is_a?(Array)
                self.for(*c)
              else
                self.for(c)
              end
            end
          end
          cs = classgen.call

          gen = generators[classes.first]
          typegen = gen.bound_min < 1 ? gen.empty(self) : gen.new(self)
          typegen.type_parameters = cs
          typegen.prefix_entropy_generation(cs)

          if gen.bound_max > 1
            c = rand(gen.bound_max - gen.bound_min + 1) + gen.bound_min
            c.times.reduce(typegen) do |g, _|
              cs2 = classgen.call
              g2 = gen.new(self)
              g2.type_parameters = cs2
              g2.prefix_entropy_generation(cs2)
              g.append(g2)
            end
          else
            typegen
          end
        end
      end

      # Common shrinking machinery for all integral types.  This includes chars,
      # etc.
      integral_shrink = ->(x) do
        candidates = []
        y = x

        until y == 0
          candidates << (x - y)
          candidates << y
          # Prevent negative integral from preventing termination
          y = (y / 2.0).to_i
        end

        candidates
          .flat_map { |i| [i - 1, i, i + 1] }
          .reject   { |i| i.abs >= x.abs }
      end

      float_shrink = ->(x) do
        candidates = [Float::NAN, Float::INFINITY]
        y = x

        until y == 0 || y
          candidates << (x - y)
          y = (y / 2.0).to_i
        end

        candidates
          .flat_map { |i| [i - 1, i, i + 1] }
          .reject   { |i| i.abs >= x.abs }
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
        candidates = [[]]
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
          h1 = xs1.reduce({}) { |c, e| c.merge({ e => h[e] }) }
          h2 = xs2.reduce({}) { |c, e| c.merge({ e => h[e] }) }
          [h1, h2] + list_remove.call(k, (n-k), h2).map { |ys| h1.merge(ys.to_h) }
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
      generator_for(Integer) do
        r = sized(MAX_SIZE)
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

      generator_for(Int8) do
        r = sized(0xff)
        (r & 0x80).zero? ? r : -(((r & 0x7f) - 1) ^ 0x7f)
      end.with_shrink_function do |i|
        i = (i & 0x80).zero? ? i : -(((i & 0x7f) - 1) ^ 0x7f)
        integral_shrink.call(i)
      end

      generator_for(Int16) do
        r = sized(0xffff)
        (r & 0x8000).zero? ? r : -(((r & 0x7fff) - 1) ^ 0x7fff)
      end.with_shrink_function do |i|
        i = (i & 0x8000).zero? ? i : -(((i & 0x7fff) - 1) ^ 0x7fff)
        integral_shrink.call(i)
      end

      generator_for(Int32) do
        r = sized(0xffffffff)
        (r & 0x80000000).zero? ? r : -(((r & 0x7fffffff) - 1) ^ 0x7fffffff)
      end.with_shrink_function do |i|
        i = if (i & 0x80000000).zero?
              i
            else
              -(((i & 0x7fffffff) - 1) ^ 0x7fffffff)
            end
        integral_shrink.call(i)
      end

      generator_for(Int64) do
        r = sized(0xffffffffffffffff)
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

      generator_for(UInt8) do
        sized(0xff)
      end.with_shrink_function do |i|
        integral_shrink.call(i).reject(&:negative?)
      end

      generator_for(UInt16) do
        sized(0xffff)
      end.with_shrink_function do |i|
        integral_shrink.call(i).reject(&:negative?)
      end

      generator_for(UInt32) do
        sized(0xffffffff)
      end.with_shrink_function do |i|
        integral_shrink.call(i).reject(&:negative?)
      end

      generator_for(UInt64) do
        sized(0xffffffffffffffff)
      end.with_shrink_function do |i|
        integral_shrink.call(i).reject(&:negative?)
      end

      generator_for(Float32) do
        # There is most likely a faster way to do this which doesn't involve
        # FFI, but it was faster than manual bit twiddling in ruby
        bits = sized(0xffffffff)
        (0..3)
          .map { |y| ((bits & (0xff << (8 * y))) >> (8 * y)).chr }
          .join
          .unpack('f')
          .first
      end.with_shrink_function do |f|
        float_shrink.call(f)
      end.with_score_function do |f|
        if f.nan? || f.infinite?
          0
        else
          f.abs.ceil
        end
      end

      generator_for(Float64) do
        bits = sized(0xffffffffffffffff)
        (0..7)
          .map { |y| ((bits & (0xff << (8 * y))) >> (8 * y)).chr }
          .join
          .unpack('d')
          .first
      end.with_shrink_function do |f|
        float_shrink.call(f)
      end.with_score_function do |f|
        if f.nan? || f.infinite?
          0
        else
          f.abs.ceil
        end
      end

      generator_for(Float) do
        bits = sized(0xffffffffffffffff)
        (0..7)
          .map { |y| ((bits & (0xff << (8 * y))) >> (8 * y)).chr }
          .join
          .unpack('d')
          .first
      end.with_shrink_function do |f|
        float_shrink.call(f)
      end.with_score_function do |f|
        if f.nan? || f.infinite?
          0
        else
          f.abs.ceil
        end
      end

      generator_for(ASCIIChar) do
        sized(0x7f).chr
      end.with_shrink_function do |c|
        integral_shrink.call(c.ord).reject(&:negative?).map(&:chr)
      end.with_score_function do |c|
        c.ord
      end

      generator_for(Char) do
        sized(0xff).chr
      end.with_shrink_function do |c|
        integral_shrink.call(c.ord).reject(&:negative?).map(&:chr)
      end.with_score_function do |c|
        c.ord
      end

      generator_for(String) do
        sized(0xff).chr
      end.with_shrink_function do |s|
        xs = list_shrink.call(integral_shrink, s.chars.map(&:ord))
        xs.map { |str| str.map { |t| t & 0xff }.map(&:chr).join }
      end.with_score_function do |s|
        s.chars.map(&:ord).reduce(1) do |c, x|
          y = x.abs
          c * (y > 0 ? y + 1 : 1)
        end
      end.with_append(0, 0x20) do |x, y|
        x + y
      end.with_empty { "" }

      generator_for(Array) do |x|
        [x]
      end.with_shrink_function(&list_shrink).with_score_function do |f, xs|
        xs.reduce(1) do |c, x|
          y = f.call(x).abs
          c * (y > 0 ? y + 1 : 1)
        end.to_i * xs.length
      end.with_append(0, 0x10) do |xs, ys|
        xs + ys
      end.with_empty { [] }

      generator_for(Hash) do |key, value|
        { key => value }
      end.with_shrink_function(&hash_shrink).with_score_function do |fk, fv, h|
        h.reduce(1) do |c, (k, v)|
          sk = fk.call(k).abs
          sv = fv.call(v).abs
          c * ((sk > 0 ? sk + 1 : 1) + (sv > 0 ? sv + 1 : 1))
        end
      end.with_append(0, 0x10) do |xm, ym|
        xm.merge(ym)
      end.with_empty { Hash.new }

      generator_for(Bool) do
        sized(0x1).even? ? false : true
      end.with_score_function do |_|
        1
      end
    end
  end
end
