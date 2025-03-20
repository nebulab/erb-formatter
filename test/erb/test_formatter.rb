# frozen_string_literal: true

require "test_helper"

class ERB::TestFormatter < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ERB::Formatter::VERSION
  end

  def test_simple_tag
    assert_equal("<div>\n  asdf\n</div>\n", ERB::Formatter.format("<div        > asdf    </div>"))
  end

  def test_fixtures
    Dir["#{__dir__}/../fixtures/*.html.erb"].shuffle.each do |erb_path|
      expected_path = erb_path.chomp('.erb') + '.expected.erb'

      # File.write expected_path, ERB::Formatter.format(File.read(erb_path))
      assert_equal(File.read(expected_path), ERB::Formatter.new(File.read(erb_path)).to_s, "Formatting of #{erb_path} failed")
    end
  end

  def test_error_on_unformattable_file
    cli = ERB::Formatter::CommandLine.new(["test/fixtures/unmatched_error.erb"])
    error = assert_raises RuntimeError do |error|
      cli.run
    end
    assert_match(/Unmatched close tag/, error.message)
  end

  def test_fail_level_flag_check_with_changes
    cli = ERB::Formatter::CommandLine.new(["--fail-level", "check", "test/fixtures/attributes.html.erb"])
    error = assert_raises SystemExit do
      assert_output(/src="image.jpg"/) { cli.run }
    end
    assert_equal(1, error.status)
  end

  def test_fail_level_flag_check_without_changes
    cli = ERB::Formatter::CommandLine.new(["--fail-level", "check", "test/fixtures/attributes.html.expected.erb"])
    assert_output(/src="image.jpg"/) { cli.run }
  end

  def test_format_text_with_extra_long_text
    text = <<~HTML * 30
      Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore
      magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
      Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    HTML

    formatter = ERB::Formatter.new ""
    10.times { formatter.tag_stack_push("div", "") }
    formatter.html.replace(+"")
    formatter.format_text(text.dup)

    assert_equal(
      text.tr("\n", " ").squeeze(' ').strip,
      formatter.html.tr("\n", " ").squeeze(' ').strip,
      "Expected to have the same content"
    )
  end

  def test_format_text_with_long_text_and_deep_indentation
    text = <<~HTML
      Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore
      magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
      consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.
      Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    HTML

    formatter = ERB::Formatter.new ""
    40.times { formatter.tag_stack_push("div", "") }
    formatter.html.replace(+"")
    formatter.format_text(text.dup)

    assert_equal(
      text.tr("\n", " ").squeeze(' ').strip,
      formatter.html.tr("\n", " ").squeeze(' ').strip,
      "Expected to have the same content"
    )

    indent = "  " * 40
    assert_equal(
      "Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor" \
      "\n#{indent}incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis" \
      "\n#{indent}nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat." \
      "\n#{indent}Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu" \
      "\n#{indent}fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in" \
      "\n#{indent}culpa qui officia deserunt mollit anim id est laborum.",
      formatter.html,
    )
  end

  def test_format_text_last_line_within_limits_is_not_interrupted
    text = <<~HTML
      In the event we decide to issue a refund, we will reimburse you no later
            than fourteen (14) days from the date on which we make that determination. We
            will use the same means of payment as You used for the Order, and You will not
            incur any fees for such
            reimbursement.
    HTML

    formatter = ERB::Formatter.new ""
    3.times { formatter.tag_stack_push("div", "") }
    formatter.html.replace(+"")
    formatter.format_text(text.dup)

    assert_equal(
      text.tr("\n", " ").squeeze(' ').strip,
      formatter.html.tr("\n", " ").squeeze(' ').strip,
      "Expected to have the same content"
    )

    assert_equal(
      "In the event we decide to issue a refund, we will reimburse you no later" \
      "\n      than fourteen (14) days from the date on which we make that" \
      "\n      determination. We will use the same means of payment as You used for the" \
      "\n      Order, and You will not incur any fees for such reimbursement.",
      formatter.html,
    )
  end

  def test_charpos
    text =
      "<p>Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et
      dolore magna aliqua. 🍰🍰🍰🍰🍰🍰🍰🍰🍰🍰Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi
      ut aliquip ex ea commodo <span>co<strong>nse</strong>quat.</span> Duis aute irure dolor in reprehenderit in
      voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt
      in culpa qui officia deserunt mollit anim id est laborum.</p>"
    formatted = ERB::Formatter.format text

    assert_equal(
      text.tr("\n", " ").squeeze(' ').strip,
      formatted.tr("\n", " ").squeeze(' ').strip,
      "Expected to have the same content"
    )
  end

  def test_tagnames_with_dashes
    assert_equal(
      "<custom-div>\n  asdf\n</custom-div>\n",
      ERB::Formatter.format("<custom-div        > asdf    </custom-div>"),
    )
  end

  def test_format_ruby
    assert_equal(
      "<div>\n" \
      "  <%= render MyComponent.new(\n" \
      "    foo: barbarbarbarbarbarbarbar,\n" \
      "    bar: bazbazbazbazbazbazbazbaz,\n" \
      "  ) %>\n" \
      "</div>\n",
      ERB::Formatter.format("<div> <%=render MyComponent.new(foo:barbarbarbarbarbarbarbar,bar:bazbazbazbazbazbazbazbaz)%> </div>"),
    )
  end

  def test_format_ruby_with_long_lines_and_larger_line_width
    assert_equal(
      %{<%- vite_client_tag %>\n} +
      %{<%= vite_typescript_tag "application", "data-turbo-track": "reload", defer: true %>\n} +
      %{<%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload", defer: true %>\n} +
      %{<%= stylesheet_link_tag "polaris_view_components", "data-turbo-track": "reload", defer: true %>\n} +
      %{<%- hotwire_livereload_tags if Rails.env.development? %>\n},
      ERB::Formatter.new(
        %{<%- vite_client_tag %> <%= vite_typescript_tag "application", "data-turbo-track": "reload", defer: true %>\n} +
        %{<%= stylesheet_link_tag "tailwind",\n} +
        %{"inter-font", \n} +
        %{"data-turbo-track": "reload", \n} +
        %{defer: true %>\n} +
        %{<%= stylesheet_link_tag "polaris_view_components",\n} +
        %{"data-turbo-track": "reload",\n} +
        %{defer: true %>\n} +
        %{<%- hotwire_livereload_tags if Rails.env .development? %>\n},
        line_width: 120,
      ).to_s,
    )
  end

  def test_tailwindcss_class_sorting
    require 'tailwindcss-rails'
    require 'erb/formatter/command_line'

    error_log = "#{__dir__}/../../tmp/tailwindcss.err.log"
    Dir.mkdir(File.dirname(error_log)) unless File.exist?(File.dirname(error_log))

    system(
      Tailwindcss::Commands.executable,
      "--content", "#{__dir__}/../fixtures/tailwindcss/class_sorting.html.erb",
      "--output", "#{__dir__}/../fixtures/tailwindcss/class_sorting.css",
      err: error_log,
    ) || raise("Failed to generate tailwindcss output:\n#{File.read(error_log)}")

    css_class_sorter = ERB::Formatter::CommandLine.tailwindcss_class_sorter("#{__dir__}/../fixtures/tailwindcss/class_sorting.css")

    assert_equal(
      File.read("#{__dir__}/../fixtures/tailwindcss/class_sorting.html.expected.erb"),
      ERB::Formatter.new(
        File.read("#{__dir__}/../fixtures/tailwindcss/class_sorting.html.erb"),
        css_class_sorter: css_class_sorter,
      ).to_s,
    )
  end
end
