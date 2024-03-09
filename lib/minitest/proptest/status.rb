# frozen_string_literal: true

module Minitest
  module Proptest
    # Sum type representing the possible statuses of a test run.
    # Invalid, Overrun, and Interesting represent different failure classes.
    # Unknown represents a lack of information about the test run (typically
    # having not run to satisfaction).
    # Valid represents a test which has run to satisfaction.
    class Status
      class Interesting < Status
      end

      class Invalid < Status
      end

      class Overrun < Status
      end

      class Unknown < Status
      end

      class Valid < Status
      end

      invalid     = Invalid.new.freeze
      interesting = Interesting.new.freeze
      overrun     = Overrun.new.freeze
      unknown     = Unknown.new.freeze
      valid       = Valid.new.freeze

      define_singleton_method(:invalid)     { invalid }
      define_singleton_method(:interesting) { interesting }
      define_singleton_method(:overrun)     { overrun }
      define_singleton_method(:unknown)     { unknown }
      define_singleton_method(:valid)       { valid }

      def invalid?
        self.is_a?(Invalid)
      end

      def overrun?
        self.is_a?(Overrun)
      end

      def unknown?
        self.is_a?(Unknown)
      end

      def valid?
        self.is_a?(Valid)
      end

      def interesting?
        self.is_a?(Interesting)
      end

      def initialize
        raise 'Please use singleton instances'
      end
    end
  end
end
