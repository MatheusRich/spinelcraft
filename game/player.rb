# The player: how it walks, swims, climbs, flies and falls, and the health
# (Vitals) and the melee attack (MeleeAttack) that it owns. BlockTarget finds
# the block in view.
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
  # The speed away from a mob, and the speed up, that a hit from the mob
  # gives the player in survival. The wiki does not give these values.
  KNOCK_SPEED = 8.0
  KNOCK_LIFT = 5.0
  # The places where the player gets out of a vehicle (Player#leave), in the
  # order of the search: the turn from the view (ahead, right, left, then
  # behind), the extra distance from the vehicle, and the cells above the
  # base of the vehicle (a bank first, then its own cell, then two up).
  LEAVE_GAP = 0.1
  LEAVE_SIDE_TURNS = [0.0, Math::PI / 2.0, -Math::PI / 2.0, Math::PI]
  LEAVE_EXTRA_DISTANCES = [0.0, 0.6]
  LEAVE_HEIGHT_OFFSETS = [1, 0, 2]
  # The medium of the player (Player#medium_in), which decides how it
  # moves up and down, and whether a fall ends.
  FLYING = 0
  CLIMBING = 1
  SWIMMING = 2
  ON_LAND = 3

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :pitch, :flying, :on_ground, :in_water
  attr_writer :fall_start
  # True when the feet are in lava. in_water is true then too, because the
  # player moves the same way in both.
  attr_reader :in_lava
  # True while the player eats or draws the bow (Game#using_item?). The
  # player then moves at sneaking speed and cannot sprint.
  attr_writer :slowed
  # True when the last step started a jump.
  attr_reader :jumped
  # The keys that move the player (Controls).
  attr_reader :controls
  attr_reader :vitals, :melee_attack

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
    @medium = ON_LAND
    @sprinting = false
    @eye = EYE
    @controls = Controls.new
    @vitals = Vitals.new
    @melee_attack = MeleeAttack.new
    @fall_start = y
  end

  # Gives the player full health and hunger again.
  def revive
    @vitals = Vitals.new
    nil
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

  # The rider sits in the vehicle at its seat, and does not fall or swim.
  # A vehicle has x, y, z, half, tall and seat_height.
  def seat_in(vehicle)
    move_to(vehicle.x.to_f, vehicle.y.to_f + vehicle.seat_height, vehicle.z.to_f)
    @on_ground = false
    @in_water = false
    nil
  end

  # The player gets out on the side of the vehicle that they face, or else
  # on another side, on land when there is land. With no room on any side,
  # the player stands on the vehicle. minecraft.wiki/w/Boat
  def leave(vehicle, world)
    return nil if leave_on_side(vehicle, world)

    move_to(vehicle.x.to_f, vehicle.y.to_f + vehicle.tall, vehicle.z.to_f)
    nil
  end

  def eye_y = @y + @eye
  def half = HALF
  def tall = TALL

  # The speed along the ground: x and z, without the speed up or down.
  def speed = Math.sqrt(@vx * @vx + @vz * @vz)

  # A hit from a mob at from_x, from_z throws the player away from it and
  # up. The new speed takes the place of the old one. A mob that stands
  # where the player stands throws the player only up.
  def knock_back(from_x, from_z)
    dx = @x - from_x
    dz = @z - from_z
    len = Math.sqrt(dx * dx + dz * dz)
    len = 1.0 if len < 0.001
    @vx = dx / len * KNOCK_SPEED
    @vz = dz / len * KNOCK_SPEED
    @vy = KNOCK_LIFT
    nil
  end

  # True when an attack now is a critical hit, if the attack cooldown is
  # full enough: the player falls, and is not on a ladder, in water, flying
  # or sprinting. minecraft.wiki/w/Damage
  def falling_attack? = @vy < 0.0 && !@on_ground && @medium != CLIMBING && !@in_water && !@flying && !@sprinting
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
  def update(world, dt)
    sense(world)
    @sneaking = @controls.sneak && standing?
    @sprinting = @controls.sprint && !slow?
    ease_eyes(dt)
    @jumped = false
    boost = @flying ? fly_boost(world) : 1.0
    steer(dt, move_speed(world, boost))
    case @medium
    when FLYING then fly_up_down(dt, boost)
    when CLIMBING then climb
    when SWIMMING then swim(dt)
    else fall_or_jump(dt)
    end
    move_and_land(world, dt)
  end

  # Finds the medium of the player from the cells at its feet and its body.
  def sense(world)
    feet = world.get(@x.floor, (@y + 0.4).floor, @z.floor)
    @in_lava = Block.lava?(feet)
    @in_water = Block.water?(feet) || @in_lava
    @medium = medium_in(world)
  end

  # The medium decides how the player moves up and down: flight first,
  # then a ladder, then water or lava.
  def medium_in(world)
    return FLYING if @flying
    # The feet or the body in a ladder cell: the player climbs to the top.
    return CLIMBING if ladder_at?(world, @y) || ladder_at?(world, @y + 1.0)
    return SWIMMING if @in_water

    ON_LAND
  end

  def ladder_at?(world, y) = Block::BASE[world.get(@x.floor, y.floor, @z.floor)] == Block::LADDER

  # A sneak needs the ground.
  def standing? = @on_ground && !@flying

  # A player who sneaks, eats or draws the bow moves at the sneak speed,
  # and cannot sprint.
  def slow? = @sneaking || @slowed

  # The eyes move down or up over about a tenth of a second.
  def ease_eyes(dt)
    @eye += ((@sneaking ? SNEAK_EYE : EYE) - @eye) * (dt * 20.0).clamp(0.0, 1.0)
  end

  # The speed of a flight, a swim or a walk. The swim speed holds while the
  # feet are in the liquid, also when the player bobs at the surface and
  # only the feet are under it.
  def move_speed(world, boost)
    return (@sprinting ? SPRINT_FLY : FLY) * boost if @flying

    low = world.get(@x.floor, @y.floor, @z.floor)
    return lava_speed(world) if @in_lava || Block.lava?(low)
    return water_speed(world) if @in_water || Block.water?(low)
    return SPRINT if @sprinting

    WALK
  end

  def lava_speed(world) = (Block.lava?(at_eyes(world)) ? SWIM_UNDER : SWIM) * LAVA

  def water_speed(world)
    return SWIM_SPRINT if @sprinting
    return SWIM_UNDER if Block.water?(at_eyes(world))

    SWIM
  end

  # The block at the eyes.
  def at_eyes(world) = world.get(@x.floor, eye_y.floor, @z.floor)

  # The keys push the speed along the ground toward speed: forward along
  # the view, and strafe to the right of it. The ground and a flight give
  # more control than the air.
  def steer(dt, speed)
    fwd = @controls.forward
    strafe = @controls.strafe
    keys = slow? ? SNEAK : 1.0
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
    share = (accel * dt).clamp(0.0, 1.0)
    @vx += (wx * speed - @vx) * share
    @vz += (wz * speed - @vz) * share
    nil
  end

  # In a flight, jump flies up and sneak flies down.
  def fly_up_down(dt, boost)
    lift = (@controls.jump ? 1.0 : 0.0) - (@controls.sneak ? 1.0 : 0.0)
    @vy += (lift * FLY_UP * boost - @vy) * (10.0 * dt).clamp(0.0, 1.0)
    nil
  end

  def climb
    @vy = climb_speed
    nil
  end

  # Jump or forward climbs a ladder, sneak holds on, and nothing slides
  # down.
  def climb_speed
    return CLIMB if @controls.jump || @controls.forward > 0.0
    return 0.0 if @controls.sneak

    -SLIDE
  end

  # Jump swims up and nothing sinks. The wiki does not give the speeds to
  # swim up and to sink.
  def swim(dt)
    @vy = @controls.jump ? swim_up_speed : (@vy - 10.0 * dt).clamp(-4.0, 4.0)
    nil
  end

  # Against a wall, a jump lifts the player over an edge as high as the
  # water.
  def swim_up_speed = @against_wall ? 6.0 : 3.2

  # On land, the player falls, or jumps from the ground.
  def fall_or_jump(dt)
    # The fall gets faster at GRAVITY, less so near TERMINAL.
    @vy -= GRAVITY * (1.0 + @vy / TERMINAL) * dt
    @jumped = @controls.jump && @on_ground
    leap if @jumped
    nil
  end

  # A jump from the ground. A sprint-jump pushes the player forward.
  def leap
    @vy = JUMP
    if @sprinting
      @vx += Math.sin(@yaw) * SPRINT_JUMP_PUSH
      @vz -= Math.cos(@yaw) * SPRINT_JUMP_PUSH
    end
    nil
  end

  # Moves the player at its speed for dt seconds, and returns the fall
  # distance when it lands (0.0 otherwise). A flight, a ladder, water and
  # lava end a fall with no distance. A player under the world comes back
  # from the sky.
  def move_and_land(world, dt)
    was_ground = @on_ground
    move(world, @vx * dt, @vy * dt, @vz * dt)
    landed = 0.0
    if @medium != ON_LAND || Block.water?(world.get(@x.floor, (@y + 0.4).floor, @z.floor))
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

  # Moves the player by dx, dy, dz, up to the blocks on the way. A wall or
  # a floor stops the speed along its axis.
  def move(world, dx, dy, dz)
    # Inside a block (placed on us, or spawned in one): climb out instead of sliding.
    if blocked?(world)
      @y = @y.floor + 1.0
      @vy = 0.0
      return
    end
    @against_wall = false
    # to_f: Spinel cannot type the position and the speed of the player.
    x = slide(world, 0, dx.to_f)
    @vx = 0.0 if x != @x + dx
    @x = x
    z = slide(world, 2, dz.to_f)
    @vz = 0.0 if z != @z + dz
    @z = z
    y = world.collide(@x.to_f, @y.to_f, @z.to_f, HALF, TALL, 1, dy.to_f)
    @on_ground = dy < 0.0 && y != @y + dy
    @vy = 0.0 if y != @y + dy
    @y = y
  end

  # Where the player ends after a move of distance along the x axis (axis
  # 0) or the z axis (axis 2): against a wall, and in a sneak, not off an edge.
  def slide(world, axis, distance)
    # to_f: Spinel cannot type the position of the player.
    x = @x.to_f
    z = @z.to_f
    from = axis == 0 ? x : z
    to = world.collide(x, @y.to_f, z, HALF, TALL, axis, distance)
    if to != from + distance
      @against_wall = true
      return to
    end
    return from if @sneaking && !ground_below?(world, axis == 0 ? to : x, axis == 2 ? to : z)

    to
  end

  # Tries each side of the vehicle in the order of LEAVE_SIDE_TURNS. True
  # when the player got out.
  def leave_on_side(vehicle, world)
    LEAVE_SIDE_TURNS.each do |side_turn|
      return true if leave_at_distance(vehicle, world, @yaw + side_turn)
    end
    false
  end

  # Tries each distance on one side, from the one beside the vehicle to the
  # farthest. The direction is an angle of the view.
  def leave_at_distance(vehicle, world, direction)
    LEAVE_EXTRA_DISTANCES.each do |extra_distance|
      distance = vehicle.half + HALF + LEAVE_GAP + extra_distance
      x = vehicle.x.to_f + Math.sin(direction) * distance
      z = vehicle.z.to_f - Math.cos(direction) * distance
      return true if leave_at_height(vehicle, world, x, z)
    end
    false
  end

  # Tries each height at one spot, in the order of LEAVE_HEIGHT_OFFSETS from
  # the base of the vehicle. The player stands at the first height with room.
  def leave_at_height(vehicle, world, x, z)
    LEAVE_HEIGHT_OFFSETS.each do |height_offset|
      y = vehicle.y.to_f.floor + height_offset
      next unless world.fits_dry?(x, y, z, HALF, TALL)

      move_to(x, y.to_f, z)
      return true
    end
    false
  end

  # True when the box of a solid block lies under any part of the feet of
  # a player at x, z.
  def ground_below?(world, x, z) = world.solid_in_box?(x, @y - 0.05, z, HALF, 0.05)

  # True when the block cell at x, y, z overlaps the player's box.
  def overlaps?(bx, by, bz)
    bx + 1 > @x - HALF && bx < @x + HALF && by + 1 > @y && by < @y + TALL && bz + 1 > @z - HALF && bz < @z + HALF
  end
end
