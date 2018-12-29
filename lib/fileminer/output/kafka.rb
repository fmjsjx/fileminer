require 'kafka'
require 'json'
require_relative '../output'


module Output

  class KafkaPlugin < OutputPlugin

    # Create a kafka output plugin instance
    #
    # @param [Hash] options
    # @option options [Array] :brokers (['localhost:9092'])
    # @option options [String] :client_id ('fileminer')
    # @option options [String] :topic ('fileminer')
    def initialize(options)
      brokers = options[:brokers] || ['localhost:9092']
      clinet_id = options[:client_id] || 'fileminer'
      @topic = options[:topic] || 'fileminer'
      @kafka = Kafka.new(brokers, client_id: client_id)
      @producer = @kafka.producer
    end

    # Send all lines to kafka using producer API
    #
    # @param [Array] lines
    # @yield a listener to be called after all lines just be delivered
    def send_all(lines, &listener)
      lines.each do |line|
        message = line.to_json
        @producer.produce(message, topic: @topic)
      end
      @producer.deliver_messages
      listener.call
    end

    # close the kafka producer
    def close
      @producer.shutdown
      @kafka.close
    end

  end

end