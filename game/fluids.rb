# The rules of flowing water and lava. Fluids does not change the world.
# Game#set_block wakes the cells next to each change. Water and lava each
# take steps at their own speed (see FlowQueue). next_water and next_lava
# give the changes of a step one at a time, as four Integers (x, y, z and
# the new block). Game puts each one in the world with Game#pour before it
# asks for the next one, so each cell sees the cells that changed before
# it in the step.
class Fluids
  # Water moves 1 block every 5 ticks, and lava in the overworld 1 block
  # every 30 ticks. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
  WATER_STEP = 0.25
  LAVA_STEP = 1.5

  def initialize(world)
    @world = world
    @water = FlowQueue.new(WATER_STEP)
    @lava = FlowQueue.new(LAVA_STEP)
    nil
  end

  # Wakes the cell x, y, z and its six neighbors for the next step of
  # water and of lava.
  def wake(x, y, z)
    @water.wake(x, y, z)
    @lava.wake(x, y, z)
  end

  # Forgets the cells that woke.
  def clear
    @water.clear
    @lava.clear
  end

  # True when a step of water starts after dt more seconds (see
  # FlowQueue#start?).
  def water_step?(dt) = @water.start?(dt)

  # True when a step of lava starts after dt more seconds.
  def lava_step?(dt) = @lava.start?(dt)

  # Adds the next change of the step of water to changes and gives true,
  # or gives false at the end of the step.
  def next_water(changes)
    while @water.next?
      block = water_wanted(@water.x, @water.y, @water.z)
      next if block < 0

      changes << @water.x << @water.y << @water.z << block
      return true
    end
    false
  end

  # Adds the next change of the step of lava to changes and gives true,
  # or gives false at the end of the step.
  def next_lava(changes)
    while @lava.next?
      block = lava_wanted(@lava.x, @lava.y, @lava.z)
      next if block < 0

      changes << @lava.x << @lava.y << @lava.z << block
      return true
    end
    false
  end

  # The block that the cell x, y, z should change to in a step of water,
  # or -1 when it stays. Water cools lava next to it into cobblestone.
  # Water flows into air and plants, and flowing water with no water to
  # feed it drains. A source stays, and water does not flow into lava.
  def water_wanted(x, y, z)
    return -1 unless @world.inside?(x, y, z)

    block = @world.get(x, y, z)
    return Block::COBBLE if Block.lava?(block) && @world.touches_water?(x, y, z)

    level = Block::WATER_LEVEL[block]
    return -1 unless block == Block::AIR || Block.plant?(block) || (level > 0 && level < 8)

    water = flow_target(x, y, z, Block::WATER_LEVEL, 8)
    want = water > 0 ? Block::FLOW + water - 1 : Block::AIR
    return -1 if want == block
    return -1 if want == Block::AIR && level == 0

    want
  end

  # The block that the cell x, y, z should change to in a step of lava,
  # or -1 when it stays. Lava flows into air, plants and flowing water,
  # and flowing lava with no lava to feed it drains. A source stays.
  def lava_wanted(x, y, z)
    return -1 unless @world.inside?(x, y, z)

    block = @world.get(x, y, z)
    level = Block::LAVA_LEVEL[block]
    water = Block::WATER_LEVEL[block]
    return -1 unless block == Block::AIR || Block.plant?(block) || (level > 0 && level < 4) || (water > 0 && water < 8)

    lava = flow_target(x, y, z, Block::LAVA_LEVEL, 4)
    want = lava > 0 ? Block::LAVA_FLOW + lava - 1 : Block::AIR
    return -1 if want == block
    return -1 if want == Block::AIR && level == 0

    want
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
