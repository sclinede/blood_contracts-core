require "bundler/setup"
require "json"
require "blood_contracts/core"
require "pry"

module Types
  class ExceptionCaught < BC::ContractFailure; end
  class Base < BC::Refined
    def exception(ex, context: @context)
      ExceptionCaught.new({ exception: ex }, context: context)
    end
  end

  class JSON < Base
    def _match
      context[:parsed] = ::JSON.parse(unpack_refined(@value))
      self
    rescue StandardError => error
      exception(error)
    end

    def _unpack(match)
      match.context[:parsed]
    end
  end
end

module RussianPost
  class DomesticTariffMapper
    def self.call(parcel)
      {
        "mass": parcel.weight,
        "mail-from": parcel.origin_postal_code,
        "mail-to":   parcel.destination_postal_code,
      }
    end
  end

  class InputValidationFailure < BC::ContractFailure; end

  class DomesticParcel < Types::Base
    self.failure_klass = InputValidationFailure

    alias parcel value
    def _match
      return failure(key: :undef_weight, field: :weight) unless parcel.weight
      return if domestic?
      failure(non_domestic_error)
    rescue StandardError => error
      exception(error)
    end

    def _unpack(match)
      DomesticTariffMapper.call(match.parcel)
    end

    private

    def domestic?
      [parcel.origin_country, parcel.destination_country].all?("RU")
    end

    def non_domestic_error
      {
        key: :non_domestic_parcel,
        context: {
          origin: parcel.origin_country,
          destination: parcel.destination_country,
        }
      }
    end
  end

  class InternationalTariffMapper
    def self.call(parcel)
      {
        "mass": parcel.weight,
        "mail-direct":   parcel.destination_country,
      }
    end
  end

  class InternationalParcel < Types::Base
    self.failure_klass = InputValidationFailure

    alias parcel value
    def _match
      return failure(key: :undef_weight, field: :weight) unless parcel.weight
      return failure(not_from_ru_error) if parcel_outside_ru?
      return failure(non_international_error) if non_international_parcel?
      self
    rescue StandardError => error
      exception(error)
    end

    def _unpack(match)
      InternationalTariffMapper.call(match.parcel)
    end

    private

    def parcel_outside_ru?
      parcel.origin_country != "RU"
    end

    def non_international_parcel?
      parcel.destination_country == "RU"
    end

    def not_from_ru_error
      {
        key: :parcel_is_not_from_ru,
        context: {
          origin: parcel.origin_country,
        }
      }
    end

    def non_international_error
      { key: :parcel_is_not_international }
    end
  end

  class RecoverableInputError < Types::Base
    alias parsed_response value
    def _match
      return if [error_code, error_message].all?
      failure(key: :not_a_recoverable_error)
    rescue StandardError => error
      exception(error)
    end

    def error_message
      @error_message ||= parsed_response["desc"]
      @error_message ||= parsed_response["error-details"]&.join("; ")
    end

    private

    def error_code
      parsed_response.values_at("code", "error-code").compact.first
    end
  end

  class OtherError < Types::Base
    alias parsed_response value
    def _match
      return failure(key: :not_a_known_error) if error_code.nil?
      self
    rescue StandardError => error
      exception(error)
    end

    private

    def error_code
      parsed_response.values_at("code", "error-code", "status").compact.first
    end
  end

  class DomesticTariff < Types::Base
    alias parsed_response value
    def _match
      return if is_a_domestic_tariff?
      context[:raw_response] = parsed_response
      failure(key: :not_a_domestic_tariff)
    rescue StandardError => error
      exception(error)
    end

    def cost
      @cost ||= delivery_cost / 100.0
    end

    private

    def is_a_domestic_tariff?
      [delivery_cost, delivery_date, cost].all?
    end

    def delivery_cost
      parsed_response["total-cost"]
    end

    def delivery_date
      @delivery_date ||= parsed_response["delivery-till"]
    end
  end

  class InternationalTariff < Types::Base
    alias parsed_response value
    def _match
      return if is_an_international_tariff?
      context[:raw_response] = parsed_response
      failure(key: :not_an_international_tariff)
    rescue StandardError => error
      exception(error)
    end

    def cost
      @cost ||= (delivery_rate + delivery_vat) / 100.0
    end

    private

    def is_an_international_tariff?
      [delivery_rate, delivery_vat, cost].all?
    end

    def delivery_rate
      parsed_response["total-rate"]
    end

    def delivery_vat
      parsed_response["total-vat"]
    end
  end
end

