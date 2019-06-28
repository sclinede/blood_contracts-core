require "set"

module BloodContracts::Core
  class Sum < Refined
    class << self
      attr_reader :sum_of, :finalized

      # rubocop:disable Style/SingleLineMethods
      def new(*args)
        return super(*args) if finalized

        new_sum = args.reduce([]) do |acc, type|
          type.respond_to?(:sum_of) ? acc + type.sum_of.to_a : acc << type
        end

        sum = Class.new(Sum) { def inspect; super; end }
        finalize!(sum, new_sum)
        sum
      end

      def or_a(other_type)
        sum = Class.new(Sum) { def inspect; super; end }
        new_sum = sum_of.to_a
        if other_type.respond_to?(:sum_of)
          new_sum += other_type.sum_of.to_a
        else
          new_sum << other_type
        end
        finalize!(sum, new_sum)
        sum
      end
      # rubocop:enable Style/SingleLineMethods
      alias or_an or_a
      alias | or_a

      private def finalize!(new_class, new_sum)
        new_class.instance_variable_set(:@sum_of, ::Set.new(new_sum.compact))
        new_class.instance_variable_set(:@finalized, true)
      end

      def inspect
        return super if name
        "Sum(#{sum_of.map(&:inspect).join(',')})"
      end
    end

    def match
      or_matches = self.class.sum_of.map do |type|
        type.match(@value, context: @context)
      end

      if (match = or_matches.find(&:valid?))
        match
      else
        failure(:no_matches)
      end
    end

    def errors
      @match.errors
    end

    def inspect
      "#<sum #{self.class.name} is #{self.class.sum_of.to_a.join(' or ')}"\
      " (value=#{@value})>"
    end
  end
end
