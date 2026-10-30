require_relative "test_helper"

class LineLimitTest < Minitest::Test
  def test_lines_are_taken_up_to_the_maximum_and_the_others_are_counted
    limit = LineLimit.new(2)
    allowed = (1..4).map { limit.take }
    assert_equal [true, true, false, false], allowed
    assert_equal 2, limit.dropped
  end

  def test_a_reset_takes_lines_again_and_clears_the_count
    limit = LineLimit.new(1)
    2.times { limit.take }
    limit.reset
    assert_equal 0, limit.dropped
    assert limit.take
  end
end
