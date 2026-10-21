# Sand or gravel that left its cell and falls down its column.
class FallingBlock
  # Gravity in m/s per second, and the speed at which a fall stops getting
  # faster. In Minecraft, the gravity is 0.04 blocks per tick², and the
  # drag is 0.98 each tick (minecraft.wiki/w/Falling_Block). At 20 ticks
  # a second, that is 16 m/s², and 40 m/s at most.
  GRAVITY = 16.0
  TERMINAL = 40.0

  attr_reader :block, :x, :y, :z

  def initialize(block, x, y, z)
    @block = block
    @x = x
    @y = y
    @z = z
    @vy = 0.0
  end

  def fall(dt)
    # The fall gets faster at GRAVITY, less so near TERMINAL.
    @vy -= GRAVITY * (1.0 + @vy / TERMINAL) * dt
    @y += @vy * dt
  end

  # A full-size cube.
  def draw(mesh)
    mesh.set_frame(@x + 0.5, @y + 0.5, @z + 0.5, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    mesh.item_model(@block)
  end
end
