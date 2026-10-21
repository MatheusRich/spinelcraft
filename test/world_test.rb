require_relative "test_helper"

class WorldTest < Minitest::Test
  # The terrain tables are read by position, so each must have one entry
  # for each biome or tree kind.
  def test_each_terrain_table_has_one_entry_for_each_biome_or_tree_kind
    [Biome::GROUND, Biome::TREES, Biome::TREE, Biome::BIRCHES, Biome::LARGE_OAKS, Biome::PINES,
     Biome::GRASS, Biome::FLOWERS, Biome::GRASS_COLOR, Biome::FOLIAGE_COLOR].each do |table|
      assert_equal Biome::ALL.size, table.size
    end
    assert_equal Biome::TREE_KINDS.size, Trees::TRUNK.size
    assert_equal Biome::TREE_KINDS.size, Trees::WOOD.size
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
    ORES.each do |ore|
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
    assert_in_delta 4.5 * World::VEIN_9, total.(Block::SPINEL_ORE), 1e-9
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
    assert_operator World.mc_ore(Block::SPINEL_ORE, 31), :>, 0.0
    assert_equal 0.0, World.mc_ore(Block::SPINEL_ORE, 32)
    assert_operator World.mc_ore(Block::SPINEL_ORE, -64), :>, 0.0
    assert_equal 0.0, World.mc_ore(Block::SPINEL_ORE, -65)
  end

  # A layer holds the veins that start at it, times their blocks. In a
  # triangle from y low to high, the peak layer gets 2 / (high - low) of
  # the veins. In an even spread, each layer gets 1 / (high - low + 1).
  # minecraft.wiki/w/Coal_Ore, /w/Iron_Ore, /w/Diamond_Ore and
  # /w/Gold_Ore (which spinel copies) give the veins and the spreads.
  def test_each_layer_of_minecraft_holds_the_veins_that_start_at_it
    coal = World::VEIN_17
    assert_in_delta coal * 20 * 2 / 192, World.mc_ore(Block::COAL_ORE, 96), 1e-9
    assert_in_delta coal * 20 * 2 / 192 * 57 / 96, World.mc_ore(Block::COAL_ORE, 135), 1e-9
    assert_in_delta coal * (20 * 2.0 / 192 * 56 / 96 + 30 / 185.0), World.mc_ore(Block::COAL_ORE, 136), 1e-9
    assert_in_delta coal * 30 / 185, World.mc_ore(Block::COAL_ORE, 193), 1e-9
    iron = World::VEIN_9
    small = World::VEIN_4 * 10 / 137
    assert_in_delta small, World.mc_ore(Block::IRON, -64), 1e-9
    assert_in_delta iron * 10 * 2 / 80 * 2 / 40 + small, World.mc_ore(Block::IRON, -22), 1e-9
    assert_in_delta iron * 10 * 2 / 80 + small, World.mc_ore(Block::IRON, 16), 1e-9
    assert_in_delta iron * 10 * 2 / 80 * 2 / 40 + small, World.mc_ore(Block::IRON, 54), 1e-9
    assert_in_delta iron * 90 * 2 / 304, World.mc_ore(Block::IRON, 232), 1e-9
    veins = 7 * World::VEIN_4 + 4 * World::VEIN_8 + World::VEIN_12 / 9
    medium = 2 * World::VEIN_8 / 61
    assert_in_delta veins * 2 / 160 + medium, World.mc_ore(Block::DIAMOND, -64), 1e-9
    assert_in_delta veins * 2 / 160 * 20 / 80 + medium, World.mc_ore(Block::DIAMOND, -4), 1e-9
    assert_in_delta veins * 2 / 160 * 19 / 80, World.mc_ore(Block::DIAMOND, -3), 1e-9
    spinel = World::VEIN_9 * 4 * 2 / 96
    lower = World::VEIN_9 * 0.5 / 17
    assert_in_delta lower, World.mc_ore(Block::SPINEL_ORE, -64), 1e-9
    assert_in_delta spinel * 16 / 48 + lower, World.mc_ore(Block::SPINEL_ORE, -48), 1e-9
    assert_in_delta spinel * 17 / 48, World.mc_ore(Block::SPINEL_ORE, -47), 1e-9
    assert_in_delta spinel, World.mc_ore(Block::SPINEL_ORE, -16), 1e-9
  end

  ORES = [Block::COAL_ORE, Block::IRON, Block::DIAMOND, Block::SPINEL_ORE].freeze

  # The stone and ore blocks of each layer, and the blocks of each ore by
  # its cell (x >> 2, y >> 1, z >> 2 for coal, x >> 1, y >> 1, z >> 1 for
  # the others), in the 4 x 4 chunks from x = z = 0.
  def self.ore_area
    @ore_area ||= begin
      world = World.new(1337)
      4.times { |cx| 4.times { |cz| world.load_chunk(cx, cz) } }
      stone = Array.new(WY, 0)
      cells = ORES.to_h { |ore| [ore, Hash.new(0)] }
      64.times do |x|
        64.times do |z|
          (1...WY).each do |y|
            b = world.get(x, y, z)
            stone[y] += 1 if b == Block::STONE || cells.key?(b)
            next unless cells.key?(b)
            cell = b == Block::COAL_ORE ? [x >> 2, y >> 1, z >> 2] : [x >> 1, y >> 1, z >> 1]
            cells[b][cell] += 1
          end
        end
      end
      [stone, cells]
    end
  end

  def test_each_ore_fills_its_share_of_the_stone_at_each_layer
    stone, cells = WorldTest.ore_area
    ORES.each do |ore|
      want = (1...WY).sum { |y| stone[y] * World.ore_at(ore, y) / 256 }
      assert_in_delta 1.0, cells[ore].values.sum / want, 0.15, Block::NAMES[ore]
    end
  end

  # Caves and the land surface cut some clumps, so a clump holds a bit
  # less than a vein.
  def test_a_clump_of_ore_fills_its_cell_with_about_the_blocks_of_a_vein
    _, cells = WorldTest.ore_area
    { Block::COAL_ORE => World::VEIN_17, Block::IRON => World::VEIN_9, Block::DIAMOND => World::DIAMOND_VEIN,
      Block::SPINEL_ORE => World::VEIN_9 }.each do |ore, vein|
      mean = cells[ore].values.sum.to_f / cells[ore].size
      assert_in_delta 0.93 * vein, mean, 0.08 * vein, Block::NAMES[ore]
    end
  end

  # Each cell has its own roll. So few pairs of cells at one height both
  # hold coal in one chunk, or both hold iron or diamond side by side.
  def test_each_cell_has_its_own_roll
    _, cells = WorldTest.ore_area
    pairs = ->(keys, &group) { keys.group_by(&group).values.sum { |same| same.size * (same.size - 1) / 2 } }
    coal = cells[Block::COAL_ORE].keys
    assert_operator pairs.(coal) { |x, y, z| [x >> 2, y, z >> 2] }, :<, coal.size / 3
    others = cells[Block::IRON].keys + cells[Block::DIAMOND].keys + cells[Block::SPINEL_ORE].keys
    assert_operator pairs.(others) { |x, y, z| [x >> 1, y, z] }, :<, others.size / 10
    assert_operator pairs.(others) { |x, y, z| [x, y, z >> 1] }, :<, others.size / 10
  end

  # The generator keeps the rolls of the coal cells of the last chunk, so
  # the next chunk must make all of its own.
  def test_a_chunk_has_the_same_blocks_after_another_chunk
    first = World.new(1337)
    first.load_chunk(0, 0)
    second = World.new(1337)
    second.load_chunk(5, 3)
    second.load_chunk(0, 0)
    assert_equal first.chunk_bytes(0, 0), second.chunk_bytes(0, 0)
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

  def test_a_door_fits_on_a_solid_block_with_room_for_its_two_halves
    world = world_with_one_chunk
    world.set(8, SKY_Y - 1, 8, Block::STONE)
    assert world.door_fits?(8, SKY_Y, 8)
    refute world.door_fits?(8, SKY_Y + 1, 8)
    world.set(8, SKY_Y + 1, 8, Block::STONE)
    refute world.door_fits?(8, SKY_Y, 8)
    world.set(8, SKY_Y + 1, 8, Block::AIR)
    world.set(8, SKY_Y + 2, 8, Block::DOOR_BLOCK)
    refute world.door_fits?(8, SKY_Y, 8)
    world.set(4, SKY_Y - 1, 4, Block::DOOR_BLOCK + 4)
    refute world.door_fits?(4, SKY_Y, 4)
  end

  # The upper half takes the place of the blocks that a placed block takes
  # the place of, and not of a flower.
  def test_the_upper_half_of_a_door_takes_the_place_of_water_lava_and_grass
    world = world_with_one_chunk
    world.set(8, SKY_Y - 1, 8, Block::STONE)
    [[Block::WATER, true], [Block::LAVA_FLOW, true], [Block::TALL_GRASS, true], [Block::ROSE, false]].each do |cell, fits|
      world.set(8, SKY_Y + 1, 8, cell)
      assert_equal fits, world.door_fits?(8, SKY_Y, 8), Block::NAMES[cell]
    end
  end

  # The upper half goes with the lower half, so it needs nothing itself.
  def test_the_lower_half_of_a_door_needs_a_solid_block_under_it_and_the_upper_half_needs_nothing
    world = world_with_one_chunk
    [false, true].each do |open|
      lower = Block.door_id(0, false, open)
      refute world.can_hold?(lower, 8, SKY_Y, 8), "open #{open}"
      assert world.can_hold?(Block.door_id(0, true, open), 8, SKY_Y, 8), "open #{open}"
      world.set(8, SKY_Y - 1, 8, Block::STONE)
      assert world.can_hold?(lower, 8, SKY_Y, 8), "open #{open}"
      world.set(8, SKY_Y - 1, 8, Block::AIR)
    end
  end

  def test_each_half_of_a_door_finds_the_other
    world = world_with_one_chunk
    world.set(8, SKY_Y, 8, Block::DOOR_BLOCK)
    world.set(8, SKY_Y + 1, 8, Block::DOOR_BLOCK + 4)
    assert_equal SKY_Y + 1, world.door_partner(8, SKY_Y, 8)
    assert_equal SKY_Y, world.door_partner(8, SKY_Y + 1, 8)
  end

  def test_lava_on_any_side_of_a_cell_is_near
    world = world_with_one_chunk
    refute world.near_lava?(8, SKY_Y, 8)
    [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]].each do |dx, dy, dz|
      world.set(8 + dx, SKY_Y + dy, 8 + dz, Block::LAVA)
      assert world.near_lava?(8, SKY_Y, 8), [dx, dy, dz].inspect
      world.set(8 + dx, SKY_Y + dy, 8 + dz, Block::AIR)
    end
  end

  def test_water_on_a_side_or_above_touches_a_cell_and_water_below_does_not
    world = world_with_one_chunk
    [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, 0, 1], [0, 0, -1]].each do |dx, dy, dz|
      world.set(8 + dx, SKY_Y + dy, 8 + dz, Block::WATER)
      assert world.touches_water?(8, SKY_Y, 8), [dx, dy, dz].inspect
      world.set(8 + dx, SKY_Y + dy, 8 + dz, Block::AIR)
    end
    world.set(8, SKY_Y - 1, 8, Block::WATER)
    refute world.touches_water?(8, SKY_Y, 8)
  end

  def test_dry_land_is_ground_above_the_beach_with_no_leaves_or_water_on_top
    world = world_with_one_chunk
    world.set(8, SEA + 10, 8, Block::STONE)
    assert world.dry_land?(8, 8)
    world.set(8, SEA + 11, 8, Block::OAK_LEAVES)
    refute world.dry_land?(8, 8)
    world.set(8, SEA + 11, 8, Block::WATER)
    refute world.dry_land?(8, 8)
    # The top block must stand at SEA + 2 or higher.
    (SEA + 2...WY).each { |y| world.set(4, y, 4, Block::AIR) }
    world.set(4, SEA + 1, 4, Block::STONE)
    refute world.dry_land?(4, 4)
    world.set(4, SEA + 2, 4, Block::STONE)
    assert world.dry_land?(4, 4)
  end

  def test_a_block_with_no_hold_needs_nothing_around_it
    world = world_with_one_chunk
    assert world.can_hold?(Block::STONE, 8, SKY_Y, 8)
  end

  def test_a_torch_on_the_floor_needs_a_solid_block_under_it
    world = world_with_one_chunk
    refute world.can_hold?(Block::TORCH, 8, SKY_Y, 8)
    world.set(8, SKY_Y - 1, 8, Block::STONE)
    assert world.can_hold?(Block::TORCH, 8, SKY_Y, 8)
    world.set(8, SKY_Y - 1, 8, Block::GLASS)
    assert world.can_hold?(Block::TORCH, 8, SKY_Y, 8)
    world.set(8, SKY_Y - 1, 8, Block::WATER)
    refute world.can_hold?(Block::TORCH, 8, SKY_Y, 8)
  end

  def test_a_sapling_needs_dirt_grass_or_snowy_grass_under_it
    world = world_with_one_chunk
    [[Block::DIRT, true], [Block::GRASS, true], [Block::SNOW_GRASS, true], [Block::STONE, false], [Block::SAND, false],
     [Block::AIR, false]].each do |ground, held|
      world.set(8, SKY_Y - 1, 8, ground)
      assert_equal held, world.can_hold?(Block::OAK_SAPLING, 8, SKY_Y, 8), Block::NAMES[ground]
    end
  end

  def test_dry_grass_needs_soil_or_sand_under_it
    world = world_with_one_chunk
    [[Block::GRASS, true], [Block::SAND, true], [Block::STONE, false]].each do |ground, held|
      world.set(8, SKY_Y - 1, 8, ground)
      assert_equal held, world.can_hold?(Block::DRY_GRASS, 8, SKY_Y, 8), Block::NAMES[ground]
    end
  end

  def test_a_cactus_needs_sand_or_a_cactus_under_it
    world = world_with_one_chunk
    [[Block::SAND, true], [Block::CACTUS, true], [Block::GRASS, false], [Block::AIR, false]].each do |ground, held|
      world.set(8, SKY_Y - 1, 8, ground)
      assert_equal held, world.can_hold?(Block::CACTUS, 8, SKY_Y, 8), Block::NAMES[ground]
    end
  end

  # A torch or a flower holds sand up, as in Minecraft.
  def test_sand_and_gravel_need_a_block_under_them_that_they_do_not_fall_into
    world = world_with_one_chunk
    [Block::SAND, Block::GRAVEL].each do |falling|
      [[Block::STONE, true], [Block::TORCH, true], [Block::ROSE, true], [Block::AIR, false], [Block::WATER, false],
       [Block::FLOW, false], [Block::LAVA, false], [Block::LAVA_FLOW, false], [Block::TALL_GRASS, false],
       [Block::DRY_GRASS, false]].each do |ground, held|
        world.set(8, SKY_Y - 1, 8, ground)
        assert_equal held, world.can_hold?(falling, 8, SKY_Y, 8), "#{Block::NAMES[falling]} on #{Block::NAMES[ground]}"
      end
    end
  end

  # Only the chunk at x = z = 0 to 15 is loaded, so x = -1 is not.
  def test_a_wall_in_a_chunk_that_is_not_loaded_holds_a_wall_torch
    world = world_with_one_chunk
    assert world.can_hold?(Block.facing_id(Block::TORCH, 0), 0, SKY_Y, 8)
    refute world.can_hold?(Block.facing_id(Block::TORCH, 1), 0, SKY_Y, 8)
  end

  def test_a_cactus_needs_no_solid_block_or_lava_beside_it
    world = world_with_one_chunk
    world.set(8, SKY_Y - 1, 8, Block::SAND)
    4.times do |dir|
      side_x = 8 + Block::DIR_DX[dir]
      side_z = 8 + Block::DIR_DZ[dir]
      [[Block::STONE, false], [Block::CACTUS, false], [Block::LAVA, false], [Block::WATER, true], [Block::TORCH, true]].each do |side, held|
        world.set(side_x, SKY_Y, side_z, side)
        assert_equal held, world.can_hold?(Block::CACTUS, 8, SKY_Y, 8), "#{Block::NAMES[side]} on side #{dir}"
      end
      world.set(side_x, SKY_Y, side_z, Block::AIR)
    end
  end

  def test_a_cactus_needs_no_water_or_lava_above_it
    world = world_with_one_chunk
    world.set(8, SKY_Y - 1, 8, Block::SAND)
    [[Block::WATER, false], [Block::FLOW, false], [Block::LAVA, false], [Block::STONE, true]].each do |above, held|
      world.set(8, SKY_Y + 1, 8, above)
      assert_equal held, world.can_hold?(Block::CACTUS, 8, SKY_Y, 8), Block::NAMES[above]
    end
  end

  # A torch or a ladder that faces one way hangs on the block on the
  # other side, and on no other block.
  def test_a_wall_torch_or_a_ladder_needs_the_solid_block_that_it_faces_away_from
    world = world_with_one_chunk
    [Block::TORCH, Block::LADDER].each do |base|
      4.times do |dir|
        hung = Block.facing_id(base, dir)
        wall_x = 8 - Block::DIR_DX[dir]
        wall_z = 8 - Block::DIR_DZ[dir]
        refute world.can_hold?(hung, 8, SKY_Y, 8), "#{Block::NAMES[hung]} #{dir} with no wall"
        world.set(8 + Block::DIR_DX[dir], SKY_Y, 8 + Block::DIR_DZ[dir], Block::STONE)
        world.set(8, SKY_Y - 1, 8, Block::STONE)
        refute world.can_hold?(hung, 8, SKY_Y, 8), "#{Block::NAMES[hung]} #{dir} on the wrong side"
        world.set(wall_x, SKY_Y, wall_z, Block::STONE)
        assert world.can_hold?(hung, 8, SKY_Y, 8), "#{Block::NAMES[hung]} #{dir}"
        world.set(wall_x, SKY_Y, wall_z, Block::AIR)
        world.set(8 + Block::DIR_DX[dir], SKY_Y, 8 + Block::DIR_DZ[dir], Block::AIR)
        world.set(8, SKY_Y - 1, 8, Block::AIR)
      end
    end
  end

  # The spawn search looks for land: a column whose noise surface is more
  # than 4 blocks above the sea.
  def test_land_rises_more_than_four_blocks_above_the_sea
    world = World.new(1337)
    [[SEA + 5, true], [SEA + 4, false], [SEA - 10, false]].each do |surface, land|
      world.define_singleton_method(:surface_height) { |_x, _z| surface }
      assert_equal land, world.land?(3, 4), "surface #{surface}"
    end
  end
end
