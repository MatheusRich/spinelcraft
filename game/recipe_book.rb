# The recipe book: the recipes, which of them the player has found, and the
# scroll of the recipe list. A recipe shows in the list once the player has
# had its ingredient, with the NEW tag until the list closes.
# minecraft.wiki/w/Recipe_book
class RecipeBook
  # The recipe list shows this many rows of two recipes. The wheel scrolls
  # the other rows into view.
  ROWS = 10

  def initialize
    # The recipes, in the order of the list: two to a row. The planks and
    # the crafting table come first, as the first things to make. The tools
    # come next, in pairs of one material, so that each kind of tool is a
    # column: the pickaxes and then the axes at the left, the swords and
    # then the shovels at the right.
    @recipes = [Recipe.new(Block::OAK_LOG, 1, Block::OAK_PLANKS, 4, Recipe::BY_HAND), Recipe.new(Block::SPRUCE_LOG, 1, Block::SPRUCE_PLANKS, 4, Recipe::BY_HAND),
                Recipe.new(Block::BIRCH_LOG, 1, Block::BIRCH_PLANKS, 4, Recipe::BY_HAND), Recipe.new(Block::ANY_PLANKS, 4, Block::CRAFTING_TABLE, 1, Recipe::BY_HAND),
                Recipe.new(Block::ANY_PLANKS, 3, Block::WOOD_PICK, 1, Recipe::AT_TABLE), Recipe.new(Block::ANY_PLANKS, 2, Block::WOOD_SWORD, 1, Recipe::AT_TABLE),
                Recipe.new(Block::COBBLE, 3, Block::STONE_PICK, 1, Recipe::AT_TABLE), Recipe.new(Block::COBBLE, 2, Block::STONE_SWORD, 1, Recipe::AT_TABLE),
                Recipe.new(Block::IRON_INGOT, 3, Block::IRON_PICK, 1, Recipe::AT_TABLE), Recipe.new(Block::IRON_INGOT, 2, Block::IRON_SWORD, 1, Recipe::AT_TABLE),
                Recipe.new(Block::DIAMOND, 3, Block::DIAMOND_PICK, 1, Recipe::AT_TABLE), Recipe.new(Block::DIAMOND, 2, Block::DIAMOND_SWORD, 1, Recipe::AT_TABLE),
                Recipe.new(Block::ANY_PLANKS, 3, Block::WOOD_AXE, 1, Recipe::AT_TABLE), Recipe.new(Block::ANY_PLANKS, 1, Block::WOOD_SHOVEL, 1, Recipe::AT_TABLE),
                Recipe.new(Block::COBBLE, 3, Block::STONE_AXE, 1, Recipe::AT_TABLE), Recipe.new(Block::COBBLE, 1, Block::STONE_SHOVEL, 1, Recipe::AT_TABLE),
                Recipe.new(Block::IRON_INGOT, 3, Block::IRON_AXE, 1, Recipe::AT_TABLE), Recipe.new(Block::IRON_INGOT, 1, Block::IRON_SHOVEL, 1, Recipe::AT_TABLE),
                Recipe.new(Block::DIAMOND, 3, Block::DIAMOND_AXE, 1, Recipe::AT_TABLE), Recipe.new(Block::DIAMOND, 1, Block::DIAMOND_SHOVEL, 1, Recipe::AT_TABLE),
                # Minecraft has no mattock: 3 spinel is a choice for balance.
                Recipe.new(Block::SPINEL, 3, Block::SPINEL_MATTOCK, 1, Recipe::AT_TABLE),
                Recipe.new(Block::COAL, 1, Block::TORCH, 4, Recipe::BY_HAND),
                # Minecraft makes 4 arrows of a flint, a stick and a feather
                # (minecraft.wiki/w/Arrow). The game has no flint and no
                # sticks, so a plank takes the place of both.
                Recipe.new(Block::FEATHER, 1, Block::ARROW, 4, Recipe::AT_TABLE, Block::ANY_PLANKS, 1),
                Recipe.new(Block::STONE, 2, Block::BRICK, 1, Recipe::AT_TABLE),
                # minecraft.wiki/w/Bed shows 3 wool over 3 planks of any wood
                # in the grid. Its text does not give the counts.
                Recipe.new(Block::WOOL, 3, Block::BED, 1, Recipe::AT_TABLE, Block::ANY_PLANKS, 3),
                Recipe.new(Block::ANY_PLANKS, 5, Block::BOW, 1, Recipe::AT_TABLE), Recipe.new(Block::ANY_PLANKS, 8, Block::CHEST, 1, Recipe::AT_TABLE),
                Recipe.new(Block::ANY_PLANKS, 6, Block::DOOR, 3, Recipe::AT_TABLE), Recipe.new(Block::ANY_PLANKS, 3, Block::LADDER, 4, Recipe::AT_TABLE),
                Recipe.new(Block::WHEAT, 3, Block::BREAD, 1, Recipe::AT_TABLE), Recipe.new(Block::IRON_INGOT, 3, Block::BUCKET, 1, Recipe::AT_TABLE),
                Recipe.new(Block::COBBLE, 8, Block::FURNACE, 1, Recipe::AT_TABLE),
                # minecraft.wiki/w/Sandstone shows 4 sand in the grid. It does not
                # give the count of sandstone in text; 1 is the count in Minecraft.
                Recipe.new(Block::SAND, 4, Block::SANDSTONE, 1, Recipe::BY_HAND),
                # A boat takes 5 planks of its wood. minecraft.wiki/w/Boat
                Recipe.new(Block::OAK_PLANKS, 5, Block::OAK_BOAT, 1, Recipe::AT_TABLE), Recipe.new(Block::SPRUCE_PLANKS, 5, Block::SPRUCE_BOAT, 1, Recipe::AT_TABLE),
                Recipe.new(Block::BIRCH_PLANKS, 5, Block::BIRCH_BOAT, 1, Recipe::AT_TABLE), Recipe.new(Block::IRON_INGOT, 2, Block::SHEARS, 1, Recipe::BY_HAND),
                Recipe.new(Block::PUMPKIN, 1, Block::PUMPKIN_SEEDS, 4, Recipe::BY_HAND),
                # Minecraft makes a pumpkin pie of a pumpkin, sugar and an egg
                # (minecraft.wiki/w/Pumpkin_Pie). The game has no sugar.
                Recipe.new(Block::PUMPKIN, 1, Block::PUMPKIN_PIE, 1, Recipe::BY_HAND, Block::EGG, 1),
                Recipe.new(Block::BONE, 1, Block::BONE_MEAL, 3, Recipe::BY_HAND),
                Recipe.new(Block::CARVED_PUMPKIN, 1, Block::JACK_O_LANTERN, 1, Recipe::BY_HAND, Block::TORCH, 1),
                Recipe.new(Block::IRON, 1, Block::IRON_INGOT, 1, Recipe::AT_FURNACE), Recipe.new(Block::OAK_LOG, 1, Block::COAL, 1, Recipe::AT_FURNACE),
                Recipe.new(Block::SPRUCE_LOG, 1, Block::COAL, 1, Recipe::AT_FURNACE), Recipe.new(Block::BIRCH_LOG, 1, Block::COAL, 1, Recipe::AT_FURNACE), Recipe.new(Block::PORKCHOP, 1, Block::COOKED_PORKCHOP, 1, Recipe::AT_FURNACE),
                Recipe.new(Block::MUTTON, 1, Block::COOKED_MUTTON, 1, Recipe::AT_FURNACE), Recipe.new(Block::BEEF, 1, Block::STEAK, 1, Recipe::AT_FURNACE),
                Recipe.new(Block::RAW_CHICKEN, 1, Block::COOKED_CHICKEN, 1, Recipe::AT_FURNACE),
                Recipe.new(Block::SAND, 1, Block::GLASS, 1, Recipe::AT_FURNACE), Recipe.new(Block::COBBLE, 1, Block::STONE, 1, Recipe::AT_FURNACE)]
    # 1 for each block that the player has had. It stays through death and
    # goes into the save.
    @seen = Array.new(Block::COUNT, 0)
    # 1 for each recipe with the NEW tag.
    @fresh = Array.new(@recipes.size, 0)
    # The first row in view, and the wheel steps not used yet.
    @top = 0
    @wheel = 0.0
  end

  # The first row of the recipe list in view.
  attr_reader :top

  # The recipe at index in the list.
  def recipe(index) = @recipes[index]

  def recipe_count = @recipes.size

  # The recipe that smelts b in a furnace, or nil.
  def smelt_recipe(b)
    @recipes.size.times do |index|
      recipe = @recipes[index]
      return recipe if recipe.where == Recipe::AT_FURNACE && recipe.ingredient == b
    end
    nil
  end

  def smelts?(b) = !smelt_recipe(b).nil?

  # Marks b as seen. Each recipe that b unlocks gets the NEW tag until the
  # recipe list closes. Returns the message that tells the player where to
  # make them, or "" when b unlocks nothing new.
  def see(b)
    return "" if @seen[b] == 1
    @seen[b] = 1
    found = 0
    last = 0
    stations = [0, 0, 0]
    @recipes.size.times do |index|
      recipe = @recipes[index]
      if Block.fillers(recipe.ingredient).include?(b)
        @fresh[index] = 1
        found += 1
        last = index
        stations[recipe.where] = 1
      end
    end
    return "" if found == 0
    places = Array.new(0, "")
    places << "PRESS E" if stations[Recipe::BY_HAND] == 1
    places << "AT A CRAFTING TABLE" if stations[Recipe::AT_TABLE] == 1
    places << "AT A FURNACE" if stations[Recipe::AT_FURNACE] == 1
    head = found == 1 ? "NEW RECIPE: #{Block::NAMES[@recipes[last].result]}" : "#{found} NEW RECIPES"
    "#{head} - #{places.join(", ")}"
  end

  # Marks b as seen, without the NEW tags, as a loaded save does.
  def learn(b)
    @seen[b] = 1
    nil
  end

  def seen?(b) = @seen[b] == 1

  # True when the recipe at index has the NEW tag.
  def fresh?(index) = @fresh[index] == 1

  # True when the player has seen a block that fills the recipe ingredient ing.
  def seen_ingredient?(ing) = Block.fillers(ing).any? { |b| @seen[b] == 1 }

  # The indexes of the recipes that the list shows for the station open, in
  # the order of the list: those that it makes, and whose ingredient the
  # player has seen. Other recipes stay a surprise.
  def shown(open)
    out = Array.new(0, 0)
    @recipes.size.times do |index|
      recipe = @recipes[index]
      out << index if seen_ingredient?(recipe.ingredient) && recipe.made_at?(open)
    end
    out
  end

  # The indexes of the recipes in view: ROWS rows of the shown recipes from
  # row top on.
  def in_view(open)
    all = shown(open)
    view = Array.new(0, 0)
    place = @top * 2
    while place < all.size && view.size < ROWS * 2
      view << all[place]
      place += 1
    end
    view
  end

  # Scrolls the list by rows. The last row does not go above the bottom of
  # the list.
  def scroll_by(rows, open)
    most = (shown(open).size + 1) / 2 - ROWS
    @top += rows
    @top = most if @top > most
    @top = 0 if @top < 0
    nil
  end

  # The wheel scrolls the list a row for each step. A trackpad sends parts
  # of a step, and the parts add up.
  def turn_wheel(steps, open)
    @wheel += steps
    while @wheel >= 1.0
      scroll_by(-1, open)
      @wheel -= 1.0
    end
    while @wheel <= -1.0
      scroll_by(1, open)
      @wheel += 1.0
    end
    nil
  end

  # The list opens at the top.
  def open_list
    @top = 0
    @wheel = 0.0
    nil
  end

  # The player saw the NEW tags of the recipes that the list showed.
  def close_list(open)
    shown(open).each { |index| @fresh[index] = 0 }
    nil
  end
end
