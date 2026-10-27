require_relative "test_helper"

class PlayerTest < Minitest::Test
  # Flight is as fast as in Minecraft at the ground, and gets faster up to
  # Player::FLY_BOOST times as fast at Player::FLY_HIGH above it.
  def test_flight_is_slow_near_the_ground_and_fast_high_above_it
    world = world_with_one_chunk
    ground = world.height_at(8, 8).to_f
    player = Player.new(8.5, ground, 8.5)
    assert_equal 1.0, player.fly_boost(world)
    player.y = ground + Player::FLY_HIGH / 2.0
    assert_equal (1.0 + Player::FLY_BOOST) / 2.0, player.fly_boost(world)
    player.y = ground + Player::FLY_HIGH * 2.0
    assert_equal Player::FLY_BOOST, player.fly_boost(world)
  end

  def test_the_speed_is_along_the_ground_only
    player = Player.new(0.5, SKY_Y.to_f, 0.5)
    player.vx = 3.0
    player.vy = -20.0
    player.vz = -4.0
    assert_equal 5.0, player.speed
  end

  def test_a_mob_hit_throws_the_player_away_from_the_mob_and_up
    player = Player.new(10.5, SKY_Y.to_f, 10.5)
    player.vx = 3.0
    player.vy = -2.0
    player.vz = -2.0
    player.knock_back(7.5, 14.5)
    assert_in_delta 3.0 / 5.0 * Player::KNOCK_SPEED, player.vx, 1.0e-9
    assert_in_delta(-4.0 / 5.0 * Player::KNOCK_SPEED, player.vz, 1.0e-9)
    assert_equal Player::KNOCK_LIFT, player.vy
  end

  # Closer than 0.001 blocks, the direction away from the mob is not
  # known, so the push to the side is only as large as the distance.
  def test_a_mob_hit_from_where_the_player_stands_throws_the_player_up
    player = Player.new(0.0, SKY_Y.to_f, 0.0)
    player.knock_back(-0.001, 0.0)
    assert_in_delta Player::KNOCK_SPEED, player.vx, 1.0e-9
    player.knock_back(-0.0009, 0.0)
    assert_in_delta 0.0009 * Player::KNOCK_SPEED, player.vx, 1.0e-9
    assert_equal 0.0, player.vz
    assert_equal Player::KNOCK_LIFT, player.vy
  end

  def test_a_rider_sits_at_the_seat_of_the_vehicle_and_does_not_fall_or_swim
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 9.5, 0.0)
    player = Player.new(0.5, SKY_Y.to_f, 0.5)
    player.vy = -5.0
    player.on_ground = true
    player.in_water = true
    player.seat_in(boat)
    assert_equal [8.5, SKY_Y + Boat::SEAT, 9.5], [player.x, player.y, player.z]
    assert_equal 0.0, player.vy
    refute player.on_ground
    refute player.in_water
  end

  def test_the_player_leaves_a_vehicle_on_the_side_that_they_face
    world = boat_world
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    player.yaw = Math::PI / 2.0
    player.leave(boat, world)
    assert_in_delta 8.5 + Boat::HALF + Player::HALF + Player::LEAVE_GAP, player.x, 0.0001
    assert_in_delta 8.5, player.z, 0.0001
    assert_equal SKY_Y.to_f, player.y
  end

  def test_the_player_leaves_to_the_right_when_the_way_ahead_is_blocked
    world = boat_world
    [9, 10].each { |x| 16.times { |z| 3.times { |up| world.set(x, SKY_Y + up, z, Block::STONE) } } }
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    player.yaw = Math::PI / 2.0
    player.leave(boat, world)
    assert_in_delta 8.5, player.x, 0.0001
    assert_in_delta 8.5 + Boat::HALF + Player::HALF + Player::LEAVE_GAP, player.z, 0.0001
  end

  def test_the_player_leaves_to_the_far_spot_when_the_near_one_has_no_ground
    world = boat_world
    world.set(9, SKY_Y - 1, 8, Block::AIR)
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    player.yaw = Math::PI / 2.0
    player.leave(boat, world)
    assert_in_delta 8.5 + Boat::HALF + Player::HALF + Player::LEAVE_GAP + 0.6, player.x, 0.0001
  end

  def test_the_player_facing_north_leaves_to_the_far_spot_ahead_and_then_to_the_right
    world = boat_world
    world.set(8, SKY_Y - 1, 7, Block::AIR)
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    reach = Boat::HALF + Player::HALF + Player::LEAVE_GAP
    player.leave(boat, world)
    assert_in_delta 8.5, player.x, 0.0001
    assert_in_delta 8.5 - reach - 0.6, player.z, 0.0001
    [6, 7].each { |z| 16.times { |x| 3.times { |up| world.set(x, SKY_Y + up, z, Block::STONE) } } }
    player.leave(boat, world)
    assert_in_delta 8.5 + reach, player.x, 0.0001
    assert_in_delta 8.5, player.z, 0.0001
  end

  def test_the_player_leaves_up_onto_a_bank_above_the_vehicle
    world = boat_world
    16.times { |z| world.set(9, SKY_Y, z, Block::STONE) }
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    player.yaw = Math::PI / 2.0
    player.leave(boat, world)
    assert_equal SKY_Y + 1.0, player.y
  end

  def test_the_player_leaves_to_the_sides_that_are_behind_the_view_last
    world = boat_world
    [9, 10].each { |x| 16.times { |z| 3.times { |up| world.set(x, SKY_Y + up, z, Block::STONE) } } }
    [9, 10].each { |z| 16.times { |x| 3.times { |up| world.set(x, SKY_Y + up, z, Block::STONE) } } }
    [6, 7].each { |z| 16.times { |x| 3.times { |up| world.set(x, SKY_Y + up, z, Block::STONE) } } }
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    player.yaw = Math::PI / 2.0
    player.leave(boat, world)
    assert_in_delta 8.5 - Boat::HALF - Player::HALF - Player::LEAVE_GAP, player.x, 0.0001
  end

  def test_the_player_stands_on_the_vehicle_when_no_side_has_room
    world = world_with_one_chunk
    boat = Boat.new(Block::OAK_BOAT, 8.5, SKY_Y.to_f, 8.5, 0.0)
    player = Player.new(8.5, SKY_Y.to_f, 8.5)
    player.leave(boat, world)
    assert_equal [8.5, SKY_Y + Boat::TALL, 8.5], [player.x, player.y, player.z]
  end

  # A stone floor at SKY_Y - 1, so the player stands at SKY_Y.
  def boat_world
    world = world_with_one_chunk
    16.times { |x| 16.times { |z| world.set(x, SKY_Y - 1, z, Block::STONE) } }
    world
  end
end
