# frozen_string_literal: true

require 'minitest/proptest/gen/value_generator'

module Minitest
  module Proptest
    # Generic value generation and shrinking implementations, and
    # support for built-in types.
    class Gen
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
        constructor = ->(_c1) do
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

        instance_variable_get(:@_generators)[klass] = new_class
        self.const_set("#{klass.name}Gen".split('::').last, new_class)
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
            classes[1..].map do |k|
              if k.is_a?(Array)
                self.for(*k)
              else
                self.for(k)
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
          candidates << y if y.abs < x.abs
          y = (y / 2.0).to_i
        end

        candidates
      end

      score_float = ->(f) do
        if f.nan? || f.infinite?
          0
        else
          f.abs.ceil
        end
      end

      float_shrink = ->(x) do
        return [] if x.nan? || x.infinite? || x.zero?

        candidates = [Float::NAN, Float::INFINITY]
        y = x

        until y.zero? || y.to_f.infinite? || y.to_f.nan?
          candidates << (x - y)
          y = (y / 2.0).to_i
        end

        score = score_float.call(x)
        candidates.reduce([]) do |cs, c|
          cs + (score_float.call(c) < score ? [c.to_f] : [])
        end
      end

      score_complex = ->(c) do
        r = if c.real.to_f.nan? || c.real.to_f.infinite?
              0
            else
              c.real.abs.ceil
            end
        i = if c.imaginary.to_f.nan? || c.imaginary.to_f.infinite?
              0
            else
              c.imaginary.abs.ceil
            end
        r + i
      end

      complex_shrink = ->(x) do
        rs = float_shrink.call(x.real)
        is = float_shrink.call(x.imaginary)

        score = score_complex.call(x)
        rs.flat_map { |real| is.map { |imag| Complex(real, imag) } }
          .reject { |c| score_complex.call(c) >= score }
          .uniq
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
          [xs2] + list_remove.call(k, (n - k), xs2).map { |ys| xs1 + ys }
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
          [h1, h2] + list_remove.call(k, (n - k), h2).map { |ys| h1.merge(ys.to_h) }
        end
      end

      range_shrink = ->(f, r) do
        xs = f.call(r.first)
        ys = f.call(r.last)

        xs.flat_map { |x| ys.map { |y| x <= y ? (x..y) : (y..x) } }
      end

      score_rational = ->(r) do
        (r.numerator * r.denominator).abs
      end

      rational_shrink = ->(r) do
        ns = integral_shrink.call(r.numerator)
        ds = integral_shrink.call(r.denominator)

        score = score_rational.call(r)
        ns.flat_map do |n|
          ds.reduce([]) do |rs, d|
            if d.zero?
              rs
            else
              rational = Rational(n, d)
              rs + (score_rational.call(rational) < score ? [rational] : [])
            end
          end
        end
      end

      hash_shrink = ->(_fk, _fv, h) do
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
        j = if (i & SIGN_BIT).zero?
              i
            else
              -(((i & (MAX_SIZE ^ SIGN_BIT)) - 1) ^ (MAX_SIZE ^ SIGN_BIT))
            end
        integral_shrink.call(j)
      end

      generator_for(Int8) do
        r = sized(0xff)
        (r & 0x80).zero? ? r : -((r ^ 0x7f) - 0x7f)
      end.with_shrink_function(&integral_shrink)

      generator_for(Int16) do
        r = sized(0xffff)
        (r & 0x8000).zero? ? r : -((r ^ 0x7fff) - 0x7fff)
      end.with_shrink_function(&integral_shrink)

      generator_for(Int32) do
        r = sized(0xffffffff)
        (r & 0x80000000).zero? ? r : -((r ^ 0x7fffffff) - 0x7fffffff)
      end.with_shrink_function(&integral_shrink)

      generator_for(Int64) do
        r = sized(0xffffffffffffffff)
        if (r & 0x8000000000000000).zero?
          r
        else
          -((r ^ 0x7fffffffffffffff) - 0x7fffffffffffffff)
        end
      end.with_shrink_function(&integral_shrink)

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
          .unpack1('f')
      end.with_shrink_function do |f|
        float_shrink.call(f)
      end.with_score_function(&score_float)

      float64build = ->(bits) do
        (0..7)
          .map { |y| ((bits & (0xff << (8 * y))) >> (8 * y)).chr }
          .join
          .unpack1('d')
      end

      generator_for(Float64) do
        bits = sized(0xffffffffffffffff)
        float64build.call(bits)
      end.with_shrink_function do |f|
        float_shrink.call(f)
      end.with_score_function(&score_float)

      generator_for(Float) do
        bits = sized(0xffffffffffffffff)
        float64build.call(bits)
      end.with_shrink_function do |f|
        float_shrink.call(f)
      end.with_score_function(&score_float)

      generator_for(Complex) do
        real = sized(0xffffffffffffffff)
        imag = sized(0xffffffffffffffff)
        Complex(float64build.call(real), float64build.call(imag))
      end.with_shrink_function do |c|
        complex_shrink.call(c)
      end.with_score_function(&score_complex)

      generator_for(ASCIIChar) do
        sized(0x7f).chr
      end.with_shrink_function do |c|
        integral_shrink.call(c.ord).reject(&:negative?).map(&:chr)
      end.with_score_function(&:ord)

      generator_for(Char) do
        sized(0xff).chr
      end.with_shrink_function do |c|
        integral_shrink.call(c.ord).reject(&:negative?).map(&:chr)
      end.with_score_function(&:ord)

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
      end.with_empty { '' }

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
      end.with_empty { {} }

      generator_for(Range) do |x|
        (x..x)
      end.with_shrink_function(&range_shrink).with_score_function do |f, r|
        r.to_a.reduce(1) do |c, x|
          y = f.call(x).abs
          c * (y > 0 ? y + 1 : 1)
        end.to_i * r.to_a.length
      end.with_append(2, 2) do |ra, rb|
        xs = [ra.first, ra.last, rb.first, rb.last].sort
        (xs.first..xs.last)
      end

      generator_for(Rational) do
        n = sized(MAX_SIZE)
        d = sized(MAX_SIZE - 1) + 1
        if (n & SIGN_BIT).zero?
          Rational(n, d)
        else
          Rational(-(((n & (MAX_SIZE ^ SIGN_BIT)) - 1) ^ (MAX_SIZE ^ SIGN_BIT)), d)
        end
      end.with_shrink_function(&rational_shrink)
         .with_score_function(&score_rational)

      generator_for(Bool) do
        sized(0x1).odd?
      end.with_score_function do |_|
        1
      end
    end
  end
end
