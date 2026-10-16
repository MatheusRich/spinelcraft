require_relative "test_helper"

# One recipe: where it works, how many times the slots can make it, and the
# craft.
class RecipeTest < Minitest::Test
  HAND = Recipe::BY_HAND
  TABLE = Recipe::AT_TABLE
  FURNACE = Recipe::AT_FURNACE

  def test_a_crafting_table_makes_its_recipes_and_the_recipes_by_hand
    assert Recipe.makes?(HAND, HAND)
    refute Recipe.makes?(HAND, TABLE)
    refute Recipe.makes?(HAND, FURNACE)
    assert Recipe.makes?(TABLE, HAND)
    assert Recipe.makes?(TABLE, TABLE)
    refute Recipe.makes?(TABLE, FURNACE)
    assert Recipe.makes?(FURNACE, FURNACE)
    refute Recipe.makes?(FURNACE, HAND)
    refute Recipe.makes?(FURNACE, TABLE)
  end

  def test_a_recipe_can_be_made_as_many_times_as_its_scarcest_ingredient_allows
    slots = Slots.new(36)
    assert_equal 0, jack.craftable(slots)
    3.times { slots.add(Block::CARVED_PUMPKIN) }
    2.times { slots.add(Block::TORCH) }
    assert_equal 2, jack.craftable(slots)
    7.times { slots.add(Block::COBBLE) }
    assert_equal 2, pick.craftable(slots)
  end

  def test_any_kind_of_planks_counts_for_a_planks_ingredient
    slots = Slots.new(36)
    2.times { slots.add(Block::OAK_PLANKS) }
    2.times { slots.add(Block::BIRCH_PLANKS) }
    assert_equal 1, crafting_table.craftable(slots)
  end

  def test_the_ingredients_read_as_text
    assert_equal "4 PLANKS", crafting_table.need
    assert_equal "1 CARVED PUMPKIN + 1 TORCH", jack.need
  end

  def test_crafting_takes_the_ingredients_and_gives_the_results
    slots = Slots.new(36)
    3.times { slots.add(Block::OAK_LOG) }
    assert_equal 8, planks.craft(2, slots)
    assert_equal 1, slots.total(Block::OAK_LOG)
    assert_equal 8, slots.total(Block::OAK_PLANKS)
  end

  def test_crafting_takes_each_ingredient_for_each_result
    slots = Slots.new(36)
    2.times { slots.add(Block::CARVED_PUMPKIN) }
    3.times { slots.add(Block::TORCH) }
    assert_equal 2, jack.craft(100, slots)
    assert_equal 0, slots.total(Block::CARVED_PUMPKIN)
    assert_equal 1, slots.total(Block::TORCH)
    assert_equal 2, slots.total(Block::JACK_O_LANTERN)
  end

  def test_a_planks_ingredient_takes_the_first_kind_of_planks_first
    slots = Slots.new(36)
    3.times { slots.add(Block::SPRUCE_PLANKS) }
    2.times { slots.add(Block::OAK_PLANKS) }
    crafting_table.craft(1, slots)
    assert_equal 0, slots.total(Block::OAK_PLANKS)
    assert_equal 1, slots.total(Block::SPRUCE_PLANKS)
  end

  def test_a_planks_ingredient_takes_the_kinds_of_planks_in_their_order
    slots = Slots.new(36)
    [Block::OAK_PLANKS, Block::SPRUCE_PLANKS, Block::BIRCH_PLANKS].each { |b| 2.times { slots.add(b) } }
    crafting_table.craft(1, slots)
    assert_equal [0, 0, 2], [slots.total(Block::OAK_PLANKS), slots.total(Block::SPRUCE_PLANKS), slots.total(Block::BIRCH_PLANKS)]
  end

  def test_crafting_without_the_ingredients_makes_nothing
    slots = Slots.new(36)
    slots.add(Block::IRON_INGOT)
    assert_equal 0, shears.craft(1, slots)
    assert_equal 1, slots.total(Block::IRON_INGOT)
  end

  def test_a_slot_that_the_ingredients_empty_is_room_for_the_result
    slots = full_of(Block::DIRT)
    slots.set(0, Block::OAK_LOG, 1)
    assert_equal 4, planks.craft(1, slots)
    assert_equal Block::OAK_PLANKS, slots.block(0)
    assert_equal 4, slots.count(0)
  end

  def test_crafting_makes_fewer_when_the_results_do_not_fit
    slots = full_of(Block::DIRT)
    slots.set(0, Block::OAK_LOG, 3)
    slots.set(1, Block::OAK_PLANKS, Block.stack(Block::OAK_PLANKS) - 4)
    # The logs keep their slot until the last one goes, so 2 logs make room
    # only for the 4 planks that fill the planks stack.
    assert_equal 4, planks.craft(2, slots)
    assert_equal 2, slots.total(Block::OAK_LOG)
    assert_equal Block.stack(Block::OAK_PLANKS), slots.total(Block::OAK_PLANKS)
  end

  def test_crafting_into_a_full_inventory_makes_nothing_and_takes_nothing
    slots = full_of(Block::DIRT)
    slots.set(0, Block::COBBLE, 3)
    assert_equal 0, shovel.craft(1, slots)
    assert_equal 3, slots.total(Block::COBBLE)
    assert_equal 0, slots.total(Block::STONE_SHOVEL)
  end

  def test_a_recipe_is_made_at_its_station_and_a_hand_recipe_at_a_table
    assert torch.made_at?(HAND)
    assert torch.made_at?(TABLE)
    refute torch.made_at?(FURNACE)
    refute pick.made_at?(HAND)
  end

  def test_a_second_ingredient_of_two_counts_two_for_each_craft
    bed = Recipe.new(Block::WOOL, 1, Block::BED, 1, TABLE, Block::OAK_PLANKS, 2)
    slots = Slots.new(36)
    3.times { slots.add(Block::WOOL) }
    5.times { slots.add(Block::OAK_PLANKS) }
    assert_equal "1 WOOL + 2 OAK PLANKS", bed.need
    assert_equal 2, bed.craftable(slots)
    assert_equal 2, bed.craft(5, slots)
    assert_equal [1, 1], [slots.total(Block::WOOL), slots.total(Block::OAK_PLANKS)]
  end

  def planks = Recipe.new(Block::OAK_LOG, 1, Block::OAK_PLANKS, 4, HAND)
  def crafting_table = Recipe.new(Block::ANY_PLANKS, 4, Block::CRAFTING_TABLE, 1, HAND)
  def torch = Recipe.new(Block::COAL, 1, Block::TORCH, 4, HAND)
  def shears = Recipe.new(Block::IRON_INGOT, 2, Block::SHEARS, 1, HAND)
  def pick = Recipe.new(Block::COBBLE, 3, Block::STONE_PICK, 1, TABLE)
  def shovel = Recipe.new(Block::COBBLE, 1, Block::STONE_SHOVEL, 1, TABLE)
  def jack = Recipe.new(Block::CARVED_PUMPKIN, 1, Block::JACK_O_LANTERN, 1, HAND, Block::TORCH, 1)

  # 36 slots, each with a full stack of b.
  def full_of(b)
    slots = Slots.new(36)
    36.times { |i| slots.set(i, b, Block.stack(b)) }
    slots
  end
end
