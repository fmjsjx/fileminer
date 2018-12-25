# abstract class OutputPlugin
class OutputPlugin

  attr_accessor :batch_size

  # Create a new output plugin instance
  #
  # @param [Hash] options
  # @option options [Integer] :batch_size
  def initialize(options)
    @batch_size = options[:batch_size]
  end

  # If plugin is in batch mode
  def is_batch?
    @batch_size > 1
  end

end