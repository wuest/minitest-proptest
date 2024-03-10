# frozen_string_literal: true

require 'test_helper'

class CustomGeneratorTest < Minitest::Test
  BoxedUInt8 = Struct.new(:value)

  generator_for(BoxedUInt8) do
    BoxedUInt8.new(sized(0xff))
  end.with_shrink_function do |i|
    candidates = []
    y = i.value

    until y.zero?
      candidates << BoxedUInt8.new(i.value - y)
      candidates << BoxedUInt8.new(y)
      y = (y / 2.0).to_i
    end

    candidates
  end.with_score_function(&:value)

  Dice = Struct.new(:value) do
    def +(other)
      self.value + other.value
    end
  end

  generator_for(Dice) do
    Dice.new(one_of(1..6))
  end

  Twople = Struct.new(:fst, :snd) do
    def sum
      self.fst + self.snd
    end
  end

  generator_for(Twople) do |fst, snd|
    Twople.new(fst, snd)
  end.with_shrink_function do |ffst, fsnd, t|
    f_candidates = ffst.call(t.fst)
    s_candidates = fsnd.call(t.snd)

    f_candidates.reduce([]) do |candidates, fst|
      candidates + s_candidates.map { |snd| Twople.new(fst, snd) }
    end
  end.with_score_function do |ffst, fsnd, t|
    ffst.call(t.fst) + fsnd.call(t.snd)
  end

  def test_boxed_uint8
    property do
      a = arbitrary BoxedUInt8
      a.value >= 0 && a.value <= 255
    end
  end

  def test_dice
    property do
      a = arbitrary Dice
      b = arbitrary Dice

      a.value + b.value == a + b
    end
  end

  def test_compare_tuples
    property do
      a = arbitrary Twople, Int8, Int8
      b = arbitrary Twople, Int8, Int8

      a.sum == a.fst + a.snd &&
        b.sum == b.fst + b.snd &&
        (( a.sum >= b.sum && b.sum <= a.sum) ||
         ( a.sum <= b.sum && b.sum >= a.sum))
    end
  end
end
