# Weather: spells of rain between dry spells. Rain grays the sky, dims the
# light, brings the fog nearer, puts out fires under the open sky, and
# splashes on the ground. The rain itself is streaks on crossed quads in
# the columns around the player; the vrain shader moves them down.
class Game
  # Rain falls in the columns within RAIN_R blocks of the player.
  RAIN_R = 10
  # Seconds that the rain takes to start or to stop.
  RAIN_FADE = 8.0

  def update_weather(dt)
    @weather_timer -= dt
    set_raining(!@raining) if @weather_timer <= 0.0
    step = dt / RAIN_FADE
    @rain = @raining ? (@rain + step).clamp(0.0, 1.0) : (@rain - step).clamp(0.0, 1.0)
    return if @rain <= 0.0
    rain_splashes(dt)
    @rain_sound -= dt
    if @rain_sound <= 0.0
      # The sound is 1.5 seconds long; the next one starts before it ends.
      # Under a roof it is quieter, and 10 blocks under the ground it stops.
      @rain_sound = 1.3
      cover = @world.height_at(@player.x.floor, @player.z.floor) - @player.eye_y
      play(Sfx::RAIN, (cover <= 0.0 ? 0.3 : (cover < 10.0 ? 0.1 : 0.0)) * @rain)
    end
  end

  # Starts or stops the rain, and sets how long the new weather lasts.
  def set_raining(on)
    @raining = on
    @weather_timer = on ? 120.0 + rand01 * 240.0 : 300.0 + rand01 * 600.0
  end

  # True when nothing above x, y, z stops the rain.
  def under_sky?(x, y, z) = @world.height_at(x.floor, z.floor) <= y.floor

  # Drops that splash on the ground around the player.
  def rain_splashes(dt)
    n = (dt * 90.0 * @rain + rand01).to_i
    while n > 0
      x = @player.x + (rand01 * 2.0 - 1.0) * 8.0
      z = @player.z + (rand01 * 2.0 - 1.0) * 8.0
      h = @world.height_at(x.floor, z.floor)
      if h > @player.y - 8.0 && h < @player.y + 6.0
        spawn_particle(DROP, x, h + 0.05, z, 0.0, 1.2 + rand01, 0.0, 0.2 + rand01 * 0.1, Tex::PUFF)
      end
      n -= 1
    end
  end

  # Makes the rain quads again when the player moves to another block, and
  # every second for the blocks that change. Returns true when it did.
  def build_rain(dt)
    @rain_age += dt
    return false if @rain <= 0.0
    cx = @player.x.floor
    cy = @player.y.floor
    cz = @player.z.floor
    return false if cx == @rain_x && cy == @rain_y && cz == @rain_z && @rain_age < 1.0
    @rain_x = cx
    @rain_y = cy
    @rain_z = cz
    @rain_age = 0.0
    mesh = @rain_mesh
    mesh.clear
    top = (cy + 14).to_f
    dx = -RAIN_R
    while dx <= RAIN_R
      dz = -RAIN_R
      while dz <= RAIN_R
        if dx * dx + dz * dz <= RAIN_R * RAIN_R
          x = cx + dx
          z = cz + dz
          ground = @world.height_at(x, z)
          bottom = (ground > cy - 10 ? ground : cy - 10).to_f
          if bottom < top
            # Each column starts its streaks at another place, so the
            # columns do not fall in step. The texture repeats twice across a
            # quad and every 4 blocks down.
            v0 = ((x * 73856093) ^ (z * 19349663)) % 1024 / 256.0
            v1 = v0 + (top - bottom) / 4.0
            fx = x.to_f
            fz = z.to_f
            mesh.wall(fx, fz, fx + 1.0, fz + 1.0, bottom, top, 2.0, v0, v1, Tex::RAIN, 0.75, 0.8, 0.95, 0.45)
            mesh.wall(fx + 1.0, fz, fx, fz + 1.0, bottom, top, 2.0, v0 + 0.5, v1 + 0.5, Tex::RAIN, 0.75, 0.8, 0.95, 0.45)
          end
        end
        dz += 1
      end
      dx += 1
    end
    true
  end
end
