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

  def _match
    return if (context[:email] = value.to_s) =~ REGEX
    failure(:invalid_email)
  end
end

class Phone < ::BC::Refined
  REGEX = /\A(\+7|8)(9|8)\d{9}\z/i

  def _match
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

To create your first type just inherit class from BC::Refined and implement method `#_match`.

The method should:
- return nil on successful validation
- return BC::ContractFailure instance by calling method `#failure` and provide error text/symbol

```ruby
require 'countries' # gem with data about countries
class Country < BC::Refined
  def _match
    return if ISO3166::Country.find_country_by_alpha2(context[:country_name] = value.to_s)
    failure(:unknown_country)
  end
end
```

Also, you could improve the successful outcome by mapping VALID data to something more appropriate, for example you could normalize data. For that you need only implement `#_unpack`

```ruby
require 'countries' # gem with data about countries
class Country < BC::Refined
  def _match
    context[:country_string] = value.to_s
    context[:found_country] = ISO3166::Country.find_country_by_alpha2(context[:country_string])
    return if context[:found_country]
    failure(:unknown_country)
  end

  def _unpack(match)
    match.context[:found_country].name
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

## "And Then" Composition (BC::Pipe class)

## "Or" Composition (BC::Sum class)

## "And" Composition (BC::Tuple class)


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/sclinede/blood_contracts-core. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BloodContracts::Core project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/sclinede/blood_contracts-core/blob/master/CODE_OF_CONDUCT.md).
