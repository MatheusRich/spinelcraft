require_relative "test_helper"

# The recipe book: which recipes the player has found, the recipe list,
# and the crafting math.
class RecipeBookTest < Minitest::Test
  HAND = RecipeBook::BY_HAND
  TABLE = RecipeBook::AT_TABLE
  FURNACE = RecipeBook::AT_FURNACE

  def test_a_recipe_has_an_ingredient_a_result_a_count_and_a_station
    planks = recipe_for(Block::OAK_PLANKS)
    assert_equal [Block::OAK_LOG, Block::OAK_PLANKS, 4, HAND],
                 [RecipeBook.ingredient(planks), RecipeBook.result(planks), RecipeBook.result_count(planks), RecipeBook.where(planks)]
    iron = recipe_for(Block::IRON_INGOT)
    assert_equal [Block::IRON, Block::IRON_INGOT, 1, FURNACE],
                 [RecipeBook.ingredient(iron), RecipeBook.result(iron), RecipeBook.result_count(iron), RecipeBook.where(iron)]
  end

  def test_a_crafting_table_makes_its_recipes_and_the_recipes_by_hand
    assert RecipeBook.makes?(HAND, HAND)
    refute RecipeBook.makes?(HAND, TABLE)
    refute RecipeBook.makes?(HAND, FURNACE)
    assert RecipeBook.makes?(TABLE, HAND)
    assert RecipeBook.makes?(TABLE, TABLE)
    refute RecipeBook.makes?(TABLE, FURNACE)
    assert RecipeBook.makes?(FURNACE, FURNACE)
    refute RecipeBook.makes?(FURNACE, HAND)
    refute RecipeBook.makes?(FURNACE, TABLE)
  end

  def test_a_new_ingredient_tells_how_many_recipes_it_unlocks_and_where
    book = RecipeBook.new
    assert_equal "2 NEW RECIPES - PRESS E, AT A FURNACE", book.see(Block::OAK_LOG)
    assert_equal "10 NEW RECIPES - PRESS E, AT A CRAFTING TABLE", book.see(Block::OAK_PLANKS)
    assert_equal "NEW RECIPE: IRON INGOT - AT A FURNACE", book.see(Block::IRON)
  end

  def test_an_ingredient_tells_nothing_the_second_time_or_when_it_unlocks_nothing
    book = RecipeBook.new
    book.see(Block::OAK_LOG)
    assert_equal "", book.see(Block::OAK_LOG)
    assert_equal "", book.see(Block::STONE_PICK)
    assert book.seen?(Block::STONE_PICK)
  end

  def test_a_recipe_has_the_new_tag_until_the_list_closes
    book = RecipeBook.new
    planks = recipe_for(Block::OAK_PLANKS)
    refute book.fresh?(planks)
    book.see(Block::OAK_LOG)
    assert book.fresh?(planks)
    book.close_list(HAND)
    refute book.fresh?(planks)
  end

  def test_closing_a_list_keeps_the_tags_of_the_recipes_that_it_did_not_show
    book = RecipeBook.new
    book.see(Block::OAK_LOG)
    book.close_list(TABLE)
    refute book.fresh?(recipe_for(Block::OAK_PLANKS))
    assert book.fresh?(recipe_for(Block::COAL))
  end

  def test_a_loaded_ingredient_is_seen_without_new_tags
    book = RecipeBook.new
    refute book.seen?(Block::OAK_LOG)
    book.learn(Block::OAK_LOG)
    assert book.seen?(Block::OAK_LOG)
    refute book.fresh?(recipe_for(Block::OAK_PLANKS))
    assert_equal [recipe_for(Block::OAK_PLANKS)], book.shown(HAND)
    assert_equal "", book.see(Block::OAK_LOG)
  end

  def test_the_list_shows_the_recipes_of_seen_ingredients_that_the_station_makes
    book = RecipeBook.new
    assert_empty book.shown(TABLE)
    book.see(Block::BIRCH_PLANKS)
    hand = book.shown(HAND)
    table = book.shown(TABLE)
    assert_equal [recipe_for(Block::CRAFTING_TABLE)], hand
    assert_includes table, recipe_for(Block::CRAFTING_TABLE)
    assert_includes table, recipe_for(Block::WOOD_PICK)
    refute_includes table, recipe_for(Block::STONE_PICK)
    assert_equal table.sort, table
    assert_empty book.shown(FURNACE)
  end

  def test_the_view_shows_rows_of_the_list_from_the_top_row
    book = all_seen
    shown = book.shown(TABLE)
    assert_equal shown[0, RecipeBook::ROWS * 2], book.in_view(TABLE)
    book.scroll_by(2, TABLE)
    assert_equal 2, book.top
    assert_equal shown[4, RecipeBook::ROWS * 2], book.in_view(TABLE)
  end

  def test_the_list_scrolls_to_its_last_row_and_no_further
    book = all_seen
    rows = (book.shown(TABLE).size + 1) / 2
    book.scroll_by(100, TABLE)
    assert_equal rows - RecipeBook::ROWS, book.top
    view = book.in_view(TABLE)
    assert_equal book.shown(TABLE).last, view.last
    book.scroll_by(-100, TABLE)
    assert_equal 0, book.top
  end

  def test_a_list_with_full_rows_scrolls_to_its_last_row
    book = RecipeBook.new
    RecipeBook::RECIPES.each { |r| Block.fillers(r[0]).each { |b| book.learn(b) } unless r[0] == Block::COAL }
    assert_equal 38, book.shown(TABLE).size
    book.scroll_by(100, TABLE)
    assert_equal 19 - RecipeBook::ROWS, book.top
    assert_equal book.shown(TABLE).last, book.in_view(TABLE).last
  end

  def test_a_short_list_does_not_scroll
    book = RecipeBook.new
    book.see(Block::OAK_LOG)
    book.scroll_by(3, HAND)
    assert_equal 0, book.top
  end

  def test_each_wheel_step_scrolls_a_row_and_parts_of_a_step_add_up
    book = all_seen
    book.turn_wheel(-2.0, TABLE)
    assert_equal 2, book.top
    book.turn_wheel(0.6, TABLE)
    assert_equal 2, book.top
    book.turn_wheel(0.6, TABLE)
    assert_equal 1, book.top
    book.turn_wheel(-0.5, TABLE)
    assert_equal 1, book.top
    book.turn_wheel(-0.5, TABLE)
    assert_equal 1, book.top
    book.turn_wheel(-0.4, TABLE)
    assert_equal 2, book.top
  end

  def test_one_whole_wheel_step_up_scrolls_one_row_up
    book = all_seen
    book.scroll_by(2, TABLE)
    book.turn_wheel(1.0, TABLE)
    assert_equal 1, book.top
  end

  def test_the_list_opens_at_the_top_without_parts_of_a_wheel_step
    book = all_seen
    book.scroll_by(3, TABLE)
    book.turn_wheel(-0.75, TABLE)
    book.open_list
    assert_equal 0, book.top
    book.turn_wheel(-0.75, TABLE)
    assert_equal 0, book.top
  end

  def test_a_recipe_can_be_made_as_many_times_as_its_scarcest_ingredient_allows
    slots = Slots.new(36)
    jack = recipe_for(Block::JACK_O_LANTERN)
    assert_equal 0, RecipeBook.craftable(jack, slots)
    3.times { slots.add(Block::CARVED_PUMPKIN) }
    2.times { slots.add(Block::TORCH) }
    assert_equal 2, RecipeBook.craftable(jack, slots)
    7.times { slots.add(Block::COBBLE) }
    assert_equal 2, RecipeBook.craftable(recipe_for(Block::STONE_PICK), slots)
  end

  def test_any_kind_of_planks_counts_for_a_planks_ingredient
    slots = Slots.new(36)
    2.times { slots.add(Block::OAK_PLANKS) }
    2.times { slots.add(Block::BIRCH_PLANKS) }
    assert_equal 1, RecipeBook.craftable(recipe_for(Block::CRAFTING_TABLE), slots)
  end

  def test_the_ingredients_read_as_text
    assert_equal "4 PLANKS", RecipeBook.need(recipe_for(Block::CRAFTING_TABLE))
    assert_equal "1 CARVED PUMPKIN + 1 TORCH", RecipeBook.need(recipe_for(Block::JACK_O_LANTERN))
  end

  def test_crafting_takes_the_ingredients_and_gives_the_results
    slots = Slots.new(36)
    3.times { slots.add(Block::OAK_LOG) }
    assert_equal 8, RecipeBook.craft(recipe_for(Block::OAK_PLANKS), 2, slots)
    assert_equal 1, slots.total(Block::OAK_LOG)
    assert_equal 8, slots.total(Block::OAK_PLANKS)
  end

  def test_crafting_takes_each_ingredient_for_each_result
    slots = Slots.new(36)
    2.times { slots.add(Block::CARVED_PUMPKIN) }
    3.times { slots.add(Block::TORCH) }
    assert_equal 2, RecipeBook.craft(recipe_for(Block::JACK_O_LANTERN), 100, slots)
    assert_equal 0, slots.total(Block::CARVED_PUMPKIN)
    assert_equal 1, slots.total(Block::TORCH)
    assert_equal 2, slots.total(Block::JACK_O_LANTERN)
  end

  def test_a_planks_ingredient_takes_the_first_kind_of_planks_first
    slots = Slots.new(36)
    3.times { slots.add(Block::SPRUCE_PLANKS) }
    2.times { slots.add(Block::OAK_PLANKS) }
    RecipeBook.craft(recipe_for(Block::CRAFTING_TABLE), 1, slots)
    assert_equal 0, slots.total(Block::OAK_PLANKS)
    assert_equal 1, slots.total(Block::SPRUCE_PLANKS)
  end

  def test_a_planks_ingredient_takes_the_kinds_of_planks_in_their_order
    slots = Slots.new(36)
    [Block::OAK_PLANKS, Block::SPRUCE_PLANKS, Block::BIRCH_PLANKS].each { |b| 2.times { slots.add(b) } }
    RecipeBook.craft(recipe_for(Block::CRAFTING_TABLE), 1, slots)
    assert_equal [0, 0, 2], [slots.total(Block::OAK_PLANKS), slots.total(Block::SPRUCE_PLANKS), slots.total(Block::BIRCH_PLANKS)]
  end

  def test_crafting_without_the_ingredients_makes_nothing
    slots = Slots.new(36)
    slots.add(Block::IRON_INGOT)
    assert_equal 0, RecipeBook.craft(recipe_for(Block::SHEARS), 1, slots)
    assert_equal 1, slots.total(Block::IRON_INGOT)
  end

  def test_a_slot_that_the_ingredients_empty_is_room_for_the_result
    slots = full_of(Block::DIRT)
    slots.set(0, Block::OAK_LOG, 1)
    assert_equal 4, RecipeBook.craft(recipe_for(Block::OAK_PLANKS), 1, slots)
    assert_equal Block::OAK_PLANKS, slots.block(0)
    assert_equal 4, slots.count(0)
  end

  def test_crafting_makes_fewer_when_the_results_do_not_fit
    slots = full_of(Block::DIRT)
    slots.set(0, Block::OAK_LOG, 3)
    slots.set(1, Block::OAK_PLANKS, Block.stack(Block::OAK_PLANKS) - 4)
    # The logs keep their slot until the last one goes, so 2 logs make room
    # only for the 4 planks that fill the planks stack.
    assert_equal 4, RecipeBook.craft(recipe_for(Block::OAK_PLANKS), 2, slots)
    assert_equal 2, slots.total(Block::OAK_LOG)
    assert_equal Block.stack(Block::OAK_PLANKS), slots.total(Block::OAK_PLANKS)
  end

  def test_crafting_into_a_full_inventory_makes_nothing_and_takes_nothing
    slots = full_of(Block::DIRT)
    slots.set(0, Block::COBBLE, 3)
    assert_equal 0, RecipeBook.craft(recipe_for(Block::STONE_SHOVEL), 1, slots)
    assert_equal 3, slots.total(Block::COBBLE)
    assert_equal 0, slots.total(Block::STONE_SHOVEL)
  end

  def test_a_furnace_smelts_the_ingredient_of_its_recipes
    assert_equal recipe_for(Block::IRON_INGOT), RecipeBook.smelt_recipe(Block::IRON)
    assert RecipeBook.smelts?(Block::SAND)
    refute RecipeBook.smelts?(Block::OAK_PLANKS)
    assert_equal(-1, RecipeBook.smelt_recipe(Block::DIRT))
  end

  def recipe_for(b) = RecipeBook::RECIPES.index { |r| r[2] == b }

  # A book that has seen the ingredient of each recipe.
  def all_seen
    book = RecipeBook.new
    RecipeBook::RECIPES.each { |r| Block.fillers(r[0]).each { |b| book.learn(b) } }
    book
  end

  # 36 slots, each with a full stack of b.
  def full_of(b)
    slots = Slots.new(36)
    36.times { |i| slots.set(i, b, Block.stack(b)) }
    slots
  end
end
