require 'redis'
require 'json'
require_relative '../output'


module Output

  class RedisPlugin < OutputPlugin

    # Create a redis output plugin instance
    #
    # @param [Hash] options
    # @option options [String] :uri  redis URI string
    # @option options [String] :host
    # @option options [Integer] :port
    # @option options [Integer] :db
    # @option options [String] :password
    # @option options [String] :key  redis key
    def initialize(options)
      uri = options[:uri]
      if uri.nil?
        uri = parse_uri options
      end
      @key = options[:key]
      raise 'Missing key config on output.redis' if @key.nil?      
      @redis = Redis.new url: uri
    end

    private
    def parse_uri(options)
      host = options[:host] || 'localhost'
      port = options[:port] || 6379
      db = options[:db] || 0
      password = options[:password]
      if password.nil?
        "redis://#{host}:#{port}/#{db}"
      else
        "redis://:#{password}@#{host}:#{port}/#{db}"
      end
    end

    # Send all lines to redis using LPUSH @key
    #
    # @param [Array] lines
    # @yield a listener to be called after all lines just be sent
    public
    def send_all(lines, &listener)
      messages = lines.map { |line| line.to_json }
      @redis.lpush @key, messages
      listener.call
    end

  end

end