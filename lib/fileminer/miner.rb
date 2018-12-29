require 'set'
require 'json'


class Dir

  class << self

    # Creates the directory with the path given, including anynecessary but nonexistent parent directories.
    #
    # @param [String] path
    def mkdirs(path)
      parent = File.dirname path
      mkdirs parent unless Dir.exist? parent
      Dir.mkdir path
    end

  end

end


class Miner

  DEFAULTS = {
    registry_path: '/var/lib/fileminer/registry',
    eof_seconds: 86400,
    batch_lines: 50,
  }

  attr_reader :registry_path, :paths, :eof_seconds, :file_list

  # Create a new file miner instance
  #
  # @param [Hash] options
  # @option options [String] :registry_path (/var/lib/fileminer/registry)
  # @option options [Array] :paths
  # @option options [Integer] :eof_seconds (86400)
  # @option options [Integer] :batch_lines (50)
  # @option options [String] :host (Socket.gethostname)
  def initialize(options = {})
    # fix options by DEFAULTS
    DEFAULTS.each { |k, v| options[k] = v unless options.key? k }
    @registry_path = options[:registry_path]
    @paths = options[:paths]
    @eof_seconds = options[:eof_seconds]
    @batch_lines = options[:batch_lines]
    @host = options[:host]
    if @host.nil?
      require 'socket'
      @host = Socket.gethostname
    end
    @file_list = []
    if File.exist? @registry_path
      File.open(@registry_path) { |io| @file_list = JSON.parse(io.read, {symbolize_names: true}) }
    else
      parent_dir = File.dirname @registry_path
      Dir.mkdirs parent_dir unless Dir.exist? parent_dir
    end
  end

  # Save registry
  def save_registry
    File.open(@registry_path, 'w') { |io| io.write @file_list.to_json }
  end

  # Refresh
  def refresh_file_list
    file_paths = Set.new
    @paths.each do |path|
      file_paths.merge Dir[path].select { |path| File.file? path }
    end
    @file_list.each do |record|
      path = record[:path]
      unless record[:eof]
        if file_paths.delete? path
          # check if EOF
          if record[:pos] == File.size(path) && Time.now - File.mtime(path) > @eof_seconds
            record[:eof] = true
          end
        else
          # missing file, set :eof to true
          record[:eof] = true
        end
      end
    end
    file_paths.each do |path|
      record = {path: path, pos: 0, eof: false}
      @file_list << record
    end
    @file_list_refresh_time = Time.now
  end

  # Read lines
  def read_lines(record)
    file_path = record[:path]
    File.open file_path do |io|
      lines = []
      io.pos = record[:pos]
      while lines.size < @batch_lines
        line = {host: @host, path: file_path, pos: io.pos}
        begin
          data = io.readline
          break if data.nil?
          if data[-1] != "\n"
            io.pos = line[:pos]
            break
          end
        rescue EOFError
          break
        end
        line[:end] = io.pos
        line[:data] = data
        lines << line
      end
      lines
    end
  end

end
