# Particles: block chips, flames, smoke and embers. Each one is a small
# square that faces the camera. Burning mobs, torches, lava and explosions
# make the flames and the smoke.
class Particle
  # Particle kinds. Chips, embers and drops of rain fall; flames and smoke rise.
  CHIP = 0
  FLAME = 1
  SMOKE = 2
  EMBER = 3
  DROP = 4

  attr_reader :kind

  def initialize(kind, x, y, z, vx, vy, vz, life, layer)
    @kind = kind
    @x = x
    @y = y
    @z = z
    @vx = vx
    @vy = vy
    @vz = vz
    @life = life
    @max = life
    @layer = layer
  end

  def alive? = @life > 0.0

  def update(world, dt)
    @life -= dt
    if @kind == FLAME || @kind == SMOKE
      # Flames and smoke rise and slow down sideways.
      k = 1.0 - (2.0 * dt).clamp(0.0, 1.0)
      @vx *= k
      @vz *= k
      @x += @vx * dt
      @y += @vy * dt
      @z += @vz * dt
    else
      @vy -= (@kind == EMBER ? 10.0 : 18.0) * dt
      nx = @x + @vx * dt
      ny = @y + @vy * dt
      nz = @z + @vz * dt
      if Block.solid?(world.get(nx.floor, ny.floor, nz.floor))
        @vx *= 0.3
        @vz *= 0.3
        @vy = 0.0
      else
        @x = nx
        @y = ny
        @z = nz
      end
    end
  end

  # Adds the particle to mesh as a square that faces the camera, whose right
  # and up axes are (rx, 0, rz) and (ux, uy, uz).
  def draw(mesh, rx, rz, ux, uy, uz)
    # t goes from 1 at birth to 0 at death.
    t = @life / @max
    case @kind
    when CHIP
      mesh.billboard(@x, @y, @z, 0.07, rx, rz, ux, uy, uz, @layer, 1.0, 1.0, 1.0, 1.0)
    when FLAME
      mesh.glow = 1.0
      mesh.billboard(@x, @y, @z, 0.04 + 0.12 * t, rx, rz, ux, uy, uz, Tex::FIRE, 1.0, 0.7 + 0.3 * t, 0.5 + 0.5 * t, 1.0)
      mesh.glow = 0.0
    when SMOKE
      c = 0.25 + 0.25 * t
      mesh.billboard(@x, @y, @z, 0.08 + 0.12 * (1.0 - t), rx, rz, ux, uy, uz, Tex::PUFF, c, c, c, 1.0)
    when DROP
      mesh.billboard(@x, @y, @z, 0.035, rx, rz, ux, uy, uz, Tex::PUFF, 0.7, 0.78, 0.95, 1.0)
    else
      mesh.glow = 1.0
      mesh.billboard(@x, @y, @z, 0.04, rx, rz, ux, uy, uz, Tex::WHITE, 1.0, 0.45 + 0.3 * t, 0.1, 1.0)
      mesh.glow = 0.0
    end
  end
end

