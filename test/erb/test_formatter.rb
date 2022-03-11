# frozen_string_literal: true

require "test_helper"

class ERB::TestFormatter < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::ERB::Formatter::VERSION
  end

  def test_simple_tag
    assert_equal("<div>\n  asdf\n</div>\n", ERB::Formatter.format("<div        > asdf    </div>"))
  end
end
