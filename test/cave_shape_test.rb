require_relative "test_helper"

class CaveShapeTest < Minitest::Test
  def test_a_tunnel_is_closed_under_the_top_block_and_widens_to_its_full_width
    roof = CaveShape::CAVE_ROOF
    fade = CaveShape::CAVE_FADE
    assert_equal 0.0, CaveShape.cave_width(roof)
    assert_in_delta CaveShape::CAVE_WIDTH / fade, CaveShape.cave_width(roof + 1), 1e-12
    assert_in_delta CaveShape::CAVE_WIDTH * (fade - 1) / fade, CaveShape.cave_width(roof + fade - 1), 1e-12
    assert_equal CaveShape::CAVE_WIDTH, CaveShape.cave_width(roof + fade)
    assert_equal CaveShape::CAVE_WIDTH, CaveShape.cave_width(roof + fade + 50)
  end

  def test_a_cave_is_where_both_noise_fields_are_near_zero
    assert CaveShape.cave?(0.5, 0.4, 0.5)
    refute CaveShape.cave?(0.5, 0.5, 0.5)
    refute CaveShape.cave?(0.0, 0.8, 0.5)
    assert CaveShape.cave_possible?(0.6, 0.5)
    refute CaveShape.cave_possible?(0.8, 0.5)
    refute CaveShape.cave_possible?(0.5, 0.25)
  end

  def test_only_some_columns_are_in_an_entrance_patch
    shape = CaveShape.new(1337)
    patch = (0...CHUNK).sum { |x| (0...CHUNK).count { |z| shape.entrance?(x, z) } }
    assert_operator patch, :>, 0
    assert_operator patch, :<, CHUNK * CHUNK
  end

  def test_an_entrance_patch_spans_many_columns
    shape = CaveShape.new(1337)
    columns = (0...64).to_a.product((0...64).to_a)
    alike = columns.count { |x, z| shape.entrance?(x, z) == shape.entrance?(x + 1, z) && shape.entrance?(x, z) == shape.entrance?(x, z + 1) }
    assert_operator alike, :>, columns.size * 9 / 10
    assert_operator columns.count { |x, z| shape.entrance?(x, z) }, :>, columns.size / 16
  end

  def test_the_cave_region_goes_from_closed_to_full_and_has_values_between
    shape = CaveShape.new(1337)
    values = (-30..30).flat_map { |i| (-30..30).map { |j| shape.cave_region(i * 40, j * 40) } }
    assert_equal 0.0, values.min
    assert_equal 1.0, values.max
    assert(values.any? { |value| value > 0.0 && value < 1.0 })
    assert_operator values.count(0.0), :>, values.size / 4
    assert_operator values.count(1.0), :>, values.size / 8
  end

  def test_the_room_threshold_has_a_roof_and_falls_to_its_value
    roof = CaveShape::ROOM_ROOF
    fade = CaveShape::ROOM_FADE
    assert_operator CaveShape.room_threshold(roof), :>, 1.0
    assert_in_delta CaveShape::ROOM_THRESHOLD, CaveShape.room_threshold(roof + fade), 1e-12
    assert_in_delta CaveShape::ROOM_THRESHOLD, CaveShape.room_threshold(roof + fade + 40), 1e-12
    steps = (roof + 1..roof + fade).map { |depth| CaveShape.room_threshold(depth) }
    assert_equal steps.sort.reverse, steps
    assert_operator steps.first, :<, 1.0
    assert_operator steps[-2], :>, CaveShape::ROOM_THRESHOLD
  end

  # Where point n of the grid holds n + 1, the blend at tx, ty, tz is
  # 1 + 4 tx + 2 ty + tz.
  def test_the_blend_of_a_grid_cell_is_a_straight_line_along_each_axis
    grid = Array.new(8) { |n| n + 1.0 }
    edges = Array.new(4, 0.0)
    CaveShape.x_edges(grid, 0, 2, 2, 0.25, edges)
    assert_in_delta 3.75, CaveShape.yz_lerp(edges, 0.5, 0.75), 1e-12
  end

  # Caves gives tunnels in an entrance patch their full width. The leaves of
  # a tree next to an opening can fill its air.
  def test_carved_blocks_of_an_entrance_patch_are_the_caves_of_the_generated_chunk
    terrain = Terrain.new(1337)
    cx, cz = (-8..8).flat_map { |i| (-8..8).map { |j| [i, j] } }.find do |i, j|
      CHUNK.times.any? do |x|
        CHUNK.times.any? do |z|
          column_x = i * CHUNK + x
          column_z = j * CHUNK + z
          top = terrain.surface_height(column_x, column_z)
          terrain.cave_shape.entrance?(column_x, column_z) &&
            (top - 1 - CaveShape::ROOM_ROOF...top).any? { |y| y >= 2 && terrain.cave_shape.carved?(column_x, y, column_z) }
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
        next unless terrain.cave_shape.entrance?(x, z)

        top = terrain.surface_height(x, z)
        (2...top).each do |y|
          next if top - 1 - y > CaveShape::ROOM_ROOF

          block = world.get(x, y, z)
          next if Block.leaves?(block)

          cave = [Block::AIR, Block::LAVA].include?(block)
          assert_equal cave, terrain.cave_shape.carved?(x, y, z), "block #{x} #{y} #{z}"
          carved += 1 if cave
        end
      end
    end
    assert_operator carved, :>, 0
  end

  def test_a_block_is_an_opening_where_it_is_carved_in_an_entrance_patch
    [[true, true, true], [true, false, false], [false, true, false]].each do |entrance, carved, opening|
      shape = CaveShape.new(1337)
      shape.define_singleton_method(:entrance?) { |_x, _z| entrance }
      shape.define_singleton_method(:carved?) { |_x, _y, _z| carved }
      assert_equal opening, shape.opening?(0, 0, 0)
    end
  end
end