module RussianPost
  KnownError = RecoverableInputError | OtherError

  DomesticResponse =
    (Types::JSON.and_then(DomesticTariff | KnownError)).set(names: %i[parsed mapped])
  InternationalResponse =
    (Types::JSON.and_then(InternationalTariff | KnownError)).set(names: %i[parsed mapped])

  TariffRequestContract = ::BC::Contract.new(
    DomesticParcel      => DomesticResponse,
    InternationalParcel => InternationalResponse
  )
end

def contractable_request_tariff(input)
  RussianPost::TariffRequestContract.match(input) do |refined_parcel|
    request_tariff(refined_parcel.unpack)
  end
end

def match_response(response)
  case response
  when Types::ExceptionCaught
    puts "Honeybadger.notify #{response.errors_h[:exception]}"
  when RussianPost::InputValidationFailure
    # работаем с тарифом
    puts "render json: { errors: 'Parcel is invalid for request (#{response.to_h})' }"
  when RussianPost::DomesticTariff
    # работаем с тарифом
    puts "render json: { context: 'inside Russia only!', cost: #{response.cost} }"
  when RussianPost::InternationalTariff
    # работаем с тарифом
    puts "render json: { context: 'outside Russia only!', cost_inc_vat: #{response.cost} }"
  when RussianPost::RecoverableInputError
    # работаем с ошибкой, e.g. адрес слишком длинный
    puts "render json: { errors: [#{response.error_message}] } }"
  when RussianPost::OtherError
    # работаем с ошибкой, e.g. адрес слишком длинный
    puts "Honeybadger.notify 'Non-recoverable error from Russian Post API', context: #{pp(response.context)}"
    puts "render json: { errors: ['Sorry, API could not process your request, we've been notified. Try again later'] } }"
  when BC::ContractFailure
    puts "Honeybadger.notify 'Unexpected behavior in Russian Post API Client', context:"
    puts "  'Unexpected behavior in Russian Post API Client'"
    puts "  context:"
    pp(response.context)
    puts "render json: { errors: 'Ooops! Not working, we've been notified. Please, try again later' }"
  else
    require"pry"; binding.pry
  end
end

# DEMO STUFF

Stuff = Struct.new(:daaamn, keyword_init: true)
Parcel = Struct.new(
  :weight, :origin_country, :origin_postal_code, :destination_country,
  :destination_postal_code,
  keyword_init: true
)

PARCELS = [
  # domestic without weight
  Parcel.new(weight: nil, origin_country: "RU", origin_postal_code: "123", destination_country: "RU", destination_postal_code: "123"),

  # not from RU
  Parcel.new(weight: 123, origin_country: "US", origin_postal_code: "123", destination_country: "RU", destination_postal_code: "123"),

  # domestic
  Parcel.new(weight: 123, origin_country: "RU", origin_postal_code: "123", destination_country: "RU", destination_postal_code: "123"),

  # international
  Parcel.new(weight: 123, origin_country: "RU", origin_postal_code: "123", destination_country: "RU", destination_postal_code: "123"),

  # not a parcel
  Stuff.new(daaamn: "WTF?!")
]

RESPONSES = [
  '{"total-cost": 10000, "delivery-till": "2019-12-12"}',
  '{"total-rate": 100000, "total-vat": 1800}',
  '{"total-rate": "some", "total-vat": "text"}',
  '{"code": 1010, "desc": "Too long address"}',
  '{"error-code": 2020, "error-details": ["Too heavy parcel"]}'
]

def run_tests(runs: ENV["RUNS"] || 10)
  runs.to_i.times do
    input = PARCELS.sample
    puts "#{'=' * 20}================================#{'=' * 20}"
    puts "\n\n\n"
    puts "#{'=' * 20}================================#{'=' * 20}"
    puts "#{'=' * 20} WHEN INPUT:                    #{'=' * 20}"
    pp(input)
    match = contractable_request_tariff(input)
    puts "#{'=' * 20}================================#{'=' * 20}"
    puts "#{'=' * 20} ACTION:                        #{'=' * 20}"
    match_response(match)
    puts "#{'=' * 20}================================#{'=' * 20}"
  end
end

def request_tariff(request)
  puts "#{'=' * 20}================================#{'=' * 20}"
  puts "#{'=' * 20} AND THEN REQUEST:              #{'=' * 20}"
  pp(request)

  puts "#{'=' * 20}================================#{'=' * 20}"
  puts "#{'=' * 20} AND THEN RESPONSE:             #{'=' * 20}"
  response = RESPONSES.sample
  puts response

  response
end

run_tests
