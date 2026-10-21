require_relative "test_helper"

# The recipe book: the recipes, which of them the player has found, and
# the recipe list.
class RecipeBookTest < Minitest::Test
  HAND = Recipe::BY_HAND
  TABLE = Recipe::AT_TABLE
  FURNACE = Recipe::AT_FURNACE

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
    book.recipe_count.times do |index|
      ingredient = book.recipe(index).ingredient
      Block.fillers(ingredient).each { |b| book.learn(b) } unless [Block::COAL, Block::SPINEL, Block::BONE].include?(ingredient)
    end
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

  def test_a_feather_and_a_plank_make_four_arrows_at_a_crafting_table
    book = RecipeBook.new
    assert_equal "", book.see(Block::GRAVEL)
    assert_equal "NEW RECIPE: ARROW - AT A CRAFTING TABLE", book.see(Block::FEATHER)
    arrow = book.recipe(recipe_for(Block::ARROW))
    slots = Slots.new(36)
    2.times { slots.add(Block::FEATHER) }
    slots.add(Block::BIRCH_PLANKS)
    assert_equal "1 FEATHER + 1 PLANKS", arrow.need
    assert_equal 4, arrow.craft(2, slots)
    assert_equal [4, 1, 0], [slots.total(Block::ARROW), slots.total(Block::FEATHER), slots.total(Block::BIRCH_PLANKS)]
  end

  def test_a_bed_takes_three_wool_and_three_planks_of_any_wood
    bed = RecipeBook.new.recipe(recipe_for(Block::BED))
    slots = Slots.new(36)
    3.times { slots.add(Block::WOOL) }
    assert_equal 0, bed.craftable(slots)
    2.times { slots.add(Block::OAK_PLANKS) }
    slots.add(Block::SPRUCE_PLANKS)
    assert_equal "3 WOOL + 3 PLANKS", bed.need
    assert_equal 1, bed.craft(1, slots)
    assert_equal [1, 0, 0, 0], [slots.total(Block::BED), slots.total(Block::WOOL), slots.total(Block::OAK_PLANKS), slots.total(Block::SPRUCE_PLANKS)]
  end

  def test_a_pumpkin_and_an_egg_make_a_pumpkin_pie_by_hand
    book = RecipeBook.new
    assert_equal "2 NEW RECIPES - PRESS E", book.see(Block::PUMPKIN)
    pie = book.recipe(recipe_for(Block::PUMPKIN_PIE))
    assert pie.made_at?(HAND)
    slots = Slots.new(36)
    2.times { slots.add(Block::PUMPKIN) }
    slots.add(Block::EGG)
    assert_equal "1 PUMPKIN + 1 EGG", pie.need
    assert_equal 1, pie.craft(2, slots)
    assert_equal [1, 1, 0], [slots.total(Block::PUMPKIN_PIE), slots.total(Block::PUMPKIN), slots.total(Block::EGG)]
    assert_operator Block.food(Block::PUMPKIN_PIE), :>, 0
  end

  def test_a_furnace_smelts_the_ingredient_of_its_recipes
    book = RecipeBook.new
    assert_same book.recipe(recipe_for(Block::IRON_INGOT)), book.smelt_recipe(Block::IRON)
    assert book.smelts?(Block::SAND)
    refute book.smelts?(Block::OAK_PLANKS)
    assert_nil book.smelt_recipe(Block::DIRT)
    assert_nil book.smelt_recipe(Block::OAK_PLANKS)
  end

  # The index of the recipe that makes b.
  def recipe_for(b)
    book = RecipeBook.new
    (0...book.recipe_count).find { |index| book.recipe(index).result == b }
  end

  # A book that has seen the ingredient of each recipe.
  def all_seen
    book = RecipeBook.new
    book.recipe_count.times { |index| Block.fillers(book.recipe(index).ingredient).each { |b| book.learn(b) } }
    book
  end

end
