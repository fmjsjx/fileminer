require 'set'
require 'json'
require_relative 'tools/io'


class Miner

  DEFAULTS = {
    work_dir: '/var/lib/fileminer',
    max_eof_files: 20,
    eof_seconds: 86400,
    batch_lines: 200,
  }

  attr_reader :registry_path, :paths, :eof_seconds, :batch_lines, :files, :active_files

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
    if @registry_path.nil?
      @registry_path = "#{options[:work_dir]}/registry"
    end
    @history_path = options[:history_path]
    if @history_path.nil?
      @history_path = "#{options[:work_dir]}/history"
    end
    @max_eof_files = options[:max_eof_files]
    @paths = options[:paths]
    @eof_seconds = options[:eof_seconds]
    @batch_lines = options[:batch_lines]
    @host = options[:host]
    if @host.nil?
      require 'socket'
      @host = Socket.gethostname
    end
    @files = []
    @active_files = []
    @history = []
    if File.exist? @history_path
      @history = File.open(@history_path) { |io| JSON.parse(io.read) }
    else
      parent_dir = File.dirname @history_path
      Dir.mkdirs parent_dir unless Dir.exist? parent_dir
    end
    if File.exist? @registry_path
      @files = File.open(@registry_path) { |io| JSON.parse(io.read, {symbolize_names: true}) }
      @active_files = @files.select { |record| !record[:eof] }
    else
      parent_dir = File.dirname @registry_path
      Dir.mkdirs parent_dir unless Dir.exist? parent_dir
    end
  end

  # Save work status
  def save_work_status
    save_history
    save_registry
  end

  # Save registry
  def save_registry
    File.open(@registry_path, 'w') { |io| io.write @files.to_json }
  end

  # Save history
  def save_history
    File.open(@history_path, 'w') { |io| io.write @history.to_json }
  end

  # Refresh
  def refresh_files
    now = Time.now
    file_paths = Set.new
    file_paths.merge Dir[*@paths].select { |path| File.file? path }
    active_files, eof_size = select_active_files file_paths
    if eof_size > @max_eof_files
      move_eof_to_history
    end
    history_files = Set.new @history
    file_paths.select do |path|
      ! history_files.member? path
    end.each do |path|
      record = {path: path, pos: 0, eof: false}
      @files << record
      active_files << record
    end
    @active_files = active_files
    @files_refresh_time = now
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

  def files_need_refresh?(refresh_files_time_trigger)
    Time.now - @files_refresh_time >= refresh_files_time_trigger
  end

  private
  def select_active_files(file_paths)
    eof_seconds = @eof_seconds
    eof_size = 0
    active_files = @files.select do |record|
      path = record[:path]
      file_exists = file_paths.delete? path
      if record[:eof]
        eof_size += 1
      else
        if file_exists
          # check if EOF
          if record[:pos] == File.size(path) && now - File.mtime(path) > eof_seconds
            record[:eof] = true
            eof_size += 1
          end
        else
          # missing file, set :eof to true
          record[:eof] = true
          eof_size += 1
        end
      end
      !record[:eof]
    end
    [active_files, eof_size]
  end

  private
  def move_eof_to_history
    to_removed_paths = @files.select do |record|
      record[:eof]
    end.map do |record|
      record[:path]
    end
    path_set = Set.new to_removed_paths
    @files.delete_if { |record| path_set.member? record[:path] }
    @history.concat to_removed_paths
  end

end
