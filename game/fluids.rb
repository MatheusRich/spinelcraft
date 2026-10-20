# The rules of flowing water and lava. Fluids does not change the world.
# Game#set_block wakes the cells next to each change. Each step looks at
# the cells that woke before it, and next_change gives the changes one at
# a time, as four Integers (x, y, z and the new block). Game puts each one
# in the world with Game#pour before it asks for the next one, so each
# cell sees the cells that changed before it in the step.
class Fluids
  # The time from one step to the next, in seconds.
  STEP = 0.15
  # A step looks at this many cells at most. The rest wait for the next
  # step.
  STEP_CELLS = 6000

  def initialize(world)
    @world = world
    # The cells that woke since the step started: x, y and z for each one.
    @queue = Array.new(0, 0)
    # The cells of this step, and the index of the next one.
    @batch = Array.new(0, 0)
    @next = 0
    @timer = 0.0
    nil
  end

  # Wakes the cell x, y, z and its six neighbors for the next step.
  def wake(x, y, z)
    @queue << x << y << z
    @queue << x + 1 << y << z
    @queue << x - 1 << y << z
    @queue << x << y + 1 << z
    @queue << x << y - 1 << z
    @queue << x << y << z + 1
    @queue << x << y << z - 1
    nil
  end

  # Forgets the cells that woke.
  def clear
    @queue.clear
    nil
  end

  # True when a step is due after dt more seconds and a cell woke.
  def due?(dt)
    @timer -= dt
    return false if @timer > 0.0
    @timer = STEP
    !@queue.empty?
  end

  # Starts a step with the cells that woke. A cell that wakes during the
  # step waits for the next step.
  def start_step
    @batch = @queue
    @queue = Array.new(0, 0)
    @next = 0
    nil
  end

  # Adds the next change of the step to changes and gives true. At the end
  # of the step it gives false, and the cells past STEP_CELLS wait for the
  # next step.
  def next_change(changes)
    while @next < @batch.size && @next < STEP_CELLS * 3
      x = @batch[@next]
      y = @batch[@next + 1]
      z = @batch[@next + 2]
      @next += 3
      block = wanted(x, y, z)
      next if block < 0
      changes << x << y << z << block
      return true
    end
    @queue.concat(@batch[@next, @batch.size - @next]) if @next < @batch.size
    false
  end

  # The block that the cell x, y, z should change to, or -1 when it
  # stays. Water cools lava into cobblestone, and flowing fluid with no
  # fluid to feed it drains. A source stays.
  def wanted(x, y, z)
    return -1 unless @world.inside?(x, y, z)
    block = @world.get(x, y, z)
    return Block::COBBLE if Block.lava?(block) && @world.touches_water?(x, y, z)
    water = Block::WATER_LEVEL[block]
    lava = Block::LAVA_LEVEL[block]
    return -1 if water == 8 || lava == 4
    return -1 unless block == Block::AIR || water > 0 || lava > 0 || Block.plant?(block)
    want = flow_block(x, y, z)
    return -1 if want == block
    return -1 if want == Block::AIR && water == 0 && lava == 0
    want
  end

  # The flowing lava or water that the cell x, y, z gets from its
  # neighbors (see flow_target), or air when it gets neither. Lava comes
  # before water.
  def flow_block(x, y, z)
    lava = flow_target(x, y, z, Block::LAVA_LEVEL, 4)
    return Block::LAVA_FLOW + lava - 1 if lava > 0
    water = flow_target(x, y, z, Block::WATER_LEVEL, 8)
    return Block::FLOW + water - 1 if water > 0
    Block::AIR
  end

  # The level of a fluid that the cell x, y, z should have. levels is the
  # level table of the fluid (Block::WATER_LEVEL or Block::LAVA_LEVEL),
  # and source is the level of its source. The level is one less than a
  # source under falling fluid, else one less than the best neighbor that
  # spreads sideways (a source, or fluid resting on a solid block). Water
  # spreads 7 blocks and lava 3.
  def flow_target(x, y, z, levels, source)
    return source - 1 if levels[@world.get(x, y + 1, z)] > 0
    best = 0
    dir = 0
    while dir < 4
      nx = x + Block::DIR_DX[dir]
      nz = z + Block::DIR_DZ[dir]
      level = levels[@world.get(nx, y, nz)]
      best = level - 1 if level - 1 > best && (level == source || Block.solid?(@world.get(nx, y - 1, nz)))
      dir += 1
    end
    best
  end
end
