# The sky as it is now, from the time of day and the weather: the sky
# light for the rules of the game, and the sky layer with the sun, the
# moon and the stars. Game draws the layer before the world, so the
# terrain and the clouds cover it. The colors of the sky and of the fog
# are uniforms (Sky#write_uniforms).
class Sky
  STARS = 260
  # The sky light of Minecraft under the open sky by the time of day, in
  # clear weather and in rain. DUSK has the first tick of each level as it
  # goes down from the top level to 4, and DAWN the first tick of each level
  # as it goes up from 5 to the top level. A day has 24000 ticks, and tick
  # 6000 is noon. minecraft.wiki/w/Light
  TOP_CLEAR = 15
  DUSK_CLEAR = [12041, 12210, 12377, 12542, 12705, 12867, 13027, 13188, 13348, 13509, 13670]
  DAWN_CLEAR = [22331, 22492, 22653, 22813, 22974, 23135, 23297, 23460, 23624, 23791, 23961]
  TOP_RAIN = 12
  DUSK_RAIN = [12010, 12256, 12497, 12734, 12969, 13203, 13436, 13670]
  DAWN_RAIN = [22331, 22566, 22799, 23032, 23267, 23505, 23746, 23992]
  # A thunderstorm takes 10 from the sky light of a clear day for the spawn
  # of monsters, so they spawn by day. minecraft.wiki/w/Thunderstorm
  STORM_DARKEN = 10
  # A thunderstorm takes away 5/16 more of the daylight, as in Minecraft's
  # code (Level#getSkyDarken). The wiki does not give this value.
  STORM_DAYLIGHT = 5.0 / 16.0
  # The sky color that a lightning flash pulls the sky toward, a little
  # above full daylight. minecraft.wiki/w/Lightning
  # A thunderstorm makes the gray of rain darker by this share.
  STORM_GRAY = 0.5
  FLASH_RED = 0.85
  FLASH_GREEN = 0.88
  FLASH_BLUE = 1.0
  FLASH_LIGHT = 1.1

  # The quads of the sky, in pixels.
  attr_reader :mesh

  def initialize(clock, weather, camera)
    @clock = clock
    @weather = weather
    @camera = camera
    @mesh = Ui.new
    # Four values for each star: the direction x, y, z and the brightness.
    @stars = []
    make_stars
  end

  # The sky light under the open sky now, for the rules of the game: the
  # spawns of monsters, the spread of grass, the cave sounds, the bed and
  # the sun that burns undead mobs. It counts the levels of DUSK and DAWN
  # that the tick of the day has passed.
  def light
    tick = @clock.ticks
    raining = @weather.rain.on?
    dawn = raining ? DAWN_RAIN : DAWN_CLEAR
    return 4 + passed(dawn, tick) if tick >= dawn[0]
    return TOP_RAIN - passed(DUSK_RAIN, tick) if raining

    TOP_CLEAR - passed(DUSK_CLEAR, tick)
  end

  # The sky light under the open sky for the spawn of monsters. In a
  # thunderstorm it is at most the clear sky light of a day less
  # STORM_DARKEN, so the storm darkens the day and not the night.
  def spawn_light = @weather.striking? ? [light, TOP_CLEAR - STORM_DARKEN].min : light

  # How many ticks of ticks the tick has reached.
  def passed(ticks, tick) = ticks.count { |start| tick >= start }

  # Writes 6 uniforms at uniforms[at]: the red, green and blue of the sky,
  # the end of the fog for a view of view blocks, the daylight, and the
  # start of the fog. The sky is blue by day and dark at night, and it
  # glows orange at dusk and dawn. Rain grays the sky, dims the daylight,
  # and brings the fog nearer. A thunderstorm makes the gray darker, and a
  # lightning flash (from 0 to 1) lights the sky.
  def write_uniforms(uniforms, at, view, flash)
    day = @clock.daylight
    rain = @weather.rain.strength
    red = 0.03 + 0.50 * day
    green = 0.04 + 0.68 * day
    blue = 0.10 + 0.88 * day
    dusk = 1.0 - Math.sin(@clock.sun_angle).abs * 4.0
    if dusk > 0.0
      dusk *= 0.75
      red += (1.0 - red) * dusk
      green += (0.55 - green) * dusk
      blue += (0.25 - blue) * dusk
    end
    gray = 0.06 + 0.4 * day * (1.0 - STORM_GRAY * @weather.thunderstorm_strength)
    fog = view * (1.0 - 0.6 * rain)
    red += (gray - red) * rain * 0.85
    green += (gray - green) * rain * 0.85
    blue += (gray * 1.08 - blue) * rain * 0.85
    uniforms[at] = red + (FLASH_RED - red) * flash
    uniforms[at + 1] = green + (FLASH_GREEN - green) * flash
    uniforms[at + 2] = blue + (FLASH_BLUE - blue) * flash
    uniforms[at + 3] = fog
    light = day * (1.0 - 0.35 * rain) * (1.0 - STORM_DAYLIGHT * @weather.thunderstorm_strength)
    uniforms[at + 4] = light + (FLASH_LIGHT - light) * flash
    # Fog at the view's end starts 65 blocks before it, or a quarter of the
    # view before it for long views, so it blends with the haze.
    uniforms[at + 5] = fog - (fog * 0.25 > 65.0 ? fog * 0.25 : 65.0)
    nil
  end

  # The quads for a frame of w by h pixels, with the HUD scale s. The camera
  # must have the view of the frame.
  def build_sky(w, h, s)
    @mesh.clear
    draw_sky_body(w, h, s, 1.0, Tex::WHITE, 1.0, 0.95, 0.75, 70.0, 1.0)
    draw_sky_body(w, h, s, -1.0, Tex::MOON + @clock.moon_phase, 1.0, 1.0, 1.0, 46.0, @clock.moon_lit)
    draw_stars(w, h, s)
    nil
  end

  # Star directions on the upper sphere, fixed for the world.
  def make_stars
    rng = Rng.new(977)
    STARS.times do
      u = (rng.next_int % 10000) / 10000.0
      v = (rng.next_int % 10000) / 10000.0
      bright = 0.4 + (rng.next_int % 600) / 1000.0
      theta = u * 6.283185
      y = v * 1.6 - 0.6
      r = Math.sqrt(1.0 - y * y)
      @stars << r * Math.cos(theta) << y << r * Math.sin(theta) << bright
    end
    nil
  end

  # The stars at night. Rain hides them.
  def draw_stars(w, h, s)
    night = @clock.starlight * (1.0 - @weather.rain.strength)
    return if night <= 0.0

    a = @clock.sun_angle
    ca = Math.cos(a)
    sa = Math.sin(a)
    i = 0
    while i < @stars.size
      # The stars turn with the sun around the z axis.
      sx = @stars[i]
      sy = @stars[i + 1]
      rx = sx * ca - sy * sa
      ry = sx * sa + sy * ca
      if ry > -0.05
        if @camera.project_direction(rx, ry, @stars[i + 2], w, h)
          size = 2.0 * s
          c = @stars[i + 3]
          @mesh.rect(@camera.sx, @camera.sy, size, size, c, c, c * 1.05, night)
        end
      end
      i += 4
    end
    nil
  end

  # The sun (side 1) or the moon (side -1): the texture layer with the color
  # r, g, b, in a glow that is as bright as the lit part.
  def draw_sky_body(w, h, s, side, layer, r, g, b, size, lit)
    a = @clock.sun_angle
    dx = Math.cos(a) * side
    dy = Math.sin(a) * side
    return if dy < -0.15
    return unless @camera.project_direction(dx, dy, 0.25, w, h)

    half = size * s / 2.0
    sx = @camera.sx
    sy = @camera.sy
    # Rain hides the sun and the moon.
    clear = 1.0 - @weather.rain.strength
    return if clear <= 0.0

    @mesh.rect(sx - half * 1.4, sy - half * 1.4, half * 2.8, half * 2.8, r, g, b, 0.18 * clear * lit)
    @mesh.quad(sx - half, sy - half, half * 2.0, half * 2.0, layer, 1.0, 1.0, r, g, b, clear)
    nil
  end
end
