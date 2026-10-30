# Particles: block chips, flames, smoke, embers, effect specks, the
# sparks of a critical hit, the sparkles of bone meal, the hearts of
# animals in love and the cloud of an explosion. Each one is a square that
# faces the camera. Burning mobs, torches, lava and explosions make the
# flames and the smoke.
class Particle
  # Particle kinds. Chips, embers and drops of rain fall; flames, smoke and
  # effect specks rise; the sparks of a critical hit fly out and slow down.
  # The puffs of the cloud of an explosion stay in place and grow.
  CHIP = 0
  FLAME = 1
  SMOKE = 2
  EMBER = 3
  DROP = 4
  EFFECT = 5
  CRIT = 6
  GROWTH = 7
  HEART = 8
  BLAST = 9

  CHIP_COLOR = Color.new(0.6, 0.6, 0.6, 1.0)
  DROP_COLOR = Color.new(0.7, 0.78, 0.95, 1.0)
  # The green of the bone meal sparkle in VoxeLibre (#00EE00).
  GROWTH_COLOR = Color.new(0.0, 0.93, 0.0, 1.0)
  CRIT_COLOR = Color.new(0.85, 0.85, 0.8, 1.0)
  # The dull green #587653 of the Hunger effect. minecraft.wiki/w/Hunger_(effect)
  EFFECT_COLOR = Color.new(0.345, 0.463, 0.325, 1.0)
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
    # A chip shows the piece of its texture from (@u0, @v0), a quarter of the
    # texture wide, on a square of half size @half (see piece).
    @u0 = 0.0
    @v0 = 0.0
    @half = 0.07
  end

  def piece(u0, v0, half)
    @u0 = u0
    @v0 = v0
    @half = half
  end

  def alive? = @life > 0.0

  def update(world, dt)
    @life -= dt
    if @kind == FLAME || @kind == SMOKE || @kind == EFFECT || @kind == CRIT || @kind == GROWTH || @kind == HEART || @kind == BLAST
      # Flames, smoke and effect specks rise and slow down sideways. Sparks
      # slow down fast in all directions.
      k = 1.0 - ((@kind == CRIT ? 6.0 : 2.0) * dt).clamp(0.0, 1.0)
      @vx *= k
      @vz *= k
      @vy *= k if @kind == CRIT || @kind == GROWTH || @kind == HEART
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
  def draw(mesh, rx, rz, ux, uy, uz) # rubocop:todo Metrics/MethodLength
    # t goes from 1 at birth to 0 at death.
    t = @life / @max
    case @kind
    when CHIP
      mesh.billboard(@x, @y, @z, @half, rx, rz, ux, uy, uz, @u0, @v0, 0.25, @layer, CHIP_COLOR)
    when FLAME
      mesh.glow = 1.0
      mesh.billboard(@x, @y, @z, 0.04 + 0.12 * t, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::FIRE, Color.new(1.0, 0.7 + 0.3 * t, 0.5 + 0.5 * t, 1.0))
      mesh.glow = 0.0
    when SMOKE
      c = 0.25 + 0.25 * t
      mesh.billboard(@x, @y, @z, 0.08 + 0.12 * (1.0 - t), rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::PUFF, Color.new(c, c, c, 1.0))
    when DROP
      mesh.billboard(@x, @y, @z, 0.035, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::PUFF, DROP_COLOR)
    when GROWTH
      mesh.glow = 1.0
      mesh.billboard(@x, @y, @z, 0.02 + 0.03 * t, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::PUFF, GROWTH_COLOR)
      mesh.glow = 0.0
    when HEART
      # The heart of the HUD, whose icon fills the top left of its layer.
      mesh.billboard(@x, @y, @z, 0.12, rx, rz, ux, uy, uz, 0.0, 0.0, Tex::ICON_PART, Tex::HEART, Color::WHITE)
    when BLAST
      c = 0.55 + 0.45 * t
      mesh.billboard(@x, @y, @z, 1.5 - 0.75 * t, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::PUFF, Color.new(c, c, c, 1.0))
    when CRIT
      mesh.billboard(@x, @y, @z, 0.03 + 0.03 * t, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::PUFF, CRIT_COLOR)
    when EFFECT
      mesh.billboard(@x, @y, @z, 0.02, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::PUFF, EFFECT_COLOR)
    else
      mesh.glow = 1.0
      mesh.billboard(@x, @y, @z, 0.04, rx, rz, ux, uy, uz, 0.0, 0.0, 1.0, Tex::WHITE, Color.new(1.0, 0.45 + 0.3 * t, 0.1, 1.0))
      mesh.glow = 0.0
    end
    # A nil return keeps Spinel from boxing the value of each branch.
    nil
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

  # Chips of block that fly out of the block cell x, y, z. As in Minecraft,
  # they start on a grid of 4 x 4 x 4 points in the cell and fly away from its
  # middle, and each one shows a random piece of 4 x 4 pixels of the texture.
  def burst(x, y, z, block)
    layer = Block::SIDE[block]
    64.times do |i|
      dx = ((i & 3) + 0.5) / 4.0
      dy = (((i >> 2) & 3) + 0.5) / 4.0
      dz = ((i >> 4) + 0.5) / 4.0
      vx = dx - 0.5 + (@rng.rand01 - 0.5) * 0.8
      vy = dy - 0.5 + (@rng.rand01 - 0.5) * 0.8
      vz = dz - 0.5 + (@rng.rand01 - 0.5) * 0.8
      len = Math.sqrt(vx * vx + vy * vy + vz * vz)
      len = 1.0 if len < 0.001
      speed = (@rng.rand01 + @rng.rand01 + 1.0) * 1.2
      chip(x + dx, y + dy, z + dz, vx / len * speed, vy / len * speed + 2.0, vz / len * speed, layer)
    end
  end

  # Chips of the item block that fly from in front of the player when the item
  # breaks, or crumbs when the player eats it. As in Minecraft
  # (LivingEntity.spawnItemParticles, not on the wiki), 5 chips start 0.6
  # blocks ahead of the eyes and 0.3 to 0.9 blocks below them, and fly up
  # and a little to the sides.
  def shatter(player, block)
    cy = Math.cos(player.yaw)
    sy = Math.sin(player.yaw)
    cp = Math.cos(player.pitch)
    sp = Math.sin(player.pitch)
    # The right, up and forward axes of the view.
    ux = -sp * sy
    uz = sp * cy
    fx = sy * cp
    fz = -cy * cp
    5.times do
      side = (@rng.rand01 - 0.5) * 0.3
      down = -0.3 - @rng.rand01 * 0.6
      vside = (@rng.rand01 - 0.5) * 2.0
      vup = 2.0 + @rng.rand01 * 2.0
      chip(player.x + cy * side + ux * down + fx * 0.6, player.eye_y + cp * down + sp * 0.6,
           player.z + sy * side + uz * down + fz * 0.6, cy * vside + ux * vup, cp * vup + 1.0, sy * vside + uz * vup, Block::SIDE[block])
    end
  end

  # Chips of the item block at x, y, z that fly a little to each side, as when a
  # thrown egg breaks. Minecraft makes 8, with speeds of up to 0.04 blocks
  # each tick on each axis (ThrownEgg.handleEntityEvent, not on the wiki).
  def splat(x, y, z, block)
    8.times do
      chip(x, y, z, (@rng.rand01 - 0.5) * 1.6, (@rng.rand01 - 0.5) * 1.6 + 1.0, (@rng.rand01 - 0.5) * 1.6, Block::SIDE[block])
    end
  end

  # A chip that lives 0.3 to 1 second and shows a random piece of 4 x 4
  # pixels of the texture layer.
  def chip(x, y, z, vx, vy, vz, layer)
    return if @all.size >= MAX

    c = Particle.new(Particle::CHIP, x, y, z, vx, vy, vz, 0.3 + @rng.rand01 * 0.7, layer)
    c.piece((@rng.rand01 * 13.0).floor / 16.0, (@rng.rand01 * 13.0).floor / 16.0, 0.05 + @rng.rand01 * 0.05)
    @all << c
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

  # Specks of the Hunger effect for dt seconds in front of the player, who
  # looks along yaw with the eyes at x, eye_y, z. The view is first person
  # only, so the specks start where the player sees them: 0.4 to 0.7 blocks
  # ahead, at most 60 degrees to a side, from 0.8 below the eyes to 0.2
  # above. A speck closer to the camera covers much of the view. The wiki
  # gives no rate or life for effect particles, so about 10 each second
  # that live 0.4 to 2 seconds are a guess.
  def hunger(x, eye_y, z, yaw, dt)
    (dt * 10.0 + @rng.rand01).to_i.times do
      a = yaw + (@rng.rand01 - 0.5) * 2.0 * Math::PI / 3.0
      r = 0.4 + @rng.rand01 * 0.3
      add(Particle::EFFECT, x + Math.sin(a) * r, eye_y - 0.8 + @rng.rand01, z - Math.cos(a) * r,
          0.0, 0.1 + @rng.rand01 * 0.2, 0.0, 0.4 + @rng.rand01 * 1.6, Tex::PUFF)
    end
  end

  # The sparks of a critical hit, which fly out of the mob from x, y, z.
  # The wiki does not give their number or speed, so 16 that live up to
  # half a second are a guess.
  def crit(x, y, z)
    16.times do
      vx = @rng.rand01 * 2.0 - 1.0
      vy = @rng.rand01 * 2.0 - 1.0
      vz = @rng.rand01 * 2.0 - 1.0
      add(Particle::CRIT, x, y, z, vx * 4.0, vy * 4.0 + 1.0, vz * 4.0, 0.2 + @rng.rand01 * 0.3, Tex::PUFF)
    end
  end

  # The green sparkles of bone meal on the block cell x, y, z. As in
  # Minecraft (BoneMealItem.addGrowthParticles, not on the wiki), a plant
  # gets 15 in its cell, and a grass block 45 in the layer of cells above
  # it, 3 blocks out to each side. The life of 0.6 to 1.6 seconds is a guess.
  def growth(x, y, z, grass)
    n = grass ? 45 : 15
    spread = grass ? 3.0 : 0.0
    base = grass ? y + 1.0 : y.to_f
    n.times do
      add(Particle::GROWTH, x + 0.5 + (@rng.rand01 * 2.0 - 1.0) * (spread + 0.4), base + @rng.rand01 * 0.8,
          z + 0.5 + (@rng.rand01 * 2.0 - 1.0) * (spread + 0.4), (@rng.rand01 - 0.5) * 0.2, (@rng.rand01 - 0.5) * 0.2,
          (@rng.rand01 - 0.5) * 0.2, 0.6 + @rng.rand01, Tex::PUFF)
    end
  end

  # The 7 hearts of an animal that enters love mode or breeds, in the box
  # of half width half and height tall on x, y, z. They rise 0.5 above it
  # and live 16 ticks, as in the game code (Animal.handleEntityEvent and
  # HeartParticle); the wiki does not give these values.
  def hearts(x, y, z, half, tall)
    7.times { heart(x, y, z, half, tall) }
  end

  # One heart, as in hearts.
  def heart(x, y, z, half, tall)
    add(Particle::HEART, x + (@rng.rand01 * 2.0 - 1.0) * half, y + 0.5 + @rng.rand01 * tall, z + (@rng.rand01 * 2.0 - 1.0) * half,
        (@rng.rand01 - 0.5) * 0.4, 2.0, (@rng.rand01 - 0.5) * 0.4, 0.8, Tex::HEART)
  end

  # The cloud of an explosion at x, y, z: 48 puffs up to 4 blocks from x,
  # y, z along each axis, which last 0.3 to 0.8 seconds. Minecraft has the
  # same count and spread (HugeExplosionSeedParticle, not on the wiki). Its
  # puffs are 2 to 4 blocks wide, but its sprite does not fill its square.
  # A round PUFF does, so these puffs are 1.5 to 3 blocks wide.
  def blast(x, y, z)
    48.times do
      add(Particle::BLAST, x + (@rng.rand01 - @rng.rand01) * 4.0, y + (@rng.rand01 - @rng.rand01) * 4.0, z + (@rng.rand01 - @rng.rand01) * 4.0,
          0.0, 0.0, 0.0, 0.3 + @rng.rand01 * 0.5, Tex::PUFF)
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
  def sample_fire(world, x, y, z, dt) # rubocop:todo Metrics/MethodLength
    span = SAMPLE_REACH * 2 + 1
    sx = x.floor - SAMPLE_REACH
    sy = y.floor - SAMPLE_REACH
    sz = z.floor - SAMPLE_REACH
    (dt * SAMPLES_PER_SECOND).to_i.times do
      bx = sx + (@rng.rand01 * span).to_i
      by = sy + (@rng.rand01 * span).to_i
      bz = sz + (@rng.rand01 * span).to_i
      block = world.get(bx, by, bz)
      if Block.torch?(block)
        # The flame is at height 0.75 of the torch, and the smoke starts at 0.9.
        fx = bx + 0.5
        fy = by.to_f
        fz = bz + 0.5
        sx = fx
        sz = fz
        if Block.wall_torch?(block)
          # The torch leans toward its wall, behind its front.
          w = Block::FACING[block]
          fx -= Block::DIR_DX[w] * Block.wall_lean(0.75)
          fz -= Block::DIR_DZ[w] * Block.wall_lean(0.75)
          sx -= Block::DIR_DX[w] * Block.wall_lean(0.9)
          sz -= Block::DIR_DZ[w] * Block.wall_lean(0.9)
          fy += Block::WALL_LIFT
        end
        add(Particle::FLAME, fx, fy + 0.75, fz, 0.0, 0.25, 0.0, 0.3 + @rng.rand01 * 0.2, Tex::FIRE)
        if @rng.rand01 < 0.5
          add(Particle::SMOKE, sx, fy + 0.9, sz, (@rng.rand01 - 0.5) * 0.1, 0.5, (@rng.rand01 - 0.5) * 0.1, 0.8 + @rng.rand01 * 0.6, Tex::PUFF)
        end
      elsif block == Block::LAVA && @rng.rand01 < 0.05 && world.get(bx, by + 1, bz) == Block::AIR
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
