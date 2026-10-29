require_relative "test_helper"

class TerrainTest < Minitest::Test
  def test_the_continent_spline_has_rising_points_and_one_height_for_each
    assert(Terrain::CONTINENT.each_cons(2).all? { |a, b| b > a })
    assert_equal Terrain::CONTINENT.size, Terrain::BASE.size
  end

  # The spawn search looks for land: a column whose noise surface is more
  # than 4 blocks above the sea.
  def test_land_rises_more_than_four_blocks_above_the_sea
    terrain = Terrain.new(1337)
    [[SEA + 5, true], [SEA + 4, false], [SEA - 10, false]].each do |surface, land|
      terrain.define_singleton_method(:surface_height) { |_x, _z| surface }
      assert_equal land, terrain.land?(3, 4), "surface #{surface}"
    end
  end

  def test_the_land_near_the_origin_is_the_origin_when_it_is_land
    assert_equal [0, 0], terrain_with_land([0, 0], [64, 0]).land_near_origin
  end

  # Each side of the square has one land point. The point is the only land.
  def test_the_land_near_the_origin_is_found_on_each_side_of_the_square
    [[0, -64], [0, 64], [-64, 0], [64, 0]].each do |point|
      assert_equal point, terrain_with_land(point).land_near_origin, "land at #{point}"
    end
  end

  def test_the_land_near_the_origin_is_found_in_each_corner_of_the_square
    [[-64, -64], [64, -64], [-64, 64], [64, 64]].each do |point|
      assert_equal point, terrain_with_land(point).land_near_origin, "land at #{point}"
    end
  end

  def test_the_land_near_the_origin_is_found_along_a_side_of_a_larger_square
    [[64, -128], [-128, 64], [-64, 128], [128, -64]].each do |point|
      assert_equal point, terrain_with_land(point).land_near_origin, "land at #{point}"
    end
  end

  def test_the_land_near_the_origin_is_on_the_nearest_square
    assert_equal [0, 64], terrain_with_land([128, 0], [0, 64], [0, 192]).land_near_origin
  end

  # The squares are 64 blocks apart and reach 4096 blocks from the origin.
  def test_the_land_near_the_origin_is_on_the_grid_up_to_4096_blocks_out
    assert_equal [4096, 0], terrain_with_land([4096, 0]).land_near_origin
    assert_equal [0, 0], terrain_with_land([4160, 0]).land_near_origin
    assert_equal [0, 0], terrain_with_land([32, 0], [0, 65], [32, -32], [-65, -65]).land_near_origin
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
          terrain.entrance?(column_x, column_z) && (2...terrain.surface_height(column_x, column_z)).any? { |y| terrain.carved?(column_x, y, column_z) }
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

  # The hash of the patch at x = 0 gives gravel, and that at x = 6 does not.
  def test_the_sea_floor_below_the_gravel_line_has_patches_of_gravel
    terrain = Terrain.new(1337)
    floor = Terrain::GRAVEL_LINE
    assert_equal Block::GRAVEL, terrain.top_block(0, 0, floor, Biome::PLAINS)
    assert_equal Block::SAND, terrain.top_block(0, 0, floor + 1, Biome::PLAINS)
    assert_equal Block::SAND, terrain.top_block(6, 0, floor, Biome::PLAINS)
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
    assert_equal Biome::SWAMP, terrain.biome(555, -795, Terrain::SWAMP_TOP)
    refute_equal Biome::SWAMP, terrain.biome(555, -795, Terrain::SWAMP_TOP + 1)
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
    terrain = Terrain.new(1337)
    plains = Biome::PLAINS
    assert_equal Block::SAND, terrain.top_block(0, 0, Terrain::BEACH_TOP + 1, plains)
    assert_equal Biome::GROUND[plains], terrain.top_block(0, 0, Terrain::BEACH_TOP + 2, plains)
    assert_equal Biome::GROUND[plains], terrain.top_block(0, 0, Terrain::ROCK_LINE + 1, plains)
    assert_equal Block::STONE, terrain.top_block(0, 0, Terrain::ROCK_LINE + 2, plains)
    assert_equal Block::STONE, terrain.top_block(0, 0, Terrain::SNOW_LINE + 1, plains)
    assert_equal Block::SNOW, terrain.top_block(0, 0, Terrain::SNOW_LINE + 2, plains)
  end

  private

  # A terrain where only these points are land.
  def terrain_with_land(*points)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:land?) { |x, z| points.include?([x, z]) }
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
