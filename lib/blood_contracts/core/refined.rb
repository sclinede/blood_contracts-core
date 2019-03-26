module BloodContracts
  module Core
    class Refined
      class << self
        def or_a(other_type)
          BC::Sum.new(self, other_type)
        end
        alias :or_an :or_a
        alias :| :or_a

        def and_then(other_type)
          BC::Pipe.new(self, other_type)
        end
        alias :> :and_then

        def match(*args)
          new(*args).match
        end
        alias :call :match

        def ===(object)
          return object.to_ary.any?(self) if object.is_a?(Tuple)
          super
        end
      end

      attr_accessor :context
      attr_reader :errors, :value

      def initialize(value, context: Hash.new { |h,k| h[k] = Hash.new }, **)
        @errors = []
        @context = context
        @value = value
      end

      def match
        return @match if defined? @match
        return @match = yield if block_given?
        self
      end
      alias :call :match

      def valid?
        match.errors.empty?
      end
      def invalid?; !valid?; end

      def unpack
        raise "This is not what you're looking for" if match.invalid?
        return yield(match) if block_given?

        unpack_refined @value
      end

      def failure(error = nil, errors: @errors, context: @context)
        errors << error if error
        ContractFailure.new(
          { self.class => errors }, context: context
        )
      end

      protected

      def refined?(object)
        object.class < BloodContracts::Core::Refined
      end

      def share_context_with(match)
        match.context = @context.merge!(match.context)
        yield(match.context)
      end

      def refine_value(value)
        refined?(value) ? value.match : Anything.new(value)
      end

      def unpack_refined(value)
        refined?(value) ? value.unpack : value
      end

      def errors_by_type(matches)
        Hash[
          matches.map(&:class).zip(matches.map(&:errors))
        ].delete_if { |_, errors| errors.empty? }
      end
    end

    class ContractFailure < Refined
      def initialize(*)
        super
        @context.merge!(errors: @value.to_h)
      end

      def errors
        context[:errors]
      end

      def match
        self
      end

      def unpack
        context
      end
    end

    class Anything < Refined
      def match
        self
      end

      def valid?
        true
      end

      def unpack
        @value
      end
    end
  end
end
