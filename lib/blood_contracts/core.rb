module BloodContracts
  module Core
    require_relative "./core/refined.rb"
    require_relative "./core/contract_failure.rb"
    require_relative "./core/anything.rb"
    require_relative "./core/pipe.rb"
    require_relative "./core/contract.rb"
    require_relative "./core/sum.rb"
    require_relative "./core/tuple.rb"

    # constant aliases
    Or = Sum
    AndThen = Pipe
  end
end

BC = BloodContracts::Core
