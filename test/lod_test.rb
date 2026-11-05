require_relative "test_helper"

class LodTest < Minitest::Test
  GROUND = SEA + 10

  # The tree roll of cell 2, 0 is 601, below the 2600 trees of the forest.
  def test_a_far_cell_shows_a_tree_only_where_the_meadow_leaves_trees
    assert_equal 601, Noise.hash3(2, 0, 0, 26) >> 4
    assert_equal GROUND + Trees::TRUNK[Biome::OAK] + 2, sampled_height(meadow: 0.0)
    assert_equal GROUND, sampled_height(meadow: Terrain::CLEARING_START)
  end

  # The swamp grows 900 trees, and 450 at half the density.
  def test_the_far_tree_roll_is_against_the_trees_at_the_density_of_the_cell
    assert_operator sampled_height(meadow: 0.0, biome: Biome::SWAMP), :>, GROUND
    assert_equal GROUND, sampled_height(meadow: Terrain::CLEARING_START / 2, biome: Biome::SWAMP)
  end

  def test_a_far_tree_grows_on_grass_or_snowy_grass
    assert_operator sampled_height(meadow: 0.0, ground: Block::SNOW_GRASS), :>, GROUND
    assert_equal GROUND, sampled_height(meadow: 0.0, ground: Block::SAND)
  end

  # The top block of a cell under the sea is its floor, at FLOOR - 1.
  FLOOR = SEA - 10

  def test_a_far_cell_under_the_sea_shows_its_floor_under_a_water_surface
    tops = top_faces(FLOOR, Block::SAND)
    floors = tops.reject { |face| texture(face) == Tex::WATER }
    waters = tops.select { |face| texture(face) == Tex::WATER }
    assert_equal Lod::CELLS * Lod::CELLS, floors.size
    assert_equal [FLOOR - 1], floors.map { |face| Mesher.face_y(face[0]) }.uniq
    assert_equal [Block::TOP[Block::SAND]], floors.map { |face| texture(face) }.uniq
    assert_equal Lod::CELLS * Lod::CELLS, waters.size
    assert_equal [SEA], waters.map { |face| Mesher.face_y(face[0]) }.uniq
    assert_equal [2], waters.map { |face| Mesher.face_dir(face[0]) }.uniq
    assert_equal [1], waters.map { |face| Mesher.field(face[1], Lod::TALL_AT, Lod::TALL_BITS) }.uniq
    assert_equal [SEA + 1 - FLOOR], waters.map { |face| water_depth(face) }.uniq
  end

  def test_the_depth_of_far_water_stops_at_the_largest_that_its_field_holds
    waters = top_faces(1, Block::SAND).select { |face| texture(face) == Tex::WATER }
    assert_equal [Lod::DEPTH_MAX], waters.map { |face| water_depth(face) }.uniq
  end

  # A cell whose top block is at SEA - 1 is under the sea, and one at SEA is not.
  def test_the_water_surface_starts_under_the_top_of_the_sea
    assert_equal Lod::CELLS * Lod::CELLS * 2, top_faces(SEA, Block::SAND).size
    assert_equal Lod::CELLS * Lod::CELLS, top_faces(SEA + 1, Block::SAND).size
  end

  def test_a_far_cell_on_land_has_no_water_surface
    tops = top_faces(GROUND, Block::SAND)
    assert_equal Lod::CELLS * Lod::CELLS, tops.size
    assert_equal [Block::TOP[Block::SAND]], tops.map { |face| texture(face) }.uniq
  end

  private

  def sampled_height(meadow:, biome: Biome::FOREST, ground: Block::GRASS)
    lod = Lod.new(flat_terrain(GROUND, ground, meadow: meadow, biome: biome), 0)
    lod.sample(2, 0, 0)
    lod.instance_variable_get(:@h)[0]
  end

  def flat_terrain(height, ground, meadow: 0.0, biome: Biome::FOREST)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:surface_height) { |_x, _z| height }
    terrain.define_singleton_method(:biome) { |_x, _z, _h| biome }
    terrain.define_singleton_method(:top_block) { |_x, _z, _h, _biome| ground }
    terrain.define_singleton_method(:meadow) { |_x, _z| meadow }
    terrain
  end

  # The top faces of a far tile of flat terrain at height, with ground on top, as
  # pairs of the two words of a face record.
  def top_faces(height, ground)
    lod = Lod.new(flat_terrain(height, ground), 0)
    lod.build(0, 0)
    (lod.offsets[2]...lod.offsets[3]).map { |k| [lod.faces[k * 2], lod.faces[k * 2 + 1]] }
  end

  def water_depth(face) = Mesher.field(face[1], Lod::DEPTH_AT, Lod::DEPTH_BITS)

  def texture(face) = Mesher.field(face[1], Mesher::TEX_AT, Mesher::TEX_BITS)
end
