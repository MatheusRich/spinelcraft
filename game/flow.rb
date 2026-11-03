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
    source = @fluid.source
    return source - 1 if @fluid.level(@world.get(x, y + 1, z)) > 0

    best = 0
    dir = 0
    while dir < 4
      nx = x + Block::DIR_DX[dir]
      nz = z + Block::DIR_DZ[dir]
      level = @fluid.level(@world.get(nx, y, nz))
      best = level - 1 if level - 1 > best && (level == source || Block.solid?(@world.get(nx, y - 1, nz)))
      dir += 1
    end
    best
  end
end
