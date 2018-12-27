#!/usr/bin/env ruby


require 'yaml'

require_relative 'fileminer/miner'
require_relative 'fileminer/plugins'


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


if __FILE__ == $0
  # Usage:
  #     ruby fileminer.rb /etc/fileminer/fileminer.yml
  yml = File.open(ARGV[0]) { |io| io.read }
  conf = YAML.load yml
  miner_options = {}
  # TODO
end