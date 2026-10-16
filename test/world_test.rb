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
