module BloodContracts::Core
  class TupleContractFailure < ContractFailure
    def attributes
      @context[:attributes]
    end

    def attribute_errors
      attributes.select { |_name, type| type.invalid? }
    end

    def unpack_h
      @unpack_h ||= attribute_errors.transform_values(&:unpack)
    end
    alias to_hash unpack_h
    alias to_h unpack_h
    alias unpack_attributes unpack_h
  end
end
