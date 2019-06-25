class BloodContracts::Core::ContractFailure < BloodContracts::Core::Refined
  def initialize(value = nil, **)
    super
    return unless @value
    @context[:errors] = (@context[:errors].to_a << @value.to_h)
  end

  def errors
    @context[:errors].to_a
  end

  def errors_h
    errors.reduce(:merge)
  end
  alias to_h errors_h

  def match
    self
  end

  def unpack
    @context
  end
end
