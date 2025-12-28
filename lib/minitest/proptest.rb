# frozen_string_literal: true

require 'minitest'
require 'minitest/proptest/gen'
require 'minitest/proptest/property'
require 'minitest/proptest/status'
require 'minitest/proptest/version'
require 'yaml'

module Minitest
  class ResultsDatabase < Minitest::AbstractReporter
    def initialize(pathname)
      super()

      results = if File.file?(pathname)
                  YAML.load_file(pathname)
                else
                  {}
                end
      self.class.instance_variable_set(:@_results, results) unless self.class.instance_variable_defined?(:@_results)
    end

    def report
      return unless Proptest.use_db?

      File.write(Proptest.result_db, self.class.instance_variable_get(:@_results).to_yaml)
    end

    def lookup(file, classname, methodname)
      self.class.instance_variable_get(:@_results)
          .dig(file, classname, methodname)
          .to_a
    end

    def record_failure(file, classname, methodname, generated)
      return unless Proptest.use_db?

      results = self.class.instance_variable_get(:@_results)
      results[file] ||= {}
      results[file][classname] ||= {}
      results[file][classname][methodname] = generated
    end

    def strike_failure(file, classname, methodname)
      return unless Proptest.use_db?

      results = self.class.instance_variable_get(:@_results)
      return unless results.key?(file)

      return unless results[file].key?(classname)

      results[file][classname].delete(methodname)
      results[file].delete(classname) if results[file][classname].empty?
      results.delete(file) if results[file].empty?
    end
  end

  module Proptest
    DEFAULT_RANDOM = Random.method(:new)
    DEFAULT_MAX_SUCCESS = 100
    DEFAULT_MAX_DISCARD_RATIO = 10
    DEFAULT_MAX_SIZE = 0x100
    DEFAULT_MAX_SHRINKS = (((1 << (1.size * 8)) - 1) / 2)
    DEFAULT_DB_LOCATION = File.join(Dir.pwd, '.proptest_failures.yml')

    self.instance_variable_set(:@_random, DEFAULT_RANDOM)
    self.instance_variable_set(:@_max_success, DEFAULT_MAX_SUCCESS)
    self.instance_variable_set(:@_max_discard_ratio, DEFAULT_MAX_DISCARD_RATIO)
    self.instance_variable_set(:@_max_size, DEFAULT_MAX_SIZE)
    self.instance_variable_set(:@_max_shrinks, DEFAULT_MAX_SHRINKS)
    self.instance_variable_set(:@_result_db, DEFAULT_DB_LOCATION)
    self.instance_variable_set(:@_use_db, false)

    def self.set_seed(seed)
      self.instance_variable_set(:@_random_seed, seed)
    end

    def self.max_success=(success)
      self.instance_variable_set(:@_max_success, success)
    end

    def self.max_discard_ratio=(discards)
      self.instance_variable_set(:@_max_discard_ratio, discards)
    end

    def self.max_size=(size)
      self.instance_variable_set(:@_max_size, size)
    end

    def self.max_shrinks=(shrinks)
      self.instance_variable_set(:@_max_shrinks, shrinks)
    end

    def self.result_db=(location)
      self.instance_variable_set(:@_result_db, File.expand_path(location))
    end

    def self.use_db!(use = true)
      self.instance_variable_set(:@_use_db, use)
    end

    def self.seed
      self.instance_variable_get(:@_random_seed)
    end

    def self.max_success
      self.instance_variable_get(:@_max_success)
    end

    def self.max_discard_ratio
      self.instance_variable_get(:@_max_discard_ratio)
    end

    def self.max_size
      self.instance_variable_get(:@_max_size)
    end

    def self.max_shrinks
      self.instance_variable_get(:@_max_shrinks)
    end

    def self.result_db
      self.instance_variable_get(:@_result_db)
    end

    def self.use_db?
      self.instance_variable_get(:@_use_db)
    end

    def self.record_failure(file, classname, methodname, generated)
      self.instance_variable_get(:@_results)
          .record_failure(file, classname, methodname, generated)
    end

    def self.strike_failure(file, classname, methodname)
      self.instance_variable_get(:@_results)
          .strike_failure(file, classname, methodname)
    end

    def self.reporter
      return self.instance_variable_get(:@_results) if self.instance_variable_defined?(:@_results)

      reporter = Minitest::ResultsDatabase.new(result_db)
      self.instance_variable_set(:@_results, reporter)

      reporter
    end
  end
end

module Kernel
  def generator_for(klass, &)
    ::Minitest::Proptest::Gen.generator_for(klass, &)
  end
  private :generator_for
end
