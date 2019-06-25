require "bundler/setup"
require "json"
require "blood_contracts/core"
require "pry"

module Types
  class JSON < BC::Refined
    def match
      super do
        begin
          context[:parsed] = ::JSON.parse(unpack_refined(@value))
          self
        rescue StandardError => error
          failure(error)
        end
      end
    end

    def unpack
      super { |match| match.context[:parsed] }
    end
  end

  class Symbol < BC::Refined
    def match
      super do
        begin
          context[:as_symbol] = unpack_refined(@value).to_sym
          self
        rescue StandardError => error
          failure(error)
        end
      end
    end

    def unpack
      super { |match| match.context[:as_symbol] }
    end
  end
end

Config = BC::Tuple.new(Types::Symbol, Types::JSON, names: %i[name config])
c = Config.new("test", '{"some": "value"}')
binding.pry
