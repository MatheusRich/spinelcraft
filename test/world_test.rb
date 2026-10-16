require_relative "test_helper"

class WorldTest < Minitest::Test
  # The terrain tables are read by position, so each must have one entry
  # for each biome or tree kind.
  def test_each_terrain_table_has_one_entry_for_each_biome_or_tree_kind
    [Biome::GROUND, Biome::TREES, Biome::TREE, Biome::BIRCHES, Biome::LARGE_OAKS, Biome::PINES,
     Biome::GRASS, Biome::FLOWERS, Biome::GRASS_COLOR, Biome::FOLIAGE_COLOR].each do |table|
      assert_equal Biome::ALL.size, table.size
    end
    assert_equal Biome::TREE_KINDS.size, World::TRUNK.size
    assert_equal Biome::TREE_KINDS.size, World::WOOD.size
    assert Biome::TREE.all? { |kind| kind < Biome::TREE_KINDS.size }
  end

  def test_the_continent_spline_has_rising_points_and_one_height_for_each
    assert World::CONTINENT.each_cons(2).all? { |a, b| b > a }
    assert_equal World::CONTINENT.size, World::BASE.size
  end

  # A desert well has the blocks of minecraft.wiki/w/Desert_Well/Structure:
  # 89 sandstone and 12 slabs, which are sandstone here, 4 sand and 2
  # suspicious sand, which are sand here, and 5 water.
  def test_a_desert_well_has_the_blocks_of_minecraft
    world = World.new(1337)
    reach = -World::WELL_REACH..World::WELL_REACH
    blocks = (-2..4).flat_map { |dy| reach.flat_map { |dx| reach.map { |dz| world.well_block(dx, dy, dz) } } }
    assert_equal 101, blocks.count(Block::SANDSTONE)
    assert_equal 6, blocks.count(Block::SAND)
    assert_equal 5, blocks.count(Block::WATER)
  end

  def test_the_water_of_a_desert_well_is_a_cross_with_air_above_it
    world = World.new(1337)
    [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dz|
      assert_equal Block::WATER, world.well_block(dx, 0, dz)
      assert_equal Block::AIR, world.well_block(dx, 1, dz)
    end
  end

  def test_the_layers_below_the_sea_each_stand_for_2_layers_of_minecraft
    assert_equal World::MC_BOTTOM, World.mc_y(1)
    assert_equal World::MC_BOTTOM + 2, World.mc_y(2)
    assert_equal World::MC_SEA - 2, World.mc_y(SEA - 1)
    assert_equal World::MC_SEA, World.mc_y(SEA)
    assert_equal World::MC_SEA + 1, World.mc_y(SEA + 1)
  end

  # So the ore of a column is that of a column of Minecraft from its
  # bottom to the y of the top layer here.
  def test_a_column_holds_as_much_of_each_ore_as_in_minecraft
    [Block::COAL_ORE, Block::IRON, Block::DIAMOND].each do |ore|
      here = (1...WY).sum { |y| World.ore_at(ore, y) }
      there = (World::MC_BOTTOM..World.mc_y(WY - 1)).sum { |m| World.mc_ore(ore, m) }
      assert_in_delta there, here, 1e-9
    end
  end

  # minecraft.wiki/w/Ore_(feature) gives the veins of each chunk.
  def test_the_ore_of_a_chunk_is_its_veins_times_their_blocks
    total = ->(ore) { (-200..500).sum { |m| World.mc_ore(ore, m) } }
    assert_in_delta 50 * World::VEIN_17, total.(Block::COAL_ORE), 1e-9
    assert_in_delta 100 * World::VEIN_9 + 10 * World::VEIN_4, total.(Block::IRON), 1e-9
    assert_in_delta 7 * World::VEIN_4 + 6 * World::VEIN_8 + World::VEIN_12 / 9, total.(Block::DIAMOND), 1e-9
  end

  # minecraft.wiki/w/Ore lists the layers with none of each ore.
  def test_each_ore_lies_in_its_layers_of_minecraft
    assert_equal 0.0, World.mc_ore(Block::COAL_ORE, -1)
    assert_operator World.mc_ore(Block::COAL_ORE, 1), :>, 0.0
    assert_equal 0.0, World.mc_ore(Block::COAL_ORE, 321)
    assert_operator World.mc_ore(Block::COAL_ORE, 320), :>, 0.0
    assert_operator World.mc_ore(Block::IRON, 72), :>, 0.0
    assert (73..80).all? { |m| World.mc_ore(Block::IRON, m) == 0.0 }
    assert_operator World.mc_ore(Block::IRON, 81), :>, 0.0
    assert_equal 0.0, World.mc_ore(Block::IRON, -65)
    assert_operator World.mc_ore(Block::DIAMOND, 15), :>, 0.0
    assert_equal 0.0, World.mc_ore(Block::DIAMOND, 16)
  end

  # Below y 136, coal is most common at y 96. Diamond is more common lower
  # down (minecraft.wiki/w/Diamond_Ore).
  def test_coal_peaks_at_y_96_and_diamond_at_the_bottom
    assert_operator World.mc_ore(Block::COAL_ORE, 96), :>, World.mc_ore(Block::COAL_ORE, 95)
    assert_operator World.mc_ore(Block::COAL_ORE, 96), :>, World.mc_ore(Block::COAL_ORE, 97)
    diamond = [-64, -5, -3, 15].map { |m| World.mc_ore(Block::DIAMOND, m) }
    assert_equal diamond.sort.reverse, diamond
  end

  # 1 block of ore in each layer of a chunk takes 1 full cell in 256
  # columns, and twice as many cells when each holds half its blocks.
  def test_the_odds_of_a_clump_give_the_blocks_of_each_layer
    assert_equal 256, World.ore_odds(1.0, 8, 8.0)
    assert_equal 512, World.ore_odds(1.0, 8, 4.0)
    assert_equal 1024, World.ore_odds(2.0, 32, 16.0)
  end

  # A column of 16 cells covers each byte of an Integer twice, also the ids
  # from 128 and the byte that holds the sign bit.
  def test_the_store_keeps_each_block_id_in_its_own_byte
    world = world_with_one_chunk
    ids = [Block::COUNT - 1, Block::STONE, Block::PLACED_SPRUCE_LEAVES, Block::AIR] * 4
    column = (SKY_Y - 16...SKY_Y)
    column.zip(ids) { |y, id| world.set(8, y, 8, id) }
    assert_equal ids, column.map { |y| world.get(8, y, 8) }

    world.set(8, SKY_Y - 9, 8, Block::STONE)
    ids[7] = Block::STONE
    assert_equal ids, column.map { |y| world.get(8, y, 8) }

    column.each { |y| world.set(8, y, 8, Block::AIR) }
    assert_equal [Block::AIR] * 16, column.map { |y| world.get(8, y, 8) }
  end
end
