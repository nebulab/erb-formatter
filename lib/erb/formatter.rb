# frozen_string_literal: false

require 'pp'
require 'erb'
require 'yaml'
require 'strscan'
require 'stringio'
require 'securerandom'
require 'erb/formatter/version'

require 'syntax_tree'
require 'syntax_tree/plugin/trailing_comma'

class ERB::Formatter
  module SyntaxTreeCommandPatch
    def format(q)
      q.group do
        q.format(message)
        q.text(" ")
        q.format(arguments) # WAS: q.nest(message.value.length + 1) { q.format(arguments) }
      end
    end
  end

  autoload :IgnoreList, 'erb/formatter/ignore_list'

  class Error < StandardError; end

  SPACES = /\s+/m

  # https://stackoverflow.com/a/317081
  ATTR_NAME = %r{[^\r\n\t\f\v= '"<>]*[^\r\n\t\f\v= '"<>/]} # not ending with a slash
  UNQUOTED_VALUE = %r{[^<>'"\s]+}
  UNQUOTED_ATTR = %r{#{ATTR_NAME}=#{UNQUOTED_VALUE}}
  SINGLE_QUOTE_ATTR = %r{(?:#{ATTR_NAME}='[^']*?')}m
  DOUBLE_QUOTE_ATTR = %r{(?:#{ATTR_NAME}="[^"]*?")}m
  BAD_ATTR = %r{#{ATTR_NAME}=\s+}
  QUOTED_ATTR = Regexp.union(SINGLE_QUOTE_ATTR, DOUBLE_QUOTE_ATTR)
  ATTR = Regexp.union(SINGLE_QUOTE_ATTR, DOUBLE_QUOTE_ATTR, UNQUOTED_ATTR, UNQUOTED_VALUE)
  MULTILINE_ATTR_NAMES = %w[class data-action]

  ERB_TAG = %r{(<%(?:==|=|-|))\s*(.*?)\s*(-?%>)}m
  ERB_PLACEHOLDER = %r{erb[a-z0-9]+tag}

  TAG_NAME = /[a-z0-9_:-]+/
  TAG_NAME_ONLY = /\A#{TAG_NAME}\z/
  HTML_ATTR = %r{\s+#{SINGLE_QUOTE_ATTR}|\s+#{DOUBLE_QUOTE_ATTR}|\s+#{UNQUOTED_ATTR}|\s+#{ATTR_NAME}}m
  HTML_TAG_OPEN = %r{<(#{TAG_NAME})((?:#{HTML_ATTR})*)(\s*?)(/>|>)}m
  HTML_TAG_CLOSE = %r{</\s*(#{TAG_NAME})\s*>}

  SELF_CLOSING_TAG = /\A(area|base|br|col|command|embed|hr|img|input|keygen|link|menuitem|meta|param|source|track|wbr)\z/i

  begin
    require 'prism' # ruby 3.3
    RUBY_OPEN_BLOCK = Prism.method(:parse_failure?)
  rescue LoadError
    require 'ripper'
    RUBY_OPEN_BLOCK = ->(code) do
      # is nil when the parsing is broken, meaning it's an open expression
      Ripper.sexp(code).nil?
    end.freeze
  end

  RUBY_STANDALONE_BLOCK = /\A(yield|next)\b/
  RUBY_CLOSE_BLOCK = /\Aend\z/
  RUBY_REOPEN_BLOCK = /\A(else|elsif\b(.*)|when\b(.*))\z/

  RUBOCOP_STDIN_MARKER = "===================="

  module DebugShovel
    def <<(string)
      puts "ADDING: #{string.inspect} FROM:\n  #{caller(1, 5).join("\n  ")}"
      super
    end
  end

  def self.format(source, filename: nil)
    new(source, filename: filename).html
  end

  def initialize(source, line_width: 80, single_class_per_line: false, filename: nil, css_class_sorter: nil, debug: $DEBUG)
    @original_source = source
    @filename = filename || '(erb)'
    @line_width = line_width
    @source = remove_front_matter source.dup
    @html = +""
    @debug = debug
    @single_class_per_line = single_class_per_line
    @css_class_sorter = css_class_sorter

    html.extend DebugShovel if @debug

    @tag_stack = []
    @pre_pos = 0

    build_uid = -> { ['erb', SecureRandom.uuid, 'tag'].join.delete('-') }

    @pre_placeholders = {}
    @erb_tags = {}

    @source.gsub!(ERB_PLACEHOLDER) { |tag| build_uid[].tap { |uid| pre_placeholders[uid] = tag } }
    @source.gsub!(ERB_TAG) { |tag| build_uid[].tap { |uid| erb_tags[uid] = tag } }

    @erb_tags_regexp = /(#{Regexp.union(erb_tags.keys)})/
    @pre_placeholders_regexp = /(#{Regexp.union(pre_placeholders.keys)})/
    @tags_regexp = Regexp.union(HTML_TAG_CLOSE, HTML_TAG_OPEN)

    format
    freeze
  end

  def remove_front_matter(source)
    return source unless source.start_with?("---\n")

    first_body_line = YAML.parse(source).children.first.end_line + 1
    lines = source.lines

    @front_matter = lines[0...first_body_line].join
    lines[first_body_line..].join
  end

  attr_accessor \
    :source, :html, :tag_stack, :pre_pos, :pre_placeholders, :erb_tags, :erb_tags_regexp,
    :pre_placeholders_regexp, :tags_regexp, :line_width

  alias to_s html

  def format_attributes(tag_name, attrs, tag_closing)
    return "" if attrs.strip.empty?

    plain_attrs = attrs.tr("\n", " ").squeeze(" ").gsub(erb_tags_regexp, erb_tags)
    within_line_width = "<#{tag_name} #{plain_attrs}#{tag_closing}".size <= line_width

    return " #{plain_attrs}" if within_line_width && !@css_class_sorter && !plain_attrs.match?(/ class=/)

    attr_html = ""
    tag_stack_push(['attr='], attrs)

    attrs.scan(ATTR).flatten.each do |attr|
      attr.strip!
      name, value = attr.split('=', 2)

      if value.nil?
        attr_html << indented("#{name}")
        next
      end

      if /\A#{UNQUOTED_VALUE}\z/o.match?(value)
        attr_html << indented("#{name}=\"#{value}\"")
        next
      end

      value_parts = value[1...-1].strip.split(SPACES)
      value_parts.sort_by!(&@css_class_sorter) if name == 'class' && @css_class_sorter

      full_attr = "#{name}=#{value[0]}#{value_parts.join(" ")}#{value[-1]}"
      full_attr = within_line_width ? " #{full_attr}" : indented(full_attr)

      if full_attr.size > line_width && MULTILINE_ATTR_NAMES.include?(name) && attr.match?(QUOTED_ATTR)
        attr_html << indented("#{name}=#{value[0]}")
        tag_stack_push('attr"', value)

        if !@single_class_per_line && name == 'class'
          line = value_parts.shift
          value_parts.each do |value_part|
            if (line.size + value_part.size + 1) <= line_width
              line << " #{value_part}"
            else
              attr_html << indented(line)
              line = value_part
            end
          end
          attr_html << indented(line) if line
        else
          value_parts.each do |value_part|
            attr_html << indented(value_part)
          end
        end

        tag_stack_pop('attr"', value)
        attr_html << (within_line_width ? value[-1] : indented(value[-1]))
      else
        attr_html << full_attr
      end
    end

    tag_stack_pop(['attr='], attrs)
    attr_html << indented("") unless within_line_width
    attr_html
  end

  def tag_stack_push(tag_name, code)
    tag_stack << [tag_name, code]
    p PUSH: tag_stack if @debug
  end

  def tag_stack_pop(tag_name, code)
    if tag_name == tag_stack.last&.first
      tag_stack.pop
      p POP_: tag_stack if @debug
    else
      raise "Unmatched close tag, tried with #{[tag_name, code]}, but #{tag_stack.last} was on the stack"
    end
  end

  def raise(message)
    line = @original_source[0..pre_pos].count("\n")
    location = "#{@filename}:#{line}:in `#{tag_stack.last&.first}'"
    error = RuntimeError.new([
      nil,
      "==> FORMATTED:",
      html,
      "==> STACK:",
      tag_stack.pretty_inspect,
      "==> ERROR: #{message}",
    ].join("\n"))
    error.set_backtrace caller.to_a + [location]
    super error
  end

  def indented(string, strip: true)
    string = string.strip if strip
    indent = "  " * tag_stack.size
    "\n#{indent}#{string}"
  end

  def format_text(text)
    p format_text: text if @debug
    return unless text

    starting_space = text.match?(/\A\s/)

    final_newlines_count = text.match(/(\s*)\z/m).captures.last.count("\n")
    html << "\n" if final_newlines_count > 1

    return if text.match?(/\A\s*\z/m) # empty

    text = text.gsub(SPACES, ' ').strip

    offset = indented("").size
    # Restore full line width if there are less than 40 columns available
    offset = 0 if (line_width - offset) <= 40
    available_width = line_width - offset

    lines = []

    until text.empty?
      if text.size >= available_width
        last_space_index = text[0..available_width].rindex(' ')
        lines << text.slice!(0..last_space_index)
      else
        lines << text.slice!(0..-1)
      end
      offset = 0
    end
    p lines: lines if @debug
    html << lines.shift.strip unless starting_space
    lines.each do |line|
      html << indented(line)
    end
  end

  def format_ruby(code, autoclose: false)
    if autoclose
      code += "\nend" unless RUBY_OPEN_BLOCK["#{code}\nend"]
      code += "\n}" unless RUBY_OPEN_BLOCK["#{code}\n}"]
    end
    p RUBY_IN_: code if @debug

    SyntaxTree::Command.prepend SyntaxTreeCommandPatch

    code = begin
      SyntaxTree.format(code, @line_width)
    rescue SyntaxTree::Parser::ParseError => error
      p RUBY_PARSE_ERROR: error if @debug
      code
    end

    lines = code.strip.lines
    lines = lines[0...-1] if autoclose
    code = lines.map { |l| indented(l.chomp("\n"), strip: false) }.join.strip
    p RUBY_OUT: code if @debug
    code
  end

  def format_erb_tags(string)
    p format_erb_tags: string if @debug
    if %w[style script].include?(tag_stack.last&.first)
      html << string.rstrip
      return
    end

    erb_scanner = StringScanner.new(string.to_s)
    erb_pre_pos = 0
    until erb_scanner.eos?
      if erb_scanner.scan_until(erb_tags_regexp)
        p PRE_MATCH: [erb_pre_pos, '..', erb_scanner.pre_match] if @debug
        erb_pre_match = erb_scanner.pre_match
        erb_pre_match = erb_pre_match[erb_pre_pos..].to_s
        erb_pre_pos = erb_scanner.pos

        erb_code = erb_tags[erb_scanner.captures.first]

        format_text(erb_pre_match)

        erb_open, ruby_code, erb_close = ERB_TAG.match(erb_code).captures
        erb_open << ' ' unless ruby_code.start_with?('#')

        case ruby_code
        when RUBY_STANDALONE_BLOCK
          ruby_code = format_ruby(ruby_code, autoclose: false)
          full_erb_tag = "#{erb_open}#{ruby_code} #{erb_close}"
          html << (erb_pre_match.match?(/\s+\z/) ? indented(full_erb_tag) : full_erb_tag)
        when RUBY_CLOSE_BLOCK
          full_erb_tag = "#{erb_open}#{ruby_code} #{erb_close}"
          tag_stack_pop('%erb%', ruby_code)
          html << (erb_pre_match.match?(/\s+\z/) ? indented(full_erb_tag) : full_erb_tag)
        when RUBY_REOPEN_BLOCK
          full_erb_tag = "#{erb_open}#{ruby_code} #{erb_close}"
          tag_stack_pop('%erb%', ruby_code)
          html << (erb_pre_match.match?(/\s+\z/) ? indented(full_erb_tag) : full_erb_tag)
          tag_stack_push('%erb%', ruby_code)
        when RUBY_OPEN_BLOCK
          full_erb_tag = "#{erb_open}#{ruby_code} #{erb_close}"
          html << (erb_pre_match.match?(/\s+\z/) ? indented(full_erb_tag) : full_erb_tag)
          tag_stack_push('%erb%', ruby_code)
        else
          ruby_code = format_ruby(ruby_code, autoclose: false)
          full_erb_tag = "#{erb_open}#{ruby_code} #{erb_close}"
          html << (erb_pre_match.match?(/\s+\z/) ? indented(full_erb_tag) : full_erb_tag)
        end
      else
        p ERB_REST: erb_scanner.rest if @debug
        rest = erb_scanner.rest.to_s
        format_text(rest)
        erb_scanner.terminate
      end
    end
  end

  def format
    scanner = StringScanner.new(source)

    until scanner.eos?
      if matched = scanner.scan_until(tags_regexp)
        p format_pre_match: [pre_pos, '..', scanner.pre_match[pre_pos..]] if @debug
        pre_match = scanner.pre_match[pre_pos..]
        p POS: pre_pos...scanner.pos, advanced: source[pre_pos...scanner.pos] if @debug
        p MATCHED: matched if @debug
        self.pre_pos = scanner.charpos

        # Don't accept `name= "value"` attributes
        raise "Bad attribute, please fix spaces after the equal sign:\n#{pre_match}" if BAD_ATTR.match? pre_match

        format_erb_tags(pre_match) if pre_match

        if matched.match?(HTML_TAG_CLOSE)
          tag_name = scanner.captures.first

          full_tag = "</#{tag_name}>"
          tag_stack_pop(tag_name, full_tag)
          html << (scanner.pre_match.match?(/\s+\z/) ? indented(full_tag) : full_tag)

        elsif matched.match(HTML_TAG_OPEN)
          _, tag_name, tag_attrs, _, tag_closing = *scanner.captures

          raise "Unknown tag #{tag_name.inspect}" unless tag_name.match?(TAG_NAME_ONLY)

          tag_self_closing = tag_closing == '/>' || SELF_CLOSING_TAG.match?(tag_name)
          tag_attrs.strip!
          formatted_tag_name = format_attributes(tag_name, tag_attrs.strip, tag_closing).gsub(erb_tags_regexp, erb_tags)
          full_tag = "<#{tag_name}#{formatted_tag_name}#{tag_closing}"
          html << (scanner.pre_match.match?(/\s+\z/) ? indented(full_tag) : full_tag)

          tag_stack_push(tag_name, full_tag) unless tag_self_closing
        else
          raise "Unrecognized content: #{matched.inspect}"
        end
      else
        p format_rest: scanner.rest if @debug
        format_erb_tags(scanner.rest.to_s)
        scanner.terminate
      end
    end

    html.gsub!(erb_tags_regexp, erb_tags)
    html.gsub!(pre_placeholders_regexp, pre_placeholders)
    html.strip!
    html.prepend @front_matter + "\n" if @front_matter
    html << "\n"
  end
end
