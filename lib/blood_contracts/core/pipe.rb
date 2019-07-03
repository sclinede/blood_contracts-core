module BloodContracts::Core
  # Meta refinement type, represents pipe of several refinement types
  class Pipe < Refined
    class << self
      # List of data transformation step
      #
      # @return [Array<Refined>]
      #
      attr_reader :steps

      # List of data transformation step names
      #
      # @return [Array<Symbol>]
      #
      attr_reader :names

      # rubocop:disable Style/SingleLineMethods
      def new(*args, **kwargs, &block)
        return super(*args, **kwargs) if @finalized
        names = kwargs.delete(:names) unless kwargs.empty?
        names ||= []

        raise ArgumentError unless args.all? { |type| type < Refined }
        pipe = Class.new(self) { def inspect; super; end }
        finalize!(pipe, args, names)
        pipe.class_eval(&block) if block_given?
        pipe
      end

      # Compose types in a Pipe check
      # Pipe passes data from type to type sequentially
      #
      # @return [BC::Pipe]
      #
      # rubocop:disable Style/CaseEquality
      def and_then(other_type, **kwargs)
        raise ArgumentError unless Class === other_type
        pipe = Class.new(self) { def inspect; super; end }
        finalize!(pipe, [self, other_type], kwargs[:names].to_a)
        pipe
      end
      # rubocop:enable Style/CaseEquality Style/SingleLineMethods
      alias > and_then

      # Helper which registers step in validation pipe, also defines a reader
      #
      # @param [Symbol] name of the matching step
      # @param [Refined] type of the matching step
      #
      def step(name, type)
        raise ArgumentError unless type < Refined
        @steps << type
        @names << name
        define_method(name) do
          match.context.dig(:steps_values, name)
        end
      end

      # Returns text representation of Pipe meta-class
      #
      # @return [String]
      #
      def inspect
        return super if name
        "Pipe(#{steps.to_a.join(',')})"
      end

      private def finalize!(new_class, steps, names)
        new_class.instance_variable_set(:@steps, steps)
        new_class.instance_variable_set(:@names, names)
        new_class.instance_variable_set(:@finalized, true)
      end
    end

    # Constructs a Pipe using the given value
    # (for Pipe steps are also stored in the context)
    #
    # @return [Pipe]
    #
    def initialize(*)
      super
      @context[:steps] = @context[:steps].to_a
    end

    # The type which is the result of data matching process
    # For PIpe it verifies that data is valid through all data transformation
    # steps
    #
    # @return [BC::Refined]
    #
    def match
      steps_enumerator.reduce(value) do |next_value, (step, index)|
        match = next_step_value_match!(step, next_value, index)

        break match if match.invalid?
        next match unless block_given?
        next refine_value(yield(match)) if index < self.class.steps.size - 1

        match
      end
    end

    # List of errors per type during the matching
    #
    # @return [Array<Hash<Refined, String>>]
    #
    def errors
      @context[:errors]
    end

    # @private
    private def next_step_value_match!(step, value, index)
      unpacked_value = unpack_refined(value)
      match = step.match(unpacked_value, context: @context)
      track_steps!(index, unpacked_value, match.class.name)
      match
    end

    # @private
    private def steps_enumerator
      self.class.steps.each_with_index
    end

    # @private
    private def track_steps!(index, unpacked_value, match_class_name)
      @context[:steps_values][step_name(index)] = unpacked_value
      steps << match_class_name unless current_step.eql?(match_class_name)
    end

    # @private
    private def steps
      @context[:steps]
    end

    # @private
    private def current_step
      @context[:steps].last
    end

    # @private
    private def step_name(index)
      self.class.names[index] || index
    end

    # @private
    private def steps_with_names
      steps = self.class.steps
      if self.class.names.empty?
        steps.map(&:inspect)
      else
        steps.zip(self.class.names).map { |k, n| "#{k.inspect}(#{n})" }
      end
    end

    # @private
    private def inspect
      "#<pipe #{self.class.name} = #{steps_with_names.join(' > ')}"\
      " (value=#{@value})>"
    end
  end
end
