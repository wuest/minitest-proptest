module Minitest
  module Proptest
    class Property

      attr_reader :result, :status, :trivial
      def initialize(
        # The function which proves the property
        test_proc,
        # Any class which provides `rand` accepting both an Integer and a Range
        # is acceptable.  The default value is Ruby's standard Mersenne Twister
        # implementation.
        random: Random.method(:new),
        # Maximum number of successful cases before considering the test a
        # success.
        max_success: 100,
        # Maximum ratio of discarded tests per successful test before giving up.
        max_discard_ratio: 10,
        # Maximum amount of entropy to generate in a single run
        max_size: 0x100,
        # Maximum number of shrink attempts (default of half of max unsigned int
        # on the system architecture adopted from QuickCheck
        max_shrinks: 0x7fffffffffffffff
      )
        @test_proc         = test_proc
        @random            = random.call
        @generator         = ::Minitest::Proptest::Gen.new(@random)
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
        @arbitrary         = nil
      end

      def run!
        iterate!
        shrink!
      end

      def arbitrary(*classes)
        if @arbitrary
          @arbitrary.call(*classes)
        else
          a = @generator.for(*classes)
          @generated << a
          @status = Status.overrun unless @generated.length <= @max_size
          a.value
        end
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
                 "The property has found the following counterexample after " +
                   "#{@valid_test_cases} valid " +
                   "example#{@valid_test_cases == 1 ? '' : 's'}:\n" +
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

      def iterate!
        while continue_iterate? && @result.nil? && @valid_test_cases <= @max_success / 2
          @generated = []
          @generator = ::Minitest::Proptest::Gen.new(@random)
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

      def shrink!
        return if @result.nil?
        old_random     = @random
        old_generator  = @generator
        best_score     = @generated.map(&:score).reduce(&:+)
        best_generated = @generated
        candidates     = @generated.map(&:shrink_candidates)
        old_arbitrary  = @arbitrary

        to_test = candidates
          .map    { |x| x.map { |y| [y] } }
          .reduce { |c, e| c.flat_map { |a| e.map { |b| a + b } } }
          .sort   { |x, y| x.map(&:first).reduce(&:+) <=> y.map(&:first).reduce(&:+) }
          .uniq
        run = { run: 0, index: -1 }

        @arbitrary = ->(*classes) do
          run[:index] += 1
          raise IndexError if run[:index] >= to_test[run[:run]].length

          a = @generator.for(*classes)
          a = a.force(to_test[run[:run]][run[:index]].last)
          @generated << a
          to_test[run[:run]][run[:index]].last
        end

        while continue_shrink? && run[:run] < to_test.length
          @generated  = []
          run[:index] = -1

          @generator = ::Minitest::Proptest::Gen.new(@random)
          if to_test[run[:run]].map(&:first).reduce(&:+) < best_score
            unless instance_eval(&@test_proc)
              best_generated = @generated
              # Because we pre-sorted our shrink candidates, the first hit is
              # necessarily the best scoring
              break
            end
          end

          @calls    += 1
          run[:run] += 1
        end
        # Clean up after we're done
        @generated = best_generated
        @result    = best_generated
        @generator = old_generator
        @random    = old_random
        @arbitrary = old_arbitrary
      end

      def continue_iterate?
        !@trivial &&
          !@status.invalid? &&
          !@status.overrun? &&
          @valid_test_cases < @max_success &&
          @calls < @max_success * @max_discard_ratio
      end

      def continue_shrink?
        !@trivial &&
          !@status.invalid? &&
          !@status.overrun?
          @calls < @max_shrinks
      end
    end
  end
end
