#!/usr/bin/env ruby


require 'logger'
require 'yaml'
require 'socket'
require_relative 'fileminer/miner'
require_relative 'fileminer/plugins'

FILEMINER_SETTINGS = 'fileminer.settings'
FILEMINER_INPUTS = 'fileminer.inputs'


class Hash

  def keys_to_sym
    map { |k, v| [k.to_sym, v] }.to_h
  end

  def keys_to_sym!
    new_hash = keys_to_sym
    clear
    merge! new_hash
  end

end


class FileMiner

  attr_reader :miner, :output, :running

  # Create a new FileMiner instance
  #
  # @param [Hash] conf
  def initialize(conf)
    init_settings conf['fileminer.settings'] if conf.key? 'fileminer.settings'
    @output = init_output conf
    raise 'Missing config fileminer.inputs' unless conf.key? 'fileminer.inputs'
    @miner = Miner.new conf['fileminer.inputs'].keys_to_sym
    @miner.refresh_file_list
    @miner.save_registry
    @running = false
  end

  private
  def init_settings(conf)
    # default logger to stdout
    @logger = Logger.new STDOUT
    @logger.level = Logger::WARN
    # refresh_files_time_trigger
    @refresh_files_time_trigger = parse_time conf['refresh_files_time_trigger'], 'refresh_files_time_trigger on fileminer.settings'
  end

  def parse_time(value, conf_name)
    raise "Missing config #{conf_name}" if value.nil?
    if /^(\d+)(\w+)$/ =~ value
      num = $1.to_i
      unit = $2
      case unit
      when 'd'
        num * 86400
      when 'h'
        num * 3600
      when 'min'
        num * 60
      when 's'
        num
      when 'ms'
        num.to_f / 1000
      else
        raise "Unsupported time unit '#{unit}' of #{conf_name}"
      end
    else
      raise "Error format '#{value}' of #{conf_name}"
    end
  end

  def init_output(conf)
    case
    when conf.key?('output.redis')
      redis_conf = conf['output.redis'].keys_to_sym
      init_output_redis redis_conf
    when conf.key?('output.kafka')
      kafka_conf = conf['output.kafka'].keys_to_sym
      init_output_kafka kafka_conf
    when conf.key?('output.mysql')
      mysql_conf = conf['output.mysql'].keys_to_sym
      init_output_mysql mysql_conf
    else
      raise 'Missing config for output'
    end
  end

  def init_output_redis(redis_conf)
    require_relative 'fileminer/output/redis'
    Output::RedisPlugin.new redis_conf
  end

  def init_output_kafka(kafka_conf)
    require_relative 'fileminer/output/kafka'
    kafka_conf[:mode] = kafka_conf[:mode] == 'async' ? :async : :sync
    if kafka_conf[:mode] == :async
      kafka_conf[:auto_delivery] = kafka_conf[:auto_delivery] == 'enabled' ? :enabled : :disabled
      if kafka_conf[:auto_delivery] == :enabled
        delivery_threshold = kafka_conf.delete :delivery_threshold
        delivery_interval = kafka_conf.delete :delivery_interval
        raise 'Missing conf delivery_threshold or delivery_interval' if delivery_threshold.nil? && delivery_interval.nil?
        kafka_conf[:delivery_conf] = delivery_conf = Hash.new
        delivery_conf[:delivery_threshold] = delivery_threshold unless delivery_threshold.nil?
        delivery_conf[:delivery_interval] = delivery_interval unless delivery_interval.nil?
      end
    end
    Output::KafkaPlugin.new kafka_conf
  end

  def init_output_mysql(mysql_conf)
    require_relative 'fileminer/output/mysql'
    mysql_conf[:ssl_mode] = mysql_conf[:ssl_mode] == 'enabled' ? :enabled : :disabled
    Output::MysqlPlugin.new mysql_conf
  end

  def send_lines(record, lines)
    if @output.batch?
      @output.send_all lines do
        record[:pos] = lines[-1][:end]
        @miner.save_registry
      end
    else
      lines.each do |line|
        @output.send line do
          record[:pos] = line[:end]
          @miner.save_registry
        end
      end
    end
  end

  public
  def mine_once
    @miner.active_files.select do |record|
      record[:pos] < File.size(record[:path])
    end.sum do |record|
      sent_lines = 0
      loop do
        lines = @miner.read_lines record
        return sent_lines if lines.empty?
        send_lines record, lines
        sent_lines += lines.size
        return sent_lines if lines.size < @miner.batch_lines
      end
    end
  end

  def start_mining
    unless @running
      @running = true
      while @running
        begin
          @miner.refresh_file_list if @miner.files_need_refresh? @refresh_files_time_trigger
          sent_lines = mine_once
          # sleep 5 seconds if no more data
          # TODO using settings instead in future
          sleep 5 if sent_lines == 0
        rescue => e
          @logger.error e
        end
      end
    end
  end

  def stop_mining
    @running = false if @running
  end

end


if __FILE__ == $0
  # Usage:
  #     ruby fileminer.rb /etc/fileminer/fileminer.yml
  yml = File.open(ARGV[0]) { |io| io.read }
  conf = YAML.load yml
  fileminer = FileMiner.new conf
  trap(:INT) { fileminer.stop_mining }
  fileminer.start_mining
end
