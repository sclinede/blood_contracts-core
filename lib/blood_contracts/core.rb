require "dry-initializer"
require_relative "./core/contract.rb"
require_relative "./core/type.rb"
require_relative "./core/version.rb"

BloodContract = BloodContracts::Core::Contract
BloodType = BloodContracts::Core::Type

module BloodContracts
  module Core; end

  class ContractFailure < Core::Type
    def errors
      context[:errors].to_h
    end

    def unpack
      context
    end
  end

  class Anything < Core::Type
    param :data
  end
end

module BC
  Anything = BloodContracts::Anything
  ContractFailure = BloodContracts::ContractFailure
end
