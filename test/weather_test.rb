require_relative "test_helper"

class WeatherTest < Minitest::Test
  def setup
    @weather = Weather.new(1)
  end

  def test_the_rain_wets_once_it_is_stronger_than_half
    @weather.rain.start
    @weather.update_weather(Spell::FADE * 0.5)
    assert @weather.rain.on?
    refute @weather.wet_at?(LevelGround.new(11), 8.5, 8.5)
    @weather.update_weather(Spell::FADE * 0.1)
    assert @weather.wet_at?(LevelGround.new(11), 8.5, 8.5)
  end

  def test_snow_and_dry_land_do_not_wet_in_strong_rain
    @weather.rain.start.settle
    { [-70, -47] => true, [-70, -70] => false, [-8, 16] => false }.each do |(chunk_x, chunk_z), wet|
      x = chunk_x * 16 + 8.5
      z = chunk_z * 16 + 8.5
      assert_equal wet, @weather.wet_at?(World.new(1337), x, z)
    end
  end

  def test_a_position_wets_the_column_that_it_is_in_also_at_a_negative_x
    @weather.rain.start.settle
    world = World.new(1337)
    assert @weather.wet_at?(world, -1110.5, -499.5)
    refute @weather.wet_at?(world, -1109.5, -499.5)
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

  def test_snow_falls_as_snowflakes_and_rain_as_streaks_and_a_desert_stays_dry
    @weather.graphics = GraphicsMode::FAST
    @weather.rain.start.settle
    assert_equal [Tex::SNOWFLAKE_1, Tex::SNOWFLAKE_2], quad_layers(quads_over(-70, -70))
    assert_equal [Tex::RAIN], quad_layers(quads_over(-70, -47))
    assert_empty quads_over(-8, 16)
  end

  def test_the_snowflake_texture_repeats_more_often_down_a_column_than_the_streak_texture
    @weather.graphics = GraphicsMode::FAST
    @weather.rain.start.settle
    assert_in_delta 1 / 0.7, repeats_per_block(quads_over(-70, -70)), 1.0e-6
    assert_in_delta 1 / 4.0, repeats_per_block(quads_over(-70, -47)), 1.0e-6
  end

  def test_the_shader_finds_both_snowflake_layers_from_the_first_one
    assert_equal Tex::SNOWFLAKE_1 + 1, Tex::SNOWFLAKE_2
    assert_match(/\A#define SNOWFLAKE_FIRST #{Tex::SNOWFLAKE_1}\.0\n\z/, Weather.shader_defines)
  end

  def test_snow_and_dry_land_make_no_splash_and_no_rain_sound
    @weather.graphics = GraphicsMode::FAST
    @weather.rain.start.settle
    { [-70, -47] => true, [-70, -70] => false, [-8, 16] => false }.each do |(chunk_x, chunk_z), rains|
      world = chunk_world(chunk_x, chunk_z)
      player = player_over(world, chunk_x, chunk_z)
      particles = Particles.new(1)
      @weather.splash(particles, world, player, 1.0)
      assert_equal rains, particles.count(Particle::DROP).positive?
      assert_equal rains, @weather.sound(world, player).positive?
    end
  end

  def chunk_world(chunk_x, chunk_z)
    world = World.new(1337)
    world.load_chunk(chunk_x, chunk_z)
    world
  end

  def player_over(world, chunk_x, chunk_z)
    x = chunk_x * 16 + 8
    z = chunk_z * 16 + 8
    Player.new(x + 0.5, world.height_at(x, z).to_f, z + 0.5)
  end

  def quads_over(chunk_x, chunk_z)
    world = chunk_world(chunk_x, chunk_z)
    @weather.build_quads(world, player_over(world, chunk_x, chunk_z), 0.0)
    @weather.mesh.v.each_slice(11).to_a
  end

  def quad_layers(vertices) = vertices.map { |vertex| vertex[5].to_i }.uniq.sort

  def repeats_per_block(vertices)
    height = vertices[0][1] - vertices[2][1]
    (vertices[2][4] - vertices[0][4]) / height
  end

  def test_fast_graphics_make_a_smaller_rain_with_fewer_quads
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    @weather.rain.start.settle
    @weather.build_quads(world, player, 0.0)
    fancy_floats = @weather.mesh.count
    @weather.graphics = GraphicsMode::FAST
    assert_equal Weather::FAST_R, @weather.radius
    assert @weather.build_quads(world, player, 0.0)
    assert_operator @weather.mesh.count, :<, fancy_floats / 2
    farthest = @weather.mesh.v.each_slice(11).map { |vertex| [(vertex[0] - player.x).abs, (vertex[2] - player.z).abs].max }.max
    assert_operator farthest, :<=, Weather::FAST_R + 1.0
  end

  def test_a_change_of_the_graphics_mode_makes_the_quads_again_where_the_player_stands
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    @weather.rain.start.settle
    @weather.build_quads(world, player, 0.0)
    refute @weather.build_quads(world, player, 0.0)
    @weather.graphics = GraphicsMode::FAST
    assert @weather.build_quads(world, player, 0.0)
  end

  def test_fast_graphics_splash_fewer_drops
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    drops = [GraphicsMode::FANCY, GraphicsMode::FAST].map do |mode|
      weather = Weather.new(1)
      weather.graphics = mode
      weather.rain.start.settle
      particles = Particles.new(1)
      weather.splash(particles, world, player, 1.0)
      particles.count(Particle::DROP)
    end
    assert_operator drops[1], :<, drops[0]
    assert_operator drops[1], :>, 0
  end

  # The drops that a Weather gives to its particles, with where they fall.
  class DropRecorder
    attr_reader :spots

    def initialize
      @spots = []
    end

    def add(_kind, x, _y, z, *_motion)
      @spots << [x, z]
    end
  end

  class LevelGround
    def initialize(height)
      @height = height
    end

    def height_at(_x, _z) = @height
    def precipitation(_x, _z) = Biome::RAIN
  end

  def splash_spots(mode)
    weather = Weather.new(1)
    weather.graphics = mode
    weather.rain.start.settle
    recorder = DropRecorder.new
    weather.splash(recorder, LevelGround.new(11), Player.new(8.5, 10.0, 8.5), 1.0)
    recorder.spots
  end

  def test_drops_land_only_on_ground_from_8_blocks_below_to_6_blocks_above_the_player
    @weather.rain.start.settle
    { -50 => false, 2 => false, 3 => true, 15 => true, 16 => false, 100 => false }.each do |ground, lands|
      recorder = DropRecorder.new
      @weather.splash(recorder, LevelGround.new(ground), Player.new(8.5, 10.0, 8.5), 1.0)
      assert_equal lands, recorder.spots.any?, "ground at #{ground}"
    end
  end

  # Each axis of the drops stays within reach of the player and goes out to
  # both sides of the player, close to reach.
  def assert_spread(spots, reach)
    [0, 1].each do |axis|
      offsets = spots.map { |spot| spot[axis] - 8.5 }
      assert_operator offsets.map(&:abs).max, :<=, reach
      assert_operator offsets.max, :>, reach * 0.6
      assert_operator offsets.min, :<, -reach * 0.6
    end
  end

  def test_a_second_of_full_rain_splashes_90_drops_within_8_blocks_of_the_player
    spots = splash_spots(GraphicsMode::FANCY)
    assert_equal 90, spots.size
    assert_spread spots, 8.0
  end

  def test_fast_graphics_splash_the_same_drops_in_each_block_over_a_smaller_circle
    spots = splash_spots(GraphicsMode::FAST)
    assert_includes [32, 33], spots.size
    assert_spread spots, Weather::FAST_R * Weather::SPLASH_REACH
  end

  def rain_columns(mode)
    world = world_with_one_chunk
    player = Player.new(8.5, world.height_at(8, 8).to_f, 8.5)
    @weather.graphics = mode
    @weather.rain.start.settle
    @weather.build_quads(world, player, 0.0)
    @weather.mesh.v.each_slice(11).each_slice(12).map { |wall| [wall[0][0].to_i - 8, wall[0][2].to_i - 8] }
  end

  def test_the_rain_falls_in_the_columns_of_a_circle_that_includes_its_edge
    [GraphicsMode::FANCY, GraphicsMode::FAST].each do |mode|
      radius = mode.rain_radius
      circle = (-radius..radius).to_a.product((-radius..radius).to_a).select { |dx, dz| dx * dx + dz * dz <= radius * radius }
      assert_equal circle.sort, rain_columns(mode).sort, mode.name
    end
  end
end
