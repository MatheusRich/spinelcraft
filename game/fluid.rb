# Water or lava: its blocks and their levels.
class Fluid
  attr_reader :source

  # flow is the flowing block of level 1. The higher levels follow it.
  def initialize(levels, source_block, flow)
    @levels = levels
    @flow = flow
    @source = levels[source_block]
    nil
  end

  def level(block) = @levels[block]

  def flowing_block(level)
    return Block::AIR if level == 0

    @flow + level - 1
  end

  def passes?(block)
    level = @levels[block]
    block == Block::AIR || Block.plant?(block) || (level > 0 && level < @source)
  end
end
