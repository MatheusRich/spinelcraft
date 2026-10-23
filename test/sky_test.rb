require_relative "test_helper"

class SkyTest < Minitest::Test
  W = 1280.0
  H = 720.0
  # The floats of one quad: 6 vertices of 9 floats.
  QUAD = 54

  def setup
    @clock = Clock.new(0.0, 0)
    @weather = Weather.new(1, false)
    @camera = Camera.new
    @sky = Sky.new(@clock, @weather, @camera)
  end

  # The camera at x, y, z looks along yaw and pitch; then the sky builds
  # for that view at the HUD scale.
  def build(yaw, pitch, x: 0.0, y: 64.0, z: 0.0, scale: 1.0)
    @camera.update_camera(x, y, z, yaw, pitch, W / H, 300.0, 0.6)
    @sky.build_sky(W, H, scale)
    quads
  end

  # Each quad as a Hash of what the screen shows: its corner, its center,
  # its width and height, its texture layer, its color and its alpha.
  def quads
    @sky.mesh.v.each_slice(QUAD).map do |v|
      width = v[9] - v[0]
      height = v[19] - v[1]
      { x: v[0], y: v[1], center: [v[0] + width / 2.0, v[1] + height / 2.0], size: width, height: height,
        layer: v[4].to_i, color: v[5, 3], alpha: v[8] }
    end
  end

  # A star is a square of 2 pixels at the HUD scale 1.
  def stars(shown, scale: 1.0) = shown.select { |quad| quad[:size] == 2.0 * scale }

  # The stars in the box from x0, y0 to x1, y1 on the screen.
  def stars_in(shown, x0, y0, x1, y1)
    stars(shown).select { |star| star[:x].between?(x0, x1) && star[:y].between?(y0, y1) }
  end

  # The yaw and the pitch that look straight along dx, dy, dz.
  def look_along(dx, dy, dz)
    [Math.atan2(dx, -dz), Math.asin(dy / Math.sqrt(dx * dx + dy * dy + dz * dz))]
  end

  # The direction of the sun at the time of day: it rises at +x and goes
  # over the sky a little to +z.
  def sun_direction(time)
    a = time * Math::PI * 2.0
    [Math.cos(a), Math.sin(a), 0.25]
  end

  # Toward +x, up at the morning sun.
  EAST = Math::PI / 2.0
  # Toward -x, away from the morning sun.
  WEST = -Math::PI / 2.0

  def test_the_morning_sun_shows_in_its_glow_where_the_camera_looks_at_it
    @clock.time_of_day = 0.08
    glow, sun = build(EAST, 0.45)
    assert_equal Tex::WHITE, sun[:layer]
    assert_equal [1.0, 0.95, 0.75], sun[:color]
    assert_equal 70.0, sun[:size]
    assert_equal 1.0, sun[:alpha]
    assert_in_delta 0.18, glow[:alpha], 1e-9
    assert sun[:x] > glow[:x]
    assert_equal 2, quads.size
  end

  def test_the_sun_does_not_show_when_the_camera_looks_away
    @clock.time_of_day = 0.08
    assert_empty build(WEST, 0.45)
  end

  def test_the_sun_shows_at_one_place_on_the_screen_from_each_eye
    @clock.time_of_day = 0.08
    near = build(EAST, 0.45)
    far = build(EAST, 0.45, x: 1000.0, y: 120.0, z: -500.0)
    assert_in_delta near[1][:x], far[1][:x], 1e-6
    assert_in_delta near[1][:y], far[1][:y], 1e-6
  end

  def test_the_sun_moves_up_the_screen_through_the_morning
    @clock.time_of_day = 0.06
    early = build(EAST, 0.45)[1]
    @clock.time_of_day = 0.08
    later = build(EAST, 0.45)[1]
    assert later[:y] < early[:y]
  end

  def test_the_sun_just_under_the_horizon_shows_and_lower_does_not
    @clock.time_of_day = 0.98
    assert_equal 70.0, build(EAST, 0.0)[1][:size]
    @clock.time_of_day = 0.9
    assert_empty(build(EAST, -0.6).reject { |quad| quad[:size] == 2.0 })
  end

  def test_rain_hides_the_sun
    @clock.time_of_day = 0.08
    @weather.set_now(true)
    assert_empty build(EAST, 0.45)
  end

  def test_the_full_moon_shows_at_midnight_with_the_stars
    @clock.time_of_day = 0.75
    shown = build(0.0, 1.3)
    moon = shown.find { |quad| quad[:layer] == Tex::MOON }
    assert moon
    assert_equal 1.0, moon[:alpha]
    assert_equal 46.0, moon[:size]
    assert_operator stars(shown).size, :>, 10
    assert(stars(shown).all? { |star| star[:alpha] == 1.0 })
  end

  def test_the_moon_shows_its_phase_and_a_glow_as_bright_as_its_lit_part
    @clock.time_of_day = 0.75
    @clock.day = 3
    shown = build(0.0, 1.3)
    moon_at = shown.index { |quad| quad[:layer] == Tex::MOON + 3 }
    assert moon_at
    assert_in_delta 0.18 * 0.25, shown[moon_at - 1][:alpha], 1e-9
  end

  def test_the_stars_fade_in_at_dusk
    @clock.time_of_day = 0.52
    dusk = stars(build(0.0, 1.3)).map { |star| star[:alpha] }.uniq
    assert_equal 1, dusk.size
    assert_in_delta @clock.starlight, dusk[0], 1e-9
    assert_operator dusk[0], :<, 0.5
  end

  def test_no_stars_show_by_day
    @clock.time_of_day = 0.25
    shown = build(0.0, 1.3)
    assert_equal 2, shown.size
    assert_empty stars(shown)
  end

  def test_the_stars_turn_with_the_time
    @clock.time_of_day = 0.75
    before = stars(build(0.0, 1.3)).map { |star| [star[:x], star[:y]] }
    @clock.time_of_day = 0.76
    after = stars(build(0.0, 1.3)).map { |star| [star[:x], star[:y]] }
    refute_equal before, after
  end

  def test_rain_hides_the_moon_and_the_stars
    @clock.time_of_day = 0.75
    @weather.set_now(true)
    assert_empty build(0.0, 1.3)
  end

  def test_each_build_starts_a_new_sky
    @clock.time_of_day = 0.75
    first = build(0.0, 1.3).size
    assert_equal first, build(0.0, 1.3).size
  end

  def test_the_sun_shows_at_the_center_of_the_screen_when_the_camera_looks_straight_at_it
    @clock.time_of_day = 0.08
    glow, sun = build(*look_along(*sun_direction(0.08)))
    assert_in_delta W / 2.0, sun[:center][0], 1e-6
    assert_in_delta H / 2.0, sun[:center][1], 1e-6
    assert_in_delta W / 2.0, glow[:center][0], 1e-6
    assert_in_delta H / 2.0, glow[:center][1], 1e-6
  end

  def test_the_moon_shows_at_the_center_of_the_screen_when_the_camera_looks_straight_at_it
    @clock.time_of_day = 0.7
    sun_x, sun_y, = sun_direction(0.7)
    moon = build(*look_along(-sun_x, -sun_y, 0.25)).find { |quad| quad[:size] == 46.0 }
    assert_in_delta W / 2.0, moon[:center][0], 1e-6
    assert_in_delta H / 2.0, moon[:center][1], 1e-6
  end

  def test_the_sun_and_its_glow_are_squares_that_grow_with_the_hud_scale
    @clock.time_of_day = 0.08
    glow, sun = build(EAST, 0.45, scale: 2.0)
    assert_equal [140.0, 140.0], [sun[:size], sun[:height]]
    assert_in_delta 196.0, glow[:size], 1e-9
    assert_in_delta 196.0, glow[:height], 1e-9
    assert_in_delta sun[:center][0], glow[:center][0], 1e-9
    assert_in_delta sun[:center][1], glow[:center][1], 1e-9
  end

  def test_half_rain_dims_the_sun_and_its_glow_by_half
    @clock.time_of_day = 0.08
    @weather.set(true)
    @weather.update_weather(Weather::FADE / 2.0)
    glow, sun = build(EAST, 0.45)
    assert_in_delta 0.5, sun[:alpha], 1e-9
    assert_in_delta 0.09, glow[:alpha], 1e-9
  end

  def test_the_stars_are_white_with_a_little_blue_and_of_many_brightnesses
    @clock.time_of_day = 0.75
    shown = stars(build(0.0, 1.3))
    reds = shown.map { |star| star[:color][0] }
    assert(reds.all? { |red| red >= 0.4 && red < 1.0 })
    assert_operator reds.max - reds.min, :>, 0.5
    assert(shown.all? { |star| (star[:color][2] - star[:color][0] * 1.05).abs < 1e-9 && star[:color][1] == star[:color][0] })
  end

  def test_the_stars_grow_with_the_hud_scale
    @clock.time_of_day = 0.75
    shown = build(0.0, 1.3, scale: 2.0)
    assert_operator stars(shown, scale: 2.0).size, :>, 10
    assert(stars(shown, scale: 2.0).all? { |star| (star[:height] - 4.0).abs < 1e-9 })
  end

  def test_the_stars_fill_the_night_sky_in_each_direction
    @clock.time_of_day = 0.75
    [0.0, EAST, Math::PI, WEST].each do |yaw|
      assert_operator stars_in(build(yaw, 0.4), 0.0, 0.0, W, H).size, :>=, 3, "yaw #{yaw}"
    end
    assert_operator stars_in(build(0.0, 1.5), 0.0, 0.0, W, H).size, :>=, 3
  end

  def test_no_star_shows_under_the_horizon
    @clock.time_of_day = 0.75
    assert_empty stars_in(build(0.0, -1.3), 0.0, 0.0, W, H)
  end

  # The stars turn around the z axis, and so does a camera that looks along
  # +x when its pitch changes. So a camera that turns with the sky sees
  # each star at one place on the screen.
  def test_the_stars_turn_with_the_sun_around_the_z_axis
    @clock.time_of_day = 0.70
    before = stars_in(build(EAST, 0.3), 100.0, 200.0, W - 100.0, 500.0).map { |star| star[:center] }
    @clock.time_of_day = 0.75
    after = stars_in(build(EAST, 0.3 + 0.05 * Math::PI * 2.0), 100.0, 200.0, W - 100.0, 500.0).map { |star| star[:center] }
    assert_operator before.size, :>=, 3
    assert_equal before.size, after.size
    before.sort.zip(after.sort).each do |(x0, y0), (x1, y1)|
      assert_in_delta x0, x1, 1e-6
      assert_in_delta y0, y1, 1e-6
    end
  end

  def test_the_sky_light_is_15_at_noon_7_at_tick_13200_4_at_midnight_and_12_in_rain
    assert_equal 15, light_at(6000)
    assert_equal 7, light_at(13200)
    assert_equal 4, light_at(18000)
    assert_equal 12, light_at(6000, raining: true)
  end

  def test_the_sky_light_goes_down_at_the_first_tick_of_each_level_and_up_at_dawn
    assert_equal 15, light_at(12040)
    assert_equal 14, light_at(12041)
    assert_equal 4, light_at(22330)
    assert_equal 5, light_at(22331)
    assert_equal 15, light_at(23961)
    assert_equal 15, light_at(0)
    assert_equal 4, light_at(13670, raining: true)
    assert_equal 12, light_at(23992, raining: true)
  end

  # In clear weather, minecraft.wiki/w/Daylight_cycle says that undead mobs
  # stop to burn at tick 12542 and begin to burn at tick 23460. These are
  # the ticks where the sky light goes below Monster::SUN_BURN_LIGHT and
  # back, as Game#sun_burns? reads it.
  def test_the_sky_light_crosses_the_sun_burn_light_at_the_ticks_of_the_wiki
    assert_operator light_at(12541), :>=, Monster::SUN_BURN_LIGHT
    assert_operator light_at(12542), :<, Monster::SUN_BURN_LIGHT
    assert_operator light_at(23459), :<, Monster::SUN_BURN_LIGHT
    assert_operator light_at(23460), :>=, Monster::SUN_BURN_LIGHT
  end

  # The sky light at the tick of the day, in rain or not.
  def light_at(tick, raining: false)
    @clock.set_ticks(tick)
    @weather.set_now(raining)
    @sky.light
  end


  def test_by_day_the_sky_is_blue
    red, green, blue = colors(6000)
    assert_operator blue, :>, green
    assert_operator green, :>, red
  end

  def test_at_night_the_sky_is_dark
    noon = colors(6000)
    colors(18000).each_with_index { |color, i| assert_operator color, :<, noon[i] / 3.0 }
  end

  # The colors of the sky are tuned by eye, and the wiki gives none. At
  # sunset the glow mixes three quarters of orange into the dusk sky, so
  # some of the blue still shows.
  def test_at_sunset_the_sky_glows_orange
    red, green, blue = colors(12000)
    assert_in_delta 0.82, red, 0.01
    assert_in_delta 0.51, green, 0.01
    assert_in_delta 0.32, blue, 0.01
  end

  def test_rain_grays_the_sky_with_a_hint_of_blue
    @weather.set_now(true)
    red, green, blue = colors(6000)
    assert_in_delta red, green, 0.05
    assert_operator blue - green, :>, 0.05
    assert_operator blue - red, :<, 0.15
    [red, green, blue].each { |color| assert_operator color, :>, 0.3 }
  end

  def test_rain_keeps_the_night_sky_dark
    @weather.set_now(true)
    colors(18000).each { |color| assert_operator color, :<, 0.3 }
  end

  def test_at_noon_the_daylight_is_full
    assert_in_delta 1.0, sky_uniforms(6000, 160.0)[4], 0.001
  end

  def test_rain_brings_the_fog_nearer_and_dims_the_daylight
    clear = sky_uniforms(6000, 160.0)
    @weather.set_now(true)
    rain = sky_uniforms(6000, 160.0)
    assert_in_delta 0.4 * clear[3], rain[3], 0.001
    assert_in_delta 0.65 * clear[4], rain[4], 0.001
  end

  # The fog starts 65 blocks before the end of a short view, and a quarter
  # of the view before the end of a long view.
  def test_the_fog_starts_before_the_end_of_the_view
    short = sky_uniforms(6000, 160.0)
    assert_in_delta 160.0, short[3], 0.001
    assert_in_delta 95.0, short[5], 0.001
    long = sky_uniforms(6000, 1600.0)
    assert_in_delta 1200.0, long[5], 0.001
  end

  def test_the_uniforms_go_at_their_place
    u = Array.new(10, -1.0)
    @clock.set_ticks(6000)
    @sky.write_uniforms(u, 3, 160.0)
    assert_equal [-1.0, -1.0, -1.0], u[0, 3]
    assert_equal [-1.0], u[9, 1]
  end

  # The 6 sky uniforms at the tick of the day, for a view of view blocks.
  def sky_uniforms(tick, view)
    @clock.set_ticks(tick)
    u = Array.new(6, 0.0)
    @sky.write_uniforms(u, 0, view)
    u
  end

  # The red, green and blue of the sky at the tick of the day.
  def colors(tick) = sky_uniforms(tick, 160.0)[0, 3]

end
