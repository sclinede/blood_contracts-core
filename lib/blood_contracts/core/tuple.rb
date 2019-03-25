module BloodContracts
  module Core
    class Tuple < Refined
      class << self
        attr_reader :attributes, :names, :finalized

        def new(*args, **kwargs)
          return super(*args, **kwargs) if finalized

          raise ArgumentError unless args.all?(Class)
          pipe = Class.new(Tuple) { def inspect; super; end }
          pipe.instance_variable_set(:@attributes, args)
          pipe.instance_variable_set(:@names, kwargs[:names].to_a)
          pipe.instance_variable_set(:@finalized, true)
          pipe
        end
      end

      attr_reader :values
      def initialize(*args)
        super
        @values = args
      end

      def match
        super do
          matches = self.class.attributes.zip(values).map do |(type, value)|
            type.match(value, context: @context)
          end
          next self unless (failure = matches.find?(&:invalid?)).nil?
          failure
        end
      end

      def unpack
        super { |match| match.values.map(&method(:unpack_refined)) }
      end
      alias :to_ary :unpack

      private def values_by_names
        if self.class.names.empty?
          self.values
        else
          self.class.names.zip(attributes).map { |k, v| [k, v].join('=') }
        end
      end

      private def inspect
        "#<tuple #{self.class.name} (#{values_by_names.join(',')}>"
      end
    end
  end
end
