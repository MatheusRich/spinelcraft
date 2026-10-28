# An arrow from the player's bow or from a skeleton. It falls, and it sticks
# in the first solid block that it flies into.
class Arrow
  SHAFT_COLOR = Color.new(0.45, 0.32, 0.18, 1.0)
  FLETCHING_COLOR = Color.new(0.9, 0.9, 0.9, 1.0)
  attr_reader :x, :y, :z, :vx, :vz
  # 0 for a skeleton's arrow; otherwise the damage of the player's arrow.
  attr_reader :damage
  # True on the step that the arrow sticks in a block; Game clears it.
  attr_accessor :landed

  def initialize(x, y, z, vx, vy, vz, life, damage)
    @x = x
    @y = y
    @z = z
    @vx = vx
    @vy = vy
    @vz = vz
    @life = life
    @stuck = false
    @landed = false
    @damage = damage
  end

  def alive? = @life > 0.0

  def vanish
    @life = 0.0
  end

  # Moves the arrow for dt seconds. Returns true when it is still in the air.
  def fly(world, dt)
    @life -= dt
    return false if @stuck

    @vy -= 18.0 * dt
    nx = @x + @vx * dt
    ny = @y + @vy * dt
    nz = @z + @vz * dt
    if Block.solid?(world.get(nx.floor, ny.floor, nz.floor))
      @stuck = true
      @landed = true
      @life = 3.0 if @life > 3.0
      return false
    end
    @x = nx
    @y = ny
    @z = nz
    true
  end

  # True when the tip is in the box of half width half and height tall that
  # stands on bx, by, bz.
  def in_box?(bx, by, bz, half, tall)
    @x > bx - half && @x < bx + half && @y > by && @y < by + tall && @z > bz - half && @z < bz + half
  end

  def draw(mesh)
    yaw = Math.atan2(-@vx, @vz)
    pitch = -Math.atan2(@vy, Math.sqrt(@vx * @vx + @vz * @vz))
    mesh.box(@x, @y, @z, yaw, 0.0, 0.0, pitch, -0.03, -0.03, -0.6, 0.03, 0.03, 0.0, Tex::WHITE, SHAFT_COLOR)
    mesh.box(@x, @y, @z, yaw, 0.0, 0.0, pitch, -0.05, -0.05, -0.62, 0.05, 0.05, -0.5, Tex::WHITE, FLETCHING_COLOR)
  end
end
