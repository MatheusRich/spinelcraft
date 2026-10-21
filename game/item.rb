# An item on the ground: a stack of one block or item kind. It falls,
# floats in water, slides to a stop, and turns and bobs above the ground.
class Item
  # Seconds before the game removes an item that nobody picked up.
  LIFE = 300.0
  # The player picks up items within this distance on x and z.
  REACH = 1.3
  # The half width and the height of the item's box. minecraft.wiki/w/Item_(entity)
  HALF = 0.125
  TALL = 0.25

  attr_reader :block, :x, :y, :z, :age, :wait
  attr_accessor :count

  def initialize(block, count, x, y, z, vx, vy, vz, wait, age)
    @block = block
    @count = count
    @x = x
    @y = y
    @z = z
    @vx = vx
    @vy = vy
    @vz = vz
    @wait = wait
    @age = age
  end

  def gone? = @count <= 0 || @age > LIFE

  # True when the player can pick the item up.
  def ready? = @wait <= 0.0

  def near?(player)
    dx = @x - player.x
    dz = @z - player.z
    dy = @y - player.y
    dx * dx + dz * dz < REACH * REACH && dy > -0.8 && dy < Player::TALL + 0.5
  end

  def touches?(other)
    dx = other.x - @x
    dy = other.y - @y
    dz = other.z - @z
    dx * dx + dy * dy + dz * dz < 0.5
  end

  # Takes all of other into this stack.
  def absorb(other)
    @count += other.count
    @wait = other.wait if other.wait > @wait
    other.count = 0
  end

  # Moves the item for dt seconds. Returns false when it is in lava.
  def update(world, dt) # rubocop:todo Metrics/MethodLength
    @age += dt
    @wait -= dt
    at = world.get(@x.floor, @y.floor, @z.floor)
    return false if Block.lava?(at)

    # A block placed on the item pushes it up.
    if Block.solid?(at)
      @y = @y.floor + 1.0
      @vy = 0.0
      return true
    end
    if Block.water?(at)
      @vy += (1.2 - @vy) * (3.0 * dt).clamp(0.0, 1.0)
    else
      @vy -= 18.0 * dt
      @vy = -30.0 if @vy < -30.0
    end
    nx = @x + @vx * dt
    if Block.solid?(world.get(nx.floor, @y.floor, @z.floor))
      @vx = 0.0
    else
      @x = nx
    end
    nz = @z + @vz * dt
    if Block.solid?(world.get(@x.floor, @y.floor, nz.floor))
      @vz = 0.0
    else
      @z = nz
    end
    ny = @y + @vy * dt
    if Block.solid?(world.get(@x.floor, ny.floor, @z.floor))
      @y = ny.floor + 1.0 if @vy < 0.0
      @vy = 0.0
      # Ground friction.
      k = 1.0 - (8.0 * dt).clamp(0.0, 1.0)
      @vx *= k
      @vz *= k
    else
      @y = ny
    end
    true
  end

  # The item turns and bobs above the ground, ahead or behind other items
  # by phase. A stack of more than one shows a second copy.
  def draw(mesh, phase)
    size = Block.flat?(@block) ? 0.4 : 0.25
    y = @y + size / 2.0 + 0.08 + Math.sin(@age * 2.5 + phase) * 0.06
    yaw = @age * 1.6 + phase
    c = Math.cos(yaw) * size
    s = Math.sin(yaw) * size
    mesh.set_frame(@x, y, @z, c, 0.0, s, 0.0, size, 0.0, -s, 0.0, c)
    mesh.item_model(@block)
    if @count > 1 && !Block.tool?(@block)
      mesh.set_frame(@x + 0.08, y + 0.06, @z + 0.05, c, 0.0, s, 0.0, size, 0.0, -s, 0.0, c)
      mesh.item_model(@block)
    end
  end
end
