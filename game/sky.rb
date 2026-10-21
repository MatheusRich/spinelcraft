# The sky layer: the sun, the moon and the stars. Game draws it before the
# world, so the terrain and the clouds cover it. The colors of the sky and
# of the fog are uniforms (Game#set_uniforms).
class Sky
  STARS = 260

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
    night = @clock.starlight * (1.0 - @weather.rain)
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
    clear = 1.0 - @weather.rain
    return if clear <= 0.0

    @mesh.rect(sx - half * 1.4, sy - half * 1.4, half * 2.8, half * 2.8, r, g, b, 0.18 * clear * lit)
    @mesh.quad(sx - half, sy - half, half * 2.0, half * 2.0, layer, 1.0, 1.0, r, g, b, clear)
    nil
  end
end
