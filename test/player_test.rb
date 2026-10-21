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
