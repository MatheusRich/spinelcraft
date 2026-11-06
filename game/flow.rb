# Water or lava that moves in the world, one step at a time.
class Flow
  def initialize(world, fluid, step)
    @world = world
    @fluid = fluid
    @queue = FlowQueue.new(step)
    @search = DropSearch.new(self)
    nil
  end

  def wake(x, y, z) = @queue.wake(x, y, z)

  def clear = @queue.clear

  def step?(dt)
    return false unless @queue.start?(dt)

    @search.forget
    true
  end

  def next_change(change)
    change.clear
    while @queue.next?
      block = yield @queue.x, @queue.y, @queue.z
      next if block < 0

      change << @queue.x << @queue.y << @queue.z << block
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
      nx = x + Block::DIR_DX[dir]
      nz = z + Block::DIR_DZ[dir]
      level = spread_level(nx, y, nz)
      best = level - 1 if level - 1 > best && (@search.directions(nx, y, nz) >> (dir ^ 1)) & 1 == 1
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

  def passes?(x, y, z) = @fluid.passes?(@world.get(x, y, z))

  # World#get gives air outside the loaded world, which is no way down.
  def way_down?(x, y, z) = @world.loaded?(x, z) && @fluid.falls_into?(@world.get(x, y - 1, z))

  def falling?(x, y, z) = @fluid.level(@world.get(x, y + 1, z)) > 0
end
