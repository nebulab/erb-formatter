require "erb/formatter"
require "optparse"
require "tailwind_sorter"

class ERB::Formatter::CommandLine
  def self.tailwindcss_class_sorter(css_path)
    ->(class_name) do
      # Create an array of classes to sort with just this single class
      sorted = TailwindSorter.sort([class_name])
      # Return the index (0 since there's only one class)
      # or -1 if the class wasn't recognized/sortable
      sorted.include?(class_name) ? 0 : -1
    end
  end

  attr_reader :write, :filename, :read_stdin

  def initialize(argv, stdin: $stdin)
    @argv = argv.dup
    @stdin = stdin

    @write, @filename, @read_stdin, @code, @single_class_per_line = nil

    OptionParser
      .new do |parser|
        parser.banner = "Usage: #{$0} FILENAME... --write"

        parser.on("-w", "--[no-]write", "Write file") { |value| @write = value }

        parser.on(
          "--stdin-filename FILEPATH",
          "Set the stdin filename (implies --stdin)"
        ) do |value|
          @filename = value
          @read_stdin = true
        end

        parser.on("--[no-]stdin", "Read the file from stdin") do |value|
          if read_stdin == true && value == false
            abort "Can't set stdin filename and not use stdin at the same time"
          end

          @read_stdin = value
          @filename ||= "-"
        end

        parser.on(
          "--print-width WIDTH",
          Integer,
          "Set the formatted output width"
        ) { |value| @width = value }

        parser.on(
          "--single-class-per-line",
          "Print each class on a separate line"
        ) { |value| @single_class_per_line = value }

        parser.on(
          "--tailwind-output-path PATH",
          "Set the path to the tailwind output file"
        ) { |value| @tailwind_output_path = value }

        parser.on("--[no-]debug", "Enable debug mode") do |value|
          $DEBUG = value
        end

        parser.on(
          "--fail-level LEVEL",
          "'check' exits(1) on any formatting changes)"
        ) { |value| @fail_level = value }

        parser.on("-h", "--help", "Prints this help") do
          puts parser
          exit
        end

        parser.on(
          "-v",
          "--version",
          "Show ERB::Formatter version number and quit"
        ) do
          puts "ERB::Formatter #{ERB::Formatter::VERSION}"
          exit
        end
      end
      .parse!(@argv)
  end

  def ignore_list
    @ignore_list ||= ERB::Formatter::IgnoreList.new
  end

  def run
    if read_stdin
      abort "Can't read both stdin and a list of files" unless @argv.empty?
      files = [[@filename, @stdin.read]]
    else
      files = @argv.map { |filename| [filename, File.read(filename)] }
    end

    if @tailwind_output_path
      css_class_sorter =
        self.class.tailwindcss_class_sorter(@tailwind_output_path)
    end

    files_changed = false

    files.each do |(filename, code)|
      if ignore_list.should_ignore_file? filename
        print code unless write
      else
        html =
          ERB::Formatter.new(
            code,
            filename: filename,
            line_width: @width || 80,
            single_class_per_line: @single_class_per_line,
            css_class_sorter: css_class_sorter
          )

        files_changed = true if html.to_s != code

        if write
          File.write(filename, html)
        else
          puts html
        end
      end
    end
    exit(1) if files_changed && @fail_level == "check"
  end
end
