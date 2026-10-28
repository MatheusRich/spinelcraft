require_relative "test_helper"

class WeatherTest < Minitest::Test
  def setup
    @weather = Weather.new(1)
  end

  def test_the_rain_wets_once_it_is_stronger_than_half
    @weather.rain.start
    @weather.update_weather(Spell::FADE * 0.5)
    assert @weather.rain.on?
    refute @weather.wet?
    @weather.update_weather(Spell::FADE * 0.1)
    assert @weather.wet?
  end

  def test_drops_splash_around_the_player_in_rain_and_not_when_dry
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    dry = Particles.new(1)
    @weather.splash(dry, world, player, 1.0)
    wet = Particles.new(1)
    rainy = Weather.new(1)
    rainy.rain.start.settle
    rainy.splash(wet, world, player, 1.0)
    assert_equal 0, dry.count(Particle::DROP)
    assert_operator wet.count(Particle::DROP), :>, 0
  end

  def test_rain_while_the_thunder_spell_is_on_is_a_storm_that_strikes_once_it_is_strong
    @weather.thunder.start.settle
    refute @weather.thunderstorm?
    @weather.rain.start
    assert @weather.thunderstorm?
    @weather.update_weather(Spell::FADE * 0.5)
    refute @weather.striking?
    @weather.update_weather(Spell::FADE * 0.5)
    assert @weather.striking?
  end

  def test_the_storm_is_never_stronger_than_the_rain
    @weather.rain.start.settle
    @weather.thunder.start.settle
    @weather.rain.stop
    @weather.update_weather(Spell::FADE * 0.5)
    assert_in_delta 0.5, @weather.rain.strength, 0.001
    assert_in_delta 0.5, @weather.thunderstorm_strength, 0.001
  end

  def test_the_spells_last_for_the_times_of_the_wiki
    @weather.thunder.start
    assert Weather::THUNDER_LASTS.cover?(@weather.thunder.timer)
    @weather.thunder.stop
    assert Weather::THUNDER_PAUSES.cover?(@weather.thunder.timer)
    @weather.rain.start
    assert Weather::RAIN_LASTS.cover?(@weather.rain.timer)
    @weather.rain.stop
    assert Weather::RAIN_PAUSES.cover?(@weather.rain.timer)
  end

  def test_clear_stops_the_rain_and_the_thunder_and_settle_makes_it_so_at_once
    @weather.rain.start.settle
    @weather.thunder.start.settle
    assert @weather.striking?
    @weather.clear
    refute @weather.rain.on?
    refute @weather.thunder.on?
    assert_equal 1.0, @weather.rain.strength
    @weather.settle
    assert_equal 0.0, @weather.rain.strength
    assert_equal 0.0, @weather.thunderstorm_strength
  end

  def test_the_save_fields_keep_both_spells
    @weather.rain.start
    @weather.rain.timer = 77.5
    @weather.thunder.start
    @weather.thunder.timer = 55.5
    other = Weather.new(2)
    assert_equal 4, other.load(@weather.to_a.map(&:to_s), 0)
    assert other.thunderstorm?
    assert_equal 77.5, other.rain.timer
    assert_equal 55.5, other.thunder.timer
    assert_equal 1.0, other.thunderstorm_strength
  end

  def test_rain_falls_in_two_crossed_streaks_in_each_column_around_the_player
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    @weather.rain.start.settle
    assert @weather.build_quads(world, player, 0.0)
    vertices = @weather.mesh.v.each_slice(11).to_a
    assert_equal 0, vertices.size % 12
    along, across = vertices.first(12).each_slice(6).to_a
    assert_equal [1.0, 1.0], [along[1][0] - along[0][0], along[1][2] - along[0][2]]
    assert_equal [-1.0, 1.0], [across[1][0] - across[0][0], across[1][2] - across[0][2]]
    assert_in_delta 0.5, across[0][4] - along[0][4], 1.0e-6
    assert_in_delta 0.5, across[2][4] - along[2][4], 1.0e-6
    assert_operator along[0][1], :>, along[2][1]
    color = along.first[6, 4]
    assert_operator color[3], :<, 1.0
    assert_operator color[2], :>, color[0]
  end
end
