# Vertex builder for the HUD, in pixels (2D).
class Ui
  attr_reader :v

  def initialize
    @v = []
    # The center and the edge of the cube that cube draws.
    @ix = 0.0
    @iy = 0.0
    @ie = 0.0
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

  # Item b in the square at x, y with the side size, as in the inventory of
  # Minecraft: a flat item is its picture, and a block is a small cube.
  def item(x, y, size, b, shade)
    if Block.flat?(b)
      icon(x, y, size, Block::FRONT[b], shade)
    else
      cube(x + size / 2.0, y + size / 2.0, size * 0.625, b, shade)
    end
  end

  # Block b as a cube with the edge e around cx, cy. The view comes from
  # above at 30 degrees and from the corner between the -x and +z faces, as
  # the gui display of block/block in Minecraft: rotation (30, 225, 0) and
  # scale 0.625. The top shows TOP, the left face FRONT and the right face
  # SIDE. A block with a shape (a chest) is the box of its shape.
  def cube(cx, cy, e, b, shade) # rubocop:todo Metrics/MethodLength
    @ix = cx
    @iy = cy
    @ie = e
    x0 = 0.0
    y0 = 0.0
    z0 = 0.0
    x1 = 1.0
    y1 = 1.0
    z1 = 1.0
    if Block::SHAPE[b] > 0
      s = Block::SHAPE[b] * 6
      x0 = Block::SHAPE_BOX[s] / 16.0
      y0 = Block::SHAPE_BOX[s + 1] / 16.0
      z0 = Block::SHAPE_BOX[s + 2] / 16.0
      x1 = Block::SHAPE_BOX[s + 3] / 16.0
      y1 = Block::SHAPE_BOX[s + 4] / 16.0
      z1 = Block::SHAPE_BOX[s + 5] / 16.0
    end
    face(iso_x(x0, z0), iso_y(x0, y1, z0), iso_x(x1, z0), iso_y(x1, y1, z0),
         iso_x(x1, z1), iso_y(x1, y1, z1), iso_x(x0, z1), iso_y(x0, y1, z1),
         x0, z0, x1, z1, Block::TOP[b], shade)
    face(iso_x(x0, z0), iso_y(x0, y1, z0), iso_x(x0, z1), iso_y(x0, y1, z1),
         iso_x(x0, z1), iso_y(x0, y0, z1), iso_x(x0, z0), iso_y(x0, y0, z0),
         z0, 1.0 - y1, z1, 1.0 - y0, Block::FRONT[b], shade * 0.8)
    face(iso_x(x0, z1), iso_y(x0, y1, z1), iso_x(x1, z1), iso_y(x1, y1, z1),
         iso_x(x1, z1), iso_y(x1, y0, z1), iso_x(x0, z1), iso_y(x0, y0, z1),
         x0, 1.0 - y1, x1, 1.0 - y0, Block::SIDE[b], shade * 0.6)
  end

  # The screen place of the point x, y, z of the cube of cube, from 0 to 1
  # on each axis.
  def iso_x(x, z) = @ix + (x + z - 1.0) * 0.7071 * @ie
  def iso_y(x, y, z) = @iy - (y - 0.5) * 0.866 * @ie + (z - x) * 0.3536 * @ie

  # A face with the corners a, b, c and d, and the texture from u0, v0 at a
  # to u1, v1 at c.
  def face(ax, ay, bx, by, cx, cy, dx, dy, u0, v0, u1, v1, layer, s)
    l = layer.to_f
    vert(ax, ay, u0, v0, l, s, s, s, 1.0)
    vert(bx, by, u1, v0, l, s, s, s, 1.0)
    vert(cx, cy, u1, v1, l, s, s, s, 1.0)
    vert(ax, ay, u0, v0, l, s, s, s, 1.0)
    vert(cx, cy, u1, v1, l, s, s, s, 1.0)
    vert(dx, dy, u0, v1, l, s, s, s, 1.0)
  end

  # The bottom part (0 to 1) of an icon, as the flame of a furnace that
  # burns down.
  def icon_bottom(x, y, size, layer, part)
    l = layer.to_f
    top = y + size * (1.0 - part)
    v0 = 1.0 - part
    vert(x, top, 0.0, v0, l, 1.0, 1.0, 1.0, 1.0)
    vert(x + size, top, 1.0, v0, l, 1.0, 1.0, 1.0, 1.0)
    vert(x + size, y + size, 1.0, 1.0, l, 1.0, 1.0, 1.0, 1.0)
    vert(x, top, 0.0, v0, l, 1.0, 1.0, 1.0, 1.0)
    vert(x + size, y + size, 1.0, 1.0, l, 1.0, 1.0, 1.0, 1.0)
    vert(x, y + size, 0.0, 1.0, l, 1.0, 1.0, 1.0, 1.0)
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
