class BloodContracts::Core::Pipe < BloodContracts::Core::Refined
  class << self
    attr_reader :steps, :names, :finalized

    # rubocop:disable Style/SingleLineMethods
    def new(*args, **kwargs)
      return super(*args, **kwargs) if finalized
      names = kwargs.delete(:names) unless kwargs.empty?
      names ||= []

      raise ArgumentError unless args.all?(Class)
      pipe = Class.new(Pipe) { def inspect; super; end }
      finalize!(pipe, args, names)
      pipe
    end

    # rubocop:disable Style/CaseEquality
    def and_then(other_type, **kwargs)
      raise ArgumentError unless Class === other_type
      pipe = Class.new(Pipe) { def inspect; super; end }
      finalize!(pipe, [self, other_type], kwargs[:names].to_a)
      pipe
    end
    # rubocop:enable Style/CaseEquality Style/SingleLineMethods
    alias > and_then

    def inspect
      return super if name
      "Pipe(#{steps.to_a.join(',')})"
    end

    private def finalize!(new_class, steps, names)
      new_class.instance_variable_set(:@steps, steps)
      new_class.instance_variable_set(:@names, names)
      new_class.instance_variable_set(:@finalized, true)
    end

    private

    attr_writer :names
  end

  def initialize(*)
    super
    @context[:types] = @context[:types].to_a
  end

  def match
    super do
      index = 0
      self.class.steps.reduce(value) do |next_value, step|
        unpacked_value = unpack_refined(next_value)
        match = step.match(unpacked_value, context: @context)

        track_steps!(index, unpacked_value, match.class.name)
        index += 1

        break match if match.invalid?
        if block_given? && index < self.class.steps.size
          next refine_value(yield(match))
        end
        match
      end
    end
  end

  def errors
    match.errors
  end

  private def track_steps!(index, unpacked_value, match_class_name)
    @context[:steps][step_name(index)] = unpacked_value
    types << match_class_name unless current_type.eql?(match_class_name)
  end

  private def types
    context[:types]
  end

  private def current_type
    context[:types].last
  end

  private def step_name(index)
    self.class.names[index] || index
  end

  private def steps_with_names
    if self.class.names.empty?
      self.class.steps.map(&:inspect)
    else
      self.class.steps.zip(self.class.names).map { |k, n| "#{k.inspect}(#{n})" }
    end
  end

  private def inspect
    "#<pipe #{self.class.name} = #{steps_with_names.join(' > ')}"\
    " (value=#{@value})>"
  end
end
