# The physics of the player and the raycast that finds the block in view.
class Player
  HALF = 0.3
  TALL = 1.8
  EYE = 1.62
  # How far the player reaches blocks, and mobs, in survival.
  # minecraft.wiki/w/Player
  REACH = 4.5
  MOB_REACH = 3.0
  # A step sound plays each time the player or a mob walks this far.
  STEP = 2.1

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :pitch, :flying, :on_ground, :in_water, :fall_start, :sneaking
  attr_reader :hit, :hx, :hy, :hz, :px, :py, :pz, :hit_t
  # True when the feet are in lava. in_water is true then too, because the
  # player moves the same way in both.
  attr_reader :in_lava
  # True while the player eats or draws the bow (Game#using_item?). The
  # player then moves at sneaking speed and cannot sprint.
  attr_accessor :slowed
  # True when the last step started a jump.
  attr_reader :jumped

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
    @in_lava = false
    @slowed = false
    # True when the last step ran into a wall in x or z.
    @against_wall = false
    @jumped = false
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

  # Speeds on a ladder, in blocks per second.
  CLIMB = 3.0
  SLIDE = 2.0
  # The jump speed. With the gravity of 28 and the step of 0.02 seconds,
  # it lifts the feet 1.2522 blocks. minecraft.wiki/w/Jumping
  JUMP = 8.1
  # The forward push of a sprint-jump. Sprint-jumps on flat ground then
  # move at 7.127 m/s on average. minecraft.wiki/w/Sprinting gives that
  # average, but not the push, so the push is tuned to the average.
  SPRINT_JUMP_PUSH = 3.7

  # Moves the player for one step of dt seconds and returns the fall
  # distance when it lands (0.0 otherwise).
  def update(world, dt, fwd, strafe, jump, down, sprint)
    feet = world.get(@x.floor, (@y + 0.4).floor, @z.floor)
    @in_lava = Block.lava?(feet)
    @in_water = Block.water?(feet) || @in_lava
    # The feet or the body in a ladder cell: the player climbs to the top.
    climbing = !@flying && (Block::BASE[world.get(@x.floor, @y.floor, @z.floor)] == Block::LADDER ||
                            Block::BASE[world.get(@x.floor, (@y + 1.0).floor, @z.floor)] == Block::LADDER)
    @sneaking = down && !@flying && @on_ground
    @jumped = false
    # Walk and sprint speeds: minecraft.wiki/w/Sprinting. A player who draws
    # a bow moves at sneaking speed (minecraft.wiki/w/Bow). The wiki does
    # not give the speed for eating, so eating uses the same.
    speed = @flying ? (sprint ? 22.0 : 11.0) : (@sneaking || @slowed ? 1.3 : (sprint ? 5.6 : 4.3))
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
    elsif climbing
      # Jump or forward climbs, Shift holds on, and nothing slides down.
      @vy = jump || fwd > 0.0 ? CLIMB : (down ? 0.0 : -SLIDE)
    elsif @in_water
      @vy -= 10.0 * dt
      @vy = 3.2 if jump
      @vy = @vy.clamp(-4.0, 4.0)
      # Against a wall, a jump lifts the player over an edge as high as the water.
      @vy = 6.0 if jump && @against_wall
    else
      @vy -= 28.0 * dt
      @jumped = jump && @on_ground
      if @jumped
        @vy = JUMP
        # A sprint-jump pushes the player forward.
        if sprint
          @vx += sy * SPRINT_JUMP_PUSH
          @vz -= cy * SPRINT_JUMP_PUSH
        end
      end
      @vy = -55.0 if @vy < -55.0
    end
    was_ground = @on_ground
    move(world, @vx * dt, @vy * dt, @vz * dt)
    landed = 0.0
    if @flying || @in_water || climbing || Block.water?(world.get(@x.floor, (@y + 0.4).floor, @z.floor))
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

  def blocked?(world) = world.solid_in_box?(@x, @y, @z, HALF, TALL)

  def move(world, dx, dy, dz)
    # Inside a block (placed on us, or spawned in one): climb out instead of sliding.
    if blocked?(world)
      @y = @y.floor + 1.0
      @vy = 0.0
      return
    end
    @against_wall = false
    if dx != 0.0
      @x += dx
      if blocked?(world)
        @x = world.box_edge(@x, @y, @z, HALF, TALL, 0, dx > 0.0 ? 1 : -1) + (dx > 0.0 ? -HALF - 0.001 : HALF + 0.001)
        @vx = 0.0
        @against_wall = true
      elsif @sneaking && !ground_below?(world)
        # Sneaking never steps off an edge.
        @x -= dx
        @vx = 0.0
      end
    end
    if dz != 0.0
      @z += dz
      if blocked?(world)
        @z = world.box_edge(@x, @y, @z, HALF, TALL, 2, dz > 0.0 ? 1 : -1) + (dz > 0.0 ? -HALF - 0.001 : HALF + 0.001)
        @vz = 0.0
        @against_wall = true
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
        @y = world.box_edge(@x, @y, @z, HALF, TALL, 1, -1)
        @on_ground = true
      else
        @y = world.box_edge(@x, @y, @z, HALF, TALL, 1, 1) - TALL - 0.001
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
        return true if Block.solid?(world.get(x, y, z))
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

  # True when the ray from o along d meets the box of b (Block.box_hx, box_hz
  # and box_top) in the cell ix, iy, iz within reach.
  def hits_box?(ox, oy, oz, dx, dy, dz, ix, iy, iz, b)
    hx = Block.box_hx(b)
    hz = Block.box_hz(b)
    x = ix + 0.5 + Block.box_dx(b)
    y = iy + Block.box_dy(b)
    z = iz + 0.5 + Block.box_dz(b)
    t = Ray.box_distance(ox, oy, oz, dx, dy, dz, x - hx, y, z - hz, x + hx, y + Block.box_top(b), z + hz)
    t >= 0.0 && t <= REACH
  end

  # Voxel walk along the view ray. Sets hit, the hit cell, and the empty
  # cell in front of it. The ray passes a plant when it misses its box.
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
      if b != Block::AIR && !Block.water?(b) && !Block.lava?(b) && (!(Block.plant?(b) || Block::SHAPE[b] > 0) || hits_box?(ox, oy, oz, dx, dy, dz, ix, iy, iz, b))
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
