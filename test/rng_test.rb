require_relative "test_helper"

class RngTest < Minitest::Test
  def test_the_same_seed_gives_the_same_numbers
    assert_equal Array.new(5) { Rng.new(7).next_int }, Array.new(5) { Rng.new(7).next_int }
  end

  def test_between_gives_each_integer_from_low_to_high
    rng = Rng.new(3)
    numbers = Array.new(200) { rng.between(-2, 4) }
    assert_equal (-2..4).to_a, numbers.uniq.sort
    assert(numbers.all?(Integer))
  end
end
