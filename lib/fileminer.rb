require 'set'
require 'json'


class Miner

  # Create a new file miner instance
  #
  # @param [Hash] options
  # @option options [String] :registry_path
  # @option options [Array] :paths
  # @option options [OutputPlugin] :output
  def initialize(options = {})
    @registry_path = options[:registry_path]
    @paths = options[:paths]
    @eof_seconds = options[:eof_seconds]
    @output = options[:output]
    @registry = []
    if File.exist? registry_path
      File.open(registry_path) { |io| @registry = JSON.parse(io.read, {symbolize_names: true}) }
    end
    @files = (@registry.map { |e| [e[:path], e] }).to_h
    refresh_files
    save_registry
  end

  # Save registry file
  def save_registry
    File.open(@registry_path, 'w') { |io| io.write @registry.to_json }
  end

  # refresh files
  def refresh_files
    real_file_paths = Set.new
    @paths.each do |path|
      real_file_paths.merge Dir[path]
    end
    @files.each do |path, record|
      unless record[:eof]
        if real_file_paths.include? path
          # has 
          if Time.now - File::mtime(path) > @eof_seconds
            record[:eof] = true
          end
        else
          # missing file, set :eof to true
          record[:eof] = true
        end
      end
    end
    # TODO
  end

end
