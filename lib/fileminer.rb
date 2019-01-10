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

  DEFAULT_SETTINGS = {
    refresh_files_time_trigger: '30s',
    max_time_of_each_mining: '5s',
    max_lines_of_each_mining: -1,
    max_lines_of_each_file: -1, 
  }

  attr_reader :miner, :output, :running

  # Create a new FileMiner instance
  #
  # @param [Hash] conf
  def initialize(conf)
    init_settings conf['fileminer.settings']
    @output = init_output conf
    raise 'Missing config fileminer.inputs' unless conf.key? 'fileminer.inputs'
    @miner = Miner.new conf['fileminer.inputs'].keys_to_sym
    @miner.refresh_file_list
    @miner.save_registry
    @running = false
  end

  private
  def init_settings(conf)
    if conf.nil?
      conf = DEFAULT_SETTINGS.clone
    else
      conf = DEFAULT_SETTINGS.merge conf.keys_to_sym
    end
    # default logger to stdout
    @logger = Logger.new STDOUT
    @logger.level = Logger::WARN
    # mining break trigger
    max_time_of_each_mining = parse_time conf[:max_time_of_each_mining]
    max_lines_of_each_mining = conf[:max_lines_of_each_mining]
    if max_lines_of_each_mining >= 0
      @mining_break_trigger = lambda { |start_time, lines| Time.now - start_time > max_time_of_each_mining || lines >= max_lines_of_each_mining }
    else
      @mining_break_trigger = lambda { |start_time, lines| Time.now - start_time > max_time_of_each_mining }
    end
    # file break trigger
    max_lines_of_each_file = conf[:max_lines_of_each_file]
    if max_lines_of_each_file >= 0
      @file_break_trigger = lambda { |lines| lines < @miner.batch_lines || lines >= max_lines_of_each_file }
    else
      @file_break_trigger = lambda { |lines| lines < @miner.batch_lines }
    end
    # refresh_files_time_trigger
    @refresh_files_time_trigger = parse_time conf[:refresh_files_time_trigger], 'refresh_files_time_trigger on fileminer.settings'
  end

  def parse_time(value, conf_name)
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

  def mining_break?(start_time, lines)
    @mining_break_trigger.call start_time, lines
  end

  def file_break?(lines)
    @file_break_trigger.call lines
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
    start_time = Time.now
    broken = false
    full_lines = 0
    @miner.active_files.select do |record|
      record[:pos] < File.size(record[:path])
    end.all? do |record|
      file_lines = 0
      loop do
        lines = @miner.read_lines record
        return true if lines.empty?
        send_lines record, lines
        file_lines += lines.size
        full_lines += lines.size
        return false if broken = mining_break? start_time, full_lines
        return true if file_break? file_lines
      end
    end
    full_lines
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
          # sleep for a little while to wait output recover
          sleep 5 if @running
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
