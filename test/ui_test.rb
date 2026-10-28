require_relative "test_helper"

class UiTest < Minitest::Test
  # The floats of one vertex: x y, u v, layer, red green blue alpha.
  VERTEX = 9
  QUAD_VERTICES = 6
  COLOR = Color.new(0.5, 0.25, 1.0, 0.8)

  def setup
    @ui = Ui.new
  end

  def test_a_rect_covers_its_corners_with_one_color
    @ui.rect(10.0, 20.0, 30.0, 40.0, COLOR)
    assert_equal QUAD_VERTICES, vertices.size
    assert_equal [[10.0, 20.0], [10.0, 60.0], [40.0, 20.0], [40.0, 60.0]], vertices.map { |vertex| vertex[0, 2] }.uniq.sort
    assert_equal [[0.5, 0.25, 1.0, 0.8]], vertices.map { |vertex| vertex[5, 4] }.uniq
    assert_equal [Tex::WHITE.to_f], vertices.map { |vertex| vertex[4] }.uniq
  end

  def test_a_quad_shows_the_texture_up_to_its_far_corner
    @ui.quad(10.0, 20.0, 30.0, 40.0, Tex::HEART, 0.5, 0.25, COLOR)
    far = vertices.find { |vertex| vertex[0, 2] == [40.0, 60.0] }
    near = vertices.find { |vertex| vertex[0, 2] == [10.0, 20.0] }
    assert_equal [0.5, 0.25], far[2, 2]
    assert_equal [0.0, 0.0], near[2, 2]
    assert_equal [Tex::HEART.to_f], vertices.map { |vertex| vertex[4] }.uniq
    assert_equal [[0.5, 0.25, 1.0, 0.8]], vertices.map { |vertex| vertex[5, 4] }.uniq
  end

  def test_a_letter_has_a_dark_shadow_behind_it_and_the_next_letter_is_four_pixels_on
    @ui.text(10.0, 20.0, "AB", 2.0, COLOR)
    shadow, letter, next_shadow = quads
    assert_equal [[0.0, 0.0, 0.0, 0.8 * 0.6]], shadow.map { |vertex| vertex[5, 4] }.uniq
    assert_equal [[0.5, 0.25, 1.0, 0.8]], letter.map { |vertex| vertex[5, 4] }.uniq
    assert_equal [12.0, 22.0], shadow.map { |vertex| vertex[0, 2] }.min
    assert_equal [10.0, 20.0], letter.map { |vertex| vertex[0, 2] }.min
    assert_equal [20.0, 22.0], next_shadow.map { |vertex| vertex[0, 2] }.min
    assert_equal 4, quads.size
  end

  def test_a_letter_and_its_shadow_are_three_by_five_pixels_of_the_scale_and_show_the_part_of_their_cell_with_the_glyph
    @ui.text(10.0, 20.0, "A", 2.0, COLOR)
    quads.each do |quad|
      xs = quad.map { |vertex| vertex[0] }
      ys = quad.map { |vertex| vertex[1] }
      assert_equal [6.0, 10.0], [xs.max - xs.min, ys.max - ys.min]
      assert_equal [9.0 / 16.0, 15.0 / 16.0], quad.map { |vertex| vertex[2, 2] }.max
      assert_equal [Tex.glyph("A").to_f], quad.map { |vertex| vertex[4] }.uniq
    end
  end

  def test_the_shadow_of_a_text_is_as_clear_as_the_text
    @ui.text(0.0, 0.0, "A", 1.0, Color.new(1.0, 1.0, 1.0, 0.5))
    assert_in_delta 0.3, quads.first.first[8], 1.0e-6
  end

  def test_an_icon_is_a_grey_square_of_the_shade
    @ui.icon(0.0, 0.0, 16.0, Tex::FIRE, 0.25)
    assert_equal [[0.25, 0.25, 0.25, 1.0]], vertices.map { |vertex| vertex[5, 4] }.uniq
  end

  def test_the_edge_of_a_block_text_gets_darker_away_from_the_front
    @ui.block_text(0.0, 0.0, "I", 6.0, Tex::SPINEL_BLOCK)
    lights = vertices.map { |vertex| vertex[5] }.uniq
    assert_equal 1.0, lights.last
    assert_equal lights.sort, lights
    assert_operator lights.first, :<, 0.5
    assert_equal [1.0], vertices.map { |vertex| vertex[8] }.uniq
  end

  def test_each_filled_pixel_of_a_block_text_is_a_square_of_the_cell_and_the_edge_moves_by_a_pixel_a_layer
    @ui.block_text(100.0, 200.0, "I", 6.0, Tex::SPINEL_BLOCK)
    pixels = Tex::GLYPHS[Tex.glyph("I") - Tex::FONT].split(" ")
    filled = (0...5).flat_map { |row| (0...3).filter_map { |col| [col, row] if pixels[row][col] == "#" } }
    corners = lambda do |light|
      squares = vertices.select { |vertex| vertex[5] == light }.each_slice(QUAD_VERTICES).to_a
      squares.map { |square| [square.map { |vertex| vertex[0] }.min, square.map { |vertex| vertex[1] }.min] }
    end
    assert_equal filled.map { |col, row| [100.0 + col * 6.0, 200.0 + row * 6.0] }, corners.call(1.0)
    lights = vertices.map { |vertex| vertex[5] }.uniq
    lights.first(2).zip([2.0, 1.0]) do |light, depth|
      assert_equal corners.call(1.0).map { |x, y| [x + depth, y + depth] }, corners.call(light)
    end
    squares = vertices.each_slice(QUAD_VERTICES).first
    assert_equal [6.0, 6.0], [squares.map { |vertex| vertex[0] }.minmax.reduce(:-).abs, squares.map { |vertex| vertex[1] }.minmax.reduce(:-).abs]
  end

  private

  def vertices = @ui.v.each_slice(VERTEX).to_a

  def quads = vertices.each_slice(QUAD_VERTICES).to_a
end
