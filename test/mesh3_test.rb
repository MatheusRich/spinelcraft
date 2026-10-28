require_relative "test_helper"

class Mesh3Test < Minitest::Test
  # The floats of one vertex: x y z, u v, layer, red green blue alpha, glow.
  VERTEX = 11
  FACE_VERTICES = 6
  COLOR = Color.new(0.5, 0.25, 1.0, 0.8)
  # The sides of a box, as side gives them: the axis, and 1 for the high side.
  SIDES = [[0, 0], [0, 1], [1, 0], [1, 1], [2, 0], [2, 1]]

  def setup
    @mesh = Mesh3.new
  end

  def test_a_box_has_six_faces_of_two_triangles
    @mesh.aabb(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Tex::WHITE, COLOR)
    assert_equal 6 * FACE_VERTICES, vertices.size
  end

  def test_the_top_of_a_box_has_its_color_and_the_sides_are_darker
    @mesh.aabb(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Tex::WHITE, COLOR)
    top = faces[2]
    assert_equal [[0.5, 0.25, 1.0, 0.8]], top.map { |vertex| vertex[6, 4] }.uniq
    (faces - [top]).each do |face|
      red, green, blue, alpha = face.first[6, 4]
      assert_operator red, :<, 0.5
      assert_in_delta red * 2.0, green * 4.0, 1.0e-6
      assert_in_delta red * 2.0, blue, 1.0e-6
      assert_equal 0.8, alpha
    end
  end

  def test_a_box_with_a_skin_has_the_color_on_each_face
    @mesh.skin_box(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Tex::SKINS, 0.0, 0.0, 4.0, 4.0, 4.0, false, COLOR)
    assert_equal [[0.5, 0.25, 1.0, 0.8]], faces[2].map { |vertex| vertex[6, 4] }.uniq
    assert_equal [0.8], vertices.map { |vertex| vertex[9] }.uniq
  end

  def test_a_box_with_a_skin_in_a_frame_has_the_skin_and_the_color_on_each_face
    @mesh.set_frame(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    @mesh.frame_skin_box(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Tex::SKINS, 16.0, 16.0, 8.0, 12.0, 4.0, false, COLOR)
    assert_equal 6 * FACE_VERTICES, vertices.size
    assert_equal [[0.5, 0.25, 1.0, 0.8]], faces[2].map { |vertex| vertex[6, 4] }.uniq
    front = faces.find { |face| side(face, 0.5) == [2, 1] }
    assert_equal [20, 28, 20, 32], skin_rectangle(front)
  end

  def test_a_wall_has_its_color_on_each_vertex
    @mesh.wall(0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, Tex::RAIN, COLOR)
    assert_equal FACE_VERTICES, vertices.size
    assert_equal [[0.5, 0.25, 1.0, 0.8]], vertices.map { |vertex| vertex[6, 4] }.uniq
  end

  def test_a_billboard_has_its_color_on_each_vertex
    @mesh.billboard(0.0, 0.0, 0.0, 0.1, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, Tex::PUFF, COLOR)
    assert_equal FACE_VERTICES, vertices.size
    assert_equal [[0.5, 0.25, 1.0, 0.8]], vertices.map { |vertex| vertex[6, 4] }.uniq
  end

  def test_a_block_in_the_hand_is_not_tinted
    @mesh.set_frame(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    @mesh.item_model(Block::STONE)
    assert_equal [1.0], vertices.map { |vertex| vertex[9] }.uniq
    assert_equal [[1.0, 1.0, 1.0]], faces[2].map { |vertex| vertex[6, 3] }.uniq
  end

  def test_the_layers_of_a_box_follow_its_top_bottom_and_sides
    @mesh.set_frame(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    @mesh.frame_box(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 63, 10, 11, 12, COLOR)
    assert_equal([11, 11, 10, 12, 11, 11], faces.map { |face| face.first[5].to_i })
  end

  def test_a_box_draws_only_the_faces_of_its_mask
    @mesh.aabb_faces(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0b000100, Tex::WHITE, COLOR)
    assert_equal 1, faces.size
    @mesh.clear
    @mesh.aabb_faces(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, Tex::WHITE, COLOR)
    assert_empty vertices
    @mesh.aabb_faces(0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0b100001, Tex::WHITE, COLOR)
    assert_equal 2, faces.size
  end

  def test_a_block_on_a_body_has_a_layer_for_the_top_the_bottom_the_front_and_the_sides
    @mesh.block_box(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 10, 11, 12, 13, COLOR)
    assert_equal([11, 11, 10, 12, 13, 11], faces.map { |face| face.first[5].to_i })
    assert_equal [[0.5, 0.25, 1.0, 0.8]], faces[2].map { |vertex| vertex[6, 4] }.uniq
  end

  def test_a_furnace_in_the_hand_shows_its_front_on_the_face_that_looks_toward_the_view
    @mesh.set_frame(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    @mesh.item_model(Block::FURNACE)
    assert_equal SIDES, faces.map { |face| side(face) }.sort
    front = faces.find { |face| side(face) == [0, 0] }
    assert_equal [Block::FRONT[Block::FURNACE]], front.map { |vertex| vertex[5].to_i }.uniq
    assert_equal [1.0], vertices.map { |vertex| vertex[9] }.uniq
  end

  def test_a_chest_in_the_hand_has_the_shape_of_a_chest_and_shows_the_part_of_its_texture_that_it_covers
    @mesh.set_frame(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    @mesh.item_model(Block::CHEST)
    assert_equal SIDES, faces.map { |face| side(face) }.sort
    assert_equal [1.0], vertices.map { |vertex| vertex[9] }.uniq
    xs = vertices.map { |vertex| vertex[0] }
    assert_operator xs.max - xs.min, :<, 1.0
    layers = faces.to_h { |face| [side(face), face.first[5].to_i] }
    assert_equal Block::FRONT[Block::CHEST], layers[[0, 0]]
    assert_equal Block::TOP[Block::CHEST], layers[[1, 1]]
    assert_equal Block::BOTTOM[Block::CHEST], layers[[1, 0]]
    assert_equal Block::SIDE[Block::CHEST], layers[[0, 1]]
    faces.each do |face|
      axis, = side(face)
      across, down = [[2, 1], [0, 2], [0, 1]].fetch(axis)
      expected = face.map { |vertex| [(vertex[across] + 0.5).round(6), (axis == 1 ? vertex[down] + 0.5 : 0.5 - vertex[down]).round(6)] }
      assert_equal expected.uniq.sort, face.map { |vertex| [vertex[3].round(6), vertex[4].round(6)] }.uniq.sort
    end
  end

  def test_an_item_in_the_hand_is_a_thin_sprite
    @mesh.opaque = Array.new((Block::SIDE[Block::COAL] + 1) * 32, 0)
    @mesh.set_frame(0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    @mesh.item_model(Block::COAL)
    assert_equal [[2, 0], [2, 1]], faces.map { |face| side(face) }.sort
    assert_equal [Block::SIDE[Block::COAL]], vertices.map { |vertex| vertex[5].to_i }.uniq
    assert_equal [1.0], vertices.map { |vertex| vertex[9] }.uniq
    thickness = vertices.map { |vertex| vertex[2] }
    assert_in_delta Mesh3::ITEM_T * 2.0, thickness.max - thickness.min, 1.0e-6
  end

  def test_the_faces_of_a_skin_box_take_the_parts_of_the_skin_of_minecraft
    skin_box(16.0, 16.0, 8.0, 12.0, 4.0, false)
    assert_equal({ [0, 1] => [28, 32, 20, 32], [0, 0] => [16, 20, 20, 32],
                   [1, 1] => [20, 28, 16, 20], [1, 0] => [28, 36, 16, 20],
                   [2, 1] => [20, 28, 20, 32], [2, 0] => [32, 40, 20, 32] },
                 faces.to_h { |face| [side(face, 0.5), skin_rectangle(face)] })
  end

  def test_a_mirrored_skin_box_swaps_its_left_and_right_sides
    skin_box(16.0, 16.0, 8.0, 12.0, 4.0, true)
    assert_equal({ [0, 1] => [16, 20, 20, 32], [0, 0] => [28, 32, 20, 32],
                   [1, 1] => [20, 28, 16, 20], [1, 0] => [28, 36, 16, 20],
                   [2, 1] => [20, 28, 20, 32], [2, 0] => [32, 40, 20, 32] },
                 faces.to_h { |face| [side(face, 0.5), skin_rectangle(face)] })
  end

  # The front of a body is +z and its right is -x, so the skin of the front
  # runs along +x, and a mirror turns it around.
  def test_a_mirror_turns_the_skin_of_the_front_around
    skin_box(16.0, 16.0, 8.0, 12.0, 4.0, false)
    assert_equal [20, 28], front_us
    @mesh.clear
    skin_box(16.0, 16.0, 8.0, 12.0, 4.0, true)
    assert_equal [28, 20], front_us
  end

  def test_a_billboard_faces_the_camera_around_its_middle
    @mesh.billboard(1.0, 2.0, 3.0, 0.5, 1.0, 0.5, 0.0, 1.0, 0.25, 0.25, 0.5, 0.125, Tex::PUFF, COLOR)
    assert_equal([[0.5, 2.5, 2.875], [1.5, 2.5, 3.375], [1.5, 1.5, 3.125], [0.5, 2.5, 2.875], [1.5, 1.5, 3.125], [0.5, 1.5, 2.625]],
                 vertices.map { |vertex| vertex[0, 3] })
    assert_equal([[0.25, 0.5], [0.375, 0.5], [0.375, 0.625], [0.25, 0.5], [0.375, 0.625], [0.25, 0.625]],
                 vertices.map { |vertex| vertex[3, 2] })
  end

  def test_a_wall_goes_up_from_its_foot_and_along_the_texture
    @mesh.wall(0.0, 0.0, 2.0, 0.0, 1.0, 3.0, 4.0, 0.25, 0.75, Tex::RAIN, COLOR)
    assert_equal([[0.0, 3.0], [2.0, 3.0], [2.0, 1.0], [0.0, 3.0], [2.0, 1.0], [0.0, 1.0]], vertices.map { |vertex| [vertex[0], vertex[1]] })
    assert_equal([[0.0, 0.25], [4.0, 0.25], [4.0, 0.75], [0.0, 0.25], [4.0, 0.75], [0.0, 0.75]], vertices.map { |vertex| vertex[3, 2] })
  end

  private

  # The side of the box that a face lies on: the axis (0 x, 1 y, 2 z) on which
  # all its vertices have one place, and 1 when that place is above middle.
  def side(face, middle = 0.0)
    axis = (0..2).find { |a| face.map { |vertex| vertex[a] }.uniq.size == 1 }
    [axis, face.first[axis] > middle ? 1 : 0]
  end

  def front_us
    front = faces.find { |face| side(face, 0.5) == [2, 1] }
    front.select { |vertex| vertex[1] == 0.0 }.sort_by { |vertex| vertex[0] }.map { |vertex| (vertex[3] * 64.0).round }.uniq
  end

  def skin_box(u, v, width, height, depth, mirror)
    @mesh.skin_box(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, Tex::SKINS, u, v, width, height, depth, mirror, COLOR)
  end

  # The pixels of the skin that a face shows: the least and the most u, then the least and the most v.
  def skin_rectangle(face)
    us = face.map { |vertex| (vertex[3] * 64.0).round }
    vs = face.map { |vertex| (vertex[4] * 64.0).round }
    [us.min, us.max, vs.min, vs.max]
  end

  def vertices = @mesh.v.each_slice(VERTEX).to_a

  def faces = vertices.each_slice(FACE_VERTICES).to_a
end
