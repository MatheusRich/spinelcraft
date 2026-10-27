require_relative "test_helper"

class WeatherTest < Minitest::Test
  def test_the_rain_wets_once_it_is_stronger_than_half
    weather = Weather.new(1)
    weather.start_rain
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
    Weather.new(1).splash(dry, world, player, 1.0)
    wet = Particles.new(1)
    rainy = Weather.new(1)
    rainy.start_rain
    rainy.settle
    rainy.splash(wet, world, player, 1.0)
    assert_equal 0, dry.count(Particle::DROP)
    assert_operator wet.count(Particle::DROP), :>, 0
  end

  def test_rain_while_the_thunder_flag_is_on_is_a_storm_that_strikes_once_it_is_strong
    weather = Weather.new(1)
    weather.start_thunder
    refute weather.storm?
    weather.start_rain
    assert weather.storm?
    weather.update_weather(Weather::FADE * 0.5)
    refute weather.striking?
    weather.update_weather(Weather::FADE * 0.5)
    assert weather.striking?
  end

  def test_the_storm_is_never_stronger_than_the_rain
    weather = Weather.new(1)
    weather.start_rain
    weather.settle
    weather.start_thunder
    weather.settle
    weather.stop_rain
    weather.update_weather(Weather::FADE * 0.5)
    assert_in_delta 0.5, weather.thunder, 0.001
    assert_in_delta 0.5, weather.rain, 0.001
  end

  def test_the_thunder_flag_times_follow_the_wiki
    weather = Weather.new(1)
    weather.start_thunder
    assert_operator weather.thunder_timer, :>=, Weather::THUNDER_ON
    assert_operator weather.thunder_timer, :<=, Weather::THUNDER_ON + Weather::THUNDER_ON_SPAN
    weather.stop_thunder
    assert_operator weather.thunder_timer, :>=, Weather::THUNDER_OFF
    assert_operator weather.thunder_timer, :<=, Weather::THUNDER_OFF + Weather::THUNDER_OFF_SPAN
  end

  def test_the_thunder_flag_turns_over_when_its_timer_ends
    weather = Weather.new(1)
    weather.thunder_timer = 1.0
    weather.update_weather(1.5)
    assert weather.thundering?
  end

  def test_a_thunderstorm_set_now_is_at_full_strength
    weather = Weather.new(1)
    weather.start_rain
    weather.settle
    weather.start_thunder
    weather.settle
    assert_equal 1.0, weather.thunder
  end

  def test_clear_stops_the_rain_and_the_thunder_and_settle_makes_it_so_at_once
    weather = Weather.new(1)
    weather.start_rain
    weather.settle
    weather.start_thunder
    weather.settle
    assert weather.striking?
    weather.clear
    refute weather.raining?
    refute weather.thundering?
    assert_equal 1.0, weather.rain
    weather.settle
    assert_equal 0.0, weather.rain
    assert_equal 0.0, weather.thunder
  end

  def test_each_change_sets_the_time_that_the_new_weather_lasts
    weather = Weather.new(1)
    weather.start_rain
    assert_operator weather.timer, :>=, 120.0
    assert_operator weather.timer, :<=, 360.0
    weather.stop_rain
    assert_operator weather.timer, :>=, 300.0
    assert_operator weather.timer, :<=, 900.0
  end

  def test_start_storm_starts_the_rain_and_the_thunder
    weather = Weather.new(1)
    weather.start_storm
    assert weather.storm?
  end
end
