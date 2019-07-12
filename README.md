[![Build Status](https://travis-ci.org/sclinede/blood_contracts-core.svg?branch=master)][travis]
[![Code Climate](https://codeclimate.com/github/sclinede/blood_contracts-core/badges/gpa.svg)][codeclimate]

[gem]: https://rubygems.org/gems/blood_contracts-core
[travis]: https://travis-ci.org/sclinede/blood_contracts-core
[codeclimate]: https://codeclimate.com/github/sclinede/blood_contracts-core
[adt_wiki]: https://en.wikipedia.org/wiki/Algebraic_data_type
[functional_programming_wiki]: https://en.wikipedia.org/wiki/Functional_programming
[refinement_types_wiki]: https://en.wikipedia.org/wiki/Refinement_type
[ebaymag]: https://ebaymag.com/

# BloodContracts::Core

Simple and agile Ruby data validation tool inspired by refinement types and functional approach

* **Powerful**. [Algebraic Data Type][adt_wiki] guarantees that gem is enough to implement any kind of complex data validation, while [Functional Approach][functional_programming_wiki] gives you full control over validation outcomes
* **Simple**. You could write your first [Refinment Type][refinement_types_wiki] as simple as single Ruby method in single class
* **Independent**. It have no dependencies and you need nothing more to write your complex validations
* **Rubyish**. DSL is inspired by Ruby Struct. If you love Ruby way you'd like the BloodContracts types
* **Born in production**. Created on basis of [eBaymag][ebaymag] project, used as a tool to control and monitor data inside API communication

```ruby
# Write your "types" as simple as...
class Email < ::BC::Refined
  REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

  def match
    return if (context[:email] = value.to_s) =~ REGEX
    failure(:invalid_email)
  end
end

class Phone < ::BC::Refined
  REGEX = /\A(\+7|8)(9|8)\d{9}\z/i

  def match
    return if (context[:phone] = value.to_s) =~ REGEX
    failure(:invalid_phone)
  end
end

# ... compose them...
Login = Email.or_a(Phone)

# ... and match!
case match = Login.match("not-a-login")
when Phone, Email
  match # use as you wish, you exactly know what kind of login you received
when BC::ContractFailure # translate error message
  match.messages # => [:no_matches, :invalid_phone, :invalid_email]
else raise # to make sure you covered all scenarios (Functional Way)
end
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'blood_contracts-core'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install blood_contracts-core

## Refinment Data Type (BC::Refined class)

Refinement type is an Algebraic Data Type (read, you could compose it with other types) with some predicate to check against the data.
In Ruby we've implemented it as a class with method `.match` which accepts single argument - _value_ which could be any kind of object.
This method ALWAYS returns ancestor of BC::Refined. So the most common usage would be:

```ruby
case match = RegistrationFormType.match(params)
when RegistrationFormType
  match.to_h # converts your data to valid Ruby hash
when BC::ContractFailure
  match.messages # deal with error messages
else raise # remember the matching should be exhaustive (simplifies debugging, I promise 🙏)
end
```

To create your first type just inherit class from BC::Refined and implement method `#match`.

The method should:
- return self or nil on successful validation
- return BC::ContractFailure instance by calling method `#failure` and provide error text/symbol

```ruby
require 'countries' # gem with data about countries
class Country < BC::Refined
  def match
    return if ISO3166::Country.find_country_by_alpha2(context[:country_name] = value.to_s)
    failure(:unknown_country)
  end
end
```

Also, you could improve the successful outcome by mapping VALID data to something more appropriate, for example you could normalize data. For that you need only implement `#mapped`

```ruby
require 'countries' # gem with data about countries
class Country < BC::Refined
  def match
    context[:country_string] = value.to_s
    context[:found_country] = ISO3166::Country.find_country_by_alpha2(context[:country_string])
    return if context[:found_country]
    failure(:unknown_country)
  end

  def mapped
    context[:found_country].name
  end
end

case match = Country.call("CI")
when Country
  match.unpack # => "Côte d'Ivoire"
when BC::ContractFailure
  match.messages # => [:unknown_country]
else raise # ... you know why
end
```

Okay, we passed through single value validation. How about complex cases?

Imagine you want to validate response from some JSON API, let's write your first API client with refinement types together.

For this example we'll create RubygemsAPI client:

```ruby
require 'net/http'

module RubygemsAPI
  class Client
    ROOT = "https://rubygems.org/api/v1/gems/".freeze

    def self.get(path)
      uri = URI.parse(File.join(ROOT, path))
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(uri.request_uri).body
    end

    def self.gem(name)
      Validation.call get("#{name}.json")
    end
  end
end
```

But what is the RubygemsAPI::Validation class?

## "And Then" Composition (BC::Pipe class)

Our API client just reads a document from the Internet, which is why first we need to parse it as JSON and then extract something useful.
This is where `#and_then` method quite useful. It runs validation over first BC::Refined and only if the first validation was successful calls the other one.
Otherwise we'll just receive `BC::ContractFailure`, you know.

Our first challenge is to read Ruby gem info from the API, so we need two types: Json (for parsing) and Gem (for gem info)

```ruby
module RubygemsAPI
  require 'json'

  class Json < BC::Refined
    def match
      # now it's easy to understand why we caught JSON::ParserError
      context[:response] = value.to_s
      context[:parsed] = ::JSON.parse(context[:response])
      self
    rescue JSON::ParserError => ex
      context[:exception] = ex # now we could easily playaround with exception and reraise it
      failure(:invalid_json)
    end

    # so the next validation in the pipe will receive parsed response, not unparsed string
    def mapped
      context[:parsed]
    end
  end

  class GemInfo < BC::Refined
    # I chose some data that is interesing for me
    INFO_KEYS = %w(name downloads info authors version homepage_uri source_code_uri)

    def match
      # We have to make sure that result is a hash with appropriate keys
      is_a_project = value.is_a?(Hash) && (INFO_KEYS - value.keys).empty?
      return failure(:reponse_is_not_gem_info) unless is_a_project

      context[:gem_info] = value.slice(*INFO_KEYS)
      self
    end

    def mapped
      context[:gem_info]
    end
  end

  # Simple "and_then" composition will look like that:
  Validation = Json.and_then(GemInfo)
end
```

Let's test our API client!

```ruby
gem = RubygemsAPI::Client.gem("rack") # => #<RubygemAPI::GemInfo ...>
gem.unpack # => {"name" => ..., "authors" => ...}
```

Nice!
But wait, what if we misspelled gem name?

```ruby
gem = RubygemsAPI::Client.gem("big-bada-bum") # => #<BC::ContractFailure ...>
gem.messages # => [:invalid_json]
# hmmm, wait... what?
gem.context[:response] # => "This rubygem could not be found."
# it is plain text. yes. :(
```

It would be great to show that original message to our user, but how?


## "Or" Composition (BC::Sum class)

Actually, we could add another type in our validation using "Or" composition. Use it by calling `#or_a` / `#or_an` method on your BC::Refined class.
Let's try:

```ruby
module RubygemsAPI
  # ...

  class PlainTextError < BC::Refined
    def match
      context[:response] = value.to_s
      # to avoid multiple parsing of response, we'll try to save it
      context[:parsed] = JSON.parse(context[:response])
      failure(:non_plain_text_response)
    rescue JSON::ParserError
      self
    end

    def mapped
      context[:response]
    end
  end

  Validation = PlainTextError.or_a(Json.and_then(GemInfo))
end
```

Let's test our API client, again!

```ruby
gem = RubygemsAPI::Client.gem("rack") # => #<RubygemAPI::GemInfo ...>
gem.unpack # => {"name" => ..., "authors" => ...}

# good, but how about not found case?
gem = RubygemsAPI::Client.gem("big-bada-bum") # => #<RubygemAPI::PlainTextError ...>
gem.unpack # => "This rubygem could not be found."
```

And of course we could use it in a case statement:
```ruby
case gem = RubygemsAPI::Client.gem("rack")
when GemInfo
  gem.unpack # show data to user
when PlaintTextError
  {message: gem.unpack, status: 400} # wrap it into json response
when BC::ContractFailure
  match.messages
else raise # ... you know why
end
```

It was a nice run!

So actually only one other scenario left to show.

Do you remember the Login type from the beginning? Let's try to implement simple registration form validation.

## "And" Composition (BC::Tuple class)

If you'll try to represent complex data with refinement types the best tool is "and" composition or "product" of types. Sounds wierd?

But you actually work with that concept all the time. It's just a record or struct.

Let's write our registration form validation with a Struct:

```ruby
RegistrationForm = Struct.new(:login, :password) do
  def self.call(login, password)
    # validation logic
  end
end
```

So, the BloodContracts version will look the same, except you only need to implement types for login and password:

```ruby
module Registration
  class Email < ::BC::Refined
    REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

    def match
      context[:email_input] = value.to_s
      return failure(:invalid_email) unless context[:email_input] =~ REGEX
      context[:email] = context[:email_input]
      self
    end
  end

  class Phone < ::BC::Refined
    REGEX = /\A(\+7|8)(9|8)\d{9}\z/i

    def match
      context[:phone_input] = value.to_s
      return failure(:invalid_phone) unless context[:phone_input] =~ REGEX
      context[:phone] = context[:phone_input]
      self
    end
  end

  class Ascii < ::BC::Refined
    REGEX = /^[[:ascii:]]+$/i

    def match
      context[:ascii_input] = value.to_s
      return failure(:not_ascii) unless context[:ascii_input] =~ REGEX
      context[:ascii_string] = context[:ascii_input]
      self
    end
  end

  # Create meta class as the Struct.new
  Form = BC::Tuple.new do
    # defines a reader and applies validation on `.match` call
    attribute :login, Email.or_a(Phone)
    attribute :password, Ascii
    # defines an attribute using the anonimous type class
    attribute :remember_me do
      def match
        value.to_s.in? ["checked", ""]
      end

      def mapped
        value.to_s == "checked"
      end
    end
  end
end
```

Tuple can accept either a list of arguments or a hash:
```ruby
Registration::Form.match(login, password)
Registration::Form.match(login: login, password: password)
```

And the code that you'll put in your controller is something like that:

```ruby
class RegistrationController < ActionController::Base
  def create
    case match = Registration::Form.match(params)
    when Registration::Form
      # login here is either Phone or Email
      # password here is always ASCII only string
      user = User.find_or_create!(login: match.login) do |user|
        user.password = match.password
        user.email = match.context[:email]
        user.phone = match.context[:phone]
      end
      render json: {code: 200, user_id: user.id, message: "User was successfully created!"}
    when BC::ContractFailure
      message = match.messages.map(&I18n.method(:t)).join("\n")
      render json: {code: 400, message: message}
    else
      Honeybadger.notify("Invalid BloodContracts usage", context: match.inspect)
      render json: {code: 500, message: "Unexpected contract behavior. Fix me ASAP"}
    end
  end
end
```

Now, you're ready to write any kind of complex data validation with BloodContracts

What are the next steps?

Soon we'll announce `blood_contracts-extended` and `blood_contracts-monitoring`, which will help you monitor the data (what types and how often matches in your system) and
even collect for you unique samples of the communication (up to the types that matched).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `gemspec`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sclinede/blood_contracts-core. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BloodContracts::Core project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sclinede/blood_contracts-core/blob/master/CODE_OF_CONDUCT.md).
