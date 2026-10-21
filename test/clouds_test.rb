require_relative "test_helper"

class CloudsTest < Minitest::Test
  # The floats of one vertex in a Mesh3.
  VERTEX = 11
  # The float of a Mesh3 vertex with its glow.
  GLOW = 10

  def test_the_clouds_cover_a_fifth_of_the_sky
    [1, 1337].each do |seed|
      clouds = Clouds.new(seed)
      cells = 0
      Clouds::GRID.times { |i| Clouds::GRID.times { |j| cells += 1 if clouds.cloud?(i, j) } }
      assert_in_delta 0.2, cells.to_f / (Clouds::GRID * Clouds::GRID), 0.001
    end
  end

  def test_the_cloud_boxes_are_four_blocks_tall
    clouds = Clouds.new(1337)
    clouds.build(0.0, 0.0, 0.0)
    heights = vertices(clouds.mesh).map { |vertex| vertex[1] }.uniq.sort
    assert_equal [192.0, 196.0], heights
  end

  def test_the_far_layer_skips_the_cloud_cells_that_have_boxes
    clouds = Clouds.new(1337)
    # The same clouds move from one place to the next.
    [[0, 0], [40, -70]].each do |ci, cj|
      clouds.build(ci * Clouds::CELL + 1.0, cj * Clouds::CELL + 1.0, 0.0)
      skipped = skipped_cells(clouds).select { |i, j| clouds.cloud?(i, j) }
      assert_equal skipped, flat_cells(clouds.mesh, Clouds::HEIGHT + Clouds::DEPTH)
      assert_equal skipped, flat_cells(clouds.mesh, Clouds::HEIGHT)
    end
  end

  def test_the_boxes_have_a_wall_only_where_a_cloud_cell_meets_a_cell_with_no_cloud
    clouds = Clouds.new(1337)
    clouds.build(0.0, 0.0, 0.0)
    walls = flat_cells(clouds.mesh, Clouds::HEIGHT).flat_map do |i, j|
      [[1, 0, :x, i + 1, j], [-1, 0, :x, i, j], [0, 1, :z, j + 1, i], [0, -1, :z, j, i]].filter_map do |di, dj, *wall|
        wall unless clouds.cloud?(i + di, j + dj)
      end
    end
    assert_equal walls.sort, wall_edges(clouds.mesh)
  end

  def test_a_cloud_larger_than_the_boxes_has_one_box_for_each_column_open_to_the_far_layer
    clouds = Clouds.new(1337)
    clouds.instance_variable_set(:@cells, Array.new(Clouds::GRID * Clouds::GRID, 1))
    clouds.build(0.0, 0.0, 0.0)
    near = Clouds::NEAR
    assert_equal (-near..near).to_a.product((-near..near).to_a), flat_cells(clouds.mesh, Clouds::HEIGHT)
    # A top and a bottom for each column, and no wall where the cloud goes on.
    assert_equal (2 * near + 1) * 2, faces(clouds.mesh).size
  end

  def test_only_the_walls_have_the_glow_that_makes_them_fade
    clouds = Clouds.new(1337)
    clouds.build(0.0, 0.0, 0.0)
    faces(clouds.mesh).each do |face|
      wall = face.map { |vertex| vertex[1] }.uniq.size > 1
      assert_equal [wall ? -1.0 : 0.0], face.map { |vertex| vertex[GLOW] }.uniq
    end
  end

  def test_the_walls_fade_out_before_the_nearest_cell_that_can_switch
    defines = Clouds.shader_defines.scan(/^#define (\w+) ([\d.]+)$/).to_h { |name, value| [name, value.to_f] }
    # A player at the edge of cell 0, next to cell 1. The first cell past
    # NEAR in that direction can switch.
    player = Clouds::CELL - 0.01
    switch = (Clouds::NEAR + 1) * Clouds::CELL - player
    assert_operator defines["CLOUD_FADE_END"], :<=, switch
    assert_in_delta switch, defines["CLOUD_FADE_END"], 1.0
    assert_equal Clouds::FADE, defines["CLOUD_FADE_END"] - defines["CLOUD_FADE_START"]
    # The shader source goes on after the last line.
    assert Clouds.shader_defines.end_with?("\n")
  end

  private

  def vertices(mesh) = mesh.v.each_slice(VERTEX).to_a

  def faces(mesh) = vertices(mesh).each_slice(6).to_a

  # The first and the last cell edge that face spans along axis (0 for x,
  # 2 for z).
  def cell_span(face, axis) = face.map { |vertex| (vertex[axis] / Clouds::CELL).round }.minmax

  # The square of cells that the far layer skips, from the uniforms.
  def skipped_cells(clouds)
    uniforms = Array.new(16, 0.0)
    clouds.write_uniforms(uniforms, 8, 0.0, 0.0)
    i0, j0, i1, j1 = uniforms[12, 4].map(&:to_i)
    (i0..i1).to_a.product((j0..j1).to_a)
  end

  # The cells under the flat faces of mesh at height y.
  def flat_cells(mesh, y)
    faces(mesh).select { |face| face.all? { |vertex| vertex[1] == y } }.flat_map do |face|
      xs = cell_span(face, 0)
      zs = cell_span(face, 2)
      (xs[0]...xs[1]).to_a.product((zs[0]...zs[1]).to_a)
    end.sort
  end

  # The walls of mesh, one for each cell edge: [:x, x, j] for a wall at cell
  # edge x along cell j, and [:z, z, i] for a wall at cell edge z along cell i.
  def wall_edges(mesh)
    faces(mesh).reject { |face| face.map { |vertex| vertex[1] }.uniq.size == 1 }.flat_map do |face|
      xs = cell_span(face, 0)
      zs = cell_span(face, 2)
      next (zs[0]...zs[1]).map { |j| [:x, xs[0], j] } if xs[0] == xs[1]

      (xs[0]...xs[1]).map { |i| [:z, zs[0], i] }
    end.sort
  end
end
