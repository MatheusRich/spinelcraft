require_relative "test_helper"

# A boat on a stone floor at SKY_Y. A yaw of 0 goes along -z, and a yaw of
# pi / 2 along +x.
class BoatTest < Minitest::Test
  DT = 1.0 / 60.0

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, SKY_Y - 1, z, Block::STONE) } }
  end

  # The south face of one wall is at z = 5, and the west face of the other
  # is at x = 12. The wall stops the speed of the boat.
  def test_a_boat_that_goes_into_a_wall_stops_against_it
    16.times { |k| @world.set(k, SKY_Y, 4, Block::STONE) }
    16.times { |k| @world.set(12, SKY_Y, k, Block::STONE) }
    north = Boat.new(Block::OAK_BOAT, 6.5, SKY_Y.to_f, 7.5, 0.0)
    east = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 10.5, Math::PI / 2.0)
    300.times do
      north.move_boat(@world, DT, 1.0, 0.0)
      east.move_boat(@world, DT, 1.0, 0.0)
    end
    assert_in_delta 5.0 + Boat::HALF, north.z, 0.002
    assert_in_delta 12.0 - Boat::HALF, east.x, 0.002
    assert_operator north.speed, :<, 0.5
    assert_operator east.speed, :<, 0.5
    assert_equal [SKY_Y.to_f, SKY_Y.to_f], [north.y, east.y]
  end

  # minecraft.wiki/w/Boat
  def test_a_boat_on_land_goes_up_to_2_m_per_s
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 14.5, 0.0)
    120.times { boat.move_boat(@world, DT, 1.0, 0.0) }
    assert_in_delta 2.0, boat.speed, 0.05
  end

  # In the air, the speed keeps AIR of itself each tick, as on water, so a
  # push gets the boat faster than on land.
  def test_a_boat_in_the_air_keeps_more_of_its_speed
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y + 60.0, 8.5, 0.0)
    30.times { boat.move_boat(@world, DT, 1.0, 0.0) }
    assert_operator boat.speed, :>, 4.0
  end

  def test_a_boat_lands_on_the_floor_and_falls_again_from_rest
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y + 2.0, 8.5, 0.0)
    60.times { boat.move_boat(@world, DT, 0.0, 0.0) }
    assert_equal SKY_Y.to_f, boat.y
    assert_equal 0.0, boat.speed
    16.times { |x| 16.times { |z| @world.set(x, SKY_Y - 1, z, Block::AIR) } }
    boat.move_boat(@world, DT, 0.0, 0.0)
    assert_operator boat.y, :>, SKY_Y - 0.01
  end

  def test_a_boat_is_drawn_as_nine_boxes_of_planks_with_six_different_faces
    mesh = Mesh3.new
    Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0).draw_boat(mesh)
    vertices = mesh.v.each_slice(11).to_a
    assert_equal 9 * 36, vertices.size
    assert_equal [Block::TOP[Block::PLANKS[0]]], vertices.map { |vertex| vertex[5].to_i }.uniq
    assert_equal [1.0], vertices.map { |vertex| vertex[9] }.uniq
    assert(vertices.all? { |vertex| vertex[6] == vertex[7] && vertex[7] == vertex[8] })
    vertices.each_slice(36) do |box|
      faces = box.each_slice(6).map { |face| face.map { |vertex| vertex[0, 3].map { |place| place.round(4) } }.uniq.sort }
      assert_equal 6, faces.uniq.size
    end
  end
end
