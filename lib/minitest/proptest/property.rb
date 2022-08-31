module Minitest
  class Proptest < Minitest::Test
    class Property

      attr_reader :result, :status, :trivial
      def initialize(
        # The function which proves the property
        test_proc,
        # Any class which provides `rand` accepting both an Integer and a Range
        # is acceptable.  The default value is Ruby's standard Mersenne Twister
        # implementation.
        random: Random.new,
        # Maximum number of successful cases before considering the test a
        # success.
        max_success: 1000,
        # Maximum ratio of discarded tests per successful test before giving up.
        max_discard_ratio: 10,
        # Maximum amount of entropy to generate in a single run
        max_size: 0x100,
        # Maximum number of shrink attempts (default of half of max unsigned int
        # on the system architecture adopted from QuickCheck
        max_shrinks: 0x7fffffffffffffff
      )
        @test_proc         = test_proc
        @random            = random
        @max_success       = max_success
        @max_discard_ratio = max_discard_ratio
        @max_size          = max_size
        @max_shrinks       = max_shrinks
        @status            = Status.unknown
        @trivial           = false
        @result            = nil
        @exception         = nil
        @calls             = 0
        @valid_test_cases  = 0
        @generated         = []
      end

      def run!
        iterate
        shrink
      end

      def arbitrary(*classes)
        a = ::Minitest::Proptest::Gen.new(@random).for(*classes)
        @generated << a
        @status = Status.overrun unless @generated.length <= @max_size
        a.value
      end

      def explain
        prop = if @status.valid?
                 "The property was proved to satsfaction across " +
                   "#{@valid_test_cases} assertions."
               elsif @status.invalid?
                 "The property was determined to be invalid due to " +
                   "#{@exception.class.name}: #{@exception.message}\n" +
                   @exception.backtrace.map { |l| "    #{l}" }.join("\n")
               elsif @status.overrun?
                 "The property attempted to generate more than #{@max_size} " +
                   "bytes of entropy, violating the property's maximum size." +
                   "This might be rectified by increasing max_size."
               elsif @status.unknown?
                 "The property has not yet been tested."
               elsif @status.interesting?
                 "The property has found a counterexample after " +
                   "#{@valid_test_cases} valid examples.  The minimal " +
                   "counterexample consists of:\n  Raw values: " +
                   @generated.map(&:entropy).inspect +
                   "\n  Generated values: " +
                   @generated.map(&:value).inspect
               end
        trivial = if @trivial
                    "\nThe test does not appear to use any generated values " +
                      "and as such is likely not generating much value.  " +
                      "Consider reworking this test to make use of arbitrary " +
                      "data."
                  else
                    ""
                  end
        prop + trivial
      end

      private

      def iterate
        while continue? && (@result.nil? || @valid_test_cases <= @max_success / 2)
          @generated = []
          @calls += 1
          if instance_eval(&@test_proc)
            @status = Status.valid if @status.unknown?
            @valid_test_cases += 1
          else
            @result = @generated
            @status = Status.interesting
          end
          @trivial = true if @generated.empty?
        end
      rescue => e
        @status = Status.invalid
        @exception = e
        raise e
      end

      def target
      end

      def shrink
      end

      def continue?
        !@trivial &&
          !@status.invalid? &&
          !@status.overrun? &&
          @result.nil? &&
          @valid_test_cases < @max_success &&
          @calls < @max_success * @max_discard_ratio
      end
    end
  end
end
