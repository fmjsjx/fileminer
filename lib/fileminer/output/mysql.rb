require 'mysql2'
require_relative '../output'


module Output

  class MysqlPlugin < OutputPlugin

    DEFAULT_MYSQL = {
      host: 'localhost',
      port: 3306,
      password: '',
      encoding: 'utf8mb4',
      ssl_mode: :disabled
    }

    # Create a mysql output plugin instance
    #
    # @param [Hash] options
    # @option options [String] :host ('localhost')
    # @option options [Integer] :port (3306)
    # @option options [String] :username
    # @option options [String] :password ('')
    # @option options [String] :database
    # @option options [String] :encoding ('utf8mb4')
    # @option options [Symbol] :ssl_mode (:disabled)
    # @option options [String] :table
    def initialize(options)
      raise 'Missing config username on output.mysql' unless options.key? :username
      raise 'Missing config database on output.mysql' unless options.key? :database
      raise 'Missing config table on output.mysql' unless options.key? :table
      conf = DEFAULT_MYSQL.merge options
      @table = conf.delete :table
      conf[:port] = conf[:port].to_i
      conf[:password] = conf[:password].to_s
      @encoding = conf[:encoding]
      conf[:ssl_mode] = :disabled if conf[:ssl_mode] != :enabled
      @mysql = Mysql2::Client.new conf
      create_table_if_not_exists
      @sqls = Hash.new { |hash, key| hash[key] = generate_batch_sql key }
    end

    private
    def create_table_if_not_exists
      rs = @mysql.query 'SHOW TABLES'
      tables = rs.map { |row| row.values[0] }
      unless tables.include? @table
        sql = <<-EOS
          CREATE TABLE `#@table` (
            `id` bigint(20) PRIMARY KEY AUTO_INCREMENT,
            `host` varchar(255) NOT NULL,
            `path` varchar(255) NOT NULL,
            `pos` bigint(20) NOT NULL,
            `end` bigint(20) NOT NULL,
            `data` text NOT NULL,
            UNIQUE KEY `UNIQUE_host_path_pos` (`host`,`path`,`pos`)
          ) ENGINE=InnoDB DEFAULT CHARSET=#@encoding
        EOS
        @mysql.query sql
      end
    end

    def generate_batch_sql(size)
      "INSERT IGNORE INTO `#@table`(`host`,`path`,`pos`,`end`,`data`) VALUES " << (['(?,?,?,?,?)'] * size).join(',')
    end

    def get_batch_sql(size)
      if @sqls.key? size
        @sqls[size]
      else
        @sqls[size] = generate_batch_sql size
      end
    end

    # Send all lines to mysql
    #
    # @param [Array] lines
    # @yield a listener to be called after all lines just be sent
    public
    def send_all(lines, &listener)
      values = lines.flat_map { |line| [line[:host], line[:path], line[:pos], line[:end], line[:data]] }
      sql = get_batch_sql lines.size
      @mysql.query 'BEGIN'
      begin
        stat = @mysql.prepare sql
        stat.execute *values
        @mysql.query 'COMMIT'
        listener.call
      rescue => err
        @mysql.query 'ROLLBACK'
        raise err
      end
    end

  end

end