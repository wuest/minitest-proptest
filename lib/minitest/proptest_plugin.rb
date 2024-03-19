# frozen_string_literal: true

require 'minitest'
require 'minitest/proptest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'
require 'minitest/proptest/version'
require 'yaml'

module Minitest
  def self.plugin_proptest_init(options)
    %i[Int8 Int16 Int32 Int64
       UInt8 UInt16 UInt32 UInt64
       Float32 Float64
       ASCIIChar Char
       Bool
      ].each do |const|
      unless Minitest::Assertions.const_defined?(const)
        ::Minitest::Assertions.const_set(const, ::Minitest::Proptest::Gen.const_get(const))
      end
    end

    self.reporter << Proptest.reporter

    Proptest.set_seed(options[:seed]) if options.key?(:seed)
  end

  def self.plugin_proptest_options(opts, _options)
    opts.on('--max-success', Integer, "Maximum number of successful cases to verify for each property (Default: #{Minitest::Proptest::DEFAULT_MAX_SUCCESS})") do |max_success|
      Proptest.max_success = max_success
    end
    opts.on('--max-discard-ratio', Integer, "Maximum ratio of successful cases versus discarded cases per property (Default: #{Minitest::Proptest::DEFAULT_MAX_DISCARD_RATIO}:1)") do |max_success|
      Proptest.max_success = max_success
    end
    opts.on('--max-size', Integer, "Maximum amount of entropy a single case may use in bytes (Default: #{Minitest::Proptest::DEFAULT_MAX_SIZE} bytes)") do |max_size|
      Proptest.max_size = max_size
    end
    opts.on('--max-shrinks', Integer, "Maximum number of shrink iterations a single failure reduction may use (Default: #{Minitest::Proptest::DEFAULT_MAX_SHRINKS})") do |max_shrinks|
      Proptest.max_shrinks = max_shrinks
    end
    opts.on('--results-db', String, "Location of the file to persist most recent failure cases.  Implies --use-db.  (Default: #{Minitest::Proptest::DEFAULT_DB_LOCATION})") do |db_path|
      Proptest.result_db = db_path
      Proptest.use_db!
    end
    opts.on('--use-db', 'Persist previous failures in a database and use them before generating new values.  Helps prevent flaky builds.  (Default: false)') do
      Proptest.use_db!
    end
  end

  module Assertions
    def property(&f)
      random_thunk = if Proptest.instance_variable_defined?(:@_random_seed)
                       r = Proptest.instance_variable_get(:@_random_seed)
                       ->() { Proptest::DEFAULT_RANDOM.call(r) }
                     else
                       Proptest::DEFAULT_RANDOM
                     end

      file, methodname = caller.first.split(/:\d+:in +/)
      classname = self.class.name
      methodname.gsub!(/(?:^`|'$)/, '')

      prop = Minitest::Proptest::Property.new(
        f,
        random: random_thunk,
        max_success: Proptest.max_success,
        max_discard_ratio: Proptest.max_discard_ratio,
        max_size: Proptest.max_size,
        max_shrinks: Proptest.max_shrinks,
        previous_failure: Proptest.reporter.lookup(file, classname, methodname)
      )
      prop.run!
      self.assertions += prop.calls

      if prop.status.valid? && !prop.trivial
        Proptest.strike_failure(file, classname, methodname)
      else
        unless prop.status.exhausted? || prop.status.invalid?
          Proptest.record_failure(file, classname, methodname, prop.result.map(&:value))
        end

        raise Minitest::Assertion, prop.explain
      end
    end
  end
end
