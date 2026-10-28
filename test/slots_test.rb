require_relative "test_helper"

# A row of item slots: the inventory, a chest, a furnace or the hand.
class SlotsTest < Minitest::Test
  PICK = Block::STONE_PICK

  def test_a_slot_with_a_count_of_0_is_empty_and_holds_air
    slots = Slots.new(2)
    assert slots.empty?(0)
    slots.set(0, Block::DIRT, 3)
    refute slots.empty?(0)
    assert_equal [Block::DIRT, 3], [slots.block(0), slots.count(0)]
    slots.take(0, 3)
    assert slots.empty?(0)
    assert_equal Block::AIR, slots.block(0)
  end

  def test_clear_empties_every_slot
    slots = Slots.new(2)
    slots.set(0, Block::DIRT, 3)
    slots.set(1, PICK, 9)
    slots.clear
    assert([0, 1].all? { |index| slots.empty?(index) && slots.block(index) == Block::AIR })
  end

  def test_a_copy_does_not_change_with_the_original
    slots = Slots.new(2)
    slots.set(1, Block::DIRT, 3)
    copy = slots.copy
    slots.set(1, Block::SAND, 5)
    assert_equal [Block::DIRT, 3], [copy.block(1), copy.count(1)]
    assert copy.empty?(0)
  end

  def test_the_slots_go_into_the_save_and_back
    slots = Slots.new(2)
    slots.set(0, Block::DIRT, 3)
    slots.set(1, PICK, 9)
    assert_equal [Block::DIRT, PICK, 3, 9], slots.to_a
    loaded = Slots.new(2)
    loaded.load([7, Block::DIRT, PICK, 3, 9], 1)
    assert_equal slots.to_a, loaded.to_a
  end

  def test_room_counts_the_free_part_of_each_stack_and_each_empty_slot
    slots = Slots.new(3)
    slots.set(0, Block::DIRT, 60)
    slots.set(1, Block::SAND, 1)
    assert_equal 4 + 64, slots.room_for(Block::DIRT)
    assert_equal 16, slots.room_for(Block::EGG)
    assert_equal 1, slots.room_for(PICK)
  end

  def test_a_tool_has_room_only_in_an_empty_slot
    slots = Slots.new(2)
    slots.set(0, PICK, 5)
    assert_equal 1, slots.room_for(PICK)
  end

  def test_a_stack_goes_into_the_first_empty_slot
    slots = Slots.new(3)
    slots.set(0, Block::DIRT, 1)
    assert slots.put(PICK, 50)
    assert_equal [PICK, 50], [slots.block(1), slots.count(1)]
    assert slots.put(Block::SAND, 2)
    refute slots.put(Block::SAND, 2)
  end

  def test_an_item_joins_the_first_stack_of_its_kind_with_room
    slots = Slots.new(3)
    slots.set(0, Block::DIRT, 64)
    slots.set(2, Block::DIRT, 5)
    assert slots.add(Block::DIRT)
    assert_equal 6, slots.count(2)
    assert slots.empty?(1)
  end

  def test_an_item_with_no_stack_to_join_goes_into_an_empty_slot
    slots = Slots.new(2)
    slots.set(0, Block::DIRT, 64)
    assert slots.add(Block::DIRT)
    assert_equal [Block::DIRT, 1], [slots.block(1), slots.count(1)]
    63.times { slots.add(Block::DIRT) }
    refute slots.add(Block::DIRT)
  end

  def test_a_new_tool_has_all_its_uses_and_air_always_fits
    slots = Slots.new(1)
    assert slots.add(PICK)
    assert_equal Block.uses(PICK), slots.count(0)
    refute slots.add(PICK)
    assert slots.add(Block::AIR)
  end

  def test_the_total_adds_up_the_stacks_of_a_kind
    slots = Slots.new(3)
    slots.set(0, Block::DIRT, 3)
    slots.set(1, Block::SAND, 4)
    slots.set(2, Block::DIRT, 5)
    assert_equal 8, slots.total(Block::DIRT)
    assert_equal 0, slots.total(Block::EGG)
  end

  def test_remove_takes_from_the_last_slots_first
    slots = Slots.new(3)
    slots.set(0, Block::DIRT, 3)
    slots.set(1, Block::SAND, 4)
    slots.set(2, Block::DIRT, 5)
    slots.remove(Block::DIRT, 6)
    assert_equal [2, 4, 0], [slots.count(0), slots.count(1), slots.count(2)]
  end

  def test_a_moved_stack_fills_stacks_of_its_kind_before_empty_slots
    from = Slots.new(1)
    to = Slots.new(4)
    to.set(1, Block::DIRT, 60)
    to.set(3, Block::DIRT, 62)
    from.set(0, Block::DIRT, 10)
    from.move_stack(0, to, 0...4)
    assert_equal([4, 64, 0, 64], (0...4).map { |index| to.count(index) })
    assert_equal Block::DIRT, to.block(0)
    assert from.empty?(0)
  end

  def test_a_moved_stack_stays_in_the_range_and_keeps_what_does_not_fit
    from = Slots.new(1)
    to = Slots.new(3)
    to.set(0, Block::SAND, 1)
    from.set(0, Block::DIRT, 10)
    from.move_stack(0, to, 0...1)
    assert_equal 10, from.count(0)
    to.set(1, Block::DIRT, 60)
    from.move_stack(0, to, 0...2)
    assert_equal [64, 6], [to.count(1), from.count(0)]
    assert to.empty?(2)
  end

  def test_add_stack_gives_the_count_that_does_not_fit
    slots = Slots.new(2)
    slots.set(0, Block::DIRT, 60)
    slots.set(1, Block::SAND, 1)
    assert_equal 6, slots.add_stack(Block::DIRT, 10, 0...2)
    assert_equal 64, slots.count(0)
    assert_equal 10, slots.add_stack(Block::DIRT, 10, 0...2)
    slots.set(1, Block::AIR, 0)
    assert_equal 0, slots.add_stack(Block::DIRT, 10, 0...2)
    assert_equal [Block::DIRT, 10], [slots.block(1), slots.count(1)]
  end

  def test_add_stack_adds_nothing_onto_a_stack_past_its_limit
    slots = Slots.new(1)
    slots.set(0, Block::DIRT, 70)
    assert_equal 5, slots.add_stack(Block::DIRT, 5, 0...1)
    assert_equal 70, slots.count(0)
  end

  def test_a_moved_tool_goes_only_into_an_empty_slot
    from = Slots.new(1)
    to = Slots.new(2)
    to.set(0, PICK, 3)
    from.set(0, PICK, 9)
    from.move_stack(0, to, 0...2)
    assert_equal [3, 9], [to.count(0), to.count(1)]
    assert from.empty?(0)
  end

  def test_a_click_with_an_empty_hand_picks_up_the_stack
    slots, hand = slots_and_hand(Block::DIRT, 5, Block::AIR, 0)
    slots.click(0, hand)
    assert slots.empty?(0)
    assert_equal [Block::DIRT, 5], [hand.block(0), hand.count(0)]
  end

  def test_a_click_on_an_empty_slot_with_an_empty_hand_does_nothing
    slots, hand = slots_and_hand(Block::AIR, 0, Block::AIR, 0)
    slots.click(0, hand)
    assert slots.empty?(0)
    assert hand.empty?(0)
  end

  def test_a_click_on_an_empty_slot_puts_the_stack_down
    slots, hand = slots_and_hand(Block::AIR, 0, Block::DIRT, 5)
    slots.click(0, hand)
    assert_equal [Block::DIRT, 5], [slots.block(0), slots.count(0)]
    assert hand.empty?(0)
  end

  def test_a_click_on_the_same_kind_fills_the_stack_and_keeps_the_rest
    slots, hand = slots_and_hand(Block::DIRT, 60, Block::DIRT, 10)
    slots.click(0, hand)
    assert_equal [64, 6], [slots.count(0), hand.count(0)]
    slots, hand = slots_and_hand(Block::DIRT, 10, Block::DIRT, 5)
    slots.click(0, hand)
    assert_equal 15, slots.count(0)
    assert hand.empty?(0)
  end

  def test_a_click_on_another_kind_or_a_tool_swaps_the_stacks
    slots, hand = slots_and_hand(Block::SAND, 3, Block::DIRT, 5)
    slots.click(0, hand)
    assert_equal [Block::DIRT, 5, Block::SAND, 3], [slots.block(0), slots.count(0), hand.block(0), hand.count(0)]
    slots, hand = slots_and_hand(PICK, 3, PICK, 9)
    slots.click(0, hand)
    assert_equal [3, 9], [hand.count(0), slots.count(0)]
  end

  def test_a_right_click_with_an_empty_hand_takes_the_larger_half
    slots, hand = slots_and_hand(Block::DIRT, 7, Block::AIR, 0)
    slots.click_half(0, hand)
    assert_equal [3, 4], [slots.count(0), hand.count(0)]
    slots, hand = slots_and_hand(PICK, 9, Block::AIR, 0)
    slots.click_half(0, hand)
    assert_equal [0, 9], [slots.count(0), hand.count(0)]
  end

  def test_a_right_click_on_an_empty_slot_with_an_empty_hand_does_nothing
    slots, hand = slots_and_hand(Block::AIR, 0, Block::AIR, 0)
    slots.click_half(0, hand)
    assert slots.empty?(0)
    assert hand.empty?(0)
  end

  def test_a_right_click_puts_down_one_item_on_an_empty_slot_or_the_same_kind
    slots, hand = slots_and_hand(Block::AIR, 0, Block::DIRT, 5)
    slots.click_half(0, hand)
    assert_equal [Block::DIRT, 1, 4], [slots.block(0), slots.count(0), hand.count(0)]
    slots.click_half(0, hand)
    assert_equal [2, 3], [slots.count(0), hand.count(0)]
  end

  def test_a_right_click_puts_nothing_on_a_full_stack
    slots, hand = slots_and_hand(Block::DIRT, 64, Block::DIRT, 5)
    slots.click_half(0, hand)
    assert_equal [64, 5], [slots.count(0), hand.count(0)]
  end

  def test_a_right_click_with_the_last_item_empties_the_hand
    slots, hand = slots_and_hand(Block::DIRT, 2, Block::DIRT, 1)
    slots.click_half(0, hand)
    assert_equal 3, slots.count(0)
    assert hand.empty?(0)
    assert_equal Block::AIR, hand.block(0)
  end

  def test_a_right_click_with_a_tool_or_on_another_kind_swaps
    slots, hand = slots_and_hand(Block::SAND, 3, Block::DIRT, 5)
    slots.click_half(0, hand)
    assert_equal [Block::DIRT, Block::SAND], [slots.block(0), hand.block(0)]
    slots, hand = slots_and_hand(Block::AIR, 0, PICK, 9)
    slots.click_half(0, hand)
    assert_equal [PICK, 9], [slots.block(0), slots.count(0)]
    assert hand.empty?(0)
  end

  def test_new_slots_are_empty_and_hold_air
    slots = Slots.new(2)
    assert_equal [Block::AIR, Block::AIR], [slots.block(0), slots.block(1)]
  end

  def test_a_copy_has_every_slot
    slots = Slots.new(2)
    slots.set(0, Block::SAND, 2)
    assert_equal [Block::SAND, 2], [slots.copy.block(0), slots.copy.count(0)]
  end

  def test_an_item_joins_a_stack_in_the_first_slot_and_a_stack_of_one
    slots = Slots.new(2)
    slots.set(0, Block::DIRT, 1)
    slots.add(Block::DIRT)
    assert_equal 2, slots.count(0)
    assert slots.empty?(1)
  end

  def test_an_item_does_not_join_a_stack_of_another_kind
    slots = Slots.new(2)
    slots.set(0, Block::SAND, 3)
    slots.add(Block::DIRT)
    assert_equal [Block::SAND, 3, Block::DIRT, 1], [slots.block(0), slots.count(0), slots.block(1), slots.count(1)]
  end

  def test_remove_takes_from_stacks_side_by_side_and_from_a_stack_of_one
    slots = Slots.new(3)
    slots.set(0, Block::DIRT, 1)
    slots.set(1, Block::DIRT, 2)
    slots.set(2, Block::DIRT, 2)
    slots.remove(Block::DIRT, 5)
    assert_equal 0, slots.total(Block::DIRT)
  end

  def test_remove_of_more_than_the_slots_hold_takes_all
    slots = Slots.new(2)
    slots.set(1, Block::DIRT, 3)
    slots.remove(Block::DIRT, 10)
    assert slots.empty?(1)
  end

  def test_a_moved_item_joins_a_stack_of_its_kind_and_a_stack_of_one
    from = Slots.new(1)
    to = Slots.new(2)
    to.set(1, Block::DIRT, 60)
    from.set(0, Block::DIRT, 1)
    from.move_stack(0, to, 0...2)
    assert_equal [0, 61], [to.count(0), to.count(1)]
    to.set(1, Block::DIRT, 1)
    from.set(0, Block::DIRT, 3)
    from.move_stack(0, to, 0...2)
    assert_equal [0, 4], [to.count(0), to.count(1)]
  end

  def test_a_moved_stack_of_one_goes_into_an_empty_slot
    from = Slots.new(1)
    to = Slots.new(1)
    from.set(0, Block::DIRT, 1)
    from.move_stack(0, to, 0...1)
    assert_equal 1, to.count(0)
    assert from.empty?(0)
  end

  def test_a_moved_stack_does_not_join_a_stack_past_the_range
    from = Slots.new(1)
    to = Slots.new(2)
    to.set(1, Block::DIRT, 3)
    from.set(0, Block::DIRT, 5)
    from.move_stack(0, to, 0...1)
    assert_equal [5, 3], [to.count(0), to.count(1)]
  end

  def test_a_click_with_one_item_in_the_hand_puts_it_down_or_swaps
    slots, hand = slots_and_hand(Block::AIR, 0, Block::DIRT, 1)
    slots.click(0, hand)
    assert_equal [Block::DIRT, 1], [slots.block(0), slots.count(0)]
    assert hand.empty?(0)
    slots, hand = slots_and_hand(Block::SAND, 3, Block::DIRT, 1)
    slots.click(0, hand)
    assert_equal [Block::DIRT, 1, Block::SAND, 3], [slots.block(0), slots.count(0), hand.block(0), hand.count(0)]
  end

  def test_a_click_picks_up_a_stack_of_one_and_merges_onto_it
    slots, hand = slots_and_hand(Block::DIRT, 1, Block::AIR, 0)
    slots.click(0, hand)
    assert_equal 1, hand.count(0)
    assert slots.empty?(0)
    slots, hand = slots_and_hand(Block::DIRT, 1, Block::DIRT, 5)
    slots.click(0, hand)
    assert_equal 6, slots.count(0)
    assert hand.empty?(0)
  end

  def test_a_right_click_takes_half_of_an_even_stack_and_all_of_one
    slots, hand = slots_and_hand(Block::DIRT, 6, Block::AIR, 0)
    slots.click_half(0, hand)
    assert_equal [3, 3], [slots.count(0), hand.count(0)]
    slots, hand = slots_and_hand(Block::DIRT, 1, Block::AIR, 0)
    slots.click_half(0, hand)
    assert_equal [0, 1], [slots.count(0), hand.count(0)]
  end

  def test_a_right_click_on_one_item_of_another_kind_swaps
    slots, hand = slots_and_hand(Block::SAND, 1, Block::DIRT, 5)
    slots.click_half(0, hand)
    assert_equal [Block::DIRT, 5, Block::SAND, 1], [slots.block(0), slots.count(0), hand.block(0), hand.count(0)]
  end

  # One slot with count of kind, and a hand with held_count of held.
  def slots_and_hand(kind, count, held, held_count)
    slots = Slots.new(1)
    slots.set(0, kind, count)
    hand = Slots.new(1)
    hand.set(0, held, held_count)
    [slots, hand]
  end
end
