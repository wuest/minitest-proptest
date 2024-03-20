# frozen_string_literal: true

module Minitest
  module Proptest
    class Gen
      # Methods for value generation
      class ValueGenerator
        attr_accessor :entropy
        attr_writer :type_parameters

        def self.with_shrink_function(&f)
          define_method(:shrink_function, &f)
          self
        end

        def self.with_score_function(&f)
          define_method(:score_function, &f)
          self
        end

        def self.with_append(bound_min, bound_max, &f)
          define_singleton_method(:bound_min) { bound_min }
          define_singleton_method(:bound_max) { bound_max }
          define_method(:append) do |other|
            @value = f.call(value, other.value)
            self
          end
          self
        end

        def self.with_empty(&f)
          define_singleton_method(:empty) do |gen|
            temp = new(gen)
            temp.instance_variable_set(:@value, f.call)
            temp
          end
          self
        end

        def self.bound_max
          1
        end

        def self.bound_min
          0
        end

        # append is not expected to be called unless overridden
        def append(_other)
          self
        end

        def self.empty(gen)
          self.new(gen)
        end

        def force(v)
          temp = self.class.new(ArgumentError)
          temp.instance_variable_set(:@value, v)
          temp.type_parameters = @type_parameters
          temp
        end

        def generate_value
          gen = @generated.reduce(@generator) do |g, val|
            g.call(val)
            g
          end

          while gen.is_a?(Proc) || gen.is_a?(Method)
            gen = gen.call(*@type_parameters.map(&:value))
            gen = gen.value if gen.is_a?(ValueGenerator)
          end

          gen
        end

        def value
          return false if @value == false

          @value ||= generate_value
        end

        def prefix_entropy_generation(vals)
          @generated = vals + @generated
        end

        def score
          value
          fs = @type_parameters.map { |x| x.method(:score_function) }
          score_function(*fs, value)
        end

        def score_function(v)
          v.to_i.abs
        end

        def shrink_candidates
          fs = @type_parameters.map { |x| x.method(:shrink_function) }
          os = score
          candidates = shrink_function(*fs, value)
          candidates
            .map    { |c| [force(c).score, c] }
            .reject { |(s, _)| s > os }
            .sort   { |x, y| x.first <=> y.first }
            .uniq
        end

        def shrink_function(x)
          [x.itself]
        end

        def shrink_parameter(x)
          @shrink_parameter.call(x)
        end

        # Generator helpers

        def sized(n)
          entropy.call(n + 1)
        end

        def one_of(r)
          r.to_a[sized(r.to_a.length - 1)]
        end
      end
    end
  end
end
