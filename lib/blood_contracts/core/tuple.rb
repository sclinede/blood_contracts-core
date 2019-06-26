module BloodContracts::Core
  class Tuple < Refined
    class << self
      attr_reader :attributes, :names, :finalized

      # rubocop:disable Style/SingleLineMethods
      def new(*args, **kwargs, &block)
        return super(*args, **kwargs) if finalized
        names = args.pop.delete(:names) if args.last.is_a?(Hash)

        raise ArgumentError unless args.all?(Class)
        tuple = Class.new(Tuple) { def inspect; super; end }
        tuple.instance_variable_set(:@attributes, args)
        tuple.instance_variable_set(:@names, names.to_a)
        tuple.instance_variable_set(:@finalized, true)
        tuple.class_eval(&block) if block_given?
        tuple
      end
      # rubocop:enable Style/SingleLineMethods

      def attribute(name, type)
        raise ArgumentError unless type < Refined
        @attributes << type
        @names << name
        define_method(name) do
          match.context.dig(:attributes, name)
        end
      end

      attr_accessor :failure_klass
      def inherited(new_klass)
        new_klass.instance_variable_set(:@attributes, [])
        new_klass.instance_variable_set(:@names, [])
        new_klass.instance_variable_set(:@finalized, true)
        new_klass.failure_klass ||= TupleContractFailure
        super
      end

      private

      attr_writer :names
    end

    attr_reader :values
    def initialize(*values, context: Hash.new { |h, k| h[k] = {} }, **)
      @context = context
      @context[:attributes] ||= {}

      additional_context = values.last if values.last.is_a?(Hash)
      additional_context ||= {}

      @values = parse_values_from_context(context.merge(additional_context))
      @values ||= values

      @errors = []
    end

    def match
      super do
        @matches = attributes_enumerator.map do |(type, value), index|
          attribute_name = self.class.names[index]
          attributes.store(attribute_name, type.match(value, context: @context))
        end
        next self if @matches.find(&:invalid?).nil?
        failure(:invalid_tuple)
      end
    end

    def unpack
      super { |_match| @matches.map(&:unpack) }
    end
    alias to_ary unpack
    alias to_a unpack

    def unpack_h
      @unpack_h ||= attributes.transform_values(&:unpack)
    end
    alias to_hash unpack_h
    alias to_h unpack_h
    alias unpack_attributes unpack_h

    def attributes
      @context[:attributes]
    end

    def attribute_errors
      {}
    end

    private def parse_values_from_context(context)
      return if context.empty?
      return unless (self.class.names - context.keys).empty?
      context.values_at(*self.class.names)
    end

    private def attributes_enumerator
      self.class.attributes.zip(@values).each.with_index
    end

    private def values_by_names
      if self.class.names.empty?
        values
      else
        self.class.names.zip(values).map { |k, v| [k, v].join("=") }
      end
    end

    private def inspect
      "#<tuple #{self.class.name} of (#{values_by_names.join(', ')})>"
    end
  end
end
