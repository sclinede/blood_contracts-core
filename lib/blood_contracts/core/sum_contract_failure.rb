module BloodContracts::Core
  # Represents failure in Tuple data matching
  class SumContractFailure < ContractFailure
    # Accessor to contexts of Sum failed matches
    #
    # @return [Array<Hash>]
    #
    def contexts
      @context[:sum_failure_contexts]
    end
  end
end
