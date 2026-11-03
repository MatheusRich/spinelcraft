# The rules of flowing water and lava. Fluids does not change the world.
# Game#set_block wakes the cells next to each change. Water and lava each
# take steps at their own speed (see Flow). next_water and next_lava
# give the changes of a step one at a time, as four Integers (x, y, z and
# the new block). Game puts each one in the world with Game#pour before it
# asks for the next one, so each cell sees the cells that changed before
# it in the step.
class Fluids
  # Water moves 1 block every 5 ticks, and lava in the overworld 1 block
  # every 30 ticks. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
  WATER_STEP = 0.25
  LAVA_STEP = 1.5
  # minecraft.wiki/w/Water
  RENEW_SOURCES = 2
  WATER = Fluid.new(Block::WATER_LEVEL, Block::WATER, Block::FLOW)
  LAVA = Fluid.new(Block::LAVA_LEVEL, Block::LAVA, Block::LAVA_FLOW)

  def initialize(world)
    @world = world
    @water = Flow.new(world, WATER, WATER_STEP)
    @lava = Flow.new(world, LAVA, LAVA_STEP)
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
  def water_step?(dt) = @water.step?(dt)

  # True when a step of lava starts after dt more seconds.
  def lava_step?(dt) = @lava.step?(dt)

  # Adds the next change of the step of water to changes and gives true,
  # or gives false at the end of the step.
  def next_water(changes) = @water.next_change(changes) { |x, y, z| water_wanted(x, y, z) }

  # Adds the next change of the step of lava to changes and gives true,
  # or gives false at the end of the step.
  def next_lava(changes) = @lava.next_change(changes) { |x, y, z| lava_wanted(x, y, z) }

  # The block that the cell x, y, z should change to in a step of water,
  # or -1 when it stays. Water cools lava next to it into cobblestone.
  # Water flows into air and plants, and flowing water with no water to
  # feed it drains. A source stays, and water does not flow into lava.
  def water_wanted(x, y, z)
    return -1 unless @world.inside?(x, y, z)

    block = @world.get(x, y, z)
    return Block::COBBLE if Block.lava?(block) && @world.touches_water?(x, y, z)
    return -1 unless WATER.passes?(block)
    return Block::WATER if renews?(x, y, z)

    want = @water.flowing_block(x, y, z)
    return -1 if want == block
    return -1 if want == Block::AIR && WATER.level(block) == 0

    want
  end

  # Water becomes a source between RENEW_SOURCES sources on a solid block
  # or a source, or beside a source with a source above it.
  # minecraft.wiki/w/Water
  def renews?(x, y, z)
    sources = Block::DIR_DX.each_index.count { |dir| @world.get(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir]) == Block::WATER }
    return sources > 0 if @world.get(x, y + 1, z) == Block::WATER

    below = @world.get(x, y - 1, z)
    sources >= RENEW_SOURCES && (Block.solid?(below) || below == Block::WATER)
  end

  # The block that the cell x, y, z should change to in a step of lava,
  # or -1 when it stays. Lava flows into air, plants and flowing water,
  # and flowing lava with no lava to feed it drains. A source stays.
  def lava_wanted(x, y, z)
    return -1 unless @world.inside?(x, y, z)

    block = @world.get(x, y, z)
    return -1 unless LAVA.passes?(block) || WATER.passes?(block)

    want = @lava.flowing_block(x, y, z)
    return -1 if want == block
    return -1 if want == Block::AIR && LAVA.level(block) == 0

    want
  end
end
