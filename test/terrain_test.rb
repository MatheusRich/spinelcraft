require_relative "test_helper"

class TerrainTest < Minitest::Test
  def test_the_sea_floor_spline_has_rising_points_and_one_height_for_each
    assert(Terrain::CONTINENT.each_cons(2).all? { |a, b| b > a })
    assert_equal Terrain::CONTINENT.size, Terrain::SEA_FLOOR.size
  end

  def test_each_land_table_has_one_value_for_each_continent_and_erosion_point
    assert(Terrain::LAND_CONTINENT.each_cons(2).all? { |a, b| b > a })
    assert(Terrain::EROSION.each_cons(2).all? { |a, b| b > a })
    [Terrain::LAND_BASE, Terrain::LAND_HILLS, Terrain::LAND_RIDGES].each do |table|
      assert_equal Terrain::LAND_CONTINENT.size, table.size
      assert(table.all? { |row| row.size == Terrain::EROSION.size })
    end
  end

  def test_the_sea_floor_meets_the_coast
    assert_equal Terrain::CONTINENT.last, Terrain::LAND_CONTINENT.first
    assert_equal SEA, Terrain::SEA_FLOOR.last
  end

  # A table whose value at row r and column c is 100 * r + c.
  def test_a_land_value_follows_a_line_between_the_table_points
    table = Array.new(Terrain::LAND_CONTINENT.size) { |row| Array.new(Terrain::EROSION.size) { |column| 100.0 * row + column } }
    continents = Terrain::LAND_CONTINENT
    erosions = Terrain::EROSION
    assert_in_delta 203.0, Terrain.land(table, continents[2], erosions[3])
    assert_in_delta 203.5, Terrain.land(table, continents[2], (erosions[3] + erosions[4]) / 2)
    assert_in_delta 253.0, Terrain.land(table, (continents[2] + continents[3]) / 2, erosions[3])
    assert_in_delta 225.0, Terrain.land(table, continents[2] * 0.75 + continents[3] * 0.25, erosions[0])
    assert_in_delta 50.0, Terrain.land(table, (continents[0] + continents[1]) / 2, erosions[0])
    assert_in_delta 0.0, Terrain.land(table, continents[0] - 1.0, erosions[0] - 1.0)
    assert_in_delta 100.0 * (continents.size - 1) + erosions.size - 1, Terrain.land(table, continents.last + 1.0, erosions.last + 1.0)
  end

  # The spawn search looks for low land: a column whose noise surface is
  # more than 4 and at most 16 blocks above the sea.
  def test_low_land_is_above_the_beach_and_below_the_hills
    terrain = Terrain.new(1337)
    [[SEA + 5, true], [SEA + 16, true], [SEA + 4, false], [SEA + 17, false], [SEA - 10, false]].each do |surface, land|
      terrain.define_singleton_method(:surface_height) { |_x, _z| surface }
      assert_equal land, terrain.low_land?(3, 4), "surface #{surface}"
    end
  end

  # A low column is no spawn when the land 48 blocks to one side is high,
  # as in a valley in the mountains.
  def test_spawn_land_is_low_land_with_low_land_around_it
    reach = Terrain::SPAWN_REACH
    assert valley_terrain.spawn_land?(0, 0)
    [[reach, 0], [-reach, 0], [0, reach], [0, -reach]].each do |high|
      refute valley_terrain(high).spawn_land?(0, 0), "high land at #{high}"
    end
  end

  def test_spawn_land_is_open_grassland
    assert valley_terrain(biome: Biome::PLAINS).spawn_land?(0, 0)
    assert valley_terrain(biome: Biome::SAVANNA).spawn_land?(0, 0)
    refute valley_terrain(biome: Biome::DESERT).spawn_land?(0, 0)
    refute valley_terrain(biome: Biome::FOREST).spawn_land?(0, 0)
    refute valley_terrain(biome: Biome::JUNGLE).spawn_land?(0, 0)
  end

  LOW = Terrain::RIVER_TOP - Terrain::RIVER_RISE
  WET = Terrain::RIVER_DRY + Terrain::RIVER_WET
  BANK = SEA + 20.0

  def test_a_river_cuts_low_wet_land_down_to_its_bed
    assert_in_delta Terrain::RIVER_BED, river_terrain(0.0, WET).river_height(LOW, BANK), 1e-9
  end

  def test_the_land_outside_a_river_valley_stays
    assert_equal BANK, river_terrain(Terrain::RIVER_VALLEY, WET).river_height(LOW, BANK)
  end

  # The valley sides rise from the bed to the bank, gently near the middle:
  # a quarter of the way out, the land has risen 5/32 of the way.
  def test_a_river_valley_rises_to_its_banks
    heights = [0.25, 0.5, 0.75].map { |share| river_terrain(Terrain::RIVER_VALLEY * share, WET).river_height(LOW, BANK) }
    assert(heights.each_cons(2).all? { |low, high| low < high })
    assert(heights.all? { |height| height > Terrain::RIVER_BED && height < BANK })
    assert_in_delta Terrain::RIVER_BED + (BANK - Terrain::RIVER_BED) * 5 / 32, heights.first, 1e-9
  end

  # The spawn of seed 1337 is low plains, so a river through it cuts its
  # surface down to the bed.
  def test_a_river_cuts_the_surface_of_low_land
    x, z = Terrain.new(1337).spawn_near_origin
    assert_operator river_terrain(Terrain::RIVER_VALLEY, WET).surface_height(x, z), :>, SEA
    assert_equal Terrain::RIVER_BED.to_i, river_terrain(0.0, WET).surface_height(x, z)
  end

  def test_high_land_and_dry_land_have_no_river
    assert_equal BANK, river_terrain(0.0, WET).river_height(Terrain::RIVER_TOP, BANK)
    assert_equal BANK, river_terrain(0.0, Terrain::RIVER_DRY).river_height(LOW, BANK)
  end

  # A river narrows toward its source: on higher land, the same distance
  # from the middle is outside the valley.
  def test_a_river_narrows_as_the_land_rises
    noise = Terrain::RIVER_VALLEY * 0.6
    assert_operator river_terrain(noise, WET).river_height(LOW, BANK), :<, BANK
    assert_equal BANK, river_terrain(noise, WET).river_height(LOW + Terrain::RIVER_RISE * 0.5, BANK)
  end

  def test_land_at_the_river_bed_stays
    assert_equal Terrain::RIVER_BED - 2, river_terrain(0.0, WET).river_height(LOW, Terrain::RIVER_BED - 2)
  end

  # A terrain whose river noise is noise and whose humidity is humidity.
  def river_terrain(noise, humidity)
    terrain = Terrain.new(1337)
    river_noise = Object.new
    river_noise.define_singleton_method(:fbm2) { |_x, _z, _octaves| noise }
    terrain.instance_variable_set(:@noise3, river_noise)
    terrain.define_singleton_method(:warped_humidity) { humidity }
    terrain
  end

  # A terrain of low land of the biome, with hills at the high columns.
  def valley_terrain(*high, biome: Biome::PLAINS)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:surface_height) { |x, z| high.include?([x, z]) ? SEA + Terrain::SPAWN_TOP + 1 : SEA + 8 }
    terrain.define_singleton_method(:biome) { |_x, _z, _height| biome }
    terrain
  end

  def test_the_land_near_the_origin_is_the_origin_when_it_is_land
    assert_equal [0, 0], terrain_with_land([0, 0], [64, 0]).spawn_near_origin
  end

  # Each side of the square has one land point. The point is the only land.
  def test_the_land_near_the_origin_is_found_on_each_side_of_the_square
    [[0, -64], [0, 64], [-64, 0], [64, 0]].each do |point|
      assert_equal point, terrain_with_land(point).spawn_near_origin, "land at #{point}"
    end
  end

  def test_the_land_near_the_origin_is_found_in_each_corner_of_the_square
    [[-64, -64], [64, -64], [-64, 64], [64, 64]].each do |point|
      assert_equal point, terrain_with_land(point).spawn_near_origin, "land at #{point}"
    end
  end

  def test_the_land_near_the_origin_is_found_along_a_side_of_a_larger_square
    [[64, -128], [-128, 64], [-64, 128], [128, -64]].each do |point|
      assert_equal point, terrain_with_land(point).spawn_near_origin, "land at #{point}"
    end
  end

  def test_the_land_near_the_origin_is_on_the_nearest_square
    assert_equal [0, 64], terrain_with_land([128, 0], [0, 64], [0, 192]).spawn_near_origin
  end

  # The squares are 64 blocks apart and reach 4096 blocks from the origin.
  def test_the_land_near_the_origin_is_on_the_grid_up_to_4096_blocks_out
    assert_equal [4096, 0], terrain_with_land([4096, 0]).spawn_near_origin
    assert_equal [0, 0], terrain_with_land([4160, 0]).spawn_near_origin
    assert_equal [0, 0], terrain_with_land([32, 0], [0, 65], [32, -32], [-65, -65]).spawn_near_origin
  end

  # surface_height and biome keep the warp of the last column. The biome of
  # a column must not take the warp of a column that shares its x or its z.
  def test_the_biome_of_a_column_is_the_same_after_the_height_of_another_column
    fresh = Terrain.new(1337)
    expected = fresh.biome(700, 700, 95)
    refute_equal expected, fresh.biome(0, 700, 95)
    refute_equal expected, fresh.biome(700, 0, 95)
    terrain = Terrain.new(1337)
    terrain.surface_height(0, 700)
    assert_equal expected, terrain.biome(700, 700, 95)
    terrain.surface_height(700, 0)
    assert_equal expected, terrain.biome(700, 700, 95)
  end

  def test_a_tunnel_is_closed_under_the_top_block_and_widens_to_its_full_width
    roof = Terrain::CAVE_ROOF
    fade = Terrain::CAVE_FADE
    assert_equal 0.0, Terrain.cave_width(roof)
    assert_in_delta Terrain::CAVE_WIDTH / fade, Terrain.cave_width(roof + 1), 1e-12
    assert_in_delta Terrain::CAVE_WIDTH * (fade - 1) / fade, Terrain.cave_width(roof + fade - 1), 1e-12
    assert_equal Terrain::CAVE_WIDTH, Terrain.cave_width(roof + fade)
    assert_equal Terrain::CAVE_WIDTH, Terrain.cave_width(roof + fade + 50)
  end

  def test_a_cave_is_where_both_noise_fields_are_near_zero
    assert Terrain.cave?(0.5, 0.4, 0.5)
    refute Terrain.cave?(0.5, 0.5, 0.5)
    refute Terrain.cave?(0.0, 0.8, 0.5)
    assert Terrain.cave_possible?(0.6, 0.5)
    refute Terrain.cave_possible?(0.8, 0.5)
  end

  # Tunnels reach the surface only in patches, so a chunk has columns in a
  # patch and columns out of it.
  def test_only_some_columns_are_in_an_entrance_patch
    terrain = Terrain.new(1337)
    patch = (0...CHUNK).sum { |x| (0...CHUNK).count { |z| terrain.entrance?(x, z) } }
    assert_operator patch, :>, 0
    assert_operator patch, :<, CHUNK * CHUNK
  end

  def test_the_cave_region_goes_from_closed_to_full_and_has_values_between
    terrain = Terrain.new(1337)
    values = (-30..30).flat_map { |i| (-30..30).map { |j| terrain.cave_region(i * 40, j * 40) } }
    assert_equal 0.0, values.min
    assert_equal 1.0, values.max
    assert(values.any? { |value| value > 0.0 && value < 1.0 })
    assert_operator values.count(0.0), :>, values.size / 4
    assert_operator values.count(1.0), :>, values.size / 8
  end

  def test_the_room_threshold_has_a_roof_and_falls_to_its_value
    roof = Terrain::ROOM_ROOF
    fade = Terrain::ROOM_FADE
    assert_operator Terrain.room_threshold(roof), :>, 1.0
    assert_in_delta Terrain::ROOM_THRESHOLD, Terrain.room_threshold(roof + fade), 1e-12
    assert_in_delta Terrain::ROOM_THRESHOLD, Terrain.room_threshold(roof + fade + 40), 1e-12
    steps = (roof + 1..roof + fade).map { |depth| Terrain.room_threshold(depth) }
    assert_equal steps.sort.reverse, steps
    assert_operator steps.first, :<, 1.0
  end

  # x_edges and yz_lerp blend the 8 points of a cell of the cave grid. In
  # a grid of 2 x 2 x 2 points where point n holds n, the blend at tx, ty,
  # tz is 4 tx + 2 ty + tz.
  def test_the_blend_of_a_grid_cell_is_a_straight_line_along_each_axis
    grid = Array.new(8) { |n| n.to_f }
    edges = Array.new(4, 0.0)
    Terrain.x_edges(grid, 0, 2, 2, 0.25, edges)
    assert_in_delta 2.75, Terrain.yz_lerp(edges, 0.5, 0.75), 1e-12
  end

  # carved? tests one block from the noise. It must agree with the chunk
  # grid of World#generate_chunk, where tunnels keep their full width.
  def test_carved_blocks_of_an_entrance_patch_are_the_caves_of_the_generated_chunk
    terrain = Terrain.new(1337)
    # A chunk with a tunnel in an entrance patch, near the top block.
    cx, cz = (-8..8).flat_map { |i| (-8..8).map { |j| [i, j] } }.find do |i, j|
      CHUNK.times.any? do |x|
        CHUNK.times.any? do |z|
          column_x = i * CHUNK + x
          column_z = j * CHUNK + z
          top = terrain.surface_height(column_x, column_z)
          terrain.entrance?(column_x, column_z) &&
            (top - 1 - Terrain::ROOM_ROOF...top).any? { |y| y >= 2 && terrain.carved?(column_x, y, column_z) }
        end
      end
    end
    world = World.new(1337)
    world.load_chunk(cx, cz)
    carved = 0
    CHUNK.times do |dx|
      CHUNK.times do |dz|
        x = cx * CHUNK + dx
        z = cz * CHUNK + dz
        next unless terrain.entrance?(x, z)

        top = terrain.surface_height(x, z)
        (2...top).each do |y|
          next if top - 1 - y > Terrain::ROOM_ROOF

          cave = [Block::AIR, Block::LAVA].include?(world.get(x, y, z))
          assert_equal cave, terrain.carved?(x, y, z), "block #{x} #{y} #{z}"
          carved += 1 if cave
        end
      end
    end
    assert_operator carved, :>, 0
  end

  # The floor under the sea is sand with disks, the bed of a river is dirt
  # with disks, and a pond has dirt only.
  def test_the_floor_under_water_is_sand_at_sea_dirt_in_a_river_and_in_a_pond
    coast = river_shore(Terrain::SHORE - 0.001, Terrain::RIVER_VALLEY, 0.0)
    river = river_shore(Terrain::SHORE, 0.0, Terrain::RIVER_VALLEY)
    pond = river_shore(Terrain::SHORE, Terrain::RIVER_VALLEY, 0.0)
    bare = (0..).find { |x| Disks.floor(x, 0, Block::AIR) == Block::AIR }
    gravel = (0..).find { |x| Disks.floor(x, 0, Block::AIR) == Block::GRAVEL }
    assert_equal [Block::SAND, Block::GRAVEL], [coast.water_floor(bare, 0), coast.water_floor(gravel, 0)]
    assert_equal [Block::DIRT, Block::GRAVEL], [river.water_floor(bare, 0), river.water_floor(gravel, 0)]
    assert_equal [Block::DIRT, Block::DIRT], [pond.water_floor(bare, 0), pond.water_floor(gravel, 0)]
  end

  # The pool noise is high at x = 0 and low at x = 1.
  def test_a_swamp_holds_pools_at_sea_level_and_dirt_below_the_sea
    terrain = Terrain.new(1337)
    swamp = Biome::SWAMP
    assert_equal Block::WATER, terrain.top_block(0, 0, SEA + 1, swamp)
    assert_equal Biome::GROUND[swamp], terrain.top_block(1, 0, SEA + 1, swamp)
    assert_equal Biome::GROUND[swamp], terrain.top_block(0, 0, SEA + 2, swamp)
    assert_equal Block::DIRT, terrain.top_block(0, 0, SEA, swamp)
  end

  def test_the_air_gets_colder_up_high_so_mountains_get_snowy_biomes
    terrain = Terrain.new(1337)
    assert_equal Biome::PLAINS, terrain.biome(0, 0, Terrain::COLD_LINE)
    assert_equal Biome::TUNDRA, terrain.biome(0, 0, Terrain::TOP.to_i)
  end

  def test_swamps_grow_up_to_the_swamp_top
    terrain = Terrain.new(1337)
    assert_equal Biome::SWAMP, terrain.biome(-1456, -1984, Terrain::SWAMP_TOP)
    refute_equal Biome::SWAMP, terrain.biome(-1456, -1984, Terrain::SWAMP_TOP + 1)
  end

  # The tree roll of column 0, 50 is 667, and that of column 72, 481 is 900.
  def test_a_column_grows_a_tree_when_its_roll_is_below_the_trees_of_its_biome
    assert_equal 667, Noise.hash3(0, 0, 50, 21)
    assert_equal Biome::TREES[Biome::SWAMP], Noise.hash3(72, 0, 481, 21)
    terrain = terrain_with(biome: Biome::SWAMP)
    assert_equal SEA + 9, terrain.tree_top(0, 50)
    assert_equal(-1, terrain.tree_top(72, 481))
  end

  def test_a_tree_grows_on_grass_or_snowy_grass
    assert_equal SEA + 9, terrain_with(ground: Block::GRASS).tree_top(0, 50)
    assert_equal SEA + 9, terrain_with(ground: Block::SNOW_GRASS).tree_top(0, 50)
    assert_equal(-1, terrain_with(ground: Block::SAND).tree_top(0, 50))
  end

  # A cave that opens the top block leaves no ground for a tree. On a
  # beach the tunnels stay closed (see World#generate_chunk).
  def test_no_tree_grows_where_a_cave_opens_the_top_block_except_on_a_beach
    assert_equal(-1, terrain_with(cave: true).tree_top(0, 50))
    beach = Terrain::BEACH_TOP + 1
    assert_equal beach - 1, terrain_with(height: beach, cave: true).tree_top(0, 50)
  end

  def test_the_spline_is_flat_beyond_its_ends_and_a_straight_line_between_its_points
    xs = [0.0, 1.0, 3.0]
    ys = [10.0, 20.0, 0.0]
    assert_equal 10.0, Terrain.spline(xs, ys, -5.0)
    assert_equal 15.0, Terrain.spline(xs, ys, 0.5)
    assert_equal 10.0, Terrain.spline(xs, ys, 2.0)
    assert_equal 0.0, Terrain.spline(xs, ys, 9.0)
  end

  def test_smooth_is_0_below_0_and_1_above_1_with_an_s_curve_between
    assert_equal 0.0, Terrain.smooth(-0.5)
    assert_equal 0.5, Terrain.smooth(0.5)
    assert_equal 1.0, Terrain.smooth(1.5)
    assert_operator Terrain.smooth(0.25), :<, 0.25
  end

  def test_the_top_block_is_sand_on_a_beach_stone_on_high_rock_and_snow_above_the_snow_line
    terrain = shore_terrain(shore: true)
    plains = Biome::PLAINS
    assert_equal Block::SAND, terrain.top_block(0, 0, Terrain::BEACH_TOP + 1, plains)
    assert_equal Biome::GROUND[plains], terrain.top_block(0, 0, Terrain::BEACH_TOP + 2, plains)
    assert_equal Biome::GROUND[plains], terrain.top_block(0, 0, Terrain::ROCK_LINE + 1, plains)
    assert_equal Block::STONE, terrain.top_block(0, 0, Terrain::ROCK_LINE + 2, plains)
    assert_equal Block::STONE, terrain.top_block(0, 0, Terrain::SNOW_LINE + 1, plains)
    assert_equal Block::SNOW, terrain.top_block(0, 0, Terrain::SNOW_LINE + 2, plains)
  end

  def test_low_land_away_from_the_shore_is_no_beach
    terrain = shore_terrain(shore: false)
    plains = Biome::PLAINS
    assert_equal Biome::GROUND[plains], terrain.top_block(0, 0, Terrain::BEACH_TOP + 1, plains)
  end

  def test_the_top_block_under_water_is_the_floor_under_water
    terrain = shore_terrain(shore: true)
    terrain.define_singleton_method(:water_floor) { |_x, _z| Block::GRAVEL }
    assert_equal Block::GRAVEL, terrain.top_block(0, 0, SEA, Biome::PLAINS)
    assert_equal Block::SAND, terrain.top_block(0, 0, SEA + 1, Biome::PLAINS)
  end

  def test_the_shore_is_near_the_coast_or_in_a_river_valley
    assert river_shore(Terrain::SHORE - 0.001, Terrain::RIVER_VALLEY, 0.0).shore?(0, 0)
    refute river_shore(Terrain::SHORE, Terrain::RIVER_VALLEY, 0.0).shore?(0, 0)
    assert river_shore(Terrain::SHORE, 0.0, Terrain::RIVER_VALLEY).shore?(0, 0)
    refute river_shore(Terrain::SHORE, Terrain::RIVER_VALLEY * 0.5, Terrain::RIVER_VALLEY * 0.5).shore?(0, 0)
    refute river_shore(Terrain::SHORE, Terrain::RIVER_VALLEY, Terrain::RIVER_VALLEY * 2).shore?(0, 0)
  end

  # A river valley runs where the river noise is below its width.
  def test_the_river_width_shrinks_on_high_and_dry_land
    terrain = river_terrain(0.0, WET)
    assert_in_delta Terrain::RIVER_VALLEY, terrain.river_width(LOW), 1e-12
    assert_in_delta 0.0, terrain.river_width(Terrain::RIVER_TOP), 1e-12
    assert_in_delta Terrain::RIVER_VALLEY / 2, terrain.river_width(LOW + Terrain::RIVER_RISE / 2), 1e-12
    assert_in_delta 0.0, river_terrain(0.0, Terrain::RIVER_DRY).river_width(LOW), 1e-12
  end

  # A terrain whose columns are on the shore or not.
  def shore_terrain(shore:)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:shore?) { |_x, _z| shore }
    terrain
  end

  # A terrain with the continent noise continent, a river noise and a
  # river width.
  def river_shore(continent, noise, width)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:continent) { |_x, _z| continent }
    terrain.define_singleton_method(:river_noise) { noise }
    terrain.define_singleton_method(:river_width) { |_base| width }
    terrain
  end

  private

  # A terrain where only these points are land.
  def terrain_with_land(*points)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:spawn_land?) { |x, z| points.include?([x, z]) }
    terrain
  end

  # A terrain whose columns all have this height, biome, top block and
  # cave, for the rules of tree_top.
  def terrain_with(height: SEA + 10, biome: Biome::JUNGLE, ground: Block::GRASS, cave: false)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:surface_height) { |_x, _z| height }
    terrain.define_singleton_method(:biome) { |_x, _z, _h| biome }
    terrain.define_singleton_method(:top_block) { |_x, _z, _h, _biome| ground }
    terrain.define_singleton_method(:entrance?) { |_x, _z| cave }
    terrain.define_singleton_method(:carved?) { |_x, _y, _z| cave }
    terrain
  end
end
