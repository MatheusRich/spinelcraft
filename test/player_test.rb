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

  def test_the_player_fits_dry_on_a_solid_block_with_room_and_no_water
    world = world_with_one_chunk
    world.set(8, SKY_Y - 1, 8, Block::STONE)
    player = Player.new(0.5, SKY_Y.to_f, 0.5)
    assert player.fits_dry?(world, 8.5, SKY_Y, 8.5)
    refute player.fits_dry?(world, 8.5, SKY_Y + 1, 8.5)
    world.set(8, SKY_Y + 1, 8, Block::STONE)
    refute player.fits_dry?(world, 8.5, SKY_Y, 8.5)
    world.set(8, SKY_Y + 1, 8, Block::AIR)
    world.set(8, SKY_Y, 8, Block::WATER)
    refute player.fits_dry?(world, 8.5, SKY_Y, 8.5)
  end
end
