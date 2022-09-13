require 'test_helper'

class PropertyTest < Minitest::Test
  def test_shrink_int8
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Int8)
    property do
      n = arbitrary Int8
      g = gen.force(n)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.abs < n.abs &&
          score == x.abs &&
          x <= 0x7f && x >= -0x80 &&
          n.negative? ? x <= 1 : x >= -1
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
        x.abs < n.abs &&
          score == x.abs &&
          x <= 0x7fff && x >= -0x8000 &&
          n.negative? ? x <= 1 : x >= -1
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
        x.abs < n.abs &&
          score == x.abs &&
          x <= 0x7fffffff && x >= -0x80000000 &&
          n.negative? ? x <= 1 : x >= -1
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
        x.abs < n.abs &&
          score == x.abs &&
          x <= 0x7fffffffffffffff && x >= -0x8000000000000000 &&
          n.negative? ? x <= 1 : x >= -1
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
        x.abs < n.abs &&
          score == x.abs &&
          x <= 0x7fffffffffffffff && x >= -0x8000000000000000 &&
          n.negative? ? x <= 1 : x >= -1
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
        x.abs < n.abs &&
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
        x.abs < n.abs &&
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
        x.abs < n.abs &&
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
        x.abs < n.abs &&
          score == x.abs &&
          x <= 0xffffffffffffffff &&
          x >= 0
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

  def test_shrink_char
    gen = ::Minitest::Proptest::Gen.new(Random.new).for(Char)
    property do
      c = arbitrary Char
      g = gen.force(c)
      candidates = g.shrink_candidates

      candidates.all? do |score, x|
        x.ord < c.ord &&
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
        x.ord < c.ord &&
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
end
