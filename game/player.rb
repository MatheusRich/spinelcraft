# The physics of the player and the raycast that finds the block in view.
class Player
  HALF = 0.3
  TALL = 1.8
  EYE = 1.62
  # A sneaking player's eyes are 0.35 lower. minecraft.wiki/w/Sneaking
  SNEAK_EYE = 1.27
  # How far the player reaches blocks, and mobs, in survival.
  # minecraft.wiki/w/Player
  REACH = 4.5
  MOB_REACH = 3.0
  # A step sound plays each time the player or a mob walks this far.
  STEP = 2.1

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :pitch, :flying, :on_ground, :in_water
  attr_writer :fall_start
  attr_reader :hit, :hx, :hy, :hz, :px, :py, :pz, :hit_t
  # True when the feet are in lava. in_water is true then too, because the
  # player moves the same way in both.
  attr_reader :in_lava
  # True while the player eats or draws the bow (Game#using_item?). The
  # player then moves at sneaking speed and cannot sprint.
  attr_writer :slowed
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
    @climbing = false
    @sprinting = false
    @eye = EYE
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

  # Puts the player at rest at x, y, z. A fall starts again from there.
  def move_to(x, y, z)
    @x = x
    @y = y
    @z = z
    @vx = 0.0
    @vy = 0.0
    @vz = 0.0
    @fall_start = y
  end

  def eye_y = @y + @eye

  # True when an attack now is a critical hit, if the attack cooldown is
  # full enough: the player falls, and is not on a ladder, in water, flying
  # or sprinting. minecraft.wiki/w/Damage
  def falling_attack? = @vy < 0.0 && !@on_ground && !@climbing && !@in_water && !@flying && !@sprinting
  def fx = Math.sin(@yaw) * Math.cos(@pitch)
  def fy = Math.sin(@pitch)
  def fz = -Math.cos(@yaw) * Math.cos(@pitch)

  def look(dx, dy)
    @yaw += dx * 0.0025
    @pitch -= dy * 0.0025
    @pitch = @pitch.clamp(-1.55, 1.55)
  end

  # Speeds in blocks per second. minecraft.wiki/w/Transportation
  WALK = 4.317
  SPRINT = 5.612
  # Near the ground, flight is as fast as in Minecraft, so the player can
  # aim: 11 blocks per second, 22 in a sprint, and 7.49 up and down.
  # Higher up it gets faster, up to FLY_BOOST times as fast at FLY_HIGH
  # blocks above the ground, so the player can look around the world
  # quickly. The boost is a choice for Spinelcraft, and it does not copy
  # Minecraft.
  FLY = 11.0
  SPRINT_FLY = 22.0
  FLY_UP = 7.49
  FLY_BOOST = 8.0
  FLY_HIGH = 64.0
  # Swim speeds at the surface, under water, and in a sprint.
  SWIM = 2.2
  SWIM_UNDER = 1.97
  SWIM_SPRINT = 3.918
  # Lava keeps half of the horizontal speed each tick, and water keeps 0.8
  # (minecraft.wiki/w/Lava gives the half, but the wiki does not confirm
  # the 0.8). With the same push each tick, the player then swims in lava
  # 0.2 / 0.5 = 0.4 times as fast as in water, and cannot sprint there.
  LAVA = 0.4
  # Speeds on a ladder.
  CLIMB = 2.35
  SLIDE = 3.0
  # Sneaking scales the movement keys by this much, so a sneak moves at
  # 1.3 m/s straight and 1.83 m/s on a diagonal. A player who draws a bow
  # moves the same (minecraft.wiki/w/Bow). The wiki does not give the
  # speed for eating, so eating uses the same. minecraft.wiki/w/Transportation
  SNEAK = 0.3
  # Gravity in m/s per second, and the speed at which a fall stops getting
  # faster. minecraft.wiki/w/Entity
  GRAVITY = 32.0
  TERMINAL = 78.4
  # The jump speed. With this gravity and the step of 0.02 seconds, it
  # lifts the feet 1.2522 blocks. minecraft.wiki/w/Jumping
  JUMP = 8.96
  # The forward push of a sprint-jump. Sprint-jumps on flat ground then
  # move at 7.127 m/s on average. minecraft.wiki/w/Sprinting gives that
  # average, but not the push, so the push is tuned to the average.
  SPRINT_JUMP_PUSH = 3.46

  # How many times as fast as in Minecraft the player flies, at the height
  # of the player above the ground.
  def fly_boost(world)
    above = @y - world.height_at(@x.floor, @z.floor)
    1.0 + (FLY_BOOST - 1.0) * (above / FLY_HIGH).clamp(0.0, 1.0)
  end

  # Moves the player for one step of dt seconds and returns the fall
  # distance when it lands (0.0 otherwise).
  def update(world, dt, fwd, strafe, jump, down, sprint)
    feet = world.get(@x.floor, (@y + 0.4).floor, @z.floor)
    @in_lava = Block.lava?(feet)
    @in_water = Block.water?(feet) || @in_lava
    # The feet or the body in a ladder cell: the player climbs to the top.
    climbing = !@flying && (Block::BASE[world.get(@x.floor, @y.floor, @z.floor)] == Block::LADDER ||
                            Block::BASE[world.get(@x.floor, (@y + 1.0).floor, @z.floor)] == Block::LADDER)
    @climbing = climbing
    @sneaking = down && !@flying && @on_ground
    sprint = false if @sneaking || @slowed
    @sprinting = sprint
    # The eyes move down or up over about a tenth of a second.
    @eye += ((@sneaking ? SNEAK_EYE : EYE) - @eye) * (dt * 20.0).clamp(0.0, 1.0)
    @jumped = false
    # The swim speed holds while the feet are in the liquid, also when the
    # player bobs at the surface and only the feet are under it.
    low = world.get(@x.floor, @y.floor, @z.floor)
    boost = @flying ? fly_boost(world) : 1.0
    speed = if @flying
              (sprint ? SPRINT_FLY : FLY) * boost
            elsif @in_lava || Block.lava?(low)
              (Block.lava?(world.get(@x.floor, eye_y.floor, @z.floor)) ? SWIM_UNDER : SWIM) * LAVA
            elsif @in_water || Block.water?(low)
              under = Block.water?(world.get(@x.floor, eye_y.floor, @z.floor))
              sprint ? SWIM_SPRINT : (under ? SWIM_UNDER : SWIM)
            else
              sprint ? SPRINT : WALK
            end
    keys = @sneaking || @slowed ? SNEAK : 1.0
    sy = Math.sin(@yaw)
    cy = Math.cos(@yaw)
    wx = (sy * fwd + cy * strafe) * keys
    wz = (-cy * fwd + sy * strafe) * keys
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
      @vy += (target * FLY_UP * boost - @vy) * (10.0 * dt).clamp(0.0, 1.0)
    elsif climbing
      # Jump or forward climbs, Shift holds on, and nothing slides down.
      @vy = jump || fwd > 0.0 ? CLIMB : (down ? 0.0 : -SLIDE)
    elsif @in_water
      # The wiki does not give the speeds to swim up and to sink.
      @vy -= 10.0 * dt
      @vy = 3.2 if jump
      @vy = @vy.clamp(-4.0, 4.0)
      # Against a wall, a jump lifts the player over an edge as high as the water.
      @vy = 6.0 if jump && @against_wall
    else
      # The fall gets faster at GRAVITY, less so near TERMINAL.
      @vy -= GRAVITY * (1.0 + @vy / TERMINAL) * dt
      @jumped = jump && @on_ground
      if @jumped
        @vy = JUMP
        # A sprint-jump pushes the player forward.
        if sprint
          @vx += sy * SPRINT_JUMP_PUSH
          @vz -= cy * SPRINT_JUMP_PUSH
        end
      end
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
