# The treasure chests of TreasureMap as the game plays them. A treasure
# chest is empty in the generated world. The game fills it the first time
# that the player opens it or breaks it, as Minecraft fills a chest from
# its loot table (minecraft.wiki/w/Loot_table). Then the chest is looted,
# and it never fills again, also when a new chest takes its place.
class Treasure
  # The loot of buried treasure in Java Edition
  # (minecraft.wiki/w/Buried_Treasure), with one spinel ore in the place
  # of the heart of the sea. The spinel ore is not a Minecraft value. The
  # game has no diamond item, so diamond ore takes its place, as in the
  # recipes. The game does not have the other items, and block 0 keeps
  # their weights: gold ingots and TNT, emeralds and prismarine crystals,
  # a leather tunic and an iron spear. The pools of cooked fish, of potions
  # of water breathing and of nautilus armor have only such items, so they
  # are not here.
  LOOT = [
    LootPool.new(1, 1).row(Block::SPINEL_ORE, 1, 1, 1),
    LootPool.new(5, 8).row(Block::IRON_INGOT, 1, 4, 20).row(0, 1, 4, 10).row(0, 1, 2, 5),
    LootPool.new(1, 3).row(0, 4, 8, 5).row(0, 1, 5, 5).row(Block::DIAMOND, 1, 2, 5),
    LootPool.new(0, 1).row(Block::IRON_SWORD, 1, 1, 1).row(0, 1, 1, 1).row(0, 1, 1, 1)
  ]

  # nearest looks this many cells around the cell of its point on each
  # side, about 2000 blocks.
  NEAR_CELLS = 4

  def initialize(map, seed)
    @map = map
    @seed = seed
    # The World.key of each looted chest.
    @looted = Array.new(0, 0)
    nil
  end

  # True when x, y, z is the cell of a treasure chest that is not looted.
  def unlooted?(x, y, z)
    site = @map.site_at(x, z)
    site.found? && site.chest_x == x && site.chest_y == y && site.chest_z == z && !@looted.include?(World.key(x, y, z))
  end

  # Fills the chest at x, y, z of chests from LOOT when it is a treasure
  # chest that is not looted, and keeps it as looted. The chest holds
  # nothing before: a treasure chest fills before it first opens.
  def stock(chests, x, y, z)
    return unless unlooted?(x, y, z)

    key = World.key(x, y, z)
    @looted << key
    rng = Rng.new(key ^ @seed)
    slots = Slots.new(Chest::SLOTS)
    LOOT.each { |pool| pool.fill_slots(rng, slots) }
    chests.keep(key, slots)
  end

  # The nearest site to x, z of a chest that is not looted, within
  # NEAR_CELLS cells, or no site.
  def nearest(x, z)
    cell_x = x.floor.to_i >> TreasureMap::CELL_BITS
    cell_z = z.floor.to_i >> TreasureMap::CELL_BITS
    best = TreasureSite.none
    best_distance = 0.0
    (cell_x - NEAR_CELLS..cell_x + NEAR_CELLS).each do |site_x|
      (cell_z - NEAR_CELLS..cell_z + NEAR_CELLS).each do |site_z|
        site = @map.site(site_x, site_z)
        next unless unlooted?(site.chest_x, site.chest_y, site.chest_z)

        distance = site.distance(x, z)
        next if best.found? && distance >= best_distance

        best = site
        best_distance = distance
      end
    end
    best
  end

  # The save fields: the number of looted chests, then their keys.
  def to_a = [@looted.size] + @looted

  # Reads the looted chests of to_a from fields at at. Gives the index
  # after them.
  def load(fields, at)
    count = fields[at].to_i
    @looted = Array.new(count) { |index| fields[at + 1 + index].to_i }
    at + 1 + count
  end
end
