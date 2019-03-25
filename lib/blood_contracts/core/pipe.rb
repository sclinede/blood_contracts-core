module BloodContracts
  module Core
    class Pipe < Refined
      class << self
        attr_reader :steps, :names, :finalized

        def new(*args)
          return super(*args) if finalized
          if args.last.is_a?(Hash)
            names = args.pop.delete(:names)
          end
          names ||= []

          raise ArgumentError unless args.all?(Class)
          pipe = Class.new(Pipe) { def inspect; super; end }
          pipe.instance_variable_set(:@steps, args)
          pipe.instance_variable_set(:@names, names)
          pipe.instance_variable_set(:@finalized, true)
          pipe
        end

        def and_then(other_type)
          raise ArgumentError unless Class === other_type
          pipe = Class.new(Pipe) { def inspect; super; end }
          pipe.instance_variable_set(:@steps, args)
          pipe.instance_variable_set(:@names, kwargs[:names].to_a)
          pipe.instance_variable_set(:@finalized, true)
          pipe
        end
        alias :> :and_then
      end

      def match
        super do
          index = 0
          self.class.steps.reduce(value) do |next_value, step|
            unpacked_value = unpack_refined(next_value)
            match = step.match(unpacked_value)

            share_context_with(match) do |context|
              context[:steps][step_name(index)] = unpacked_value
              index += 1
            end

            break match if match.invalid?
            next refine_value(yield(match)) if block_given?
            match
          end
        end
      end

      private

      def step_name(index)
        self.class.names[index] || index
      end

      def steps_with_names
        steps = if self.class.names.empty?
                  self.class.steps.map(&:to_s)
                else
                  self.class.steps.zip(self.class.names).map { |k, n| "#{k}(#{n})" }
                end
      end

      def inspect
        require'pry';binding.pry
        "#<pipe #{self.class.name} = #{steps_with_names.join(' > ')} (value=#{@value})>"
      end
    end
  end
end
