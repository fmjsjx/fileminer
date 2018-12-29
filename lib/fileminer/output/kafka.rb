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
    # @option options [Symbol] :mode (:sync) :sync or :async
    # @option options [Symbol] :auto_delivery (:disabled) :disabled or :enabled
    # @option options [Hash] :delivery_conf
    def initialize(options)
      brokers = options[:brokers] || ['localhost:9092']
      clinet_id = options[:client_id] || 'fileminer'
      @topic = options[:topic] || 'fileminer'
      @kafka = Kafka.new(brokers, client_id: client_id)
      case @mode = options[:mode]
      when :sync
        @producer = @kafka.producer
      when :async
        case @auto_delivery = options[:auto_delivery]
        when :disabled
          @producer = @kafka.async_producer
        when :enabled
          @producer = @kafka.async_producer options[:delivery_conf]
        else
          raise "invalid value #@auto_delivery of auto_delivery"
        end
      else
        raise "unsupported mode #@mode"
      end
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
      @producer.deliver_messages unless @mode == :async and @auto_delivery == :enabled
      listener.call
    end

    # close the kafka producer
    def close
      @producer.shutdown
      @kafka.close
    end

  end

end