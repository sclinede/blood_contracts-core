module BloodContracts::Core
  # Refinement type which represents invalid data
  class ContractFailure < Refined
    # Constructs a ContractsFailure using the given value
    # (for ContractFailure value is an error)
    #
    # @return [ContractFailure]
    #
    def initialize(value = nil, **)
      super
      @match = self
      return unless @value
      @context[:errors] = (@context[:errors].to_a << @value.to_h)
    end

    # List of errors per type after the data matching process
    #
    # @return [Array<Hash<BC::Refined, String>>]
    #
    def errors
      @context[:errors].to_a
    end

    # Flatten list of error messages
    #
    # @return [Array<String>]
    #
    def messages
      errors.reduce(:merge).values.flatten!
    end

    # Merged map of errors per type after the data matching process
    #
    # @return [Hash<BC::Refined, String>]
    #
    def errors_h
      errors.reduce(:merge)
    end
    alias to_h errors_h

    # The type which is the result of validation
    # (for ContractFailure is always self)
    #
    # @return [BC::Refined]
    #
    def match
      self
    end
  end
end
