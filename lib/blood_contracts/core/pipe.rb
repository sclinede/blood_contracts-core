module BloodContracts::Core
  class Pipe < Refined
    class << self
      attr_reader :steps, :names, :finalized

      # rubocop:disable Style/SingleLineMethods
      def new(*args, **kwargs, &block)
        return super(*args, **kwargs) if finalized
        names = kwargs.delete(:names) unless kwargs.empty?
        names ||= []

        raise ArgumentError unless args.all? { |type| type < Refined }
        pipe = Class.new(Pipe) { def inspect; super; end }
        finalize!(pipe, args, names)
        pipe.class_eval(&block) if block_given?
        pipe
      end

      # rubocop:disable Style/CaseEquality
      def and_then(other_type, **kwargs)
        raise ArgumentError unless Class === other_type
        pipe = Class.new(Pipe) { def inspect; super; end }
        finalize!(pipe, [self, other_type], kwargs[:names].to_a)
        pipe
      end
      # rubocop:enable Style/CaseEquality Style/SingleLineMethods
      alias > and_then

      def step(name, type)
        raise ArgumentError unless type < Refined
        @steps << type
        @names << name
        define_method(name) do
          match.context.dig(:steps_values, name)
        end
      end

      def inspect
        return super if name
        "Pipe(#{steps.to_a.join(',')})"
      end

      private def finalize!(new_class, steps, names)
        new_class.instance_variable_set(:@steps, steps)
        new_class.instance_variable_set(:@names, names)
        new_class.instance_variable_set(:@finalized, true)
      end

      private

      attr_writer :names
    end

    def initialize(*)
      super
      @context[:steps] = @context[:steps].to_a
    end

    def match
      super do
        steps_enumerator.reduce(value) do |next_value, (step, index)|
          match = next_step_value_match!(step, next_value, index)

          break match if match.invalid?
          next match unless block_given?
          next refine_value(yield(match)) if index < self.class.steps.size - 1

          match
        end
      end
    end

    def errors
      match.errors
    end

    private def next_step_value_match!(step, value, index)
      unpacked_value = unpack_refined(value)
      match = step.match(unpacked_value, context: @context)
      track_steps!(index, unpacked_value, match.class.name)
      match
    end

    private def steps_enumerator
      self.class.steps.each_with_index
    end

    private def track_steps!(index, unpacked_value, match_class_name)
      @context[:steps_values][step_name(index)] = unpacked_value
      steps << match_class_name unless current_step.eql?(match_class_name)
    end

    private def steps
      @context[:steps]
    end

    private def current_step
      @context[:steps].last
    end

    private def step_name(index)
      self.class.names[index] || index
    end

    private def steps_with_names
      steps = self.class.steps
      if self.class.names.empty?
        steps.map(&:inspect)
      else
        steps.zip(self.class.names).map { |k, n| "#{k.inspect}(#{n})" }
      end
    end

    private def inspect
      "#<pipe #{self.class.name} = #{steps_with_names.join(' > ')}"\
      " (value=#{@value})>"
    end
  end
end
