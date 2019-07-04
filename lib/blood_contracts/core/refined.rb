module BloodContracts::Core
  # Base class for refinement type validations
  class Refined
    class << self
      # Compose types in a Sum check
      # Sum passes data from type to type in parallel, only one type
      # have to match
      #
      # @return [BC::Sum]
      #
      def or_a(other_type)
        BC::Sum.new(self, other_type)
      end
      alias or_an or_a
      alias | or_a

      # Compose types in a Pipe check
      # Pipe passes data from type to type sequentially
      #
      # @return [BC::Pipe]
      #
      def and_then(other_type)
        BC::Pipe.new(self, other_type)
      end
      alias > and_then

      # Validate data over refinement type conditions
      # Result is ALWAYS a Refined, but in cases when validation failed,
      # we return ContractFailure ancestor  or ContractFailure itself
      # (which is Refined anyway)
      #
      # @return [Refined]
      #
      def match(*args, **kwargs, &block)
        instance = new(*args, **kwargs)
        match = instance.match(&block) || instance
        instance.instance_variable_set(:@match, match)
        match
      end
      alias call match

      # Override of case equality operator, to handle Tuple correctly
      def ===(object)
        return object.to_ary.any?(self) if object.is_a?(Tuple)
        super
      end

      # Accessor to define alternative to ContractFailure for #failure
      # method to use
      #
      # @return [ContractFailure]
      #
      attr_accessor :failure_klass
      def inherited(new_klass)
        new_klass.failure_klass ||= ContractFailure
      end
    end

    # Matching context, contains extra debugging and output data
    #
    # @return [Hash<Symbol, Object>]
    #
    attr_accessor :context

    # List of errors per type
    #
    # @return [Array<Hash<Refined, String>>]
    #
    attr_reader :errors

    # Refinement type constructor
    #
    # @param [Object] value that Refined holds and should match
    # @option [Hash<Symbol, Object>] context to share between types
    #
    def initialize(value, context: Hash.new { |h, k| h[k] = {} }, **)
      @errors = []
      @context = context
      @value = value
    end

    # The type which is the result of data matching process
    #
    # @return [BC::Refined]
    #
    protected def match
      raise NotImplementedError
    end
    alias call match

    # Transform the value before unpacking
    protected def mapped
      value
    end

    # Checks whether the data matches the expectations or not
    #
    # @return [Boolean]
    #
    def valid?
      @match.errors.empty?
    end

    # Checks whether the data matches the expectations or not
    # (just negation of #valid?)
    #
    # @return [Boolean]
    #
    def invalid?
      !valid?
    end

    # Unpack the original value from the refinement type
    #
    # @return [Object]
    #
    def unpack
      @unpack ||= mapped
    end

    protected

    # Helper to build a ContractFailure with shared context
    #
    # @return [ContractFailure]
    #
    def failure(error = nil, errors: @errors, **kwargs)
      error ||= kwargs unless kwargs.empty?
      errors << error if error
      self.class.failure_klass.new(
        { self.class => errors }, context: @context
      )
    end

    # Helper to turn value into raw data
    #
    # @return [Object]
    def value
      unpack_refined(@value)
    end

    def refined?(object)
      object.class < BloodContracts::Core::Refined
    end

    # FIXME: do we need it?
    def share_context_with(match)
      match.context = @context.merge!(match.context)
      yield(match.context)
    end

    # Turn data into refinement type if it is not already
    #
    # @return [Object]
    #
    def refine_value(value)
      refined?(value) ? value.match : Anything.new(value)
    end

    # Turn value into raw data if it is refined
    #
    # @return [Object]
    #
    def unpack_refined(value)
      refined?(value) ? value.unpack : value
    end
  end
end
