# frozen_string_literal: true

module Minitest
  module Proptest
    # Property evaluation - status, scoring, shrinking
    class Property
      require 'minitest/assertions'
      include Minitest::Assertions

      class InvalidProperty < StandardError; end

      attr_reader :calls, :result, :status, :trivial

      attr_accessor :assertions

      def initialize(
        # The function which proves the property
        test_proc,
        # The file in which our property lives
        filename,
        # The method containing our property
        methodname,
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
        max_shrinks: 0x7fffffffffffffff,
        # Previously discovered counter-example.  If this exists, it should be
        # run before any test cases are generated.
        previous_failure: []
      )
        @test_proc         = test_proc
        @filename          = filename
        @methodname        = methodname
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
        @assertions        = 0
        @valid_test_cases  = 0
        @generated         = []
        @arbitrary         = nil
        @previous_failure  = previous_failure.to_a
        @local_variables   = {}
      end

      def run!
        rerun!
        iterate!
        shrink!
      end

      def explain
        prop = if @status.valid?
                 'The property was proved to satsfaction across ' \
                   "#{@valid_test_cases} assertions."
               elsif @status.invalid?
                 'The property was determined to be invalid due to ' \
                   "#{@exception.class.name}: #{@exception.message}\n" \
                   "#{@exception.backtrace.map { |l| "    #{l}" }.join("\n")}"
               elsif @status.overrun?
                 "The property attempted to generate more than #{@max_size} " \
                   "bytes of entropy, violating the property's maximum " \
                   'size.  This might be rectified by increasing max_size.'
               elsif @status.unknown?
                 'The property has not yet been tested.'
               elsif @status.interesting?
                 info = 'A counterexample to a property has been found after ' \
                        "#{@valid_test_cases} valid " \
                        "example#{@valid_test_cases == 1 ? '' : 's'}.\n"
                 var_info = if @local_variables.empty?
                              'Variables local to the property were unable ' \
                                'to be determined.  This is usually a bug.'
                            else
                              "The values at the time of the failure were:\n"
                            end
                 vars = @local_variables
                        .map { |k, v| "\t#{k}: #{v.inspect}" }
                        .join("\n")

                 info + var_info + vars
               elsif @status.exhausted?
                 "The property was unable to generate #{@max_success} test " \
                   'cases before generating ' \
                   "#{@max_success * @max_discard_ratio} rejected test " \
                   "cases.  This might be a problem with the property's " \
                   '`where` blocks.'
               end
        trivial = if @trivial
                    "\nThe test does not appear to use any generated values " \
                      'and as such is likely not generating much value.  ' \
                      'Consider reworking this test to make use of arbitrary ' \
                      'data.'
                  else
                    ''
                  end
        prop + trivial
      end

      private

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

      def where(&b)
        raise InvalidProperty unless b.call
      end

      def iterate!
        while continue_iterate? && @result.nil? && @valid_test_cases <= @max_success
          @generated = []
          @generator = ::Minitest::Proptest::Gen.new(@random)
          @calls += 1

          begin
            if instance_eval(&@test_proc)
              @status = Status.valid if @status.unknown?
              @valid_test_cases += 1
            else
              @result = @generated
              @status = Status.interesting
            end
          rescue Minitest::Assertion
            @result = @generated
            @status = Status.interesting
          rescue InvalidProperty
          rescue => e
            @status = Status.invalid
            @exception = e
          end

          @status = Status.exhausted if @calls >= @max_success * (@max_discard_ratio + 1)
          @trivial = true if @generated.empty?
        end
      end

      def rerun!
        return if @previous_failure.empty?

        old_generator  = @generator
        old_random     = @random
        old_arbitrary  = @arbitrary

        index = -1
        @arbitrary = ->(*classes) do
          index += 1
          raise IndexError if index >= @previous_failure.length

          a = @generator.for(*classes)
          a = a.force(@previous_failure[index])
          @generated << a
          @previous_failure[index]
        end

        @generator = ::Minitest::Proptest::Gen.new(@random)
        begin
          if instance_eval(&@test_proc)
            @generated = []
          else
            @result = @generated
            @status = Status.interesting
          end
        rescue Minitest::Assertion
          @result = @generated
          @status = Status.interesting
        rescue InvalidProperty
          @generated = []
        rescue => e
          @result = @generated
          @status = Status.invalid
          @exception = e
        end

        # Clean up after we're done
        @generator = old_generator
        @random    = old_random
        @arbitrary = old_arbitrary
      end

      def shrink!
        return if @result.nil?

        old_random     = @random
        old_generator  = @generator
        best_score     = @generated.map(&:score).reduce(&:+)
        best_generated = @generated
        candidates     = @generated.map(&:shrink_candidates)
        old_arbitrary  = @arbitrary

        # Using a TracePoint to determine variable assignments at the time of
        # the failure only occurs within shrink! - this is a deliberate decision
        # which eliminates all time lost in iterate! to optimize for the success
        # case.  The tradeoff is that if all shrinking fails, one additional
        # cycle (with the values which produced the original failure) will be
        # required.
        local_variables = {}
        tracepoint = TracePoint.new(:b_return) do |trace|
          if trace.path == @filename && trace.method_id.to_s == @methodname
            b     = trace.binding
            vs    = b.local_variables
            known = vs.to_h { |lv| [lv.to_s, b.local_variable_get(lv)] }
            local_variables.delete_if { true }
            local_variables.merge!(known)
          end
        end

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
          @generated       = []
          run[:index]      = -1
          @valid_test_case = true

          @generator = ::Minitest::Proptest::Gen.new(@random)
          if to_test[run[:run]].map(&:first).reduce(&:+) <= best_score
            begin
              tracepoint.enable
              unless instance_eval(&@test_proc)
                # The first hit is guaranteed to be the best scoring since the
                # shrink candidates are pre-sorted.
                best_generated = @generated
                break
              end
            rescue Minitest::Assertion
              best_generated = @generated
              break
            rescue InvalidProperty
              # Invalid test case generated- continue
            rescue => e
              next unless @valid_test_case

              @status = Status.invalid
              @excption = e
              break
            ensure
              tracepoint.disable
            end
          end

          @calls    += 1
          run[:run] += 1
        end

        # Clean up after we're done
        @generated       = best_generated
        @result          = best_generated
        @generator       = old_generator
        @random          = old_random
        @arbitrary       = old_arbitrary
        @local_variables = local_variables
      end

      def continue_iterate?
        !@trivial &&
          !@status.invalid? &&
          !@status.overrun? &&
          !@status.exhausted? &&
          @valid_test_cases < @max_success
      end

      def continue_shrink?
        !@trivial &&
          !@status.invalid? &&
          !@status.overrun? &&
          @calls < @max_shrinks
      end
    end
  end
end
