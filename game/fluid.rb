# Water or lava: its blocks and their levels.
class Fluid
  attr_reader :source

  # The flowing blocks of the higher levels follow first_flowing.
  def initialize(levels, source_block, first_flowing)
    @levels = levels
    @first_flowing = first_flowing
    @source = levels[source_block]
    nil
  end

  def level(block) = @levels[block]

  def flowing_block(level)
    return Block::AIR if level == 0

    @first_flowing + level - 1
  end

  def passes?(block)
    level = @levels[block]
    block == Block::AIR || Block.plant?(block) || (level > 0 && level < @source)
  end

  def falls_into?(block) = passes?(block) || Block.water?(block) || Block.lava?(block)
end
