class BloodContracts::Core::Anything < BloodContracts::Core::Refined
  def match
    self
  end

  def valid?
    true
  end

  def unpack
    @value
  end
end
