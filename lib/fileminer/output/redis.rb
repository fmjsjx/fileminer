require 'redis'
require 'json'
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

  def send_all(lines, &listener)
    # TODO
    messages = lines.map { |line| line.to_json }
    puts "send messages #{messages}"
    listener.call
  end

end