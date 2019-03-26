require 'set'

module BloodContracts
  module Core
    class Sum < Refined
      class << self
        attr_reader :sum_of, :finalized

        def new(*args)
          return super if finalized

          new_sum = args.reduce([]) { |acc, type| type.respond_to?(:sum_of) ? acc + type.sum_of.to_a : acc << type  }

          sum = Class.new(Sum) { def inspect; super; end }
          sum.instance_variable_set(:@sum_of, ::Set.new(new_sum.compact))
          sum.instance_variable_set(:@finalized, true)
          sum
        end

        def or_a(other_type)
          sum = Class.new(Sum) { def inspect; super; end }
          new_sum = self.sum_of.to_a
          new_sum += other_type.sum_of.to_a if other_type.respond_to?(:sum_of)
          sum.instance_variable_set(:@sum_of, ::Set.new(new_sum.compact))
          sum.instance_variable_set(:@finalized, true)
          sum
        end
        alias :or_an :or_a
        alias :| :or_a

        def inspect
          return super if self.name
          "Sum(#{self.sum_of.map(&:inspect).join(',')})"
        end
      end

      def match
        super do
          or_matches = self.class.sum_of.map do |type|
            match = type.match(@value, context: @context)
          end

          if (match = or_matches.find(&:valid?))
            match
          else
            or_matches.first
            # just use the context
            # ContractFailure.new(context: context)
          end
        end
      end

      def errors
        match.errors
      end

      def inspect
        "#<sum #{self.class.name} is #{self.class.sum_of.to_a.join(' or ')} (value=#{@value})>"
      end
    end
  end
end
