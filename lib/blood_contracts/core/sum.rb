require 'set'

module BloodContracts
  module Core
    class Sum < Refined
      class << self
        attr_reader :sum_of, :finalized

        def new(*args)
          return super if finalized

          sum = Class.new(Sum) { def inspect; super; end }
          sum.instance_variable_set(:@sum_of, ::Set.new(args))
          sum.instance_variable_set(:@finalized, true)
          sum
        end

        def or_a(other_type)
          sum = Class.new(Sum) { def inspect; super; end }
          sum.instance_variable_set(:@sum_of, ::Set.new(self.sum_of << other_type))
          sum.instance_variable_set(:@finalized, true)
          sum
        end
        alias :or_an :or_a
        alias :| :or_a
      end

      def match
        super do
          or_matches = self.class.sum_of.map do |type|
            match = type.match(@value, context: @context)
          end

          if (match = or_matches.find(&:valid?))
            match.context[:errors].merge(errors_by_type(or_matches))
            match
          else
            failure(errors: errors_by_type(or_matches))
          end
        end
      end

      def inspect
        "#<sum #{self.class.name} is #{self.class.sum_of.to_a.join(' or ')} (value=#{@value})>"
      end
    end
  end
end
