require_relative "test_helper"

class CloudsTest < Minitest::Test
  # The floats of one vertex in a Mesh3.
  VERTEX = 11

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

  def test_a_cloud_with_a_cell_near_the_player_has_boxes_on_all_its_cells
    clouds = Clouds.new(1337)
    far = 0
    # The same clouds move from one place to the next.
    [[0, 0], [37, -81], [200, 130], [-150, 90]].each do |ci, cj|
      clouds.build(ci * Clouds::CELL + 1.0, cj * Clouds::CELL + 1.0, 0.0)
      boxed = boxed_cells(clouds, ci, cj)
      boxed.each do |i, j|
        neighbors(i, j).each do |ni, nj|
          next if distance(ni, nj, ci, cj) > Clouds::REACH

          assert_equal clouds.cloud?(ni, nj), clouds.boxed?(ni, nj), "cell #{ni}, #{nj} beside boxed cell #{i}, #{j}"
        end
      end
      assert_equal boxed, near_clouds(clouds, ci, cj)
      far += boxed.count { |i, j| distance(i, j, ci, cj) > Clouds::NEAR }
    end
    assert_operator far, :>, 0, "no cloud goes past NEAR"
  end

  def test_a_cloud_larger_than_the_reach_has_boxes_out_to_the_reach
    clouds = Clouds.new(1337)
    clouds.instance_variable_set(:@cells, Array.new(Clouds::GRID * Clouds::GRID, 1))
    clouds.build(0.0, 0.0, 0.0)
    reach = Clouds::REACH
    square = (-reach..reach).to_a.product((-reach..reach).to_a)
    assert_equal square, flat_cells(clouds.mesh, Clouds::HEIGHT + Clouds::DEPTH)
    # Each column of cells along z is one box: a top, a bottom and two z ends.
    # The first and the last column have one x side each.
    assert_equal (2 * reach + 1) * 4 + 2, faces(clouds.mesh).size
  end

  def test_the_far_layer_skips_a_square_around_the_boxes_smaller_than_the_pattern
    clouds = Clouds.new(1337)
    clouds.build(40 * Clouds::CELL + 1.0, -70 * Clouds::CELL + 1.0, 0.0)
    uniforms = Array.new(16, 0.0)
    clouds.write_uniforms(uniforms, 8, 0.0, 0.0)
    i0, j0, i1, j1 = uniforms[12, 4]
    boxed_cells(clouds, 40, -70).each do |i, j|
      assert_includes i0..i1, i
      assert_includes j0..j1, j
    end
    assert_operator i1 - i0, :<, Clouds::GRID
    assert_operator j1 - j0, :<, Clouds::GRID
  end

  def test_the_tops_and_the_bottoms_of_the_boxes_cover_the_boxed_cells
    clouds = Clouds.new(1337)
    clouds.build(0.0, 0.0, 0.0)
    boxed = boxed_cells(clouds, 0, 0)
    assert_equal boxed, flat_cells(clouds.mesh, Clouds::HEIGHT + Clouds::DEPTH)
    assert_equal boxed, flat_cells(clouds.mesh, Clouds::HEIGHT)
  end

  def test_the_boxes_have_a_wall_only_where_a_boxed_cell_meets_a_cell_with_no_box
    clouds = Clouds.new(1337)
    clouds.build(0.0, 0.0, 0.0)
    walls = boxed_cells(clouds, 0, 0).flat_map do |i, j|
      [[1, 0, :x, i + 1, j], [-1, 0, :x, i, j], [0, 1, :z, j + 1, i], [0, -1, :z, j, i]].filter_map do |di, dj, *wall|
        wall unless clouds.boxed?(i + di, j + dj)
      end
    end
    assert_equal walls.sort, wall_edges(clouds.mesh)
  end

  private

  def vertices(mesh) = mesh.v.each_slice(VERTEX).to_a

  def faces(mesh) = vertices(mesh).each_slice(6).to_a

  # The first and the last cell edge that face spans along axis (0 for x,
  # 2 for z).
  def cell_span(face, axis) = face.map { |vertex| (vertex[axis] / Clouds::CELL).round }.minmax

  def neighbors(i, j) = [[i + 1, j], [i - 1, j], [i, j + 1], [i, j - 1]]

  def distance(i, j, ci, cj) = [(i - ci).abs, (j - cj).abs].max

  # The cells with a box in the square that can have them around (ci, cj).
  def boxed_cells(clouds, ci, cj)
    reach = Clouds::REACH
    (ci - reach..ci + reach).to_a.product((cj - reach..cj + reach).to_a).select { |i, j| clouds.boxed?(i, j) }
  end

  # The boxed cells that a cloud joins to a cloud cell within NEAR of (ci, cj).
  def near_clouds(clouds, ci, cj)
    near = Clouds::NEAR
    found = (ci - near..ci + near).to_a.product((cj - near..cj + near).to_a).select { |i, j| clouds.cloud?(i, j) }
    seen = found.to_h { |cell| [cell, true] }
    until found.empty?
      neighbors(*found.pop).each do |cell|
        next if seen[cell] || !clouds.boxed?(*cell)

        seen[cell] = true
        found << cell
      end
    end
    seen.keys.sort
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
