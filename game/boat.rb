# A boat: it floats on water, and the player sits in it, paddles it and
# steers it, as in Minecraft. minecraft.wiki/w/Boat
class Boat
  # Half the width and the height of its box. minecraft.wiki/w/Boat
  HALF = 0.6875
  TALL = 0.5625
  # Minecraft moves a boat in ticks of 1/20 s. Each tick, the forward key
  # adds 0.04 blocks per tick to the speed, the back key takes 0.005 away,
  # and a turn key adds 1 degree per tick to the turn. Then the speed and
  # the turn keep a part of themselves: 0.9 on water and 0.6 on land. That
  # gives top speeds of 8 m/s and 200 degrees/s on water, and 2 m/s and 50
  # degrees/s on land. minecraft.wiki/w/Boat
  TICK = 20.0
  PUSH = 0.04 * TICK * TICK
  BACK = 0.005 * TICK * TICK
  TURN = Math::PI / 180.0 * TICK * TICK
  WATER = 0.9
  LAND = 0.6
  # In the air a boat also keeps 0.9, and it falls at 0.04 blocks per tick
  # each tick. Both come from Minecraft's code (Boat); the wiki does not
  # confirm them.
  AIR = 0.9
  GRAVITY = 0.04 * TICK * TICK
  # The bottom of a boat floats this far under the water surface. This is
  # a choice for Spinelcraft; the wiki does not give it.
  DRAFT = 0.15
  # The feet of the player who rides the boat, from its bottom: Minecraft's
  # code puts a rider 0.1 + 0.35 under it. The wiki does not give it.
  SEAT = -0.45
  # A hit adds 10 for each point of its damage to the damage of the boat,
  # which goes down by 1 each tick. The boat breaks when it passes 40.
  # minecraft.wiki/w/Boat
  HIT = 10.0
  HEAL = 1.0 * TICK
  BREAKS = 40.0
  # A hit boat rocks for 10 ticks. The paddles turn by pi/8 each tick.
  # Both come from Minecraft's code (Boat); the wiki does not give them.
  ROCK = 0.5
  PADDLE = Math::PI / 8.0 * TICK

  attr_reader :item, :x, :y, :z, :yaw, :afloat

  # The to_i and to_f keep the fields typed for Spinel when a caller
  # passes an untyped position, such as one from the player.
  def initialize(item, x, y, z, yaw)
    @item = item.to_i
    @x = x.to_f
    @y = y.to_f
    @z = z.to_f
    @yaw = yaw.to_f
    @vx = 0.0
    @vy = 0.0
    @vz = 0.0
    @spin = 0.0
    @afloat = false
    @on_ground = false
    @damage = 0.0
    @hurt = 0.0
    @age = 0.0
    # The angle of each paddle in its stroke: left, then right.
    @paddle_l = 0.0
    @paddle_r = 0.0
    @strokes = 0
  end

  def speed = Math.sqrt(@vx * @vx + @vz * @vz)

  # The number of paddle strokes so far, for the paddle sound.
  def strokes = @strokes

  # The height of the water surface around the bottom of the boat, or -1.0
  # when no water is there. Water above the bottom raises the surface.
  def water_surface(world)
    x = @x.floor
    z = @z.floor
    y = (@y + 0.1).floor.to_i
    block = world.get(x, y, z)
    unless Block.water?(block)
      y -= 1
      block = world.get(x, y, z)
      return -1.0 unless Block.water?(block)
    end
    n = 0
    while n < 16 && Block.water?(world.get(x, y + 1, z))
      y += 1
      n += 1
    end
    (y + Block::WATER_LEVEL[world.get(x, y, z)] / 9.0).to_f
  end

  # Moves the boat for dt seconds. fwd is 1 forward, -1 back, and turn is 1
  # to the right and -1 to the left.
  def move_boat(world, dt, fwd, turn) # rubocop:todo Metrics/MethodLength
    @age += dt
    @hurt -= dt
    @damage -= HEAL * dt
    @damage = 0.0 if @damage < 0.0
    surface = water_surface(world)
    @afloat = surface >= 0.0
    keep = @afloat ? WATER : (@on_ground ? LAND : AIR)
    # Each tick the speed keeps `keep` of itself, so it tends to push / (1
    # - keep) per tick. This follows that in time steps of any length.
    k = (1.0 - keep) * TICK
    fade = Math.exp(-k * dt)
    # A turn key alone also pushes forward a little, as in Minecraft.
    push = fwd > 0.0 ? PUSH : (fwd < 0.0 ? -BACK : (turn != 0.0 ? BACK : 0.0))
    tx = Math.sin(@yaw) * push / k
    tz = -Math.cos(@yaw) * push / k
    @vx = tx + (@vx - tx) * fade
    @vz = tz + (@vz - tz) * fade
    ts = turn * TURN / k
    @spin = ts + (@spin - ts) * fade
    @yaw += @spin * dt
    paddle(dt, fwd, turn)
    if @afloat
      @vy = 0.0
      @y += (surface - DRAFT - @y) * (4.0 * dt).clamp(0.0, 1.0)
    else
      @vy -= GRAVITY * dt
    end
    # The box for a move along the ground is 0.01 short at the top and the
    # bottom, so that it slides over the floor.
    dx = @vx * dt
    x = world.collide(@x, @y + 0.01, @z, HALF, TALL - 0.02, 0, dx)
    @vx = 0.0 if x != @x + dx
    @x = x
    dz = @vz * dt
    z = world.collide(@x, @y + 0.01, @z, HALF, TALL - 0.02, 2, dz)
    @vz = 0.0 if z != @z + dz
    @z = z
    @on_ground = false
    return if @afloat

    dy = @vy * dt
    y = world.collide(@x, @y, @z, HALF, TALL, 1, dy)
    @on_ground = dy < 0.0 && y != @y + dy
    @vy = 0.0 if y != @y + dy
    @y = y
  end

  # Turns the paddles: both for forward and back, and the outer one in a
  # turn, as in Minecraft.
  def paddle(dt, fwd, turn)
    step = PADDLE * dt * (fwd < 0.0 ? -1.0 : 1.0)
    before = turns
    @paddle_l += step if fwd != 0.0 || turn > 0.0
    @paddle_r += step if fwd != 0.0 || turn < 0.0
    @strokes += 1 if turns != before
  end

  # The full turns of both paddles together.
  def turns = (@paddle_l / (Math::PI * 2.0)).floor + (@paddle_r / (Math::PI * 2.0)).floor

  # A hit of amount points of damage. Returns true when the boat breaks.
  def hit(amount)
    @damage += amount * HIT
    @hurt = ROCK
    @damage > BREAKS
  end

  # Distance along the view ray of the last trace of view to this boat's box,
  # or -1.0 when the ray misses it.
  def hit_distance(view) = view.box_distance(@x - HALF, @y, @z - HALF, @x + HALF, @y + TALL, @z + HALF)

  # The hull is a floor and four walls of the planks of the boat's wood,
  # with the sizes of the Minecraft model, and a paddle on each side. Local
  # +x is the right of the boat, +y up and -z the front.
  def draw_boat(mesh)
    layer = Block::TOP[Block::PLANKS[@item - Block::OAK_BOAT]]
    rock = @hurt > 0.0 ? Math.sin(@hurt * 30.0) * @hurt * 0.4 : 0.0
    bob = @afloat ? Math.sin(@age * 2.0) * 0.02 : 0.0
    cy = Math.cos(@yaw)
    sy = Math.sin(@yaw)
    cr = Math.cos(rock)
    sr = Math.sin(rock)
    # The right, up and back axes of the boat in the world.
    rx = cy * cr
    ry = sr
    rz = sy * cr
    ux = -cy * sr
    uy = cr
    uz = -sy * sr
    bx = -sy
    bz = cy
    oy = @y + bob
    mesh.set_frame(@x, oy, @z, rx, ry, rz, ux, uy, uz, bx, 0.0, bz)
    part(mesh, -0.5, 0.0, -0.875, 0.5, 0.1875, 0.875, layer)
    part(mesh, -0.625, 0.0, -0.875, -0.5, TALL, 0.875, layer)
    part(mesh, 0.5, 0.0, -0.875, 0.625, TALL, 0.875, layer)
    part(mesh, -0.5, 0.1875, -0.875, 0.5, TALL, -0.75, layer)
    part(mesh, -0.5, 0.1875, 0.75, 0.5, TALL, 0.875, layer)
    draw_paddle(mesh, -1.0, @paddle_l, layer, rx, ry, rz, ux, uy, uz, bx, bz, oy)
    draw_paddle(mesh, 1.0, @paddle_r, layer, rx, ry, rz, ux, uy, uz, bx, bz, oy)
  end

  # A box in the frame of set_frame. Each face shows the texture at one
  # texel per sixteenth of a block, so that the planks do not stretch.
  def part(mesh, x0, y0, z0, x1, y1, z1, layer)
    mesh.frame_corners(x0, y0, z0, x1, y1, z1)
    w = x1 - x0
    h = y1 - y0
    d = z1 - z0
    mesh.face_quad(0, layer, 0.0, d, 0.0, h, 1.0, 1.0, 1.0, 1.0)
    mesh.face_quad(1, layer, 0.0, d, 0.0, h, 1.0, 1.0, 1.0, 1.0)
    mesh.face_quad(2, layer, 0.0, w, 0.0, d, 1.0, 1.0, 1.0, 1.0)
    mesh.face_quad(3, layer, 0.0, w, 0.0, d, 1.0, 1.0, 1.0, 1.0)
    mesh.face_quad(4, layer, 0.0, w, 0.0, h, 1.0, 1.0, 1.0, 1.0)
    mesh.face_quad(5, layer, 0.0, w, 0.0, h, 1.0, 1.0, 1.0, 1.0)
  end

  # The paddle on side (-1 left, 1 right) at angle a of its stroke. It
  # sweeps back with its blade low in the water, and forward with the
  # blade up.
  def draw_paddle(mesh, side, a, layer, rx, ry, rz, ux, uy, uz, bx, bz, oy)
    sweep = Math.sin(a) * 0.6
    dip = 0.35 + Math.cos(a) * 0.25
    # The paddle points along d, in the boat's axes.
    dx = side * Math.cos(dip) * Math.cos(sweep)
    dy = -Math.sin(dip)
    dz = Math.cos(dip) * Math.sin(sweep)
    # p is level and across d, and q = d x p, so p, q, d turn like x, y, z.
    pl = Math.sqrt(dz * dz + dx * dx)
    px = -dz / pl
    pz = dx / pl
    qx = dy * pz
    qy = dz * px - dx * pz
    qz = -dy * px
    # The oarlock, where the paddle turns, on the top of the side wall.
    lx = side * 0.6
    ly = 0.5
    lz = -0.1
    ox = @x + lx * rx + ly * ux + lz * bx
    oy2 = oy + lx * ry + ly * uy
    oz = @z + lx * rz + ly * uz + lz * bz
    mesh.set_frame(ox, oy2, oz,
                   px * rx + pz * bx, px * ry, px * rz + pz * bz,
                   qx * rx + qy * ux + qz * bx, qx * ry + qy * uy, qx * rz + qy * uz + qz * bz,
                   dx * rx + dy * ux + dz * bx, dx * ry + dy * uy, dx * rz + dy * uz + dz * bz)
    part(mesh, -0.04, -0.04, -0.3, 0.04, 0.04, 0.9, layer)
    part(mesh, -0.02, -0.14, 0.5, 0.02, 0.14, 1.0, layer)
  end
end