class Particles
  MAX = 3000
  # Each second, sample_fire looks at this many random blocks near the player
  # for torches and lava.
  SAMPLES_PER_SECOND = 18000.0
  SAMPLE_REACH = 10

  def initialize(seed)
    @all = []
    @rng = Rng.new(seed)
  end

  def add(kind, x, y, z, vx, vy, vz, life, layer)
    @all << Particle.new(kind, x, y, z, vx, vy, vz, life, layer) if @all.size < MAX
  end

  def count(kind) = @all.count { |p| p.kind == kind }

  # Chips of block b that fly out of the block cell x, y, z.
  def burst(x, y, z, b)
    layer = Block::SIDE[b]
    12.times do
      add(Particle::CHIP, x + 0.2 + @rng.rand01 * 0.6, y + 0.2 + @rng.rand01 * 0.6, z + 0.2 + @rng.rand01 * 0.6,
          (@rng.rand01 - 0.5) * 4.0, @rng.rand01 * 4.0 + 1.0, (@rng.rand01 - 0.5) * 4.0, 0.5 + @rng.rand01 * 0.4, layer)
    end
  end

  # Flames and smoke for dt seconds of a burning body: the box of half width
  # half and height tall on x, y, z.
  def fire(x, y, z, half, tall, dt)
    (dt * 45.0 + @rng.rand01).to_i.times do
      add(Particle::FLAME, x + (@rng.rand01 * 2.0 - 1.0) * half, y + @rng.rand01 * tall * 0.9, z + (@rng.rand01 * 2.0 - 1.0) * half,
          (@rng.rand01 - 0.5) * 0.3, 0.6 + @rng.rand01 * 0.6, (@rng.rand01 - 0.5) * 0.3, 0.35 + @rng.rand01 * 0.35, Tex::FIRE)
    end
    (dt * 6.0 + @rng.rand01).to_i.times do
      add(Particle::SMOKE, x + (@rng.rand01 - 0.5) * half, y + tall * 0.8 + @rng.rand01 * 0.3, z + (@rng.rand01 - 0.5) * half,
          (@rng.rand01 - 0.5) * 0.3, 0.7 + @rng.rand01 * 0.4, (@rng.rand01 - 0.5) * 0.3, 1.0 + @rng.rand01 * 0.8, Tex::PUFF)
    end
  end

  # n puffs of smoke that spread from x, y, z, for an explosion or a burnt item.
  def smoke(x, y, z, n, spread)
    n.times do
      add(Particle::SMOKE, x + (@rng.rand01 - 0.5) * spread, y + (@rng.rand01 - 0.5) * spread, z + (@rng.rand01 - 0.5) * spread,
          (@rng.rand01 - 0.5) * spread * 2.0, @rng.rand01 * 1.5, (@rng.rand01 - 0.5) * spread * 2.0, 0.8 + @rng.rand01 * 1.0, Tex::PUFF)
    end
  end

  # Looks at random blocks near x, y, z: a torch gives a flame and smoke, and
  # lava under air throws an ember now and then.
  def sample_fire(world, x, y, z, dt)
    span = SAMPLE_REACH * 2 + 1
    sx = x.floor - SAMPLE_REACH
    sy = y.floor - SAMPLE_REACH
    sz = z.floor - SAMPLE_REACH
    (dt * SAMPLES_PER_SECOND).to_i.times do
      bx = sx + (@rng.rand01 * span).to_i
      by = sy + (@rng.rand01 * span).to_i
      bz = sz + (@rng.rand01 * span).to_i
      b = world.get(bx, by, bz)
      if b == Block::TORCH
        add(Particle::FLAME, bx + 0.5, by + 0.75, bz + 0.5, 0.0, 0.25, 0.0, 0.3 + @rng.rand01 * 0.2, Tex::FIRE)
        if @rng.rand01 < 0.5
          add(Particle::SMOKE, bx + 0.5, by + 0.9, bz + 0.5, (@rng.rand01 - 0.5) * 0.1, 0.5, (@rng.rand01 - 0.5) * 0.1, 0.8 + @rng.rand01 * 0.6, Tex::PUFF)
        end
      elsif b == Block::LAVA && @rng.rand01 < 0.05 && world.get(bx, by + 1, bz) == Block::AIR
        add(Particle::EMBER, bx + @rng.rand01, by + 1.0, bz + @rng.rand01, (@rng.rand01 - 0.5) * 2.0, 3.0 + @rng.rand01 * 2.0, (@rng.rand01 - 0.5) * 2.0, 1.2, Tex::WHITE)
      end
    end
  end

  def update(world, dt)
    @all.each { |p| p.update(world, dt) }
    @all.select!(&:alive?)
  end

  def draw(mesh, rx, rz, ux, uy, uz)
    @all.each { |p| p.draw(mesh, rx, rz, ux, uy, uz) }
  end
end
