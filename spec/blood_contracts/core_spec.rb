require "spec_helper"

RSpec.describe BloodContracts::Core do
  before do
    module Test
      class Json < ::BC::Refined
        require "json"

        def match
          context[:raw_value] = unpack_refined(value).to_s
          context[:parsed] =
            JSON.parse(context[:raw_value], symbolize_names: true)
          nil
        rescue JSON::ParserError => exception
          failure(exception)
        end

        def mapped
          context[:parsed]
        end
      end

      class Phone < ::BC::Refined
        REGEX = /\A(\+7|8)(9|8)\d{9}\z/i

        def match
          context[:phone] = unpack_refined(value).to_s
          context[:clean_phone] = context[:phone].gsub(/[\s\(\)-]/, "")
          return if context[:clean_phone] =~ REGEX

          failure("Not a phone")
        end

        def mapped
          context[:clean_phone]
        end
      end

      class Email < ::BC::Refined
        REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

        def match
          context[:email] = unpack_refined(value).to_s
          return if context[:email] =~ REGEX

          failure("Not an email")
        end

        def mapped
          context[:email]
        end
      end

      class Ascii < ::BC::Refined
        REGEX = /^[[:ascii:]]+$/i

        def match
          context[:ascii_string] = value.to_s
          return if context[:ascii_string] =~ REGEX

          failure("Not ASCII")
        end

        def mapped
          context[:ascii_string]
        end
      end
    end
  end

  context "standalone validation" do
    subject { Test::Ascii.match(value) }

    context "when value is valid" do
      let(:value) { "i'm written in pure ASCII" }

      it do
        is_expected.to be_valid
        expect { subject.unpack }.not_to raise_error
        expect(subject.unpack).to eq(value)
        expect(subject.context).to match({ ascii_string: value })
      end
    end

    context "when value is invalid" do
      let(:value) { "I'm ∑ritten nøt in åßçii" }
      let(:error) { { Test::Ascii => ["Not ASCII"] } }
      let(:validation_context) { { ascii_string: value, errors: [error] } }

      it do
        is_expected.to be_invalid
        expect(subject.errors).to match([error])
        expect(subject.messages).to match(["Not ASCII"])
        expect(subject.unpack).to match(error)
      end
    end
  end

  context "Sum composition" do
    before do
      module Test
        Login = Email.or_a(Phone)
      end
    end

    subject { Test::Login.match(login) }

    context "when login is valid" do
      context "when login is email" do
        let(:login) { "admin@example.com" }
        let(:errors) { [{ Test::Phone => ["Not a phone"] }] }
        let(:validation_context) do
          hash_including(
            phone: login,
            clean_phone: login,
            errors: errors,
            email: login
          )
        end

        it do
          is_expected.to be_valid
          expect { subject.unpack }.not_to raise_error
          expect(subject.unpack).to eq(login)
          expect(subject.context).to match(validation_context)
        end
      end

      context "when login is phone" do
        let(:login) { "8(800) 200 - 11 - 00" }
        let(:cleaned_phone) { "88002001100" }
        let(:errors) { [{ Test::Email => ["Not an email"] }] }
        let(:validation_context) do
          hash_including(
            phone: login,
            clean_phone: cleaned_phone,
            errors: errors,
            email: login
          )
        end

        it do
          is_expected.to be_valid
          expect { subject.unpack }.not_to raise_error
          expect(subject.unpack).to eq(cleaned_phone)
          expect(subject.context).to match(validation_context)
        end
      end
    end

    context "when login is invalid" do
      let(:login) { "I'm something else" }
      let(:errors) do
        [
          { Test::Email => ["Not an email"] },
          { Test::Phone => ["Not a phone"] },
          { Test::Login => [:no_matches] }
        ]
      end

      it do
        is_expected.to be_invalid
        expect(subject.errors).to match_array(errors)
        expect(subject.unpack).to match({ Test::Login => [:no_matches] })
      end
    end
  end

  context "Tuple composition" do
    before do
      module Test
        class RegistrationInput < ::BC::Tuple
          attribute :email,    Email
          attribute :password, Ascii
        end
      end
    end

    subject { Test::RegistrationInput.match(email, password) }

    context "when valid input" do
      let(:email) { "admin@mail.com" }
      let(:password) { "newP@ssw0rd" }
      let(:attributes) do
        { email: kind_of(Test::Email), password: kind_of(Test::Ascii) }
      end

      it do
        expect(subject).to be_valid
        expect(subject.attributes).to match(attributes)
        expect(subject.to_h).to match(email: email, password: password)
        expect(subject.errors).to be_empty
        expect(subject.attribute_errors).to be_empty
      end
    end

    context "when input is invalid" do
      let(:email) { "admin" }
      let(:email_error) { { Test::Email => ["Not an email"] } }
      let(:password) { "newP@ssw0rd" }
      let(:attributes) do
        attribute_errors.merge(password: kind_of(Test::Ascii))
      end
      let(:attribute_errors) { { email: kind_of(BC::ContractFailure) } }
      let(:tuple_invalid) { { Test::RegistrationInput => [:invalid_tuple] } }

      it do
        expect(subject).to be_invalid
        expect(subject.attributes).to match(attributes)
        expect(subject.to_h).to match(email: email_error)
        expect(subject.errors).to match_array([email_error, tuple_invalid])
        expect(subject.attribute_errors).to match(attribute_errors)
      end
    end
  end

  context "Pipe composition" do
    before do
      module Test
        class RegistrationInput < ::BC::Tuple
          attribute :login,    Email.or_a(Phone)
          attribute :password, Ascii
        end

        ResponseParser = BC::Pipe.new do
          step :parse, Json
          step :validate, RegistrationInput
        end
      end
    end

    subject { Test::ResponseParser.match(response) }

    context "when value is invalid JSON" do
      let(:response) { "<xml>" }
      let(:error) { { Test::Json => [kind_of(JSON::ParserError)] } }
      let(:validation_context) do
        {
          raw_value: response,
          errors: [error],
          steps: ["BloodContracts::Core::ContractFailure"],
          steps_values: { parse: response }
        }
      end

      it do
        is_expected.to be_invalid
        is_expected.to be_kind_of(BC::ContractFailure)
        expect(subject.unpack).to match(error)
        expect(subject.context).to match(validation_context)
      end
    end

    context "when value is valid JSON" do
      context "when value is invalid registration data" do
        let(:response) { '{"phone":"+78889992211"}' }
        let(:error) { { Test::RegistrationInput => [:invalid_tuple] } }
        let(:errors) do
          [
            { Test::Email => ["Not an email"] },
            { Test::Phone => ["Not a phone"] },
            { Test::Ascii => ["Not ASCII"] },
            { Test::RegistrationInput => [:invalid_tuple] }
          ]
        end
        let(:validation_context) do
          hash_including(
            raw_value: response,
            errors: array_including(errors),
            steps: ["Test::Json", "BloodContracts::Core::TupleContractFailure"],
            steps_values: {
              parse: response,
              validate: { phone: "+78889992211" }
            }
          )
        end

        it do
          is_expected.to be_invalid
          is_expected.to be_kind_of(BC::TupleContractFailure)
          expect(subject.unpack).to match(error)
          expect(subject.context).to match(validation_context)
        end
      end

      context "when value is valid registration data" do
        context "when login is an email" do
          let(:response) { '{"login":"admin@example.com", "password":"111"}' }
          let(:payload) { { login: "admin@example.com", password: "111" } }

          it do
            is_expected.to be_valid
            is_expected.to be_kind_of(Test::RegistrationInput)
            expect(subject.unpack).to match(["admin@example.com", "111"])
            expect(subject.to_h).to match(payload)
          end
        end

        context "when login is a phone" do
          let(:response) { '{"login":"8 (999) 123-33-12", "password":"111"}' }
          let(:payload) { { login: "89991233312", password: "111" } }

          it do
            is_expected.to be_valid
            is_expected.to be_kind_of(Test::RegistrationInput)
            expect(subject.unpack).to match(%w[89991233312 111])
            expect(subject.to_h).to match(payload)
          end
        end
      end
    end
  end
end
