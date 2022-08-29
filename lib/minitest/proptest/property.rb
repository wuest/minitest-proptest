module Minitest
  class Proptest < Minitest::Test
    class Property
      def initialize(random, max_size, generated = [])
        @generated = generated
        @random    = random
        @max_size  = max_size
        @status    = Status.unknown
      end

      def run(&f)
        instance_eval(&f)
      end

      def arbitrary(*classes)
        a = ::Minitest::Proptest::Gen.new(@random).for(*classes)
        @generated = @generated + a.entropy
        a.value
      end
    end
  end
end
