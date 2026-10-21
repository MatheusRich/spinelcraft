# One recipe: an ingredient and how many, an optional second ingredient,
# the result and how many, and the station where it works.
# minecraft.wiki/w/Crafting
class Recipe
  # Where a recipe works: by hand (the E screen), on a crafting table, or in
  # a furnace (the screen that a right-click on one opens).
  BY_HAND = 0
  AT_TABLE = 1
  AT_FURNACE = 2

  # The ingredient is a block, or Block::ANY_PLANKS.
  attr_reader :ingredient, :result, :result_count, :where

  # second is 0 for a recipe with one ingredient.
  def initialize(ingredient, count, result, result_count, where, second = 0, second_count = 0)
    @ingredient = ingredient
    @count = count
    @result = result
    @result_count = result_count
    @where = where
    @second = second
    @second_count = second_count
  end

  # True when the station open makes the recipes for where. A crafting
  # table also makes the recipes by hand, as in Minecraft.
  def self.makes?(open, where) = where == open || (where == BY_HAND && open == AT_TABLE)

  # How many of the ingredient ing slots holds: each block that fills it
  # counts.
  def self.supply(ing, slots)
    fillers = Block.fillers(ing)
    total = 0
    fillers.each { |filler| total += slots.total(filler) }
    total
  end

  # Takes wanted of the ingredient ing from slots: all that it needs of the
  # first block that fills it, then of the next one.
  def self.take_from(slots, ing, wanted)
    fillers = Block.fillers(ing)
    index = 0
    while index < fillers.size && wanted > 0
      taken = slots.total(fillers[index]) < wanted ? slots.total(fillers[index]) : wanted
      slots.remove(fillers[index], taken)
      wanted -= taken
      index += 1
    end
    nil
  end

  def made_at?(open) = Recipe.makes?(open, @where)

  # How many times slots has the ingredients.
  def craftable(slots)
    times = Recipe.supply(@ingredient, slots) / @count
    return times if @second == 0

    second_times = Recipe.supply(@second, slots) / @second_count
    second_times < times ? second_times : times
  end

  # The ingredients as text, as "1 CARVED PUMPKIN + 1 TORCH".
  def need
    text = "#{@count} #{Block.ingredient_name(@ingredient)}"
    return text if @second == 0

    "#{text} + #{@second_count} #{Block.ingredient_name(@second)}"
  end

  # Crafts up to want times from slots, fewer times when the results do not
  # fit. Returns the count of results, 0 when none fit.
  def craft(want, slots)
    have = craftable(slots)
    times = want < have ? want : have
    while times > 0
      # Take the ingredients first: a slot that they empty is room for the result.
      trial = slots.copy
      use_up(times, trial)
      break if trial.room_for(@result) >= @result_count * times

      times -= 1
    end
    return 0 if times == 0

    use_up(times, slots)
    made = @result_count * times
    made.times { slots.add(@result) }
    made
  end

  # Takes the ingredients of times crafts from slots.
  def use_up(times, slots)
    Recipe.take_from(slots, @ingredient, @count * times)
    Recipe.take_from(slots, @second, @second_count * times) if @second > 0
    nil
  end
end
