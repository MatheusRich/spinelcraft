# Vertex builder for the HUD, in pixels (2D).
class Ui
  # The gap between the armor row and the grid, and between the grid and the
  # hotbar row, in pixels at scale 1.
  PACK_ROW_GAP = 14.0
  # The room that the armor row and the title need above the grid.
  ARMOR_ROW_ROOM = 58.0
  # An empty armor slot shows a dark piece of its kind.
  EMPTY_ARMOR_OPACITY = 0.2
  # The colors of the screens.
  TITLE_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.25)
  PAUSE_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.45)
  HOTBAR_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.45)
  SCREEN_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.55)
  BAR_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.5)
  CHAT_INPUT_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.6)
  CHAT_MATCHES_BACKDROP = Color.new(0.0, 0.0, 0.0, 0.75)
  WATER_TINT = Color.new(0.1, 0.25, 0.6, 0.25)
  LAVA_TINT = Color.new(0.9, 0.3, 0.05, 0.75)
  DEATH_TINT = Color.new(0.5, 0.0, 0.0, 0.5)
  FIRE_OVERLAY = Color.new(1.0, 1.0, 1.0, 0.85)
  CROSSHAIR = Color.new(1.0, 1.0, 1.0, 0.8)
  CHARGE_FILL = Color.new(1.0, 1.0, 1.0, 0.8)
  HOTBAR_SELECTION = Color.new(1.0, 1.0, 1.0, 0.95)
  HOTBAR_SLOT_BACK = Color.new(0.25, 0.25, 0.25, 0.9)
  SLOT_SELECTION = Color.new(1.0, 1.0, 1.0, 0.9)
  BUBBLE = Color.new(0.6, 0.85, 1.0, 0.9)
  PANEL = Color.new(0.18, 0.18, 0.2, 0.95)
  INSET = Color.new(0.1, 0.1, 0.12, 1.0)
  SCROLL_THUMB = Color.new(0.6, 0.6, 0.65, 1.0)
  MENU_KNOB = Color.new(0.9, 0.9, 0.9, 1.0)
  MENU_HELP_TEXT = Color.new(0.9, 0.9, 0.9, 1.0)
  HINT_TEXT = Color.new(1.0, 1.0, 0.7, 0.9)
  LABEL_TEXT = Color.new(1.0, 1.0, 0.8, 1.0)
  EMPTY_HINT_TEXT = Color.new(0.8, 0.8, 0.8, 1.0)
  DEATH_LASTED_TEXT = Color.new(1.0, 0.85, 0.6, 1.0)
  NEW_TAG = Color.new(1.0, 0.85, 0.2, 1.0)
  MATCH_CURRENT = Color.new(1.0, 1.0, 0.3, 1.0)
  MATCH_OTHER = Color.new(0.65, 0.65, 0.65, 1.0)

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

  def quad(x, y, w, h, layer, u1, v1, color)
    l = layer.to_f
    red = color.red
    green = color.green
    blue = color.blue
    alpha = color.alpha
    vert(x, y, 0.0, 0.0, l, red, green, blue, alpha)
    vert(x + w, y, u1, 0.0, l, red, green, blue, alpha)
    vert(x + w, y + h, u1, v1, l, red, green, blue, alpha)
    vert(x, y, 0.0, 0.0, l, red, green, blue, alpha)
    vert(x + w, y + h, u1, v1, l, red, green, blue, alpha)
    vert(x, y + h, 0.0, v1, l, red, green, blue, alpha)
  end

  def rect(x, y, w, h, color)
    quad(x, y, w, h, Tex::WHITE, 1.0, 1.0, color)
  end

  def icon(x, y, size, layer, shade)
    quad(x, y, size, size, layer, 1.0, 1.0, Color.new(shade, shade, shade, 1.0))
  end

  # The item or block in the square at x, y with the side size, as in the inventory of
  # Minecraft: a flat item is its picture, and a block is a small cube.
  def item(x, y, size, block, shade)
    if Block.flat?(block)
      icon(x, y, size, Block::FRONT[block], shade)
    else
      cube(x + size / 2.0, y + size / 2.0, size * 0.625, block, shade)
    end
  end

  # Block as a cube with the edge e around cx, cy. The view comes from
  # above at 30 degrees and from the corner between the -x and +z faces, as
  # the gui display of block/block in Minecraft: rotation (30, 225, 0) and
  # scale 0.625. The top shows TOP, the left face FRONT and the right face
  # SIDE. A block with a shape (a chest) is the box of its shape.
  def cube(cx, cy, e, block, shade) # rubocop:todo Metrics/MethodLength
    @ix = cx
    @iy = cy
    @ie = e
    x0 = 0.0
    y0 = 0.0
    z0 = 0.0
    x1 = 1.0
    y1 = 1.0
    z1 = 1.0
    if Block::SHAPE[block] > 0
      s = Block::SHAPE[block] * 6
      x0 = Block::SHAPE_BOX[s] / 16.0
      y0 = Block::SHAPE_BOX[s + 1] / 16.0
      z0 = Block::SHAPE_BOX[s + 2] / 16.0
      x1 = Block::SHAPE_BOX[s + 3] / 16.0
      y1 = Block::SHAPE_BOX[s + 4] / 16.0
      z1 = Block::SHAPE_BOX[s + 5] / 16.0
    end
    face(iso_x(x0, z0), iso_y(x0, y1, z0), iso_x(x1, z0), iso_y(x1, y1, z0),
         iso_x(x1, z1), iso_y(x1, y1, z1), iso_x(x0, z1), iso_y(x0, y1, z1),
         x0, z0, x1, z1, Block::TOP[block], shade)
    face(iso_x(x0, z0), iso_y(x0, y1, z0), iso_x(x0, z1), iso_y(x0, y1, z1),
         iso_x(x0, z1), iso_y(x0, y0, z1), iso_x(x0, z0), iso_y(x0, y0, z0),
         z0, 1.0 - y1, z1, 1.0 - y0, Block::FRONT[block], shade * 0.8)
    face(iso_x(x0, z1), iso_y(x0, y1, z1), iso_x(x1, z1), iso_y(x1, y1, z1),
         iso_x(x1, z1), iso_y(x1, y0, z1), iso_x(x0, z1), iso_y(x0, y0, z1),
         x0, 1.0 - y1, x1, 1.0 - y0, Block::SIDE[block], shade * 0.6)
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

  def text(x, y, s, scale, color)
    shadow = Color.new(0.0, 0.0, 0.0, color.alpha * 0.6)
    cx = x
    s.each_char do |ch|
      glyph = Tex.glyph(ch)
      quad(cx + scale, y + scale, 3.0 * scale, 5.0 * scale, glyph, 9.0 / 16.0, 15.0 / 16.0, shadow)
      quad(cx, y, 3.0 * scale, 5.0 * scale, glyph, 9.0 / 16.0, 15.0 / 16.0, color)
      cx += 4.0 * scale
    end
  end

  def text_width(s, scale) = s.size * 4.0 * scale

  # Text in the font of the game, where each pixel of a glyph is a square
  # of the side cell with the texture layer. A dark edge goes below and to
  # the right of each square, as in assets/logo.png (tools/logo.rb). The
  # edge is a stack of copies, one pixel apart, that get darker away from
  # the front.
  def block_text(x, y, s, cell, layer)
    depth = (cell / 3.0).to_i
    depth.downto(0) do |d|
      light = d == 0 ? 1.0 : 0.25 + 0.2 * (1.0 - d.to_f / depth)
      color = Color.new(light, light, light, 1.0)
      cx = x + d
      s.each_char do |ch|
        rows = Tex::GLYPHS[Tex.glyph(ch) - Tex::FONT].split(" ")
        5.times do |row|
          3.times do |col|
            next if rows[row][col] != "#"

            quad(cx + col * cell, y + d + row * cell, cell, cell, layer, 1.0, 1.0, color)
          end
        end
        cx += 4.0 * cell
      end
    end
  end
end
