# Output module
module Output
  # abstract class OutputPlugin
  class OutputPlugin

    # If plugin is in batch mode
    def batch?
      true
    end

    def close
      # do nothing default
    end 

  end

end