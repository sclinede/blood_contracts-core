module BloodContracts::Core
  # Refinement type which represents data which is always correct
  class Anything < Refined
    # The type which is the result of data matching process
    # (for Anything is always self)
    #
    # @return [BC::Refined]
    #
    def match
      self
    end

    # Checks whether the data matches the expectations or not
    # (for Anything is always true)
    #
    # @return [Boolean]
    #
    def valid?
      true
    end
  end
end
