module BloodContracts::Core
  class InvalidTypeUnpacking < StandardError; end

  class Refined
    class << self
      def or_a(other_type)
        BC::Sum.new(self, other_type)
      end
      alias or_an or_a
      alias | or_a

      def and_then(other_type)
        BC::Pipe.new(self, other_type)
      end
      alias > and_then

      def match(*args, **kwargs, &block)
        instance = new(*args, **kwargs)
        match = instance.match(&block) || instance
        instance.instance_variable_set(:@match, match)
        match.instance_variable_set(:@unpack, match.send(:mapped))
        match
      end
      alias call match

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
    attr_reader :errors

    def initialize(value, context: Hash.new { |h, k| h[k] = {} }, **)
      @errors = []
      @context = context
      @value = value
    end

    protected def match; end
    alias call match

    protected def mapped; end

    def valid?
      @match.errors.empty?
    end

    def invalid?
      !valid?
    end

    def unpack
      @unpack ||= value
    end

    def failure(error = nil, errors: @errors, **kwargs)
      error ||= kwargs unless kwargs.empty?
      errors << error if error
      self.class.failure_klass.new(
        { self.class => errors }, context: @context
      )
    end

    protected

    def value
      unpack_refined(@value)
    end

    def refined?(object)
      object.class < BloodContracts::Core::Refined
    end

    # FIXME: do we need it?
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
  end
end
