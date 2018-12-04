require 'json'


def json_parse text
  JSON.parse text, {symbolize_names: true}
end


class Miner

  def initialize registry_path, paths, output
    @registry_path = registry_path
    @paths = paths
    @output = output
    @registry = []
    if File.exist? registry_path
      File.open(registry_path) { |io| @registry = json_parse io.read }
    end
    @files = @registry.map { |e| [e['path'], e] }
    # TODO
  end

end
