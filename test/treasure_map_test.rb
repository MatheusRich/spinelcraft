require_relative "test_helper"

# A terrain where each column is deep open ocean unless the test gives
# it a height. Columns can also be coast, have a tree, open a cave or
# have another top block.
class FakeTerrain
  attr_reader :heights, :coast, :trees, :entrances, :carved, :tops

  def initialize
    @heights = {}
    @coast = []
    @trees = []
    @entrances = []
    @carved = []
    @tops = {}
  end

  # The open ocean ends at CONTINENT[1], where the coast begins.
  def continent(x, z) = @coast.include?([x, z]) ? Terrain::CONTINENT[1] : -1.0
  def surface_height(x, z) = @heights.fetch([x, z], SEA - 20)
  # The real tree_top gives the top ground block, which can be 0.
  def tree_top(x, z) = @trees.include?([x, z]) ? 0 : -1
  def entrance?(x, z) = @entrances.include?([x, z])
  def carved?(x, y, z) = @carved.include?([x, y, z])
  def biome(_x, _z, _height) = Biome::PLAINS
  def top_block(x, z, _height, _biome) = @tops.fetch([x, z], Block::GRASS)
end

class TreasureMapTest < Minitest::Test
  # The step of the search, and a column on its grid in cell 0, 0.
  S = TreasureMap::STEP
  M = 3 * S
  CELLS = -2..2

  # The terrain and the sites of the 5 x 5 cells around x = z = 0.
  def self.area
    @area ||= begin
      terrain = Terrain.new(1337)
      map = TreasureMap.new(terrain)
      sites = CELLS.flat_map { |cell_x| CELLS.map { |cell_z| map.site(cell_x, cell_z) } }
      [terrain, sites.select(&:found?)]
    end
  end

  def terrain = self.class.area[0]
  def sites = self.class.area[1]

  def test_the_cells_around_spawn_have_sites
    assert_operator sites.size, :>=, 5
  end

  def test_a_site_is_on_dry_ground_of_an_island_in_open_ocean
    sites.each do |site|
      x = site.chest_x
      z = site.chest_z
      assert_equal site.chest_y, terrain.surface_height(x, z)
      assert_operator site.chest_y, :>, SEA + TreasureMap::RISE
      assert_operator terrain.continent(x, z), :<, Terrain::CONTINENT[1]
    end
  end

  def test_a_site_has_no_tree_and_stands_on_grass_sand_or_snow
    sites.each do |site|
      x = site.chest_x
      z = site.chest_z
      height = site.chest_y
      assert_operator terrain.tree_top(x, z), :<, 0
      assert_includes TreasureMap::GROUND, terrain.top_block(x, z, height, terrain.biome(x, z, height))
    end
  end

  def test_a_site_is_in_its_own_cell
    map = TreasureMap.new(terrain)
    sites.each do |site|
      assert_same site.chest_x, map.site_at(site.chest_x, site.chest_z).chest_x
      assert_same site.chest_z, map.site_at(site.chest_x, site.chest_z).chest_z
    end
  end

  def test_no_two_sites_are_closer_than_the_gap
    sites.combination(2) do |one, other|
      refute one.near?(other, TreasureMap::GAP), "#{one.chest_x} #{one.chest_z} and #{other.chest_x} #{other.chest_z}"
    end
  end

  def test_a_site_too_close_to_the_site_of_a_cell_before_it_is_no_site
    map = TreasureMap.new(terrain)
    before = TreasureSite.new(1000, 70, 1000)
    map.define_singleton_method(:found) { |_cell_x, _cell_z| before }
    gap = TreasureMap::GAP
    refute map.apart(TreasureSite.new(1000 + gap - 1, 70, 1000 - gap + 1), 1, 1).found?
    assert map.apart(TreasureSite.new(1000 + gap, 70, 1000), 1, 1).found?
    assert map.apart(TreasureSite.new(1000, 70, 1000 - gap), 1, 1).found?
  end

  def test_a_site_is_not_near_no_site
    refute TreasureSite.new(0, 70, 0).near?(TreasureSite.none, TreasureMap::GAP)
  end

  def test_the_site_is_the_highest_column_near_the_highest_sampled_column
    terrain = FakeTerrain.new
    terrain.heights[[S, 2 * S]] = SEA + 10
    terrain.heights[[M, M]] = SEA + 12
    terrain.heights[[M + S / 2, M - S / 2]] = SEA + 14
    terrain.heights[[M + S / 2 + 1, M]] = SEA + 20
    terrain.heights[[M, M - S / 2 - 1]] = SEA + 20
    site = TreasureMap.new(terrain).site(0, 0)
    assert_equal [M + S / 2, SEA + 14, M - S / 2], [site.chest_x, site.chest_y, site.chest_z]
  end

  def test_the_window_reaches_as_far_on_the_other_side
    terrain = FakeTerrain.new
    terrain.heights[[M, M]] = SEA + 12
    terrain.heights[[M - S / 2, M + S / 2]] = SEA + 14
    terrain.heights[[M - S / 2 - 1, M]] = SEA + 20
    terrain.heights[[M, M + S / 2 + 1]] = SEA + 20
    site = TreasureMap.new(terrain).site(0, 0)
    assert_equal [M - S / 2, M + S / 2], [site.chest_x, site.chest_z]
  end

  def test_of_two_columns_of_one_height_near_the_highest_the_first_one_wins
    terrain = FakeTerrain.new
    terrain.heights[[M, M]] = SEA + 12
    terrain.heights[[M - 2, M]] = SEA + 12
    assert_equal M - 2, TreasureMap.new(terrain).site(0, 0).chest_x
  end

  def test_a_tree_on_a_higher_column_near_the_highest_keeps_the_chest_off_it
    terrain = FakeTerrain.new
    terrain.heights[[M, M]] = SEA + 12
    terrain.heights[[M, M + 4]] = SEA + 20
    terrain.trees << [M, M + 4]
    assert_equal M, TreasureMap.new(terrain).site(0, 0).chest_z
  end

  def test_the_window_holds_no_site_lower_than_rise
    terrain = FakeTerrain.new
    terrain.heights[[64, 64]] = SEA + 20
    terrain.trees << [64, 64]
    terrain.heights[[65, 64]] = SEA + TreasureMap::RISE
    refute TreasureMap.new(terrain).site(0, 0).found?
  end

  def test_the_window_opens_only_around_a_sampled_column_higher_than_rise
    terrain = FakeTerrain.new
    corner = 2 * TreasureMap::CELL
    terrain.heights[[corner + S, corner + S]] = SEA + TreasureMap::RISE
    terrain.heights[[corner + S + 1, corner + S]] = SEA + 20
    refute TreasureMap.new(terrain).site(2, 2).found?
  end

  # The cells before the cell 5, 5 have sites, so the GAP test cannot
  # hide a site in it.
  def test_a_cell_with_no_sampled_column_higher_than_rise_has_no_site
    terrain = FakeTerrain.new
    terrain.heights[[1, 1]] = SEA + 20
    TreasureMap::BEFORE_X.size.times do |before|
      cell_x = 5 + TreasureMap::BEFORE_X[before]
      cell_z = 5 + TreasureMap::BEFORE_Z[before]
      terrain.heights[[cell_x * TreasureMap::CELL + S, cell_z * TreasureMap::CELL + S]] = SEA + 10
    end
    refute TreasureMap.new(terrain).site(5, 5).found?
  end

  def test_the_window_stays_in_the_cell
    terrain = FakeTerrain.new
    corner = TreasureMap::CELL
    terrain.heights[[corner, corner]] = SEA + 10
    terrain.heights[[corner - 1, corner]] = SEA + 20
    terrain.heights[[corner, corner - 1]] = SEA + 20
    site = TreasureMap.new(terrain).site(1, 1)
    assert_equal [corner, corner], [site.chest_x, site.chest_z]
  end

  def test_the_search_reads_the_corner_of_its_cell_but_not_the_next_cell
    terrain = FakeTerrain.new
    terrain.heights[[0, 0]] = SEA + 10
    terrain.heights[[TreasureMap::CELL, 0]] = SEA + 20
    terrain.heights[[0, TreasureMap::CELL]] = SEA + 20
    site = TreasureMap.new(terrain).site(0, 0)
    assert_equal [0, 0], [site.chest_x, site.chest_z]
  end

  def test_of_two_columns_of_one_height_the_first_one_found_wins
    terrain = FakeTerrain.new
    terrain.heights[[S, S]] = SEA + 10
    terrain.heights[[12 * S, 12 * S]] = SEA + 10
    assert_equal S, TreasureMap.new(terrain).site(0, 0).chest_x
  end

  def test_a_site_stands_more_than_rise_above_the_sea
    terrain = FakeTerrain.new
    terrain.heights[[S, S]] = SEA + TreasureMap::RISE
    refute TreasureMap.new(terrain).site(0, 0).found?
    terrain.heights[[S, S]] = SEA + TreasureMap::RISE + 1
    assert TreasureMap.new(terrain).site(0, 0).found?
  end

  def test_a_column_off_the_coast_is_no_site
    terrain = FakeTerrain.new
    terrain.heights[[S, S]] = SEA + 20
    terrain.coast << [S, S]
    terrain.heights[[64, 64]] = SEA + 10
    assert_equal 64, TreasureMap.new(terrain).site(0, 0).chest_x
  end

  def test_a_chest_does_not_stand_on_a_tree_an_open_cave_or_other_ground
    terrain = FakeTerrain.new
    terrain.heights[[64, 64]] = SEA + 20
    terrain.heights[[65, 64]] = SEA + 19
    terrain.heights[[66, 64]] = SEA + 18
    terrain.heights[[68, 64]] = SEA + 16
    terrain.trees << [64, 64]
    terrain.entrances << [65, 64]
    terrain.carved << [65, SEA + 18, 64]
    terrain.tops[[66, 64]] = Block::STONE
    assert_equal 68, TreasureMap.new(terrain).site(0, 0).chest_x
  end

  def test_a_cave_closes_a_column_only_in_an_entrance_patch_and_under_its_top_block
    terrain = FakeTerrain.new
    terrain.heights[[64, 64]] = SEA + 20
    terrain.carved << [64, SEA + 19, 64]
    assert_equal 64, TreasureMap.new(terrain).site(0, 0).chest_x
    terrain.carved.clear
    terrain.entrances << [64, 64]
    [SEA + 18, SEA + 20].each { |y| terrain.carved << [64, y, 64] }
    assert_equal 64, TreasureMap.new(terrain).site(0, 0).chest_x
  end

  def test_a_cell_with_no_column_that_holds_a_chest_has_no_site
    terrain = FakeTerrain.new
    terrain.heights[[64, 64]] = SEA + 20
    terrain.trees << [64, 64]
    refute TreasureMap.new(terrain).site(0, 0).found?
  end

  def test_the_cell_of_a_block_rounds_down
    map = TreasureMap.new(FakeTerrain.new)
    assert_same map.site(-1, -1), map.site_at(-1, -1)
    assert_same map.site(0, -1), map.site_at(TreasureMap::CELL - 1, -1)
  end

  def test_the_search_reads_each_cell_once
    map = TreasureMap.new(FakeTerrain.new)
    cells = []
    search = map.method(:find)
    map.define_singleton_method(:find) do |x0, z0|
      cells << [x0 / TreasureMap::CELL, z0 / TreasureMap::CELL]
      search.call(x0, z0)
    end
    map.site(0, 0)
    map.site(0, 0)
    assert_equal [[0, 0]], cells
    map.define_singleton_method(:find) do |x0, z0|
      cells << [x0 / TreasureMap::CELL, z0 / TreasureMap::CELL]
      TreasureSite.new(x0 + 8, SEA + 10, z0 + 8)
    end
    cells.clear
    map.site(1, 1)
    map.site(1, 1)
    # The cell 0, 0 is one of them, and the search read it before.
    assert_equal [[1, 1], [0, 1], [1, 0], [2, 0]], cells
  end

  def test_only_the_cells_before_a_cell_can_drop_its_site
    gap = TreasureMap::GAP
    site = TreasureSite.new(1000, 70, 1000)
    close = TreasureSite.new(1000 + gap - 1, 70, 1000 - gap + 1)
    [[-1, 0, true], [-1, -1, true], [0, -1, true], [1, -1, true], [1, 0, false], [-1, 1, false], [0, 1, false], [1, 1, false]].each do |dx, dz, drops|
      map = TreasureMap.new(FakeTerrain.new)
      map.define_singleton_method(:found) { |cell_x, cell_z| [cell_x, cell_z] == [1 + dx, 1 + dz] ? close : TreasureSite.none }
      assert_equal !drops, map.apart(site, 1, 1).found?, "the cell #{dx} #{dz} from it"
    end
  end

  def test_a_cell_of_land_has_no_site
    map = TreasureMap.new(terrain)
    assert terrain.land?(0, 0)
    refute map.site_at(0, 0).found?
  end

  def test_the_same_seed_gives_the_same_sites
    map = TreasureMap.new(Terrain.new(1337))
    site = sites.first
    again = map.site_at(site.chest_x, site.chest_z)
    assert_equal [site.chest_x, site.chest_y, site.chest_z], [again.chest_x, again.chest_y, again.chest_z]
  end

  def test_the_chests_of_the_sites_face_different_ways
    facings = sites.map do |site|
      world = World.new(1337)
      world.load_chunk(site.chest_x >> 4, site.chest_z >> 4)
      Block::FACING[world.get(site.chest_x, site.chest_y, site.chest_z)]
    end
    assert_operator facings.uniq.size, :>=, 3
  end

  # The block at x, y, z of the generated chunk of seed 7, with site as
  # the only treasure site.
  def self.block_with_site(site, x, y, z)
    world = World.new(7)
    world.instance_variable_get(:@generator).treasure_map.define_singleton_method(:site_at) { |_x, _z| site }
    world.load_chunk(x >> 4, z >> 4)
    world.get(x, y, z)
  end

  # Two cells of seed 7 on the ground: the leaves of a tree next to it
  # fill one, and dry grass of the desert grows in the other.
  def test_the_chest_takes_the_place_of_leaves_and_no_plant_takes_its_place
    [[-4055, 83, -879], [3644, 79, -776]].each do |x, y, z|
      refute_equal Block::AIR, self.class.block_with_site(TreasureSite.none, x, y, z)
      chest = self.class.block_with_site(TreasureSite.new(x, y, z), x, y, z)
      assert_equal Block::CHEST, Block::BASE[chest], "the site at #{x} #{z}"
    end
  end

  def test_a_site_that_a_block_fills_gets_no_chest
    world = World.new(1337)
    site = TreasureSite.new(8, world.terrain.surface_height(8, 8) - 1, 8)
    world.instance_variable_get(:@generator).treasure_map.define_singleton_method(:site_at) { |_x, _z| site }
    world.load_chunk(0, 0)
    refute_equal Block::CHEST, Block::BASE[world.get(8, site.chest_y, 8)]
  end

  def test_the_generated_chunk_of_a_site_has_a_chest_on_it
    site = sites.first
    world = World.new(1337)
    world.load_chunk(site.chest_x >> 4, site.chest_z >> 4)
    assert_equal Block::CHEST, Block::BASE[world.get(site.chest_x, site.chest_y, site.chest_z)]
    x0 = site.chest_x & ~15
    z0 = site.chest_z & ~15
    chests = (x0...x0 + CHUNK).sum { |x| (z0...z0 + CHUNK).sum { |z| (0...WY).count { |y| Block::BASE[world.get(x, y, z)] == Block::CHEST } } }
    assert_equal 1, chests
  end
end
