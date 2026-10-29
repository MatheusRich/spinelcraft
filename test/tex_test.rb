require_relative "test_helper"

# FAST graphics draws leaves from solid copies of the leaf layers: the opaque
# pixels stay, and a clear pixel takes its color darker.
class TexTest < Minitest::Test
  LEAVES = [Tex::OAK_LEAVES, Tex::SPRUCE_LEAVES, Tex::BIRCH_LEAVES].freeze

  def test_each_layer_of_leaves_has_its_own_solid_layer
    solids = LEAVES.map { |layer| Tex.solid(layer) }
    assert_equal [Tex::OAK_LEAVES_SOLID, Tex::SPRUCE_LEAVES_SOLID, Tex::BIRCH_LEAVES_SOLID], solids
    assert_equal 6, (solids + LEAVES).uniq.size
  end

  def test_a_layer_that_is_not_leaves_stays_the_same
    [Tex::STONE, Tex::GLASS, Tex::OAK_LEAVES_SOLID, Tex::WHITE].each { |layer| assert_equal layer, Tex.solid(layer) }
  end

  def test_the_solid_oak_leaves_take_the_foliage_color_as_the_oak_leaves_do
    assert_equal 2, Tex.tint(Tex::OAK_LEAVES)
    assert_equal 2, Tex.tint(Tex::OAK_LEAVES_SOLID)
    assert_equal Tex.tint(Tex::SPRUCE_LEAVES), Tex.tint(Tex::SPRUCE_LEAVES_SOLID)
    assert_equal 0, Tex.tint(Tex::STONE)
    assert_equal 1, Tex.tint(Tex::GRASS_TOP)
  end

  def test_the_solid_layer_keeps_the_opaque_pixels_and_darkens_the_clear_ones
    px = Array.new(Tex::LAYERS * 256, 0)
    LEAVES.each do |layer|
      256.times { |i| px[layer * 256 + i] = Tex.rgba(100, 200, 40, i.even? ? 255 : 0) }
    end
    Tex.solid_leaves(px)
    LEAVES.each do |layer|
      solid = Tex.solid(layer)
      256.times do |i|
        expected = i.even? ? Tex.rgba(100, 200, 40, 255) : Tex.rgba(55, 110, 22, 255)
        assert_equal expected, px[solid * 256 + i]
      end
    end
    assert_equal 0, px[(Tex::BIRCH_LEAVES_SOLID + 1) * 256], "the layer after the last solid layer is not touched"
  end

  def test_a_pixel_that_is_half_clear_counts_as_opaque_from_the_alpha_of_128
    px = Array.new(Tex::LAYERS * 256, 0)
    px[Tex::OAK_LEAVES * 256] = Tex.rgba(100, 100, 100, 128)
    px[Tex::OAK_LEAVES * 256 + 1] = Tex.rgba(100, 100, 100, 127)
    Tex.solid_leaves(px)
    assert_equal Tex.rgba(100, 100, 100, 255), px[Tex::OAK_LEAVES_SOLID * 256]
    assert_equal Tex.rgba(55, 55, 55, 255), px[Tex::OAK_LEAVES_SOLID * 256 + 1]
  end

  def test_the_texture_array_stays_inside_the_eight_bits_of_a_face_record
    assert_operator Tex::LAYERS, :<=, 1 << Mesher::TEX_BITS
  end
end
