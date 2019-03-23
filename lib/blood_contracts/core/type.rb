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

        attr_reader :sum
        def or_a(other_type)
          c = Class.new(Anything)
          c.instance_variable_set(
            :@sum, Set.new([self] + self.sum.to_a << other_type)
          )
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
          return result unless object.class < BloodContracts::Core::Type
          if object.class.send(:single?)
            return result if object.class.sum.to_a.empty?
            return object.class.sum.any? { |or_type| self == or_type }
          end

          object.attributes.values.any? { |sub_type| self === sub_type }
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
        @match = value_handler.match
      end
      alias :call :match

      def valid?
        value_handler.valid?
      end
      def invalid?; !valid?; end

      def unpack
        value_handler.unpack
      end

      def single?
        Single === value_handler
      end

      def refined?(object)
        BloodContracts::Core::Type === object
      end

      def unpack_refined(value)
        refined?(value) ? value.unpack : value
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
          @subject.refined?(object)
        end

        def unpack_refined(value)
          @subject.unpack_refined(value)
        end
      end

      class Tuple < ValueHandler
        def initialize(*)
          super
          @wrapper = Struct.new(*@subject.class.attributes, keyword_init: true)
        end

        def wrap_unpacked(match)
          @wrapper.new(
            match.attributes.transform_values(&method(:unpack_refined))
          )
        end

        def match
          failed_match =
            @subject.attributes.values.lazy.map(&:match).find(&:invalid?)

          if failed_match
            BloodContracts::ContractFailure.new(
              context: { errors: errors_by_type([failed_match]) }
            )
          else
            @subject
          end
        end

        def unpack
          raise "This is not what you're looking for" if invalid?

          wrap_unpacked(@subject.match)
        end

        def invalid?
          BloodContracts::ContractFailure === @subject.match
        end
        def valid?; !invalid?; end

        def single?
          false
        end
      end

      class Single < ValueHandler
        def match
          sum = @subject.class.sum.to_a
          return refined?(value) ? value.match : @subject if sum.empty?

          or_matches = sum.map { |type| type.match(value) }
          if (match = or_matches.find(&:valid?))
            match.context.merge!(errors: errors_by_type(or_matches))
            match
          else
            BloodContracts::ContractFailure.new(
              context: { errors: errors_by_type(or_matches) }
            )
          end
        end

        def valid?
          @subject.errors.empty?
        end

        def unpack
          raise "This is not what you're looking for" unless valid?

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
