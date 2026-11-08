require_relative "test_helper"

class WorldTest < Minitest::Test
  def test_each_terrain_table_has_one_entry_for_each_biome_or_tree_kind
    assert_equal Biome::ALL.size, Biome::GROUND.size
    assert_equal Biome::TREE_KINDS.size, Trees::TRUNK.size
    assert_equal Biome::TREE_KINDS.size, Trees::WOOD.size
    assert(Biome::TREE.all? { |kind| kind < Biome::TREE_KINDS.size })
    assert(Biome::PRECIPITATION.all? { |kind| Biome::WEATHER.include?(kind) })
  end

  def test_rain_falls_on_plains_and_no_precipitation_falls_on_a_desert
    world = World.new(1337)
    assert_equal Biome::RAIN, world.precipitation(-1408, -1984)
    assert_equal Biome::DESERT, world.terrain.biome(-1600, 1408, world.terrain.surface_height(-1600, 1408))
    assert_equal Biome::DRY, world.precipitation(-1600, 1408)
  end

  def test_snow_falls_on_a_mountain_over_a_valley_that_has_rain
    world = World.new(1337)
    assert_equal Biome::RAIN, Biome::PRECIPITATION[world.terrain.biome(-1344, -1984, Terrain::COLD_LINE)]
    assert_equal Biome::SNOW, world.precipitation(-1344, -1984)
  end

  def test_it_counts_the_loaded_chunks
    world = World.new(1337)
    assert_equal 0, world.loaded_chunk_count
    world.load_chunk(0, 0)
    world.load_chunk(3, -2)
    assert_equal 2, world.loaded_chunk_count
  end

  # A column of 16 cells covers each byte of an Integer twice, also the ids
  # from 128 and the byte that holds the sign bit.
  def test_the_store_keeps_each_block_id_in_its_own_byte
    world = world_with_one_chunk
    ids = [Block::COUNT - 1, Block::STONE, Block::PLACED_SPRUCE_LEAVES, Block::AIR] * 4
    column = (SKY_Y - 16...SKY_Y)
    column.zip(ids) { |y, id| world.set(8, y, 8, id) }
    assert_equal(ids, column.map { |y| world.get(8, y, 8) })

    world.set(8, SKY_Y - 9, 8, Block::STONE)
    ids[7] = Block::STONE
    assert_equal(ids, column.map { |y| world.get(8, y, 8) })

    column.each { |y| world.set(8, y, 8, Block::AIR) }
    assert_equal([Block::AIR] * 16, column.map { |y| world.get(8, y, 8) })
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

  def test_a_door_does_not_fit_with_its_upper_half_above_the_world
    world = world_with_one_chunk
    world.set(8, WY - 2, 8, Block::STONE)
    refute world.door_fits?(8, WY - 1, 8)
  end

  def test_a_block_can_take_only_a_replaceable_cell_inside_the_world
    world = world_with_one_chunk
    assert world.replaceable_at?(8, SKY_Y, 8)
    refute world.replaceable_at?(8, WY, 8)
    refute world.replaceable_at?(8, -1, 8)
    refute world.replaceable_at?(8 + CHUNK, SKY_Y, 8)
    world.set(8, SKY_Y, 8, Block::STONE)
    refute world.replaceable_at?(8, SKY_Y, 8)
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

  def test_flowing_lava_is_a_light_once_a_cell_next_to_it_opens
    world = world_with_one_chunk
    [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]].each do |dx, dy, dz|
      world.set(8 + dx, SKY_Y + dy, 8 + dz, Block::STONE)
    end
    world.set(8, SKY_Y, 8, Block::LAVA_FLOW)
    world.load_chunk(0, 0)
    refute_includes lights(world), [8, SKY_Y, 8]
    world.set(9, SKY_Y, 8, Block::AIR)
    assert_includes lights(world), [8, SKY_Y, 8]
    world.load_chunk(0, 0)
    assert_includes lights(world), [8, SKY_Y, 8]
  end

  SIDES = [[1, 0], [-1, 0], [0, 1], [0, -1]].freeze

  # The cell of chunk 0 on its edge toward the chunk one step along dx,
  # dz, at the last cell along that edge, and the cell beside it in that
  # chunk.
  def edge_cells(dx, dz, y)
    lava = [dx.positive? ? CHUNK - 1 : 0, y, dz.positive? ? CHUNK - 1 : 0]
    lava[dx.zero? ? 0 : 2] = CHUNK - 1
    [lava, [lava[0] + dx, y, lava[2] + dz]]
  end

  # Lava at the edge of chunk 0, with stone on its other sides, and
  # beside_block beside it in the next chunk. The player walks away, so
  # each slot takes the chunk RING chunks farther, which has away_block
  # in that cell. Then the player comes back.
  def lava_at_a_chunk_edge(dx, dz, beside_block, away_block, next_chunk_last:)
    world = World.new(1337)
    lava, beside = edge_cells(dx, dz, SKY_Y)
    away = ->(cell) { [cell[0] + dx * RING * CHUNK, cell[1], cell[2] + dz * RING * CHUNK] }
    chunks = [[0, 0], [dx, dz]]
    chunks.each { |cx, cz| world.load_chunk(cx, cz) }
    [[-dx, 0, -dz], [0, 1, 0], [0, -1, 0], [dz, 0, dx], [-dz, 0, -dx]].each do |offset|
      stone = lava.zip(offset).map(&:sum)
      world.load_chunk(stone[0] >> 4, stone[2] >> 4) unless world.loaded?(stone[0], stone[2])
      world.set(*stone, Block::STONE)
    end
    world.set(*lava, Block::LAVA)
    world.set(*beside, beside_block)
    chunks.reverse_each { |cx, cz| world.load_chunk(cx + dx * RING, cz + dz * RING) }
    world.set(*away.call(beside), away_block)
    chunks.reverse! unless next_chunk_last
    chunks.each { |cx, cz| world.load_chunk(cx, cz) }
    [world, lava]
  end

  def test_lava_at_a_chunk_edge_is_a_light_when_the_next_chunk_has_air_beside_it_in_either_load_order
    SIDES.product([true, false]).each do |(dx, dz), last|
      world, lava = lava_at_a_chunk_edge(dx, dz, Block::AIR, Block::STONE, next_chunk_last: last)
      assert_includes lights_of(world, lava), lava, "side #{dx} #{dz}, next chunk last: #{last}"
    end
  end

  def test_lava_at_a_chunk_edge_is_no_light_when_the_next_chunk_buries_it_in_either_load_order
    SIDES.product([true, false]).each do |(dx, dz), last|
      world, lava = lava_at_a_chunk_edge(dx, dz, Block::STONE, Block::AIR, next_chunk_last: last)
      refute_includes lights_of(world, lava), lava, "side #{dx} #{dz}, next chunk last: #{last}"
    end
  end

  # Cave lava in a generated chunk, at the lowest and the highest height
  # that the generator gives it, becomes a light when the next chunk loads
  # with air beside it.
  def test_cave_lava_at_a_chunk_edge_is_a_light_when_the_next_chunk_loads_with_air_beside_it
    world = World.new(1337)
    world.load_chunk(0, 0)
    world.load_chunk(1, 0)
    heights = [1, Caves::LAVA_LEVEL]
    heights.each { |y| world.set(CHUNK, y, 8, Block::AIR) }
    world.load_chunk(RING + 1, 0)
    # put_block changes the generated chunk without a mark as edited.
    heights.each do |y|
      [[-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]].each do |dx, dy, dz|
        world.put_block(World.index(CHUNK - 1 + dx, y + dy, 8 + dz), Block::STONE)
      end
      world.put_block(World.index(CHUNK - 1, y, 8), Block::LAVA)
    end
    world.load_chunk(1, 0)
    heights.each { |y| assert_includes lights(world), [CHUNK - 1, y, 8], "y #{y}" }
  end

  # Chunk -1 shares its slot with chunk RING - 1. A load of chunk 0 must
  # not list the lava of chunk RING - 1 as lava of chunk -1.
  def test_a_chunk_load_lists_no_lava_of_a_neighbor_that_is_not_loaded
    world = World.new(1337)
    edge_x = RING * CHUNK - 1
    world.load_chunk(RING - 1, 0)
    world.set(edge_x, SKY_Y, 8, Block::LAVA)
    world.load_chunk(0, 0)
    listed = world.torches_of(RING - 1, 0).each_slice(3).map(&:first)
    assert_includes listed, edge_x
    assert(listed.all? { |x| x >> 4 == RING - 1 })
  end

  def lights(world) = world.torches_of(0, 0).each_slice(3).to_a

  def lights_of(world, cell) = world.torches_of(cell[0] >> 4, cell[2] >> 4).each_slice(3).to_a

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
    (SEA + 10...WY).each { |y| world.set(8, y, 8, Block::AIR) }
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

  def test_a_dry_spot_has_dry_land_3_blocks_away_to_each_side
    around = [[10, 20], [13, 20], [7, 20], [10, 23], [10, 17]]
    assert world_with_dry_land(*around).dry_spot?(10, 20)
    around.each do |column|
      refute world_with_dry_land(*(around - [column])).dry_spot?(10, 20), "no dry land at #{column}"
    end
  end

  def test_the_dry_spot_near_a_column_is_the_column_when_it_is_a_dry_spot
    assert_equal [5, 6], world_with_dry_spots([5, 6], [6, 6]).dry_spot_near(5, 6, 4)
  end

  def test_the_dry_spot_near_a_column_is_the_column_for_a_radius_of_1
    assert_equal [5, 6], world_with_dry_spots([5, 6]).dry_spot_near(5, 6, 1)
  end

  def test_the_dry_spot_near_a_column_is_found_on_each_side_of_the_column
    [[4, 5], [6, 5], [5, 4], [5, 6]].each do |spot|
      assert_equal spot, world_with_dry_spots(spot).dry_spot_near(5, 5, 4), "spot at #{spot}"
    end
  end

  def test_the_dry_spot_near_a_column_is_on_the_nearest_square
    assert_equal [7, 5], world_with_dry_spots([7, 5], [9, 5]).dry_spot_near(5, 5, 4)
  end

  def test_the_dry_spot_near_a_column_is_the_first_one_by_x_then_by_z
    assert_equal [5, 6], world_with_dry_spots([6, 4], [5, 6]).dry_spot_near(5, 5, 4)
    assert_equal [5, 4], world_with_dry_spots([5, 6], [5, 4]).dry_spot_near(5, 5, 4)
  end

  # The squares stop before the radius: radius 4 reaches 3 blocks out.
  def test_the_dry_spot_near_a_column_is_not_farther_than_the_radius
    assert_equal [8, 5], world_with_dry_spots([8, 5]).dry_spot_near(5, 5, 4)
    assert_equal [5, 5], world_with_dry_spots([9, 5]).dry_spot_near(5, 5, 4)
  end

  def test_the_dry_spot_near_a_column_is_the_column_when_no_spot_is_near
    assert_equal [5, 5], world_with_dry_spots.dry_spot_near(5, 5, 4)
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

  def test_a_box_fits_dry_on_a_solid_block_with_room_and_no_water
    world = world_with_one_chunk
    world.set(8, SKY_Y - 1, 8, Block::STONE)
    assert world.fits_dry?(8.5, SKY_Y, 8.5, Player::HALF, Player::TALL)
    refute world.fits_dry?(8.5, SKY_Y + 1, 8.5, Player::HALF, Player::TALL)
    world.set(8, SKY_Y + 1, 8, Block::STONE)
    refute world.fits_dry?(8.5, SKY_Y, 8.5, Player::HALF, Player::TALL)
    world.set(8, SKY_Y + 1, 8, Block::AIR)
    world.set(8, SKY_Y, 8, Block::WATER)
    refute world.fits_dry?(8.5, SKY_Y, 8.5, Player::HALF, Player::TALL)
  end

  def test_the_motion_top_is_above_glass_and_water_but_the_height_is_not
    world = world_with_dry_land
    world.load_chunk(0, 0)
    ground = world.motion_top(3, 3)
    world.set(3, ground + 4, 3, Block::GLASS)
    assert_equal ground + 5, world.motion_top(3, 3)
    assert_operator world.height_at(3, 3), :<, world.motion_top(3, 3)
    world.set(4, ground + 4, 4, Block::WATER)
    assert_operator world.motion_top(4, 4), :>, ground + 4
  end

  # A world where only these columns are dry land.
  def world_with_dry_land(*columns)
    world = World.new(1337)
    world.define_singleton_method(:dry_land?) { |x, z| columns.include?([x, z]) }
    world
  end

  # A world where only these columns are dry spots.
  def world_with_dry_spots(*columns)
    world = World.new(1337)
    world.define_singleton_method(:dry_spot?) { |x, z| columns.include?([x, z]) }
    world
  end
end
