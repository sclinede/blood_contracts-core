class BloodContracts::Core::ContractFailure < BloodContracts::Core::Refined
  def initialize(value = nil, **)
    super
    @match = self
    return unless @value
    @context[:errors] = (@context[:errors].to_a << @value.to_h)
  end

  def errors
    @context[:errors].to_a
  end

  def messages
    errors.reduce(:merge).values.flatten!
  end

  def errors_h
    errors.reduce(:merge)
  end
  alias to_h errors_h

  def match
    self
  end

  def unpack
    @value
  end
end
