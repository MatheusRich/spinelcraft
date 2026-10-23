require_relative "test_helper"

class LootPoolTest < Minitest::Test
  # The stacks in slots, as [block, count] pairs.
  def stacks(slots) = (0...slots.size).reject { |slot| slots.empty?(slot) }.map { |slot| [slots.block(slot), slots.count(slot)] }

  # The slots of a chest after pool rolls once with each of 200 seeds.
  def rolls(pool) = (1..200).map { |seed| Slots.new(Chest::SLOTS).tap { |slots| pool.fill_slots(Rng.new(seed), slots) } }

  def test_a_pool_rolls_from_its_low_to_its_high_times
    counts = rolls(LootPool.new(2, 4).row(Block::COAL, 1, 1, 1)).map { |slots| stacks(slots).size }
    assert_equal [2, 3, 4], counts.uniq.sort
  end

  def test_a_row_gives_from_its_low_to_its_high_count
    counts = rolls(LootPool.new(1, 1).row(Block::COAL, 3, 5, 1)).map { |slots| stacks(slots)[0][1] }
    assert_equal [3, 4, 5], counts.uniq.sort
  end

  def test_a_roll_picks_a_row_by_its_weight
    blocks = rolls(LootPool.new(1, 1).row(Block::COAL, 1, 1, 3).row(Block::BONE, 1, 1, 1)).map { |slots| stacks(slots)[0][0] }
    assert_in_delta 0.75, blocks.count(Block::COAL) / 200.0, 0.08
    assert_in_delta 0.25, blocks.count(Block::BONE) / 200.0, 0.08
  end

  def test_the_last_row_can_win
    blocks = rolls(LootPool.new(1, 1).row(Block::COAL, 1, 1, 1).row(Block::BONE, 1, 1, 1).row(Block::APPLE, 1, 1, 1)).map { |slots| stacks(slots)[0][0] }
    assert_includes blocks, Block::APPLE
  end

  def test_a_row_of_block_1_gives_it
    slots = Slots.new(Chest::SLOTS)
    LootPool.new(1, 1).row(1, 2, 2, 1).fill_slots(Rng.new(1), slots)
    assert_equal [[1, 2]], stacks(slots)
  end

  def test_a_row_of_block_0_gives_nothing
    assert(rolls(LootPool.new(3, 3).row(0, 1, 4, 1)).all? { |slots| stacks(slots).empty? })
  end

  def test_a_tool_comes_new
    slots = Slots.new(Chest::SLOTS)
    LootPool.new(1, 1).row(Block::IRON_SWORD, 1, 1, 1).fill_slots(Rng.new(1), slots)
    assert_equal [[Block::IRON_SWORD, Block.uses(Block::IRON_SWORD)]], stacks(slots)
  end

  def test_each_stack_goes_in_a_random_empty_slot
    slots = Slots.new(Chest::SLOTS)
    slots.set(0, Block::DIRT, 1)
    LootPool.new(20, 20).row(Block::COAL, 1, 1, 1).fill_slots(Rng.new(7), slots)
    assert_equal [Block::DIRT, 1], [slots.block(0), slots.count(0)]
    assert_equal 21, stacks(slots).size
    filled = (1...Chest::SLOTS).reject { |slot| slots.empty?(slot) }
    refute_equal (1..20).to_a, filled
  end

  def test_a_stack_with_no_empty_slot_is_lost
    slots = Slots.new(2)
    LootPool.new(3, 3).row(Block::COAL, 1, 1, 1).fill_slots(Rng.new(1), slots)
    assert_equal [[Block::COAL, 1], [Block::COAL, 1]], stacks(slots)
  end

  def test_between_gives_each_number_from_low_to_high
    rng = Rng.new(3)
    assert_equal [2, 3, 4], Array.new(100) { LootPool.between(rng, 2, 4) }.uniq.sort
  end
end
