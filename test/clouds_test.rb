require_relative "test_helper"

class CloudsTest < Minitest::Test
  # The floats of one vertex in a Mesh3.
  VERTEX = 11

  def test_the_clouds_cover_a_fifth_of_the_sky
    [1, 1337].each do |seed|
      clouds = Clouds.new(seed)
      cells = 0
      Clouds::GRID.times { |i| Clouds::GRID.times { |j| cells += 1 if clouds.cloud?(i, j) } }
      assert_in_delta 0.2, cells.to_f / (Clouds::GRID * Clouds::GRID), 0.001
    end
  end

  def test_the_cloud_boxes_are_four_blocks_tall
    clouds = Clouds.new(1337)
    clouds.build(0.0, 0.0, 0.0)
    heights = vertices(clouds.mesh).map { |vertex| vertex[1] }.uniq.sort
    assert_equal [192.0, 196.0], heights
  end

  private

  def vertices(mesh) = mesh.v.each_slice(VERTEX).to_a
end
