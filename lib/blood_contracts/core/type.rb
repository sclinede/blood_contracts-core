module BloodContracts
  module Core
    class Type
      extend Dry::Initializer

      # TODO: share context between Refinement Types match
      class << self
        def attributes
          @attributes ||= []
        end

        def param(name, *)
          @attributes = attributes | [name.to_sym]
          super
        end

        def option(name, type = nil, as: name, **)
          @attributes = attributes | [as.to_sym]
          super
        end

        def single?
          attributes.size <= 1
        end

        attr_reader :others
        def or_a(other_type)
          c = Class.new(self)
          c.instance_variable_set(:@others, self.others.to_a << other_type)
          c
        end
        alias :or_an :or_a
        alias :| :or_a

        def match(*args)
          new(*args).match
        end
        alias :call :match

        def ===(object)
          return true if (result = super)
          return result unless refined?(object)
          return result if object.class.send(:single?)

          !!object.attributes.values.find { |sub_type| self === sub_type }
        end

        def refined?(object)
          self.class === object
        end
      end

      attr_accessor :context
      attr_reader :errors, :value_handler
      def initialize(*args, **kwargs)
        @errors = []
        @context = kwargs.delete(:context) || {}
        @value_handler = self.class.single? ? Single.new(self) : Tuple.new(self)

        super(*args, **kwargs)
      end

      def attributes
        @attributes ||= self.class.dry_initializer.attributes(self)
      end

      def match
        return @match if defined? @match
        return @match = yield if block_given?
        value_handler.match
      end
      alias :call :match

      def valid?
        value_handler.valid?
      end
      def invalid?; !valid?; end
      def failure?; false; end

      def unpack
        value_handler.unpack
      end

      def single?
        Single === value_handler
      end

      protected

      class ValueHandler
        def initialize(subject)
          @subject = subject
        end

        def errors_by_type(matches)
          Hash[
            matches.map(&:class).zip(matches.map(&:errors))
          ].delete_if { |_, errors| errors.empty? }
        end

        def refined?(object)
          self.class === object
        end

        def unpack_refined(value)
          refined?(value) ? value.unpack : value
        end
      end

      class Tuple < ValueHandler
        def match
          and_matches = attributes.values.map(&:match)
          return @subject if and_matches.all?(&:valid?)

          BloodContracts::ContractFailure.new(
            context: { errors: errors_by_type(and_matches) }
          )
        end

        def unpack
          raise "This is not what you're looking for" if invalid?

          match.attributes.transform_values(&method(:unpack_refined))
        end

        def single?
          false
        end
      end

      class Single < ValueHandler
        def match
          return @subject unless refined?(value)
          return value.match if @subject.class.others.empty?

          or_matches = @subject.class.others.map { |type| type.match(value) }
          if (match = or_matches.find(:valid?))
            match.merge!(context: { errors: errors_by_type(or_matches) })
            match
          else
            BloodContracts::ContractFailure.new(
              context: { errors: errors_by_type(and_matches) }
            )
          end
        end

        def valid?
          @subject.errors.empty?
        end

        def unpack
          raise "This is not what you're looking for" if @subject.invalid?

          unpack_refined value
        end

        def single?
          true
        end

        private

        def value
          @value ||= @subject.attributes.values.first
        end
      end
    end
  end
end
