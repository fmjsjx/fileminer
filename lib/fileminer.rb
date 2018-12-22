require 'json'


class Miner

  def initialize registry_path, paths, output
    @registry_path = registry_path
    @paths = paths
    @output = output
    @registry = []
    if File.exist? registry_path
      File.open(registry_path) { |io| @registry = JSON.parse(io.read, {symbolize_names: true}) }
    end
    @files = @registry.map { |e| [e['path'], e] }
    # TODO
  end

  def save_registry
    File.open(@registry_path, 'w') { |io| io.write @registry.to_json }
  end

end
