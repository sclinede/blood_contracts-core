# require "bundler/setup"
require 'blood_contracts/core'

module Types
  class JSON < BloodType
    param :json_string

    def match
      @parsed = ::JSON.parse(unpack_value(json_string))
      self
    rescue StandardError => error
      @errors << error
      self
    end

    def unpack
      @parsed
    end
  end

  class Tariff < BloodType
    param :json

    def match
      super do
        @parsed = unpack_value(self.json).slice("cost", "cur").compact
        @errors << :not_a_tariff if @parsed.size != 2
        self
      end
    end
  end

  class Error < BloodType
    param :json

    def match
      super do
        @parsed = unpack_value(self.json).slice("code", "message").compact
        @errors << :not_an_error if @parsed.size != 2
        self
      end
    end
  end

  class Response < BloodType
    option :raw, BC::Anything.method(:new)
    option :parsed, JSON.method(:new), default: -> { raw }
    option :mapped, (Tariff | Error).method(:new), default: -> { parsed }
  end
end

def match_response(response)
  case (match = Response.new(response))
  when ContractFailure
    puts "Honeybadger.notify 'Unexpected behavior in Russian Post', context: #{response_match.context}"
    puts "render json: { errors: #{match.errors} }"
  when Tariff
    # работаем с тарифом
    puts "render json: { tariff: #{match.mapped} }"
  when Error
    # работаем с ошибкой, e.g. адрес слишком длинный
    puts "render json: { errors: [#{match.mapped.unpack['message']}] } }"
  end
end

puts "#{'=' * 20}================================#{'=' * 20}"
puts "#{'=' * 20} WHEN VALID RESPONSE:           #{'=' * 20}"
valid_response = '{"cost": 1000, "cur": "RUB"}'
match_response(valid_response)
puts "#{'=' * 20}================================#{'=' * 20}"


puts "\n\n\n"
puts "#{'=' * 20} WHEN KNOWN API ERROR RESPONSE: #{'=' * 20}"
error_response = '{"code": 123, "message": "Too Long Address"}'
match_response(error_response)
puts "#{'=' * 20}================================#{'=' * 20}"


puts "\n\n\n"
puts "#{'=' * 20} WHEN UNEXPECTED RESPONSE:      #{'=' * 20}"
invalid_response = '<xml>'
match_response(invalid_response)
puts "#{'=' * 20}================================#{'=' * 20}"
