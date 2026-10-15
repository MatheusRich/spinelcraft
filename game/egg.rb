# An egg that the player threw. It falls, and it breaks on the first solid
# block or mob that it hits (Game#update_eggs).
class Egg
  # Minecraft throws an egg at 1.5 blocks each tick, and it falls by 0.03
  # blocks each tick per tick (ThrowableProjectile, not on the wiki).
  SPEED = 30.0
  GRAVITY = 12.0

  attr_reader :x, :y, :z, :vx, :vz

  # to_f: the player's position is untyped in Spinel, and an untyped @x
  # would box each step of the flight.
  def initialize(x, y, z, vx, vy, vz)
    @x = x.to_f
    @y = y.to_f
    @z = z.to_f
    @vx = vx
    @vy = vy
    @vz = vz
    @broken = false
  end

  def broken? = @broken

  def break_open
    @broken = true
  end

  # Moves the egg for dt seconds. It breaks when it flies into a solid block
  # or below the world.
  def fly(world, dt)
    @vy -= GRAVITY * dt
    nx = @x + @vx * dt
    ny = @y + @vy * dt
    nz = @z + @vz * dt
    if ny < 0.0 || Block.solid?(world.get(nx.floor, ny.floor, nz.floor))
      @broken = true
      return
    end
    @x = nx
    @y = ny
    @z = nz
  end

  # The egg item, a quarter block large, faces the way that it flies, so
  # the player sees it from behind.
  def draw(mesh)
    yaw = Math.atan2(-@vx, @vz)
    c = Math.cos(yaw) * 0.25
    s = Math.sin(yaw) * 0.25
    mesh.set_frame(@x, @y, @z, c, 0.0, s, 0.0, 0.25, 0.0, -s, 0.0, c)
    mesh.item_model(Block::EGG)
  end
end
