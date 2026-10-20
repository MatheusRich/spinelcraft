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

  def test_each_half_of_a_large_chest_is_a_chest_that_faces_its_own_way
    4.times do |d|
      [Block::CHEST_LEFT + d, Block::CHEST_RIGHT + d].each do |b|
        assert_equal Block::CHEST, Block::BASE[b]
        assert_equal Block::CHEST, Block::DROPS[b]
        assert_equal d, Block::FACING[b]
      end
      assert Block.chest_left?(Block::CHEST_LEFT + d)
      refute Block.chest_right?(Block::CHEST_LEFT + d)
      assert Block.chest_right?(Block::CHEST_RIGHT + d)
      refute Block.chest_left?(Block::CHEST_RIGHT + d)
    end
    [Block::CHEST, Block.facing_id(Block::CHEST, 3), Block::CHEST_LEFT - 1, Block::CHEST_RIGHT + 4].each do |b|
      refute Block.chest_left?(b)
      refute Block.chest_right?(b)
    end
  end

  # A player who looks at the front of a chest that faces d looks along
  # -d, so the left of the player is (-dz, dx).
  def test_the_left_half_of_a_large_chest_is_on_the_left_of_a_player_at_its_front
    4.times do |d|
      to_left = Block.chest_partner_dir(Block::CHEST_RIGHT + d)
      assert_equal [-Block::DIR_DZ[d], Block::DIR_DX[d]], [Block::DIR_DX[to_left], Block::DIR_DZ[to_left]]
      assert_equal to_left ^ 1, Block.chest_partner_dir(Block::CHEST_LEFT + d)
    end
  end

  def test_the_halves_of_a_large_chest_reach_the_edge_between_them
    4.times do |d|
      left = Block::CHEST_LEFT + d
      right = Block::CHEST_RIGHT + d
      assert_in_delta 0.5, box_reach(left, Block.chest_partner_dir(left)), 1e-9
      assert_in_delta 0.5, box_reach(right, Block.chest_partner_dir(right)), 1e-9
      # The other side keeps the gap of a chest of one block.
      assert_in_delta 7.0 / 16.0, box_reach(left, Block.chest_partner_dir(left) ^ 1), 1e-9
    end
  end

  # How far the box of b reaches from the middle of its cell in direction d.
  def box_reach(b, d)
    dx = Block::DIR_DX[d]
    dz = Block::DIR_DZ[d]
    dx * Block.box_dx(b) + dz * Block.box_dz(b) + dx.abs * Block.box_hx(b) + dz.abs * Block.box_hz(b)
  end
end
