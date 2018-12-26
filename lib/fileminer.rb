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
    @output = options[:output]
    @registry = []
    if File.exist? registry_path
      File.open(registry_path) { |io| @registry = JSON.parse(io.read, {symbolize_names: true}) }
    end
    @files = (@registry.map { |e| [e['path'], e] }).to_h
    refresh_files
    save_registry
  end

  # Save registry file
  def save_registry
    File.open(@registry_path, 'w') { |io| io.write @registry.to_json }
  end

  def refresh_files
    real_files = []
    @paths.each do |path|
      real_files += Dir[path]
    end
    # TODO
  end

end
