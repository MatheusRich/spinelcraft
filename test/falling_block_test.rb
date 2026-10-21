require_relative "test_helper"

class FallingBlockTest < Minitest::Test
  # In Minecraft, sand falls 7.4 blocks in 1 second and 25.7 blocks in 2
  # seconds. minecraft.wiki/w/Falling_Block
  def test_sand_falls_as_far_as_in_minecraft
    sand = FallingBlock.new(Block::SAND, 0, 100.0, 0)
    fall(sand, 1.0)
    assert_in_delta 92.6, sand.y, 0.3
    fall(sand, 1.0)
    assert_in_delta 74.3, sand.y, 0.5
  end

  def test_sand_falls_40_blocks_a_second_at_most
    sand = FallingBlock.new(Block::SAND, 0, 1000.0, 0)
    fall(sand, 20.0)
    top = sand.y
    fall(sand, 1.0)
    assert_in_delta 40.0, top - sand.y, 0.1
  end

  def test_a_falling_block_keeps_its_kind_and_column
    gravel = FallingBlock.new(Block::GRAVEL, 3, 100.0, -7)
    fall(gravel, 1.0)
    assert_equal [Block::GRAVEL, 3, -7], [gravel.block, gravel.x, gravel.z]
  end

  private

  # Runs the fall in steps of 0.02 seconds, as the game does.
  def fall(block, seconds)
    (seconds / 0.02).round.times { block.fall(0.02) }
  end
end
