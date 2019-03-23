module BloodContracts
  module Core
    class Contract
      class << self
        attr_accessor :input_type, :output_type
      end

      def self.call(*args)
        if (input_match = input_type.match(*args)).valid?
          result = yield(input_match)
          output_type.match(result, context: input_match.context)
        else
          input_match
        end
      end
    end
  end
end
