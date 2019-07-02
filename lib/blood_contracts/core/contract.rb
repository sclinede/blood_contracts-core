module BloodContracts::Core
  # Meta refinement type, represents contract built upon input and output
  # types
  class Contract
    class << self
      # Metaprogramming around constructor
      # Turns input types into a contract
      #
      # @param [Hash<BC::Refined, BC::Refined>] expectations about possible
      #   data input expressed in form of BC::Refined types
      # @return [BC::Refined] contract for data validation in form of
      #   BC::Refined class
      #
      def new(*args)
        input, output =
          if (opts = args.last).is_a?(Hash)
            accumulate_contract(opts)
          else
            _validate_args!(args)
            args
          end
        BC::Pipe.new(input, output, names: %i[input output])
      end

      # @private
      private def _validate_args!(args)
        return if args.size == 2
        raise ArgumentError, <<~MESSAGE
          wrong number of arguments (given #{args.size}, expected 2)
        MESSAGE
      end

      # @private
      private def accumulate_contract(options)
        accumulate_contract = options.reduce({}) do |acc, (input, output)|
          prev_input, prev_output = acc.first
          { (input | prev_input) => (output | prev_output) }
        end
        accumulate_contract.first
      end
    end
  end
end
