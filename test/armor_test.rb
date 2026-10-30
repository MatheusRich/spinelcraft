require_relative "test_helper"

class ArmorTest < Minitest::Test
  IRON_SET = [Block::IRON_HELMET, Block::IRON_CHESTPLATE, Block::IRON_LEGGINGS, Block::IRON_BOOTS]
  DIAMOND_SET = [Block::DIAMOND_HELMET, Block::DIAMOND_CHESTPLATE, Block::DIAMOND_LEGGINGS, Block::DIAMOND_BOOTS]

  SPINEL_SET = [Block::SPINEL_HELMET, Block::SPINEL_CHESTPLATE, Block::SPINEL_LEGGINGS, Block::SPINEL_BOOTS]

  def worn(pieces)
    armor = Armor.new
    pieces.each { |piece| armor.put_on(piece, Block.uses(piece)) }
    armor
  end

  def test_no_armor_gives_no_points_and_the_whole_hit
    armor = Armor.new
    assert_equal 0, armor.points
    assert_equal 0, armor.toughness
    assert_in_delta 7.0, armor.reduce(7.0)
  end

  def test_each_piece_goes_into_the_slot_of_its_place
    armor = Armor.new
    assert_equal 0, armor.put_on(Block::DIAMOND_HELMET, 1)
    assert_equal 1, armor.put_on(Block::IRON_CHESTPLATE, 1)
    assert_equal 2, armor.put_on(Block::DIAMOND_LEGGINGS, 1)
    assert_equal 3, armor.put_on(Block::IRON_BOOTS, 1)
    assert_equal Block::DIAMOND_LEGGINGS, armor.slots.block(2)
  end

  def test_a_full_set_adds_up_the_points_and_the_toughness
    assert_equal 15, worn(IRON_SET).points
    assert_equal 0, worn(IRON_SET).toughness
    assert_equal 20, worn(DIAMOND_SET).points
    assert_equal 8, worn(DIAMOND_SET).toughness
  end

  def test_a_spinel_set_has_the_points_and_the_toughness_of_diamond_and_the_uses_of_iron
    assert_equal 20, worn(SPINEL_SET).points
    assert_equal 8, worn(SPINEL_SET).toughness
    assert_equal(IRON_SET.map { |piece| Block.uses(piece) }, SPINEL_SET.map { |piece| Block.uses(piece) })
    assert_equal([0, 1, 2, 3], SPINEL_SET.map { |piece| Block.armor_slot(piece) })
  end

  def test_a_set_of_four_spinel_pieces_is_a_spinel_set
    assert worn(SPINEL_SET).spinel_set?
    refute Armor.new.spinel_set?
  end

  def test_three_spinel_pieces_and_a_diamond_piece_are_not_a_spinel_set
    refute worn(SPINEL_SET[0, 3] + [Block::DIAMOND_BOOTS]).spinel_set?
    refute worn(SPINEL_SET[0, 3]).spinel_set?
    refute worn(SPINEL_SET[1, 3]).spinel_set?
    refute worn([Block::DIAMOND_HELMET] + SPINEL_SET[1, 3]).spinel_set?
    refute worn(DIAMOND_SET).spinel_set?
  end

  def test_breaking_all_takes_off_each_piece_and_gives_them
    armor = worn(SPINEL_SET)
    armor.slots.set(2, Block::SPINEL_LEGGINGS, 1)
    assert_equal SPINEL_SET, armor.break_all
    assert_equal 0, armor.points
    assert_equal [], Armor.new.break_all
  end

  def test_a_hit_loses_4_percent_for_each_point_minus_its_hardness
    # 6 points, no toughness: the cut is 6 - 4 * 1 / 8 = 5.5 of 25 parts.
    assert_in_delta 0.78, worn([Block::IRON_CHESTPLATE]).reduce(1.0)
  end

  def test_a_hard_hit_cuts_no_less_than_a_fifth_of_the_points
    # 6 points: 6 - 4 * 10 / 8 = 1 is below 6 / 5, so the cut is 1.2 of 25.
    assert_in_delta 9.52, worn([Block::IRON_CHESTPLATE]).reduce(10.0)
  end

  def test_toughness_keeps_more_of_a_hard_hit_off
    # 20 points, toughness 8: 20 - 4 * 10 / 16 = 17.5 of 25 parts.
    assert_in_delta 3.0, worn(DIAMOND_SET).reduce(10.0)
  end

  def test_a_hit_wears_each_piece_by_1_use
    armor = worn(IRON_SET)
    assert_empty armor.wear(3.0)
    assert_equal Block.uses(Block::IRON_BOOTS) - 1, armor.slots.count(3)
    assert_equal Block.uses(Block::IRON_HELMET) - 1, armor.slots.count(0)
  end

  def test_a_hit_wears_a_piece_by_1_use_for_each_4_damage
    armor = worn([Block::IRON_HELMET])
    armor.wear(9.0)
    assert_equal Block.uses(Block::IRON_HELMET) - 2, armor.slots.count(0)
  end

  def test_an_empty_slot_does_not_wear
    armor = worn([Block::IRON_HELMET])
    armor.wear(1.0)
    assert armor.slots.empty?(2)
  end

  def test_a_piece_with_no_uses_left_breaks_and_gives_no_more_points
    armor = Armor.new
    armor.put_on(Block::DIAMOND_BOOTS, 1)
    armor.put_on(Block::IRON_HELMET, 5)
    assert_equal [Block::DIAMOND_BOOTS], armor.wear(1.0)
    assert armor.slots.empty?(3)
    assert_equal 2, armor.points
    assert_equal 0, armor.toughness
  end

  def test_a_hard_hit_breaks_a_piece_that_has_fewer_uses_than_the_wear
    armor = Armor.new
    armor.put_on(Block::IRON_BOOTS, 2)
    assert_equal [Block::IRON_BOOTS], armor.wear(40.0)
    assert armor.slots.empty?(3)
  end

  def test_swapping_a_piece_in_gives_back_the_worn_piece
    armor = Armor.new
    armor.put_on(Block::IRON_HELMET, 100)
    inv = Slots.new(2)
    inv.set(1, Block::DIAMOND_HELMET, 300)
    armor.swap_with(inv, 1)
    assert_equal [Block::DIAMOND_HELMET, 300], [armor.slots.block(0), armor.slots.count(0)]
    assert_equal [Block::IRON_HELMET, 100], [inv.block(1), inv.count(1)]
  end

  def test_swapping_a_piece_in_for_an_empty_slot_empties_the_source
    armor = Armor.new
    inv = Slots.new(1)
    inv.set(0, Block::IRON_BOOTS, 50)
    armor.swap_with(inv, 0)
    assert inv.empty?(0)
    assert_equal Block::IRON_BOOTS, armor.slots.block(3)
  end

  def test_a_click_puts_on_only_the_piece_of_the_slot
    armor = Armor.new
    hand = Slots.new(1)
    hand.set(0, Block::IRON_BOOTS, 50)
    assert_equal false, armor.click(0, hand)
    assert armor.slots.empty?(0)
    assert_equal Block::IRON_BOOTS, hand.block(0)
    assert armor.click(3, hand)
    assert_equal Block::IRON_BOOTS, armor.slots.block(3)
    assert hand.empty?(0)
  end

  def test_a_click_refuses_what_is_not_armor
    armor = Armor.new
    hand = Slots.new(1)
    hand.set(0, Block::STONE, 5)
    # Stone maps to a slot number, so only Block.armor? refuses it.
    assert_equal false, armor.click(Block.armor_slot(Block::STONE), hand)
    assert_equal 5, hand.count(0)
  end

  def test_a_click_with_an_empty_hand_takes_the_piece_off
    armor = worn([Block::IRON_HELMET])
    hand = Slots.new(1)
    refute armor.click(0, hand)
    assert_equal Block::IRON_HELMET, hand.block(0)
    assert armor.slots.empty?(0)
  end

  def test_a_quick_move_puts_on_a_piece_only_when_its_slot_is_empty
    armor = Armor.new
    inv = Slots.new(2)
    inv.set(0, Block::IRON_HELMET, 10)
    inv.set(1, Block::DIAMOND_HELMET, 20)
    assert armor.quick_put_on(inv, 0)
    assert inv.empty?(0)
    assert_equal false, armor.quick_put_on(inv, 1)
    assert_equal Block::DIAMOND_HELMET, inv.block(1)
    assert_equal Block::IRON_HELMET, armor.slots.block(0)
  end

  def test_a_quick_move_leaves_what_is_not_armor
    inv = Slots.new(1)
    inv.set(0, Block::STONE, 5)
    assert_equal false, Armor.new.quick_put_on(inv, 0)
    assert_equal 5, inv.count(0)
  end
end
