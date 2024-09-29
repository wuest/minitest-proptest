# frozen_string_literal: true

require 'test_helper'

class PropertyTest < Minitest::Test
  def test_shrink_int8
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Int8)
    property do
      n = arbitrary Int8
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0x7f && x >= -0x80 &&
          ( n < 0 ? x <= 1 : x >= -1 )
      end
    end
  end

  def test_shrink_int16
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Int16)
    property do
      n = arbitrary Int16
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0x7fff && x >= -0x8000 &&
          ( n < 0 ? x <= 1 : x >= -1 )
      end
    end
  end

  def test_shrink_int32
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Int32)
    property do
      n = arbitrary Int32
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0x7fffffff && x >= -0x80000000 &&
          ( n < 0 ? x <= 1 : x >= -1 )
      end
    end
  end

  def test_shrink_int64
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Int64)
    property do
      n = arbitrary Int64
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0x7fffffffffffffff && x >= -0x8000000000000000 &&
          ( n < 0 ? x <= 1 : x >= -1 )
      end
    end
  end

  def test_shrink_int
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Integer)
    property do
      n = arbitrary Integer
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0x7fffffffffffffff && x >= -0x8000000000000000 &&
          ( n < 0 ? x <= 1 : x >= -1 )
      end
    end
  end

  def test_shrink_uint8
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(UInt8)
    property do
      n = arbitrary UInt8
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0xff &&
          x >= 0
      end
    end
  end

  def test_shrink_uint16
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(UInt16)
    property do
      n = arbitrary UInt16
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0xffff &&
          x >= 0
      end
    end
  end

  def test_shrink_uint32
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(UInt32)
    property do
      n = arbitrary UInt32
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0xffffffff &&
          x >= 0
      end
    end
  end

  def test_shrink_uint64
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(UInt64)
    property do
      n = arbitrary UInt64
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs <= n.abs &&
          score == x.abs &&
          x <= 0xffffffffffffffff &&
          x >= 0
      end
    end
  end

  def test_shrink_float32
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Float32)
    property do
      n = arbitrary Float32
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        if x.nan? || x.infinite?
          score.zero?
        else
          score == x.abs.ceil && x.abs <= n.abs
        end
      end
    end
  end

  def test_shrink_float64
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Float64)
    property do
      n = arbitrary Float64
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        if x.nan? || x.infinite?
          score.zero?
        else
          score == x.abs.ceil && x.abs <= n.abs
        end
      end
    end
  end

  def test_shrink_float
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Float)
    property do
      n = arbitrary Float
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        if x.nan? || x.infinite?
          score.zero?
        else
          score == x.abs.ceil && x.abs <= n.abs
        end
      end
    end
  end

  def test_shrink_complex
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Complex)
    property do
      n = arbitrary Complex
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, c|
        r = c.real
        i = c.imaginary
        sr = (r.to_f.nan? || r.to_f.infinite?) ? 0 : r.abs.ceil
        si = (i.to_f.nan? || i.to_f.infinite?) ? 0 : i.abs.ceil
        score == sr + si
      end
    end
  end

  def test_shrink_string
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(String)
    property do
      s = arbitrary String
      g = gen.force(s)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        score <= g.score &&
          x.length <= s.length
      end
    end
  end

  def test_shrink_array
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Array, Int8)
    property do
      a = arbitrary Array, Int8
      g = gen.force(a)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        score <= g.score &&
          x.length <= a.length
      end
    end
  end

  def test_shrink_set
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Set, Int8)
    property do
      a = arbitrary Set, Int8
      g = gen.force(a)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        score <= g.score &&
          x.length <= a.length
      end
    end
  end

  def test_shrink_range
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Range, Int8)
    property do
      a = arbitrary Range, Int8
      g = gen.force(a)
      candidates = g.shrink_candidates

      candidates.all? do |score, _|
        score <= g.score
      end
    end
  end

  def test_shrink_rational
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Rational)
    property do
      a = arbitrary Rational
      g = gen.force(a)
      candidates = g.shrink_candidates

      candidates.all? do |score, _|
        score <= g.score
      end
    end
  end

  def test_shrink_char
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Char)
    property do
      c = arbitrary Char
      g = gen.force(c)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.ord <= c.ord &&
          score == x.ord &&
          x.ord <= 0xff && x.ord >= 0
      end
    end
  end

  def test_shrink_asciichar
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(ASCIIChar)
    property do
      c = arbitrary ASCIIChar
      g = gen.force(c)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.ord <= c.ord &&
          score == x.ord &&
          x.ord <= 0x7f && x.ord >= 0
      end
    end
  end

  def test_shrink_hash
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Hash, Int8, Int8)
    property do
      a = arbitrary Hash, Int8, Int8
      g = gen.force(a)
      candidates = g.shrink_candidates

      candidates.all? do |score, h|
        score <= g.score &&
          h.length <= a.length
      end
    end
  end

  def test_shrink_bool
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Bool)
    property do
      b = arbitrary Bool
      g = gen.force(b)
      candidates = g.shrink_candidates

      candidates.all? do |score, _l|
        score == 1
      end
    end
  end

  def test_shrink_time
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Time)
    property do
      t = arbitrary Time
      g = gen.force(t)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        score == x.to_i.abs &&
          x.to_i <= 0x7fffffff &&
          x.to_i >= -0x80000000 &&
          ( t.to_i < 0 ? x.to_i <= 1 : x.to_i >= -1 )
      end
    end
  end

  def test_where
    property do
      n = arbitrary Int32
      where do
        n.even?
      end

      n.even?
    end
  end

  def test_minitest_assert
    property do
      n = arbitrary Int32
      where do
        n.even?
      end
      where do
        n.nonzero?
      end

      assert n.even?
      assert (n % n).zero?
    end
  end
end
