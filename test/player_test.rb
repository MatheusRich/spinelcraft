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
end
