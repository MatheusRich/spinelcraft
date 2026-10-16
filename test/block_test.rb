require_relative "test_helper"

class BlockTest < Minitest::Test
  def test_raw_chicken_gives_the_hunger_effect_3_times_in_10_and_cooked_chicken_never
    assert_equal 0.3, Block.hunger_chance(Block::RAW_CHICKEN)
    assert_equal 0.0, Block.hunger_chance(Block::COOKED_CHICKEN)
    assert_equal 0.8, Block.hunger_chance(Block::ROTTEN_FLESH)
  end
end
