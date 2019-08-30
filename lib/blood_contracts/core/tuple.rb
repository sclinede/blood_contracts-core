require_relative "../ext/symbolize_keys.rb"

using BloodContracts::SymbolizeKeys

module BloodContracts::Core
  # Meta refinement type, represents product of several refinement types
  class Tuple < Refined
    class << self
      # List of types in the Tuple
      #
      # @return [Array<Refined>]
      attr_reader :attributes

      # Names of attributes
      #
      # @return [Array<Symbol>]
      #
      attr_reader :names

      # Metaprogramming around constructor
      # Turns input into Tuple meta-class
      #
      # @param (see #initialze)
      #
      # rubocop:disable Style/SingleLineMethods
      def new(*args, **kwargs, &block)
        args = lookup_hash_args(*args, kwargs)

        return super(*args, **kwargs) if @finalized
        names = args.pop.delete(:names) if args.last.is_a?(Hash)

        raise ArgumentError unless args.all? { |type| type < Refined }
        tuple = Class.new(self) { def inspect; super; end }
        tuple.instance_variable_set(:@attributes, args)
        tuple.instance_variable_set(:@names, names.to_a)
        tuple.instance_variable_set(:@finalized, true)
        tuple.class_eval(&block) if block_given?
        tuple
      end
      # rubocop:enable Style/SingleLineMethods

      # Helper which registers attribute in the Tuple, also defines a reader
      def attribute(name, type = nil, &block)
        if type.nil?
          type = type_from_block(name, &block)
        else
          raise ArgumentError unless type < Refined
        end

        @attributes << type
        @names << name

        define_method(name) do
          match.context.dig(:attributes, name)
        end
      end

      # Accessor to define alternative to ContractFailure for #failure
      # method to use
      #
      # @return [ContractFailure]
      #
      attr_accessor :failure_klass
      def inherited(new_klass)
        new_klass.instance_variable_set(:@attributes, [])
        new_klass.instance_variable_set(:@names, [])
        new_klass.instance_variable_set(:@finalized, true)
        new_klass.failure_klass ||= TupleContractFailure
        super
      end

      private

      # Generate an anonymous type from a block
      #
      # @param String name of the attribute to define the type for
      #
      # @param Proc block which will be evaluated in a context
      # of our anonymous type
      #
      # @return Class
      #
      def type_from_block(name, &block)
        raise ArgumentError unless block_given?

        const_set(
          "InlineType_#{name.to_s.capitalize}",
          Class.new(Refined) { class_eval(&block) }
        )
      end

      # Handle arguments passed as hash with string or
      # symbol keys
      #
      # @param [Array<Object>] *args that can contain an array of arguments
      # or a single Hash we're looking for
      #
      # @param [Hash<Object, Object>] **kwargs hash that can be converted to
      # args when args array is empty
      #
      # @return [Array<Object>]
      #
      def lookup_hash_args(*args, **kwargs)
        if args.empty?
          [kwargs]
        elsif args.length == 1 && args.last.is_a?(Hash)
          [args.first.symbolize_keys]
        else
          args
        end
      end
    end

    # List of values in Tuple
    #
    # @return [Array<Object>]
    #
    attr_reader :values

    # Tuple constructor, builds Tuple from list of data values
    #
    # @param [Array<Object>] *values that we'll keep inside the Tuple
    # @option [Hash<Symbol, Object>] context to share between types
    #
    def initialize(*values, context: {}, **)
      @context = context
      @context[:attributes] ||= {}

      additional_context = values.last if values.last.is_a?(Hash)
      additional_context ||= {}

      @values = parse_values_from_context(context.merge(additional_context))
      @values ||= values

      @errors = []
    end

    # The type which is the result of data matching process
    # For Tuple it verifies that all the attributes data are valid types
    #
    # @return [BC::Refined]
    #
    def match
      @matches = attributes_enumerator.map do |(type, value), index|
        attribute_name = self.class.names[index]
        attributes.store(
          attribute_name, type.match(value, context: @context.dup)
        )
      end
      return if (failures = @matches.select(&:invalid?)).empty?
      failures.unshift(failure).reduce(:merge!)
    end

    # Turns match into array of unpacked values
    #
    # @return [Array<Object>]
    #
    def mapped
      @matches.map(&:unpack)
    end

    # (see #mapped)
    alias to_ary unpack

    # (see #mapped)
    alias to_a unpack

    # Unpacked value in form of a hash per attribute
    #
    # @return [Hash<String, ContractFailure>]
    #
    def unpack_h
      @unpack_h ||= attributes.transform_values(&:unpack)
    end
    alias to_hash unpack_h
    alias to_h unpack_h
    alias unpack_attributes unpack_h

    # Hash of attributes (name & type pairs)
    #
    # @return [Hash<String, Refined>]
    #
    def attributes
      @context[:attributes]
    end

    # Subset of attributes which are invalid
    #
    # @return [Hash<String, ContractFailure>]
    #
    def attribute_errors
      {}
    end

    # Helper to build a ContractFailure with shared context
    #
    # @return [ContractFailure]
    #
    private def failure(*)
      self.class.failure_klass.new(context: @context)
    end

    # @private
    private def parse_values_from_context(context)
      return if context.empty?
      return unless (self.class.names - context.keys).empty?
      context.values_at(*self.class.names)
    end

    # @private
    private def attributes_enumerator
      self.class.attributes.zip(@values).each.with_index
    end

    # @private
    private def values_by_names
      if self.class.names.empty?
        values
      else
        self.class.names.zip(values).map { |k, v| [k, v].join("=") }
      end
    end

    # @private
    private def inspect
      "#<tuple #{self.class.name} of (#{values_by_names.join(', ')})>"
    end
  end
end
