# The sand and gravel that fall through the air (see FallingBlock).
# FallingBlocks does not change the world: update yields each block that
# lands, and Game puts it in the world.
class FallingBlocks
  def initialize(world)
    @world = world
    @blocks = []
  end

  def add(block)
    @blocks << block
    nil
  end

  def size = @blocks.size
  def empty? = @blocks.empty?

  def clear
    @blocks.clear
    nil
  end

  def draw(mesh)
    @blocks.each { |block| block.draw(mesh) }
    nil
  end

  # Moves the falling blocks by dt seconds, and yields each block that
  # lands with the y of its landing cell. A landing can make more blocks
  # fall, and they fall in this update too. A block over a chunk that is
  # not loaded waits, and a block that falls out of the world goes.
  def update(dt)
    index = 0
    while index < @blocks.size
      block = @blocks[index]
      if fall_ends?(block, dt)
        @blocks.delete_at(index)
        yield block, landing_y(block) if block.y >= 0.0
      else
        index += 1
      end
    end
    nil
  end

  private

  def fall_ends?(block, dt)
    return false unless @world.loaded?(block.x, block.z)

    block.fall(dt)
    block.y < 0.0 || !Block.lets_fall?(@world.get(block.x, block.y.floor, block.z))
  end

  # The lowest cell over the block that stopped the fall that lets a block
  # fall.
  def landing_y(block)
    x = block.x.to_i
    z = block.z.to_i
    y = block.y.floor.to_i + 1
    y += 1 while y < WY - 1 && !Block.lets_fall?(@world.get(x, y, z))
    y
  end
end
