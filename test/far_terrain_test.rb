require_relative "test_helper"

# Each level of far terrain starts where the finer one stops, and builds
# rings of tiles out to its reach or to the view.
class FarTerrainTest < Minitest::Test
  def test_level_0_starts_at_the_end_of_the_chunks_and_each_next_level_at_the_reach_before_it
    assert_equal 460.0, FarTerrain.level_start(0)
    assert_equal 640.0, FarTerrain.level_start(1)
    assert_equal 1280.0, FarTerrain.level_start(2)
    assert_equal 2560.0, FarTerrain.level_start(3)
  end

  def test_a_level_builds_rings_out_to_its_reach_or_to_the_view_and_one_more
    far = FarTerrain.new(Terrain.new(1337), 0)
    # Level 0 has tiles of 64 blocks and reaches 640 blocks.
    assert_equal 64, far.lod(0).tile
    assert_equal 11, far.tile_rings(0, 5000.0)
    assert_equal 6, far.tile_rings(0, 300.0)
    assert_equal 6, far.tile_rings(0, 320.0)
    assert_equal 7, far.tile_rings(0, 321.0)
    # Level 3 has tiles of 512 blocks and reaches 5120 blocks.
    assert_equal 11, far.tile_rings(3, 5120.0)
    assert_equal 10, far.tile_rings(3, 4600.0)
  end

  def test_no_tile_is_built_before_the_first_build
    far = FarTerrain.new(Terrain.new(1337), 0)
    assert_equal 0, far.take_builds
    assert_equal 0, far.take_builds
    refute far.lod(0).ready?(0, 0)
  end

  def test_square_rings_go_out_from_the_center_one_ring_at_a_time
    dxs = []
    dzs = []
    World.square_rings(2, dxs, dzs)
    assert_equal 25, dxs.size
    assert_equal [0, 0], [dxs[0], dzs[0]]
    rings = dxs.zip(dzs).map { |dx, dz| [dx.abs, dz.abs].max }
    assert_equal [0] + [1] * 8 + [2] * 16, rings
    assert_equal 25, dxs.zip(dzs).uniq.size
  end
end
