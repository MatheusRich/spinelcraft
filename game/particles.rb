# Particles: block chips, flames, smoke and embers. Each one is a small
# square that faces the camera. Burning mobs, torches, lava and explosions
# make the flames and the smoke.
class Game
  # Particle kinds. Chips, embers and drops of rain fall; flames and smoke rise.
  CHIP = 0
  FLAME = 1
  SMOKE = 2
  EMBER = 3
  DROP = 4
  MAX_PARTICLES = 3000
  # Each second, the game looks at this many random blocks near the player
  # for torches and lava.
  SAMPLES_PER_SECOND = 18000.0
  SAMPLE_REACH = 10

  def spawn_particle(kind, x, y, z, vx, vy, vz, life, layer)
    return if @pt_life.size >= MAX_PARTICLES
    @pt_kind << kind
    @pt_x << x
    @pt_y << y
    @pt_z << z
    @pt_vx << vx
    @pt_vy << vy
    @pt_vz << vz
    @pt_life << life
    @pt_max << life
    @pt_layer << layer
  end

  # Chips of block b that fly out of the block cell x, y, z.
  def burst_particles(x, y, z, b)
    layer = Block::SIDE[b]
    i = 0
    while i < 12
      spawn_particle(CHIP, x + 0.2 + rand01 * 0.6, y + 0.2 + rand01 * 0.6, z + 0.2 + rand01 * 0.6,
                     (rand01 - 0.5) * 4.0, rand01 * 4.0 + 1.0, (rand01 - 0.5) * 4.0, 0.5 + rand01 * 0.4, layer)
      i += 1
    end
  end

  # Flames and smoke for dt seconds of a burning body: the box of half width
  # half and height tall on x, y, z.
  def emit_fire(x, y, z, half, tall, dt)
    n = (dt * 45.0 + rand01).to_i
    while n > 0
      spawn_particle(FLAME, x + (rand01 * 2.0 - 1.0) * half, y + rand01 * tall * 0.9, z + (rand01 * 2.0 - 1.0) * half,
                     (rand01 - 0.5) * 0.3, 0.6 + rand01 * 0.6, (rand01 - 0.5) * 0.3, 0.35 + rand01 * 0.35, Tex::FIRE)
      n -= 1
    end
    n = (dt * 6.0 + rand01).to_i
    while n > 0
      spawn_particle(SMOKE, x + (rand01 - 0.5) * half, y + tall * 0.8 + rand01 * 0.3, z + (rand01 - 0.5) * half,
                     (rand01 - 0.5) * 0.3, 0.7 + rand01 * 0.4, (rand01 - 0.5) * 0.3, 1.0 + rand01 * 0.8, Tex::PUFF)
      n -= 1
    end
  end

  # n puffs of smoke that spread from x, y, z, for an explosion or a burnt item.
  def smoke_puff(x, y, z, n, spread)
    while n > 0
      spawn_particle(SMOKE, x + (rand01 - 0.5) * spread, y + (rand01 - 0.5) * spread, z + (rand01 - 0.5) * spread,
                     (rand01 - 0.5) * spread * 2.0, rand01 * 1.5, (rand01 - 0.5) * spread * 2.0, 0.8 + rand01 * 1.0, Tex::PUFF)
      n -= 1
    end
  end

  # Looks at random blocks near the player: a torch gives a flame and smoke,
  # and lava under air throws an ember now and then.
  def sample_fire_blocks(dt)
    n = (dt * SAMPLES_PER_SECOND).to_i
    span = SAMPLE_REACH * 2 + 1
    px = @player.x.floor - SAMPLE_REACH
    py = @player.y.floor - SAMPLE_REACH
    pz = @player.z.floor - SAMPLE_REACH
    while n > 0
      x = px + (rand01 * span).to_i
      y = py + (rand01 * span).to_i
      z = pz + (rand01 * span).to_i
      b = @world.get(x, y, z)
      if b == Block::TORCH
        spawn_particle(FLAME, x + 0.5, y + 0.75, z + 0.5, 0.0, 0.25, 0.0, 0.3 + rand01 * 0.2, Tex::FIRE)
        if rand01 < 0.5
          spawn_particle(SMOKE, x + 0.5, y + 0.9, z + 0.5, (rand01 - 0.5) * 0.1, 0.5, (rand01 - 0.5) * 0.1, 0.8 + rand01 * 0.6, Tex::PUFF)
        end
      elsif b == Block::LAVA && rand01 < 0.05 && @world.get(x, y + 1, z) == Block::AIR
        spawn_particle(EMBER, x + rand01, y + 1.0, z + rand01, (rand01 - 0.5) * 2.0, 3.0 + rand01 * 2.0, (rand01 - 0.5) * 2.0, 1.2, Tex::WHITE)
      end
      n -= 1
    end
  end

  def update_particles(dt)
    i = 0
    while i < @pt_life.size
      @pt_life[i] -= dt
      kind = @pt_kind[i]
      if kind == CHIP || kind == EMBER || kind == DROP
        @pt_vy[i] -= (kind == EMBER ? 10.0 : 18.0) * dt
        nx = @pt_x[i] + @pt_vx[i] * dt
        ny = @pt_y[i] + @pt_vy[i] * dt
        nz = @pt_z[i] + @pt_vz[i] * dt
        if Block.solid?(@world.get(nx.floor, ny.floor, nz.floor))
          @pt_vx[i] *= 0.3
          @pt_vz[i] *= 0.3
          @pt_vy[i] = 0.0
        else
          @pt_x[i] = nx
          @pt_y[i] = ny
          @pt_z[i] = nz
        end
      else
        # Flames and smoke rise and slow down sideways.
        k = 1.0 - (2.0 * dt).clamp(0.0, 1.0)
        @pt_vx[i] *= k
        @pt_vz[i] *= k
        @pt_x[i] += @pt_vx[i] * dt
        @pt_y[i] += @pt_vy[i] * dt
        @pt_z[i] += @pt_vz[i] * dt
      end
      i += 1
    end
    remove_dead_particles
  end

  # Moves the live particles to the front, then cuts the dead ones off.
  def remove_dead_particles
    n = @pt_life.size
    w = 0
    i = 0
    while i < n
      if @pt_life[i] > 0.0
        if w != i
          @pt_kind[w] = @pt_kind[i]
          @pt_x[w] = @pt_x[i]
          @pt_y[w] = @pt_y[i]
          @pt_z[w] = @pt_z[i]
          @pt_vx[w] = @pt_vx[i]
          @pt_vy[w] = @pt_vy[i]
          @pt_vz[w] = @pt_vz[i]
          @pt_life[w] = @pt_life[i]
          @pt_max[w] = @pt_max[i]
          @pt_layer[w] = @pt_layer[i]
        end
        w += 1
      end
      i += 1
    end
    while @pt_life.size > w
      @pt_kind.pop
      @pt_x.pop
      @pt_y.pop
      @pt_z.pop
      @pt_vx.pop
      @pt_vy.pop
      @pt_vz.pop
      @pt_life.pop
      @pt_max.pop
      @pt_layer.pop
    end
  end

  # Adds the particles to @dyn as squares that face the camera, whose right
  # and up axes are (rx, 0, rz) and (ux, uy, uz).
  def draw_particles(rx, rz, ux, uy, uz)
    i = 0
    while i < @pt_life.size
      kind = @pt_kind[i]
      # t goes from 1 at birth to 0 at death.
      t = @pt_life[i] / @pt_max[i]
      x = @pt_x[i]
      y = @pt_y[i]
      z = @pt_z[i]
      if kind == CHIP
        @dyn.billboard(x, y, z, 0.07, rx, rz, ux, uy, uz, @pt_layer[i], 1.0, 1.0, 1.0, 1.0)
      elsif kind == FLAME
        @dyn.glow = 1.0
        @dyn.billboard(x, y, z, 0.04 + 0.12 * t, rx, rz, ux, uy, uz, Tex::FIRE, 1.0, 0.7 + 0.3 * t, 0.5 + 0.5 * t, 1.0)
        @dyn.glow = 0.0
      elsif kind == SMOKE
        c = 0.25 + 0.25 * t
        @dyn.billboard(x, y, z, 0.08 + 0.12 * (1.0 - t), rx, rz, ux, uy, uz, Tex::PUFF, c, c, c, 1.0)
      elsif kind == DROP
        @dyn.billboard(x, y, z, 0.035, rx, rz, ux, uy, uz, Tex::PUFF, 0.7, 0.78, 0.95, 1.0)
      else
        @dyn.glow = 1.0
        @dyn.billboard(x, y, z, 0.04, rx, rz, ux, uy, uz, Tex::WHITE, 1.0, 0.45 + 0.3 * t, 0.1, 1.0)
        @dyn.glow = 0.0
      end
      i += 1
    end
  end
end
