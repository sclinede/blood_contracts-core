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

        def match(*args, **kwargs)
          if block_given?
            new(*args, **kwargs).match { |*subargs| yield(*subargs) }
          else
            new(*args, **kwargs).match
          end
        end
        alias :call :match

        def ===(object)
          return object.to_ary.any?(self) if object.is_a?(Tuple)
          super
        end

        def set(**kwargs)
          kwargs.each do |setting, value|
            send(:"#{setting}=", value)
          end
          self
        end

        attr_accessor :failure_klass
        def inherited(new_klass)
          new_klass.failure_klass ||= ContractFailure
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
        return @match = (yield || self) if block_given?
        return @match = (_match || self) if respond_to?(:_match)
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
        return @match = _unpack(match) if respond_to?(:_unpack)

        unpack_refined @value
      end

      def failure(error = nil, errors: @errors, **kwargs)
        error ||= kwargs unless kwargs.empty?
        errors << error if error
        self.class.failure_klass.new(
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
        matches.map(&:errors).reduce(:+).delete_if(&:empty?)
      end
    end

    class ContractFailure < Refined
      def initialize(value = nil, **)
        super
        return unless @value
        @context[:errors] = (@context[:errors].to_a << @value.to_h)
      end

      def errors
        @context[:errors].to_a
      end

      def errors_h
        errors.reduce(:merge)
      end
      alias :to_h :errors_h

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
