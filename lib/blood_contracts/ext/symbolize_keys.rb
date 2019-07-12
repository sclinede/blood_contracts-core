module BloodContracts
  module SymbolizeKeys
    refine Hash do
      def symbolize_keys
        each_with_object({}) do |(key, value), acc|
          acc[key.to_sym] = value
        end
      end
    end
  end
end
