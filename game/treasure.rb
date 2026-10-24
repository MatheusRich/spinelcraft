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

  # A treasure chest sends its guards when the player comes this near, as
  # a monster spawner starts in a sphere of 16 blocks around it
  # (minecraft.wiki/w/Monster_Spawner). It sends them again only after the
  # player has gone farther than REARM from it. Then each guard that
  # waits by the chest is farther than Monster::DESPAWN_FAR from the
  # player, so it has despawned. This is not a Minecraft rule.
  GUARD_REACH = 16.0
  REARM = Monster::DESPAWN_FAR + NaturalSpawner::GUARD_RANGE * 2

  # nearest looks this many cells around the cell of its point on each
  # side. So it finds each site up to NEAR blocks away.
  NEAR_CELLS = 2
  NEAR = NEAR_CELLS * TreasureMap::CELL

  def initialize(map, seed)
    @map = map
    @seed = seed
    # The World.key of each looted chest.
    @looted = Array.new(0, 0)
    # The sites that sent their guards (see call_guards).
    @sent = Array.new(0) { TreasureSite.none }
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
    # Rng keeps 31 bits of its seed, and World.key holds x above them, so
    # the seed comes from a hash of x, y and z.
    rng = Rng.new((Noise.hash3(x, y, z, 42) << 15) ^ @seed)
    slots = Slots.new(Chest::SLOTS)
    LOOT.each { |pool| pool.fill_slots(rng, slots) }
    chests.keep(key, slots)
  end

  # The nearest site to x, z of a chest that is not looted, up to NEAR
  # blocks away, or no site.
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
        next if distance > NEAR || (best.found? && distance >= best_distance)

        best = site
        best_distance = distance
      end
    end
    best
  end

  # The site of the chest that sends its guards now, with the player at x,
  # y, z, or no site. That is a chest that is not looted, within
  # GUARD_REACH of the player, and that did not send its guards before.
  # A site that sent them can send them again once the player has gone
  # farther than REARM.
  def call_guards(x, y, z)
    @sent.reject! { |site| site.distance(x, z) > REARM }
    [-GUARD_REACH, GUARD_REACH].each do |dx|
      [-GUARD_REACH, GUARD_REACH].each do |dz|
        site = @map.site_at((x + dx).floor, (z + dz).floor)
        next unless guards_ready?(site, x, y, z)

        @sent << site
        return site
      end
    end
    TreasureSite.none
  end

  # True when site has a chest that is not looted, within GUARD_REACH of
  # x, y, z, and has not sent its guards.
  def guards_ready?(site, x, y, z)
    dy = site.chest_y + 0.5 - y
    distance = site.distance(x, z)
    unlooted?(site.chest_x, site.chest_y, site.chest_z) && distance * distance + dy * dy <= GUARD_REACH * GUARD_REACH && !@sent.include?(site)
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
