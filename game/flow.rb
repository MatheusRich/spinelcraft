# Water or lava that moves in the world, one step at a time.
class Flow
  def initialize(world, fluid, step)
    @world = world
    @fluid = fluid
    @queue = FlowQueue.new(step)
    nil
  end

  def wake(x, y, z) = @queue.wake(x, y, z)

  def clear = @queue.clear

  def step?(dt) = @queue.start?(dt)

  # The block yields the block that the cell should change to, or -1.
  def next_change(changes)
    while @queue.next?
      block = yield @queue.x, @queue.y, @queue.z
      next if block < 0

      changes << @queue.x << @queue.y << @queue.z << block
      return true
    end
    false
  end

  def flowing_block(x, y, z) = @fluid.flowing_block(flow_target(x, y, z))

  def flow_target(x, y, z)
    return @fluid.source - 1 if falling?(x, y, z)

    best = 0
    dir = 0
    while dir < 4
      level = spread_level(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir])
      best = level - 1 if level - 1 > best
      dir += 1
    end
    best
  end

  # Flowing fluid spreads sideways only on a solid block. Falling fluid
  # spreads there as a source: Minecraft gives falling water level 8.
  # minecraft.wiki/w/Water
  def spread_level(x, y, z)
    level = @fluid.level(@world.get(x, y, z))
    return level if level == @fluid.source || level == 0
    return 0 unless Block.solid?(@world.get(x, y - 1, z))
    return @fluid.source if falling?(x, y, z)

    level
  end

  def falling?(x, y, z) = @fluid.level(@world.get(x, y + 1, z)) > 0
end
