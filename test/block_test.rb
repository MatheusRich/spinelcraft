require_relative "test_helper"

class BlockTest < Minitest::Test
  def test_raw_chicken_gives_the_hunger_effect_3_times_in_10_and_cooked_chicken_never
    assert_equal 0.3, Block.hunger_chance(Block::RAW_CHICKEN)
    assert_equal 0.0, Block.hunger_chance(Block::COOKED_CHICKEN)
    assert_equal 0.8, Block.hunger_chance(Block::ROTTEN_FLESH)
  end

  def test_a_tool_digs_the_blocks_of_its_kind_at_the_speed_of_its_tier
    assert_equal 4.0, Block.dig_speed(Block::STONE_PICK, Block::STONE)
    assert_equal 8.0, Block.dig_speed(Block::DIAMOND_AXE, Block::OAK_LOG)
    assert_equal 2.0, Block.dig_speed(Block::WOOD_SHOVEL, Block::DIRT)
    assert_equal 2.0, Block.dig_speed(Block::WOOD_PICK, Block::STONE)
    assert_equal 2.0, Block.dig_speed(Block::WOOD_AXE, Block::OAK_LOG)
    assert_equal 8.0, Block.dig_speed(Block::DIAMOND_SHOVEL, Block::DIRT)
  end

  def test_a_tool_digs_other_blocks_at_the_speed_of_a_hand
    assert_equal 1.0, Block.dig_speed(Block::DIAMOND_PICK, Block::OAK_LOG)
    assert_equal 1.0, Block.dig_speed(Block::DIAMOND_AXE, Block::GLASS)
    assert_equal 1.0, Block.dig_speed(Block::AIR, Block::STONE)
  end

  def test_shears_cut_leaves_and_wool_fast
    assert_equal 15.0, Block.dig_speed(Block::SHEARS, Block::OAK_LEAVES)
    assert_equal 5.0, Block.dig_speed(Block::SHEARS, Block::WOOL)
    assert_equal 1.0, Block.dig_speed(Block::SHEARS, Block::STONE)
  end

  def test_only_a_tool_of_the_right_kind_has_a_dig_tier
    assert_equal 3, Block.dig_tier(Block::IRON_PICK, Block::STONE)
    assert_equal 0, Block.dig_tier(Block::IRON_AXE, Block::STONE)
    assert_equal 0, Block.dig_tier(Block::IRON_PICK, Block::GLASS)
    assert_equal 0, Block.dig_tier(Block::AIR, Block::STONE)
  end

  # A hand hits for 1, 4 times a second. minecraft.wiki/w/Melee_attack
  def test_a_block_or_an_item_in_the_hand_hits_as_a_bare_hand
    [Block::STONE, Block::BREAD].each do |b|
      assert_equal 1.0, Block.damage(b)
      assert_equal 4.0, Block.attack_speed(b)
      assert_equal 0, Block.wear(b, true)
    end
  end

  def test_a_spinel_mattock_digs_each_kind_of_block_fast_at_the_iron_tier
    [Block::STONE, Block::OAK_LOG, Block::DIRT].each do |b|
      assert_equal 12.0, Block.dig_speed(Block::SPINEL_MATTOCK, b)
      assert_equal Block.dig_tier(Block::IRON_PICK, Block::STONE), Block.dig_tier(Block::SPINEL_MATTOCK, b)
    end
    assert_equal 1.0, Block.dig_speed(Block::SPINEL_MATTOCK, Block::GLASS)
    assert_equal 0, Block.dig_tier(Block::SPINEL_MATTOCK, Block::GLASS)
  end

  def test_a_spinel_mattock_hits_and_wears_as_an_iron_axe
    assert_equal Block.damage(Block::IRON_AXE), Block.damage(Block::SPINEL_MATTOCK)
    assert_equal Block.attack_speed(Block::IRON_AXE), Block.attack_speed(Block::SPINEL_MATTOCK)
    assert_equal Block.uses(Block::IRON_AXE), Block.uses(Block::SPINEL_MATTOCK)
    assert_equal Block.wear(Block::IRON_AXE, true), Block.wear(Block::SPINEL_MATTOCK, true)
  end
end
