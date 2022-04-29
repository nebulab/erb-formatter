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
    Dir["#{__dir__}/../fixtures/*.html.erb"].each do |erb_path|
      expected_path = erb_path.chomp('.erb') + '.expected.erb'

      # File.write expected_path, ERB::Formatter.format(File.read(erb_path))
      assert_equal(File.read(expected_path), ERB::Formatter.format(File.read(erb_path)), "Formatting of #{erb_path} failed")
    end
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

    indent = "  " * 40
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
      "    bar: bazbazbazbazbazbazbazbaz\n" \
      "  ) %>\n" \
      "</div>\n",
      ERB::Formatter.format("<div> <%=render MyComponent.new(foo:barbarbarbarbarbarbarbar,bar:bazbazbazbazbazbazbazbaz)%> </div>"),
    )
  end
end
