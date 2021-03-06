require 'logger'
require_relative 'fileminer/miner'
require_relative 'fileminer/plugins'
require_relative 'fileminer/tools/hash'

FILEMINER_SETTINGS = 'fileminer.settings'
FILEMINER_INPUTS = 'fileminer.inputs'


class FileMiner

  DEFAULT_SETTINGS = {
    refresh_files_time_trigger: '30s',
    max_time_of_each_mining: '5s',
    max_lines_of_each_mining: -1,
    max_lines_of_each_file: -1,
    sleep_time_when_no_more_data: '5s',
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
    @miner.refresh_files
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
    # default logger to stderr
    # TODO make logger configurable in future
    @logger = Logger.new STDERR
    @logger.level = Logger::WARN
    # mining break trigger
    max_time_of_each_mining = parse_time conf[:max_time_of_each_mining], 'max_time_of_each_mining on fileminer.settings'
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
    # sleep seconds when no more data
    @sleep_seconds_when_no_more_data = parse_time conf[:sleep_time_when_no_more_data], 'sleep_time_when_no_more_data on fileminer.settings'
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
    when conf.key?('output.script')
      script_conf = conf['output.script'].keys_to_sym
      init_output_script script_conf
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

  def init_output_script(script_conf)
    script_path = script_conf[:script]
    plugin_class_name = script_conf[:plugin_class]
    init_options = script_conf[:init_options] || {}
    require script_path
    plugin_class = Object.const_get plugin_class_name
    plugin_class.new init_options.keys_to_sym
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
    full_lines = 0
    miner = @miner
    miner.active_files.all? do |record|
      mining_next = true
      if record[:pos] < File.size(record[:path])
        file_lines = 0
        loop do
          lines = miner.read_lines record
          break if lines.empty?
          send_lines record, lines
          file_lines += lines.size
          full_lines += lines.size
          if mining_break? start_time, full_lines
            mining_next = false
            break
          end
          break if file_break? file_lines
        end
      end
      mining_next
    end
    full_lines
  end

  def start_mining
    unless @running
      @running = true
      sleep_seconds = @sleep_seconds_when_no_more_data
      while @running
        begin
          files_refreshed = check_files
          sent_lines = mine_once
          # sleep 5 seconds if no more data
          # TODO using settings instead in future
          if sent_lines == 0
            @miner.save_work_status if files_refreshed
            sleep sleep_seconds
          end
        rescue => e
          @logger.error e
          # sleep for a little while to wait output recover
          sleep sleep_seconds if @running
        end
      end
      @miner.save_registry
    end
  end

  def check_files
    if @miner.files_need_refresh? @refresh_files_time_trigger
      @miner.refresh_files
    end
  end

  def stop_mining
    @running = false if @running
  end

end
