require_relative "test_helper"

# A TreasureMap with the sites that a test gives it, by cell.
class FakeMap
  def initialize(sites = {})
    @sites = sites
  end

  def site(cell_x, cell_z) = @sites.fetch([cell_x, cell_z], TreasureSite.none)

  def site_at(x, z) = site(x >> TreasureMap::CELL_BITS, z >> TreasureMap::CELL_BITS)
end

# A TreasureMap with one site.
class OneSiteMap < FakeMap
  def initialize(site)
    super([0, -1] => site)
  end
end

class TreasureTest < Minitest::Test
  X = 100
  Y = 70
  Z = -40

  def setup
    @treasure = Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), 1337)
    @chests = Chests.new
  end

  def total(slots, block) = (0...slots.size).sum { |slot| slots.block(slot) == block ? slots.count(slot) : 0 }

  def test_a_treasure_chest_fills_with_one_spinel_ore_iron_and_maybe_diamonds_and_a_sword
    @treasure.stock(@chests, X, Y, Z)
    slots = @chests.remove_at(World.key(X, Y, Z))
    assert_equal 1, total(slots, Block::SPINEL_ORE)
    assert_operator total(slots, Block::IRON_INGOT), :>=, 1
    blocks = (0...slots.size).map { |slot| slots.block(slot) }.uniq - [Block::AIR]
    assert_empty blocks - [Block::SPINEL_ORE, Block::IRON_INGOT, Block::DIAMOND, Block::IRON_SWORD]
  end

  def test_the_loot_has_the_counts_of_buried_treasure
    irons = []
    diamonds = []
    swords = 0
    200.times do |seed|
      treasure = Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), seed)
      chests = Chests.new
      treasure.stock(chests, X, Y, Z)
      slots = chests.remove_at(World.key(X, Y, Z))
      irons << total(slots, Block::IRON_INGOT)
      diamonds << total(slots, Block::DIAMOND)
      swords += 1 if total(slots, Block::IRON_SWORD) > 0
    end
    # minecraft.wiki/w/Buried_Treasure: 9.286 iron ingots, 1 diamond, and
    # an iron sword in 16.7% of the chests.
    assert_in_delta 9.286, irons.sum / 200.0, 1.0
    assert_in_delta 1.0, diamonds.sum / 200.0, 0.25
    assert_in_delta 0.167, swords / 200.0, 0.06
  end

  def test_a_chest_fills_once
    key = World.key(X, Y, Z)
    @treasure.stock(@chests, X, Y, Z)
    slots = @chests.remove_at(key)
    slots.clear
    @chests.keep(key, slots)
    @treasure.stock(@chests, X, Y, Z)
    assert_same slots, @chests.remove_at(key)
    assert((0...slots.size).all? { |slot| slots.empty?(slot) })
    refute @treasure.unlooted?(X, Y, Z)
  end

  def test_a_new_chest_in_the_place_of_a_looted_one_stays_empty
    @treasure.stock(@chests, X, Y, Z)
    @chests.remove_at(World.key(X, Y, Z))
    @treasure.stock(@chests, X, Y, Z)
    assert_nil @chests.remove_at(World.key(X, Y, Z))
  end

  def test_only_the_cell_of_the_site_fills
    [[X + 1, Y, Z], [X, Y + 1, Z], [X, Y, Z + 1]].each do |x, y, z|
      refute @treasure.unlooted?(x, y, z)
      @treasure.stock(@chests, x, y, z)
    end
    assert_equal 0, @chests.size
    assert @treasure.unlooted?(X, Y, Z)
  end

  def test_no_site_has_no_treasure_chest
    treasure = Treasure.new(OneSiteMap.new(TreasureSite.none), 1337)
    refute treasure.unlooted?(0, -1, 0)
  end

  def test_the_looted_chests_survive_a_save
    @treasure.stock(@chests, X, Y, Z)
    fields = ["x"] + @treasure.to_a.map(&:to_s) + ["y"]
    again = Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), 1337)
    assert_equal fields.size - 1, again.load(fields, 1)
    refute again.unlooted?(X, Y, Z)
    assert Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), 1337).unlooted?(X, Y, Z)
  end

  def test_nearest_gives_the_nearest_site_that_is_not_looted
    cell = TreasureMap::CELL
    near = TreasureSite.new(cell + 10, Y, 10)
    far = TreasureSite.new(-cell * 2 + 10, Y, 10)
    treasure = Treasure.new(FakeMap.new([1, 0] => near, [-2, 0] => far), 1337)
    assert_same near, treasure.nearest(100.5, 10.5)
    assert_same far, treasure.nearest(-600.5, 10.5)
    treasure.stock(Chests.new, near.chest_x, Y, near.chest_z)
    assert_same far, treasure.nearest(100.5, 10.5)
  end

  def test_nearest_reads_near_cells_on_each_side_and_no_farther
    cell = TreasureMap::CELL
    reach = Treasure::NEAR_CELLS
    [[reach, 0], [-reach, 0], [0, reach], [0, -reach]].each do |cell_x, cell_z|
      site = TreasureSite.new(cell_x * cell + 10, Y, cell_z * cell + 10)
      assert_same site, Treasure.new(FakeMap.new([cell_x, cell_z] => site), 1337).nearest(10.5, 10.5)
    end
    beyond = TreasureSite.new((reach + 1) * cell + 10, Y, 10)
    refute Treasure.new(FakeMap.new([reach + 1, 0] => beyond), 1337).nearest(10.5, 10.5).found?
  end

  def test_of_two_sites_at_one_distance_nearest_gives_the_first
    cell = TreasureMap::CELL
    west = TreasureSite.new(-cell + 10, Y, 10)
    east = TreasureSite.new(cell + 10, Y, 10)
    assert_same west, Treasure.new(FakeMap.new([-1, 0] => west, [1, 0] => east), 1337).nearest(10.5, 10.5)
  end

  def test_the_distance_to_a_site_is_from_the_middle_of_its_chest
    assert_in_delta 5.0, TreasureSite.new(10, Y, 20).distance(13.5, 24.5), 1e-9
  end

  def test_nearest_starts_from_the_cell_that_holds_its_point
    cell = TreasureMap::CELL
    reach = Treasure::NEAR_CELLS
    west = TreasureSite.new((-1 - reach) * cell + 10, Y, -10)
    assert_same west, Treasure.new(FakeMap.new([-1 - reach, -1] => west), 1337).nearest(-0.5, -0.5)
    north = TreasureSite.new(-10, Y, (-1 - reach) * cell + 10)
    assert_same north, Treasure.new(FakeMap.new([-1, -1 - reach] => north), 1337).nearest(-0.5, -0.5)
  end

  def test_two_looted_chests_survive_a_save
    one = TreasureSite.new(10, Y, 10)
    other = TreasureSite.new(TreasureMap::CELL + 10, Y, 10)
    map = FakeMap.new([0, 0] => one, [1, 0] => other)
    treasure = Treasure.new(map, 1337)
    chests = Chests.new
    treasure.stock(chests, 10, Y, 10)
    treasure.stock(chests, TreasureMap::CELL + 10, Y, 10)
    again = Treasure.new(map, 1337)
    again.load(treasure.to_a.map(&:to_s), 0)
    refute again.unlooted?(10, Y, 10)
    refute again.unlooted?(TreasureMap::CELL + 10, Y, 10)
  end

  def test_a_chest_sends_its_guards_when_the_player_comes_within_16_blocks
    reach = Treasure::GUARD_REACH
    refute @treasure.call_guards(X + 0.5 + reach + 0.1, Y + 0.5, Z + 0.5).found?
    refute @treasure.call_guards(X + 0.5, Y + 0.5 + reach + 0.1, Z + 0.5).found?
    assert_equal X, @treasure.call_guards(X + 0.5 + reach - 0.1, Y + 0.5, Z + 0.5).chest_x
  end

  def test_the_reach_of_the_guards_is_a_sphere_around_the_middle_of_the_chest
    assert Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), 1).call_guards(X + 0.5, Y + 0.5 + Treasure::GUARD_REACH - 0.1, Z + 0.5).found?
    assert Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), 1).call_guards(X + 0.5, Y + 0.5 - Treasure::GUARD_REACH + 0.1, Z + 0.5).found?
    assert Treasure.new(OneSiteMap.new(TreasureSite.new(X, Y, Z)), 1).call_guards(X + 0.5 + Treasure::GUARD_REACH, Y + 0.5, Z + 0.5).found?
  end

  def test_a_chest_sends_its_guards_once_until_the_player_goes_far_away
    assert @treasure.call_guards(X + 0.5, Y, Z + 10.5).found?
    refute @treasure.call_guards(X + 0.5, Y, Z + 10.5).found?
    refute @treasure.call_guards(X + 0.5, Y, Z + 0.5 + Monster::DESPAWN_FAR).found?
    refute @treasure.call_guards(X + 0.5, Y, Z + 10.5).found?
    refute @treasure.call_guards(X + 0.5, Y, Z + 0.6 + Monster::DESPAWN_FAR).found?
    assert @treasure.call_guards(X + 0.5, Y, Z + 10.5).found?
  end

  def test_a_looted_chest_sends_no_guards
    @treasure.stock(@chests, X, Y, Z)
    refute @treasure.call_guards(X + 0.5, Y, Z + 10.5).found?
  end

  def test_a_chest_in_the_next_cell_sends_its_guards
    cell = TreasureMap::CELL
    # A chest at the edge of a cell, and the player 14.5 blocks away in
    # the cell next to it, on each side.
    [[cell, 10, cell - 14.0, 10.5], [cell - 1, 10, cell + 14.0, 10.5],
     [10, cell, 10.5, cell - 14.0], [10, cell - 1, 10.5, cell + 14.0]].each do |chest_x, chest_z, x, z|
      site = TreasureSite.new(chest_x, Y, chest_z)
      treasure = Treasure.new(FakeMap.new([chest_x >> TreasureMap::CELL_BITS, chest_z >> TreasureMap::CELL_BITS] => site), 1337)
      assert_same site, treasure.call_guards(x, Y + 0.5, z), "a chest at #{chest_x} #{chest_z}"
    end
  end

  def test_no_site_sends_no_guards
    refute Treasure.new(FakeMap.new, 1337).call_guards(0.5, 0.5, 0.5).found?
  end
end
