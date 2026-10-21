require_relative "test_helper"

class WeatherTest < Minitest::Test
  def test_the_rain_wets_once_it_is_stronger_than_half
    weather = Weather.new(1, false)
    weather.set(true)
    weather.update_weather(Weather::FADE * 0.5)
    assert weather.raining?
    refute weather.wet?
    weather.update_weather(Weather::FADE * 0.1)
    assert weather.wet?
  end

  def test_drops_splash_around_the_player_in_rain_and_not_when_dry
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    dry = Particles.new(1)
    Weather.new(1, false).splash(dry, world, player, 1.0)
    wet = Particles.new(1)
    Weather.new(1, true).splash(wet, world, player, 1.0)
    assert_equal 0, dry.count(Particle::DROP)
    assert_operator wet.count(Particle::DROP), :>, 0
  end
end
