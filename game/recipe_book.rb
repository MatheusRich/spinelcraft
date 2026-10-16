# The recipe book: the recipes, which of them the player has found, and the
# crafting math. A recipe shows in the list once the player has had its
# ingredient, with the NEW tag until the list closes. minecraft.wiki/w/Recipe_book
class RecipeBook
  # Where a recipe works: by hand (the E screen), on a crafting table, or in
  # a furnace (the screen that a right-click on one opens).
  BY_HAND = 0
  AT_TABLE = 1
  AT_FURNACE = 2
  # Each recipe: the ingredient, how many, the result, how many, and where.
  # The ingredient is a block, or Block::ANY_PLANKS. A recipe with a second
  # ingredient has it and how many at the end.
  # The recipe list shows two recipes to a row. The planks and the crafting
  # table come first, as the first things to make. The tools come next, in
  # pairs of one material, so that each kind of tool is a column: the
  # pickaxes and then the axes at the left, the swords and then the
  # shovels at the right.
  RECIPES = [[Block::OAK_LOG, 1, Block::OAK_PLANKS, 4, BY_HAND], [Block::SPRUCE_LOG, 1, Block::SPRUCE_PLANKS, 4, BY_HAND],
             [Block::BIRCH_LOG, 1, Block::BIRCH_PLANKS, 4, BY_HAND], [Block::ANY_PLANKS, 4, Block::CRAFTING_TABLE, 1, BY_HAND],
             [Block::ANY_PLANKS, 3, Block::WOOD_PICK, 1, AT_TABLE], [Block::ANY_PLANKS, 2, Block::WOOD_SWORD, 1, AT_TABLE],
             [Block::COBBLE, 3, Block::STONE_PICK, 1, AT_TABLE], [Block::COBBLE, 2, Block::STONE_SWORD, 1, AT_TABLE],
             [Block::IRON_INGOT, 3, Block::IRON_PICK, 1, AT_TABLE], [Block::IRON_INGOT, 2, Block::IRON_SWORD, 1, AT_TABLE],
             [Block::DIAMOND, 3, Block::DIAMOND_PICK, 1, AT_TABLE], [Block::DIAMOND, 2, Block::DIAMOND_SWORD, 1, AT_TABLE],
             [Block::ANY_PLANKS, 3, Block::WOOD_AXE, 1, AT_TABLE], [Block::ANY_PLANKS, 1, Block::WOOD_SHOVEL, 1, AT_TABLE],
             [Block::COBBLE, 3, Block::STONE_AXE, 1, AT_TABLE], [Block::COBBLE, 1, Block::STONE_SHOVEL, 1, AT_TABLE],
             [Block::IRON_INGOT, 3, Block::IRON_AXE, 1, AT_TABLE], [Block::IRON_INGOT, 1, Block::IRON_SHOVEL, 1, AT_TABLE],
             [Block::DIAMOND, 3, Block::DIAMOND_AXE, 1, AT_TABLE], [Block::DIAMOND, 1, Block::DIAMOND_SHOVEL, 1, AT_TABLE],
             [Block::COAL, 1, Block::TORCH, 4, BY_HAND], [Block::GRAVEL, 1, Block::ARROW, 4, AT_TABLE],
             [Block::STONE, 2, Block::BRICK, 1, AT_TABLE], [Block::WOOL, 3, Block::BED, 1, AT_TABLE],
             [Block::ANY_PLANKS, 5, Block::BOW, 1, AT_TABLE], [Block::ANY_PLANKS, 8, Block::CHEST, 1, AT_TABLE],
             [Block::ANY_PLANKS, 6, Block::DOOR, 3, AT_TABLE], [Block::ANY_PLANKS, 3, Block::LADDER, 4, AT_TABLE],
             [Block::WHEAT, 3, Block::BREAD, 1, AT_TABLE], [Block::IRON_INGOT, 3, Block::BUCKET, 1, AT_TABLE],
             [Block::COBBLE, 8, Block::FURNACE, 1, AT_TABLE],
             # minecraft.wiki/w/Sandstone shows 4 sand in the grid. It does not
             # give the count of sandstone in text; 1 is the count in Minecraft.
             [Block::SAND, 4, Block::SANDSTONE, 1, BY_HAND],
             # A boat takes 5 planks of its wood. minecraft.wiki/w/Boat
             [Block::OAK_PLANKS, 5, Block::OAK_BOAT, 1, AT_TABLE], [Block::SPRUCE_PLANKS, 5, Block::SPRUCE_BOAT, 1, AT_TABLE],
             [Block::BIRCH_PLANKS, 5, Block::BIRCH_BOAT, 1, AT_TABLE], [Block::IRON_INGOT, 2, Block::SHEARS, 1, BY_HAND],
             [Block::PUMPKIN, 1, Block::PUMPKIN_SEEDS, 4, BY_HAND], [Block::BONE, 1, Block::BONE_MEAL, 3, BY_HAND],
             [Block::CARVED_PUMPKIN, 1, Block::JACK_O_LANTERN, 1, BY_HAND, Block::TORCH, 1],
             [Block::IRON, 1, Block::IRON_INGOT, 1, AT_FURNACE], [Block::OAK_LOG, 1, Block::COAL, 1, AT_FURNACE],
             [Block::SPRUCE_LOG, 1, Block::COAL, 1, AT_FURNACE], [Block::BIRCH_LOG, 1, Block::COAL, 1, AT_FURNACE], [Block::PORKCHOP, 1, Block::COOKED_PORKCHOP, 1, AT_FURNACE],
             [Block::MUTTON, 1, Block::COOKED_MUTTON, 1, AT_FURNACE], [Block::BEEF, 1, Block::STEAK, 1, AT_FURNACE],
             [Block::RAW_CHICKEN, 1, Block::COOKED_CHICKEN, 1, AT_FURNACE],
             [Block::SAND, 1, Block::GLASS, 1, AT_FURNACE], [Block::COBBLE, 1, Block::STONE, 1, AT_FURNACE]]

  # The recipe list shows this many rows of two recipes. The wheel scrolls
  # the other rows into view.
  ROWS = 10

  def initialize
    # 1 for each block that the player has had. It stays through death and
    # goes into the save.
    @seen = Array.new(Block::COUNT, 0)
    # 1 for each recipe with the NEW tag.
    @fresh = Array.new(RECIPES.size, 0)
    # The first row in view, and the wheel steps not used yet.
    @top = 0
    @wheel = 0.0
  end

  # The first row of the recipe list in view.
  attr_reader :top

  # The ingredient of recipe k, its result, how many results it makes, and
  # where it works.
  def self.ingredient(k) = RECIPES[k][0]
  def self.result(k) = RECIPES[k][2]
  def self.result_count(k) = RECIPES[k][3]
  def self.where(k) = RECIPES[k][4]

  # True when a station open (BY_HAND, AT_TABLE or AT_FURNACE) makes the
  # recipes for where. A crafting table also makes the recipes by hand, as
  # in Minecraft.
  def self.makes?(open, where) = where == open || (where == BY_HAND && open == AT_TABLE)

  # Marks b as seen. Each recipe that b unlocks gets the NEW tag until the
  # recipe list closes. Returns the message that tells the player where to
  # make them, or "" when b unlocks nothing new.
  def see(b)
    return "" if @seen[b] == 1
    @seen[b] = 1
    found = 0
    last = 0
    at = [0, 0, 0]
    k = 0
    while k < RECIPES.size
      if Block.fillers(RECIPES[k][0]).include?(b)
        @fresh[k] = 1
        found += 1
        last = k
        at[RECIPES[k][4]] = 1
      end
      k += 1
    end
    return "" if found == 0
    places = Array.new(0, "")
    places << "PRESS E" if at[BY_HAND] == 1
    places << "AT A CRAFTING TABLE" if at[AT_TABLE] == 1
    places << "AT A FURNACE" if at[AT_FURNACE] == 1
    head = found == 1 ? "NEW RECIPE: #{Block::NAMES[RECIPES[last][2]]}" : "#{found} NEW RECIPES"
    "#{head} - #{places.join(", ")}"
  end

  # Marks b as seen, without the NEW tags, as a loaded save does.
  def learn(b)
    @seen[b] = 1
    nil
  end

  def seen?(b) = @seen[b] == 1

  # True when recipe k has the NEW tag.
  def fresh?(k) = @fresh[k] == 1

  # True when the player has seen a block that fills the recipe ingredient ing.
  def seen_ingredient?(ing) = Block.fillers(ing).any? { |b| @seen[b] == 1 }

  # The recipes that the list shows for the station open, in the order of
  # RECIPES: those that it makes, and whose ingredient the player has seen.
  # Other recipes stay a surprise.
  def shown(open)
    out = Array.new(0, 0)
    k = 0
    while k < RECIPES.size
      out << k if seen_ingredient?(RECIPES[k][0]) && RecipeBook.makes?(open, RECIPES[k][4])
      k += 1
    end
    out
  end

  # The recipes in view: ROWS rows of the shown recipes from row top on.
  def in_view(open)
    all = shown(open)
    view = Array.new(0, 0)
    j = @top * 2
    while j < all.size && view.size < ROWS * 2
      view << all[j]
      j += 1
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
    shown(open).each { |k| @fresh[k] = 0 }
    nil
  end

  # The second ingredient of recipe r and how many it takes, or 0 for a
  # recipe with one ingredient.
  def self.second_ingredient(r) = r.size > 5 ? r[5].to_i : 0
  def self.second_count(r) = r.size > 5 ? r[6].to_i : 0

  # How many of the recipe ingredient ing slots holds.
  def self.ingredient_total(ing, slots)
    fillers = Block.fillers(ing)
    n = 0
    i = 0
    while i < fillers.size
      n += slots.total(fillers[i])
      i += 1
    end
    n
  end

  # How many times slots has the ingredients of recipe k.
  def self.craftable(k, slots)
    r = RECIPES[k]
    n = ingredient_total(r[0], slots) / r[1]
    return n if second_ingredient(r) == 0
    m = ingredient_total(second_ingredient(r), slots) / second_count(r)
    m < n ? m : n
  end

  # The ingredients of recipe k as text, as "1 CARVED PUMPKIN + 1 TORCH".
  def self.need(k)
    r = RECIPES[k]
    text = "#{r[1]} #{Block.ingredient_name(r[0])}"
    return text if second_ingredient(r) == 0
    "#{text} + #{second_count(r)} #{Block.ingredient_name(second_ingredient(r))}"
  end

  # Crafts recipe k up to want times from slots, fewer times when the
  # results do not fit. Returns the count of results, 0 when none fit.
  def self.craft(k, want, slots)
    r = RECIPES[k]
    have = craftable(k, slots)
    times = want < have ? want : have
    while times > 0
      # Take the ingredients first: a slot that they empty is room for the result.
      trial = slots.copy
      take_ingredients(r, times, trial)
      break if trial.room_for(r[2]) >= r[3] * times
      times -= 1
    end
    return 0 if times == 0
    take_ingredients(r, times, slots)
    n = r[3] * times
    n.times { slots.add(r[2]) }
    n
  end

  # Takes the ingredients of times of recipe r from slots.
  def self.take_ingredients(r, times, slots)
    take_ingredient(r[0], r[1] * times, slots)
    take_ingredient(second_ingredient(r), second_count(r) * times, slots) if second_ingredient(r) > 0
    nil
  end

  # Takes n of the recipe ingredient ing: all that it needs of the first
  # block that fills it, then of the next one.
  def self.take_ingredient(ing, n, slots)
    fillers = Block.fillers(ing)
    i = 0
    while i < fillers.size && n > 0
      taken = slots.total(fillers[i]) < n ? slots.total(fillers[i]) : n
      slots.remove(fillers[i], taken)
      n -= taken
      i += 1
    end
    nil
  end

  # The smelting recipe for b, or -1 when a furnace does not smelt b.
  def self.smelt_recipe(b)
    k = 0
    while k < RECIPES.size
      return k if RECIPES[k][4] == AT_FURNACE && RECIPES[k][0] == b
      k += 1
    end
    -1
  end

  def self.smelts?(b) = smelt_recipe(b) >= 0
end
