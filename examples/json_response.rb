require "json"
require "blood_contracts/core"

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

  class Tariff < BC::Refined
    def match
      super do
        context[:data] = unpack_refined(@value).slice("cost", "cur").compact
        context[:tariff_context] = 1
        return self if context[:data].size == 2
        failure(:not_a_tariff)
      end
    end

    def unpack
      super { |match| match.context[:data] }
    end
  end

  class Error < BC::Refined
    def match
      super do
        context[:data] = unpack_refined(value).slice("code", "message").compact
        context[:known_error_context] = 1
        return self if context[:data].size == 2
        failure(:not_a_known_error)
      end
    end

    def unpack
      super { |match| match.context[:data] }
    end
  end

  Response = BC::Pipe.new(
    BC::Anything, JSON, (Tariff | Error | Tariff),
    names: %i[raw parsed mapped]
  )

  # The same is
  # Response = BC::Anything.and_then(JSON).and_then(Tariff | Error) do
  # class Response
  #   self.names = [:raw, :parsed, :mapped]
  # end
  #
  # or
  #
  # Response = BC::Pipe.new(BC::Anything, JSON, Tariff | Error) do
  #   self.names = [:raw, :parsed, :mapped]
  # end
end

def match_response(response)
  match = Types::Response.match(response)
  case match
  when BC::ContractFailure
    puts "Honeybadger.notify 'Unexpected behavior in Russian Post', context: #{match.context}"
    puts "render json: { errors: 'Ooops! Not working, we've been notified. Please, try again later' }"

    return unless ENV["RAISE"]
    match.errors.values.flatten.find do |v|
      raise v if StandardError === v
    end
  when Types::Tariff
    # работаем с тарифом
    puts "match.context # => #{match.context} \n\n"
    puts "render json: { tariff: #{match.unpack} }"
  when Types::Error
    # работаем с ошибкой, e.g. адрес слишком длинный
    puts "match.context # => #{match.context} \n\n"
    puts "render json: { errors: [#{match.unpack['message']}] } }"
  else
    require"pry"; binding.pry
  end
end

puts "#{'=' * 20}================================#{'=' * 20}"
puts "\n\n\n"
puts "#{'=' * 20} WHEN VALID RESPONSE:           #{'=' * 20}"
valid_response = '{"cost": 1000, "cur": "RUB"}'
match_response(valid_response)
puts "#{'=' * 20}================================#{'=' * 20}"

puts "\n\n\n"
puts "#{'=' * 20} WHEN KNOWN API ERROR RESPONSE: #{'=' * 20}"
error_response = '{"code": 123, "message": "Too Long Address"}'
match_response(error_response)
puts "#{'=' * 20}================================#{'=' * 20}"

puts "ss => errors }\n\n\n"
puts "#{'=' * 20} WHEN UNEXPECTED RESPONSE:      #{'=' * 20}"
invalid_response = "<xml>"
match_response(invalid_response)
puts "#{'=' * 20}================================#{'=' * 20}"
