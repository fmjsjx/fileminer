#!/usr/bin/env ruby


require 'yaml'
require 'socket'
require_relative 'fileminer/miner'
require_relative 'fileminer/plugins'


FILEMINER_INPUTS = 'fileminer.inputs'


class Hash

  def keys_to_sym
    map do |k, v|
      [k.to_sym, v]
    end.to_h
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
    return RedisOutputPlugin.new conf['output.redis'].keys_to_sym
  end
end


if __FILE__ == $0
  # Usage:
  #     ruby fileminer.rb /etc/fileminer/fileminer.yml
  yml = File.open(ARGV[0]) { |io| io.read }
  conf = YAML.load yml
  # initialize Output
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
