# The furnaces in the world, by World.key (see Furnace), and the time that
# they have not ticked yet. A furnace works while its chunk is loaded, as
# in Minecraft, and it is lit while it burns.
class Furnaces
  # The save fields of one furnace: x, y, z, burn, burn total and progress,
  # then the slots (Slots#to_a).
  FIELDS = 12

  def initialize
    @furnaces = {}
    @clock = 0.0
    nil
  end

  # The number of furnaces.
  def size = @furnaces.size

  # Forgets every furnace and the time not yet ticked.
  def clear
    @furnaces = {}
    @clock = 0.0
    nil
  end

  # The furnace at x, y, z. A cell that has none gets a new one.
  def furnace_at(x, y, z) = @furnaces[World.key(x, y, z)] ||= Furnace.new(x, y, z)

  # Forgets the furnace with the key, and gives it, or nil.
  def remove_at(key) = @furnaces.delete(key)

  # Ticks each furnace of a loaded chunk for dt seconds, with the recipes
  # of recipe_book. A furnace that lights or goes out adds x, y, z and its
  # new block to changes.
  def smelt(dt, world, recipe_book, changes)
    @clock += dt
    ticks = (@clock * Furnace::TICKS_PER_SECOND).to_i
    @clock -= ticks.to_f / Furnace::TICKS_PER_SECOND
    return if ticks == 0

    @furnaces.each do |_key, furnace|
      next unless world.loaded?(furnace.x, furnace.z)

      recipe = recipe_book.smelt_recipe(furnace.slots.block(Furnace::INPUT))
      out = recipe.nil? ? 0 : recipe.result
      out_n = recipe.nil? ? 0 : recipe.result_count
      ticks.times { furnace.tick(out, out_n, Furnace.fuel_ticks(furnace.slots.block(Furnace::FUEL))) }
      block = world.get(furnace.x, furnace.y, furnace.z)
      lit = Block.furnace_id(Block::FACING[block], furnace.lit?)
      # to_i: Spinel cannot type a value of the Hash, and an untyped value
      # would make changes untyped for Plants and Fluids too.
      changes << furnace.x.to_i << furnace.y.to_i << furnace.z.to_i << lit if Block::BASE[block] == Block::FURNACE && lit != block
    end
    nil
  end

  # The save fields: the number of furnaces that are not idle, then FIELDS
  # for each one. An idle furnace does not go into the save.
  def to_a
    fields = [0]
    @furnaces.each do |_key, furnace|
      next if furnace.idle?

      fields.concat([furnace.x, furnace.y, furnace.z, furnace.burn, furnace.burn_total, furnace.progress] + furnace.slots.to_a)
      fields[0] += 1
    end
    fields
  end

  # Reads the furnaces of to_a from fields at at, in the place of the
  # furnaces that it has. Gives the index after them.
  def load(fields, at)
    @furnaces = {}
    count = fields[at].to_i
    at += 1
    count.times do
      x = fields[at].to_i
      y = fields[at + 1].to_i
      z = fields[at + 2].to_i
      furnace = Furnace.new(x, y, z)
      furnace.burn = fields[at + 3].to_i
      furnace.burn_total = fields[at + 4].to_i
      furnace.progress = fields[at + 5].to_i
      furnace.slots.load(fields, at + 6)
      @furnaces[World.key(x, y, z)] = furnace
      at += FIELDS
    end
    at
  end
end
