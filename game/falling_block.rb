# Sand or gravel that left its cell and falls down its column. It speeds up
# like the player.
class FallingBlock
  attr_reader :block, :x, :y, :z

  def initialize(block, x, y, z)
    @block = block
    @x = x
    @y = y
    @z = z
    @vy = 0.0
  end

  def fall(dt)
    @vy -= 28.0 * dt
    @vy = -40.0 if @vy < -40.0
    @y += @vy * dt
  end

  # A full-size cube.
  def draw(mesh)
    mesh.set_frame(@x + 0.5, @y + 0.5, @z + 0.5, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
    mesh.item_model(@block)
  end
end
