# encoding: UTF-8
require "spec_helper"

RSpec.describe BloodContracts::Core do
  before do
    module Test
      class EmailValidation < ::BC::Refined
        REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

        def _match
          context[:email] = value.to_s
          return failure("Not an email") unless context[:email] =~ REGEX
          self
        end

        def _unpack(match)
          match.context[:email]
        end
      end
    end

    module Test
      class AsciiValidation < ::BC::Refined
        REGEX = /^[[:ascii:]]+$/i

        def _match
          context[:ascii_string] = value.to_s
          return failure("Not ASCII") unless context[:ascii_string] =~ REGEX
          self
        end

        def _unpack(match)
          match.context[:ascii_string]
        end
      end
    end
  end

  context "standalone validation" do
    subject { Test::AsciiValidation.match(value) }

    context "when value is valid" do
      let(:value) { "i'm written in pure ASCII" }

      it do
        is_expected.to be_valid
        expect { subject.unpack }.not_to raise_error
        expect(subject.unpack).to eq(value)
        expect(subject.context).to match({ascii_string: value})
      end
    end

    context "when value is invalid" do
      let(:value) { "I'm ∑ritten nøt in åßçii" }
      let(:errors) { [{Test::AsciiValidation => ["Not ASCII"]}] }
      let(:validation_context) { { ascii_string: value, errors: errors } }

      it do
        is_expected.to be_invalid
        expect(subject.errors).to match(errors)
        expect(subject.unpack).to match(validation_context)
      end
    end
  end

  context "Sum composition" do

  end

  context "Pipe composition" do

  end

  context "Tuple composition" do
    before do
      module Test
        RegistrationForm = ::BC::Tuple.new do
          attribute :email,    EmailValidation
          attribute :password, AsciiValidation
        end
      end
    end

    it do
      require'pry';binding.pry
      expect(true).to eq(false)
    end
  end
end
