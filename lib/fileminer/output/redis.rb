require 'redis'
require_relative '../output'


class RedisOutputPlugin < OutputPlugin

  # Create a redis output plugin instance
  #
  # @param [Hash] options
  # @option options [String] :uri  redis URI string
  # TODO
  def initialize(options)
    # TODO
  end

  def send_all(messages)
    # TODO
  end

  def send(message)
    # TODO
  end

end