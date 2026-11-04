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

  private

  def sampled_height(meadow:, biome: Biome::FOREST, ground: Block::GRASS)
    terrain = Terrain.new(1337)
    terrain.define_singleton_method(:surface_height) { |_x, _z| GROUND }
    terrain.define_singleton_method(:biome) { |_x, _z, _h| biome }
    terrain.define_singleton_method(:top_block) { |_x, _z, _h, _biome| ground }
    terrain.define_singleton_method(:meadow) { |_x, _z| meadow }
    lod = Lod.new(terrain, 0)
    lod.sample(2, 0, 0)
    lod.instance_variable_get(:@h)[0]
  end
end
