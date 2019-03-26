module BloodContracts
  module Core
    class Tuple < Refined
      class << self
        attr_reader :attributes, :names, :finalized

        def new(*args)
          return super(*args) if finalized
          if args.last.is_a?(Hash)
            names = args.pop.delete(:names)
          end

          raise ArgumentError unless args.all?(Class)
          tuple = Class.new(Tuple) { def inspect; super; end }
          tuple.instance_variable_set(:@attributes, args)
          tuple.instance_variable_set(:@names, names.to_a)
          tuple.instance_variable_set(:@finalized, true)
          tuple
        end
      end

      attr_reader :values
      def initialize(*values, context: Hash.new { |h,k| h[k] = Hash.new }, **)
        _validate_args!(values)
        @errors = []
        @context = context
        @values = values
      end

      def match
        super do
          @matches = self.class.attributes.zip(values).map do |(type, value)|
            type.match(value, context: @context)
          end
          next self if (failure = @matches.find(&:invalid?)).nil?
          failure
        end
      end

      def unpack
        super { |match| @matches.map(&:unpack) }
      end
      alias :to_ary :unpack
      alias :to_a :unpack

      def unpack_h
        @unpack_h ||= Hash[
          unpack.map.with_index do |unpacked, index|
            key = self.class.names[index] || index
            [key, unpacked]
          end
        ]
      end
      alias :to_hash :unpack_h
      alias :to_h :unpack_h

      private def values_by_names
        if self.class.names.empty?
          self.values
        else
          self.class.names.zip(values).map { |k, v| [k, v].join('=') }
        end
      end

      private def _validate_args!(values)
        return if values.size == self.class.attributes.size
        raise ArgumentError, <<~MESSAGE
          wrong number of arguments (given #{values.size}, \
          expected #{self.class.attributes.size})
        MESSAGE
      end

      private def inspect
        "#<tuple #{self.class.name} of (#{values_by_names.join(',')})>"
      end
    end
  end
end
