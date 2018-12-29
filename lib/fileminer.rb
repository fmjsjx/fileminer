#!/usr/bin/env ruby


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


def init_output(conf)
  case
  when conf.key?('output.redis')
    require_relative 'fileminer/output/redis'
    redis_conf = conf['output.redis'].keys_to_sym
    Output::RedisPlugin.new redis_conf
  when conf.key?('output.kafka')
    require_relative 'fileminer/output/kafka'
    kafka_conf = conf['output.kafka'].keys_to_sym
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
  when conf.key?('output.mysql')
    require_relative 'fileminer/output/mysql'
    mysql_conf = conf['output.mysql'].keys_to_sym
    mysql_conf[:ssl_mode] = mysql_conf[:ssl_mode] == 'enabled' ? :enabled : :disabled
    Output::MysqlPlugin.new mysql_conf
  else
    raise 'Missing config for output'
  end
end


if __FILE__ == $0
  # Usage:
  #     ruby fileminer.rb /etc/fileminer/fileminer.yml
  yml = File.open(ARGV[0]) { |io| io.read }
  conf = YAML.load yml
  # TODO initialize general settings
  # initialize OutputPlugin
  output = init_output conf
  # initialize Miner
  raise "Missing config #{FILEMINER_INPUTS}" unless conf.key? FILEMINER_INPUTS
  miner_options = conf[FILEMINER_INPUTS].keys_to_sym
  miner = Miner.new miner_options
  miner.refresh_file_list
  miner.save_registry
  # TODO development test
  any_read = false
  miner.file_list.select do |record|
    !record[:eof] && record[:pos] < File.size(record[:path])
  end.each do |record|
    lines = miner.read_lines record
    return if lines.empty?
    any_read |= true
    if output.batch?
      output.send_all lines do
        record[:pos] = lines[-1][:end]
        miner.save_registry
      end
    else
      lines.each do |line|
        output.send line do
          record[:pos] = line[:end]
          miner.save_registry
        end
      end
    end
  end
  puts any_read
  # exit here for test
  exit
  # start loop
  running = true
  trap(:INT) { running = false }
  while running 
    # TODO
  end
end
