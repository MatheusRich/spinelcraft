# Vertex builder for the HUD, in pixels (2D).
class Ui
  attr_reader :v

  def initialize
    @v = []
  end

  def clear = @v.clear

  def vert(x, y, u, w, layer, r, g, b, a)
    @v << x << y << u << w << layer << r << g << b << a
  end

  def quad(x, y, w, h, layer, u1, v1, r, g, b, a)
    l = layer.to_f
    vert(x, y, 0.0, 0.0, l, r, g, b, a)
    vert(x + w, y, u1, 0.0, l, r, g, b, a)
    vert(x + w, y + h, u1, v1, l, r, g, b, a)
    vert(x, y, 0.0, 0.0, l, r, g, b, a)
    vert(x + w, y + h, u1, v1, l, r, g, b, a)
    vert(x, y + h, 0.0, v1, l, r, g, b, a)
  end

  def rect(x, y, w, h, r, g, b, a)
    quad(x, y, w, h, Tex::WHITE, 1.0, 1.0, r, g, b, a)
  end

  def icon(x, y, size, layer, shade)
    quad(x, y, size, size, layer, 1.0, 1.0, shade, shade, shade, 1.0)
  end

  def text(x, y, s, scale, r, g, b, a)
    cx = x
    s.each_char do |ch|
      glyph = Tex.glyph(ch)
      quad(cx + scale, y + scale, 3.0 * scale, 5.0 * scale, glyph, 9.0 / 16.0, 15.0 / 16.0, 0.0, 0.0, 0.0, a * 0.6)
      quad(cx, y, 3.0 * scale, 5.0 * scale, glyph, 9.0 / 16.0, 15.0 / 16.0, r, g, b, a)
      cx += 4.0 * scale
    end
  end

  def text_width(s, scale) = s.size * 4.0 * scale
end
