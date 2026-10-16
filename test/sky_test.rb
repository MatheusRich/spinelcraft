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
    assert_in_delta (0.55 - @clock.daylight) * 2.5, dusk[0], 1e-9
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
end
