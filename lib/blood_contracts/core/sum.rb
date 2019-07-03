require "set"

module BloodContracts::Core
  # Meta refinement type, represents sum of several refinement types
  class Sum < Refined
    class << self
      # Represents list of types in the sum
      #
      # @return [Array<Refined>]
      #
      attr_reader :sum_of

      # Metaprogramming around constructor
      # Turns input into Sum meta-class
      #
      # @param (see #initialze)
      #
      # rubocop:disable Style/SingleLineMethods
      def new(*args)
        return super(*args) if @finalized

        new_sum = args.reduce([]) do |acc, type|
          type.respond_to?(:sum_of) ? acc + type.sum_of.to_a : acc << type
        end

        sum = Class.new(self) { def inspect; super; end }
        finalize!(sum, new_sum)
        sum
      end

      # Compose types in a Sum check
      # Sum passes data from type to type in parallel, only one type
      # have to match
      #
      # @return [BC::Sum]
      #
      def or_a(other_type)
        sum = Class.new(self) { def inspect; super; end }
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

      # @private
      private def finalize!(new_class, new_sum)
        new_class.instance_variable_set(:@sum_of, ::Set.new(new_sum.compact))
        new_class.instance_variable_set(:@finalized, true)
      end

      # Returns text representation of Sum meta-class
      #
      # @return [String]
      #
      def inspect
        return super if name
        "Sum(#{sum_of.map(&:inspect).join(',')})"
      end
    end

    # The type which is the result of data matching process
    # For Tuple it verifies that all the attributes data are valid types
    #
    # @return [BC::Refined]
    #
    def match
      @or_matches = self.class.sum_of.map do |type|
        type.match(@value, context: @context)
      end

      if (match = @or_matches.find(&:valid?))
        match
      else
        failure(:no_matches)
      end
    end

    # List of errors per type during the matching
    #
    # @return [Array<Hash<Refined, String>>]
    #
    def errors
      @context[:errors]
    end

    # @private
    private def inspect
      "#<sum #{self.class.name} is #{self.class.sum_of.to_a.join(' or ')}"\
      " (value=#{@value})>"
    end
  end
end
