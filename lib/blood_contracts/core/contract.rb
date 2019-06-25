class BloodContracts::Core::Contract
  class << self
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

    private def _validate_args!(args)
      return if args.size == 2
      raise ArgumentError, <<~MESSAGE
        wrong number of arguments (given #{args.size}, expected 2)
      MESSAGE
    end

    private def accumulate_contract(options)
      accumulate_contract = options.reduce({}) do |acc, (input, output)|
        prev_input, prev_output = acc.first
        { (input | prev_input) => (output | prev_output) }
      end
      accumulate_contract.first
    end
  end
end
