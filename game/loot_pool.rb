# One pool of a loot table, as in Minecraft (minecraft.wiki/w/Loot_table):
# it rolls from low to high times. Each roll picks a row by its weight and
# puts from its low to its high count of its block in a random empty slot.
# A tool comes new, with all its uses. A row of block 0 stands for an item
# that the game does not have, and its roll gives nothing.
class LootPool
  def initialize(low, high)
    @low = low
    @high = high
    @blocks = Array.new(0, 0)
    @lows = Array.new(0, 0)
    @highs = Array.new(0, 0)
    @weights = Array.new(0, 0)
    nil
  end

  # Adds a row, and gives the pool.
  def row(block, low, high, weight)
    @blocks << block
    @lows << low
    @highs << high
    @weights << weight
    self
  end

  # Rolls the pool with rng, and puts what it gives into slots.
  def fill_slots(rng, slots)
    rolls = rng.between(@low, @high)
    while rolls > 0
      row = pick(rng)
      block = @blocks[row]
      # to_i: Spinel types the count too late without it.
      place_stack(rng, slots, block, rng.between(@lows[row], @highs[row]).to_i) if block > 0
      rolls -= 1
    end
    nil
  end

  # A row, picked at random by the weights.
  def pick(rng)
    roll = (rng.rand01 * @weights.sum).to_i
    row = 0
    while roll >= @weights[row]
      roll -= @weights[row]
      row += 1
    end
    row
  end

  # Puts count of block in a random empty slot of slots, or one new tool.
  # When no slot is empty, the stack is lost.
  def place_stack(rng, slots, block, count)
    empty = (0...slots.size).select { |slot| slots.empty?(slot) }
    return if empty.empty?

    slots.set(empty[(rng.rand01 * empty.size).to_i], block, Block.tool?(block) ? Block.uses(block) : count)
  end
end
