class ERB::Formatter::IgnoreList
  def initialize(contents: nil, base_dir: Dir.pwd)
    ignore_list_path = "#{base_dir}/.format-erb-ignore"
    @contents = contents || (File.exists?(ignore_list_path) ? File.read(ignore_list_path) : '')
    @ignore_list = @contents.lines
  end

  def should_ignore_file?(path)
    path = File.expand_path(path, @base_dir)
    @ignore_list.any? do
      File.fnmatch? File.expand_path(_1.chomp, @base_dir), path
    end
  end
end

