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
end
