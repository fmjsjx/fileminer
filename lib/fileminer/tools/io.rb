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