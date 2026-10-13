class Player
  HALF = 0.3
  TALL = 1.8
  EYE = 1.62
  REACH = 6.0

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :pitch, :flying, :on_ground, :in_water, :fall_start, :sneaking
  attr_reader :hit, :hx, :hy, :hz, :px, :py, :pz, :hit_t

  def initialize(x, y, z)
    @x = x
    @y = y
    @z = z
    @vx = 0.0
    @vy = 0.0
    @vz = 0.0
    @yaw = 0.0
    @pitch = 0.0
    @flying = false
    @sneaking = false
    @on_ground = false
    @in_water = false
    @fall_start = y
    @hit = false
    @hit_t = 0.0
    @hx = 0
    @hy = 0
    @hz = 0
    @px = 0
    @py = 0
    @pz = 0
  end

  def eye_y = @y + EYE
  def fx = Math.sin(@yaw) * Math.cos(@pitch)
  def fy = Math.sin(@pitch)
  def fz = -Math.cos(@yaw) * Math.cos(@pitch)

  def look(dx, dy)
    @yaw += dx * 0.0025
    @pitch -= dy * 0.0025
    @pitch = @pitch.clamp(-1.55, 1.55)
  end

  # Moves the player for one step of dt seconds and returns the fall
  # distance when it lands (0.0 otherwise).
  def update(world, dt, fwd, strafe, jump, down, sprint)
    feet = world.get(@x.floor, (@y + 0.4).floor, @z.floor)
    @in_water = Block.water?(feet) || Block.lava?(feet)
    @sneaking = down && !@flying && @on_ground
    speed = @flying ? (sprint ? 22.0 : 11.0) : (@sneaking ? 1.3 : (sprint ? 6.8 : 4.3))
    speed *= 0.55 if @in_water && !@flying
    sy = Math.sin(@yaw)
    cy = Math.cos(@yaw)
    wx = (sy * fwd + cy * strafe)
    wz = (-cy * fwd + sy * strafe)
    len = Math.sqrt(wx * wx + wz * wz)
    if len > 1.0
      wx /= len
      wz /= len
    end
    accel = @on_ground || @flying ? 14.0 : 4.0
    k = (accel * dt).clamp(0.0, 1.0)
    @vx += (wx * speed - @vx) * k
    @vz += (wz * speed - @vz) * k
    if @flying
      target = (jump ? 1.0 : 0.0) - (down ? 1.0 : 0.0)
      @vy += (target * speed - @vy) * (10.0 * dt).clamp(0.0, 1.0)
    elsif @in_water
      @vy -= 10.0 * dt
      @vy = 3.2 if jump
      @vy = @vy.clamp(-4.0, 4.0)
    else
      @vy -= 28.0 * dt
      @vy = 8.6 if jump && @on_ground
      @vy = -55.0 if @vy < -55.0
    end
    was_ground = @on_ground
    move(world, @vx * dt, @vy * dt, @vz * dt)
    landed = 0.0
    if @flying || @in_water || Block.water?(world.get(@x.floor, (@y + 0.4).floor, @z.floor))
      @fall_start = @y
    elsif !@on_ground
      @fall_start = @y if @y > @fall_start
    elsif !was_ground
      landed = @fall_start - @y
      @fall_start = @y
    else
      @fall_start = @y
    end
    if @y < -20.0
      @y = WY + 5.0
      @vy = 0.0
      @fall_start = @y
    end
    landed
  end

  def blocked?(world)
    x0 = (@x - HALF).floor
    x1 = (@x + HALF).floor
    y0 = @y.floor
    y1 = (@y + TALL).floor
    z0 = (@z - HALF).floor
    z1 = (@z + HALF).floor
    solid = Block::SOLID
    x = x0
    while x <= x1
      y = y0
      while y <= y1
        z = z0
        while z <= z1
          return true if solid[world.get(x, y, z)] == 1
          z += 1
        end
        y += 1
      end
      x += 1
    end
    false
  end

  def move(world, dx, dy, dz)
    # Inside a block (placed on us, or spawned in one): climb out instead of sliding.
    if blocked?(world)
      @y = @y.floor + 1.0
      @vy = 0.0
      return
    end
    if dx != 0.0
      @x += dx
      if blocked?(world)
        @x = dx > 0.0 ? (@x + HALF).floor - HALF - 0.001 : (@x - HALF).floor + 1.0 + HALF + 0.001
        @vx = 0.0
      elsif @sneaking && !ground_below?(world)
        # Sneaking never steps off an edge.
        @x -= dx
        @vx = 0.0
      end
    end
    if dz != 0.0
      @z += dz
      if blocked?(world)
        @z = dz > 0.0 ? (@z + HALF).floor - HALF - 0.001 : (@z - HALF).floor + 1.0 + HALF + 0.001
        @vz = 0.0
      elsif @sneaking && !ground_below?(world)
        @z -= dz
        @vz = 0.0
      end
    end
    @on_ground = false
    return if dy == 0.0
    @y += dy
    if blocked?(world)
      if dy < 0.0
        @y = @y.floor + 1.0
        @on_ground = true
      else
        @y = (@y + TALL).floor - TALL - 0.001
      end
      @vy = 0.0
    end
  end

  # True when a solid block lies under any part of the player's feet.
  def ground_below?(world)
    y = (@y - 0.05).floor
    x = (@x - HALF).floor
    while x <= (@x + HALF).floor
      z = (@z - HALF).floor
      while z <= (@z + HALF).floor
        return true if Block::SOLID[world.get(x, y, z)] == 1
        z += 1
      end
      x += 1
    end
    false
  end

  # True when the block cell at x, y, z overlaps the player's box.
  def overlaps?(bx, by, bz)
    bx + 1 > @x - HALF && bx < @x + HALF && by + 1 > @y && by < @y + TALL && bz + 1 > @z - HALF && bz < @z + HALF
  end

  # Voxel walk along the view ray. Sets hit, the hit cell, and the empty
  # cell in front of it.
  def raycast(world)
    ox = @x
    oy = eye_y
    oz = @z
    dx = fx
    dy = fy
    dz = fz
    ix = ox.floor
    iy = oy.floor
    iz = oz.floor
    step_x = dx > 0.0 ? 1 : -1
    step_y = dy > 0.0 ? 1 : -1
    step_z = dz > 0.0 ? 1 : -1
    tdx = dx == 0.0 ? 1.0e9 : (1.0 / dx).abs
    tdy = dy == 0.0 ? 1.0e9 : (1.0 / dy).abs
    tdz = dz == 0.0 ? 1.0e9 : (1.0 / dz).abs
    tmx = dx > 0.0 ? (ix + 1.0 - ox) * tdx : (ox - ix) * tdx
    tmy = dy > 0.0 ? (iy + 1.0 - oy) * tdy : (oy - iy) * tdy
    tmz = dz > 0.0 ? (iz + 1.0 - oz) * tdz : (oz - iz) * tdz
    @hit = false
    lx = ix
    ly = iy
    lz = iz
    t = 0.0
    while t <= REACH
      b = world.get(ix, iy, iz)
      if b != Block::AIR && !Block.water?(b) && !Block.lava?(b)
        @hit = true
        @hit_t = t
        @hx = ix
        @hy = iy
        @hz = iz
        @px = lx
        @py = ly
        @pz = lz
        return
      end
      lx = ix
      ly = iy
      lz = iz
      if tmx < tmy && tmx < tmz
        ix += step_x
        t = tmx
        tmx += tdx
      elsif tmy < tmz
        iy += step_y
        t = tmy
        tmy += tdy
      else
        iz += step_z
        t = tmz
        tmz += tdz
      end
    end
  end
end
