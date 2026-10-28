require_relative "test_helper"

# BlockSound: a block sounds like its sound class when the player digs,
# breaks, steps on and places it.
class BlockSoundTest < Minitest::Test
  def test_footsteps_follow_the_sound_class
    assert_equal Sfx::STEP_GRASS, BlockSound.footstep(Block::GRASS)
    assert_equal Sfx::STEP_HARD, BlockSound.footstep(Block::STONE)
    assert_equal Sfx::STEP_WOOD, BlockSound.footstep(Block::OAK_PLANKS)
    assert_equal Sfx::STEP_SAND, BlockSound.footstep(Block::SAND)
    assert_equal Sfx::CLOTH, BlockSound.footstep(Block::WOOL)
    assert_equal Sfx::SNOW, BlockSound.footstep(Block::SNOW)
  end

  def test_glass_breaks_with_its_own_sound
    assert_equal Sfx::BREAK_GLASS, BlockSound.broken(Block::GLASS)
  end

  def test_leaves_and_plants_dig_alike
    assert_equal Sfx::DIG_LEAVES, BlockSound.dig(Block::OAK_LEAVES)
    assert_equal Sfx::DIG_LEAVES, BlockSound.dig(Block::ROSE)
    assert_equal Sfx::DIG_LEAVES, BlockSound.dig(Block::PLACED_BIRCH_LEAVES)
    assert_equal Sfx::DIG_LEAVES, BlockSound.dig(Block::PUMPKIN_STEM)
  end

  def test_stone_places_hard_and_dirt_places_soft
    assert_equal Sfx::PLACE_HARD, BlockSound.placed(Block::STONE)
    assert_equal Sfx::PLACE, BlockSound.placed(Block::DIRT)
  end

  def test_pumpkins_sound_like_wood
    wood = BlockSound.dig(Block::OAK_PLANKS)
    assert_equal wood, BlockSound.dig(Block::PUMPKIN)
    assert_equal wood, BlockSound.dig(Block::CARVED_PUMPKIN)
    assert_equal wood, BlockSound.dig(Block.facing_id(Block::JACK_O_LANTERN, 3))
  end

  def test_gravel_and_snowy_grass
    assert_equal Sfx::STEP_GRAVEL, BlockSound.footstep(Block::GRAVEL)
    assert_equal Sfx::STEP_GRASS, BlockSound.footstep(Block::SNOW_GRASS)
  end

  def test_blocks_that_stand_for_stone_step_hard
    [Block::BEDROCK, Block::FURNACE].each do |block|
      assert_equal Sfx::STEP_HARD, BlockSound.footstep(block)
    end
  end

  def test_blocks_that_stand_for_wood_step_wood
    [Block::TORCH, Block::CACTUS, Block::PUMPKIN, Block::OAK_LOG, Block::OAK_PLANKS, Block::CHEST, Block::BED, Block::DOOR,
     Block::CRAFTING_TABLE, Block::LADDER].each do |block|
      assert_equal Sfx::STEP_WOOD, BlockSound.footstep(block)
    end
  end

  def test_a_variant_sounds_like_its_base_block
    assert_equal Sfx::STEP_WOOD, BlockSound.footstep(Block.facing_id(Block::CHEST, 2))
  end

  def test_unlisted_blocks_sound_like_dirt
    assert_equal Sfx::DIG_SOFT, BlockSound.dig(Block::DIRT)
  end
end
