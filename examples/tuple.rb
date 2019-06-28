require "bundler/setup"
require "json"
require "blood_contracts/core"
require "pry"

module Types
  class JSON < BC::Refined
    def match
      super do
        begin
          context[:parsed] = ::JSON.parse(value)
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
      context[:as_symbol] = value.to_sym
      self
    rescue StandardError => error
      failure(error)
    end

    def unpack
      super { |match| match.context[:as_symbol] }
    end
  end
end

Config = BC::Tuple.new do
  attribute :name,  Types::Symbol
  attribute :config, Types::JSON
end

c = Config.new("test", '{"some": "value"}')
binding.pry
