# Draws the icon and the title of the game from its textures. Runs under
# CRuby, and needs ImageMagick (`magick`) to read and write the PNGs.
#   ruby tools/logo.rb
# assets/pixel-perfection/spinel_block.png is stone in the spinel red.
# assets/icon.png is a block of spinel ore, as the inventory shows a block.
# assets/logo.png is SPINELCRAFT in the font of the game. Each pixel of a
# glyph is a block, with a dark edge below it and to its right. SPINEL is
# spinel_block.png, and CRAFT is cobblestone. The title screen of the game
# (Ui#block_text) draws the same title.
require_relative "../game/textures"

ROOT = File.expand_path("..", __dir__)

# The 16 x 16 texture from assets/pixel-perfection, as [r, g, b, a] pixels.
def texture(name)
  path = File.join(ROOT, "assets/pixel-perfection/#{name}.png")
  IO.popen(["magick", path, "-alpha", "on", "-depth", "8", "rgba:-"], "rb", &:read).bytes.each_slice(4).to_a
end

# Writes the image at assets/<name>.png.
def write_png(name, w, h, pixels)
  path = File.join(ROOT, "assets/#{name}.png")
  # Without a date in the file, the same pixels give the same file.
  IO.popen(["magick", "-size", "#{w}x#{h}", "-depth", "8", "rgba:-", "-define", "png:exclude-chunks=date,time", path], "wb") do |io|
    io.write(pixels.flatten.pack("C*"))
  end
end

def shade(rgba, light) = rgba[0, 3].map { |c| (c * light).round } + [255]

def lerp(from, to, t) = from.zip(to).map { |a, b| (a + ((b - a) * t)).round }

# The stone texture, with its lightness on the spinel red palette:
# #5E0C22 (the darkest) to #D8304A (the gem) to #FF9AA8 (the lightest), as
# in assets/pixel-perfection/README.md.
def draw_spinel_block
  dark = [0x5E, 0x0C, 0x22]
  gem = [0xD8, 0x30, 0x4A]
  light = [0xFF, 0x9A, 0xA8]
  lums = texture("stone").map { |r, g, b, _| (r * 0.3) + (g * 0.59) + (b * 0.11) }
  lo, hi = lums.minmax
  pixels = lums.map do |lum|
    t = (lum - lo) / (hi - lo)
    (t < 0.5 ? lerp(dark, gem, t * 2) : lerp(gem, light, (t - 0.5) * 2)) + [255]
  end
  write_png("pixel-perfection/spinel_block", 16, 16, pixels)
end

# The three faces of the icon in a 512 x 512 image: the corner of the
# texture, the screen step for one texture width and one texture height,
# and the light. The top is a 2:1 rhombus; the left and right sides are
# darker.
ICON_SIZE = 512
ICON_FACES = [
  [56, 156, 200, -100, 200, 100, 1.0],
  [56, 156, 200, 100, 0, 220, 0.8],
  [256, 256, 200, -100, 0, 220, 0.6]
].freeze

# The texel of a face under the center of a screen pixel, or nil.
def face_texel(face, x, y)
  ox, oy, ax, ay, bx, by, = face
  px = x + 0.5 - ox
  py = y + 0.5 - oy
  det = (ax * by) - (bx * ay)
  u = ((px * by) - (bx * py)) / det
  v = ((ax * py) - (ay * px)) / det
  return nil unless u >= 0 && u < 1 && v >= 0 && v < 1

  ((v * 16).floor * 16) + (u * 16).floor
end

def draw_icon
  ore = texture("spinel_ore")
  pixels = Array.new(ICON_SIZE * ICON_SIZE) do |i|
    face = nil
    texel = nil
    ICON_FACES.each do |f|
      texel = face_texel(f, i % ICON_SIZE, i / ICON_SIZE)
      face = f
      break if texel
    end
    texel ? shade(ore[texel], face[6]) : [0, 0, 0, 0]
  end
  write_png("icon", ICON_SIZE, ICON_SIZE, pixels)
end

# The screen pixels for one texture pixel, the pixels of a block, the depth
# of the dark edge and the empty border of the title.
LOGO_SCALE = 3
BLOCK = 16 * LOGO_SCALE
DEPTH = BLOCK / 3
MARGIN = BLOCK / 2

# Each block of the title, as [column, row, texture], and the columns that
# the title fills.
def logo_blocks
  blocks = []
  column = 0
  [["SPINEL", texture("spinel_block")], ["CRAFT", texture("cobble")]].each do |word, tex|
    word.each_char do |ch|
      Tex::GLYPHS[Tex::CHARS.index(ch)].split.each_with_index do |row, y|
        row.each_char.with_index { |cell, x| blocks << [column + x, y, tex] if cell == "#" }
      end
      column += 4
    end
  end
  [blocks, column - 1]
end

def draw_block(pixels, width, block, offset, light)
  column, row, tex = block
  BLOCK.times do |sy|
    BLOCK.times do |sx|
      x = MARGIN + (column * BLOCK) + sx + offset
      y = MARGIN + (row * BLOCK) + sy + offset
      pixels[(y * width) + x] = shade(tex[((sy / LOGO_SCALE) * 16) + (sx / LOGO_SCALE)], light)
    end
  end
end

# The edge is a stack of copies of each block, one pixel apart, that get
# darker away from the front.
def draw_logo
  blocks, columns = logo_blocks
  width = (columns * BLOCK) + DEPTH + (MARGIN * 2)
  height = (5 * BLOCK) + DEPTH + (MARGIN * 2)
  pixels = Array.new(width * height) { [0, 0, 0, 0] }
  DEPTH.downto(1) do |d|
    light = 0.25 + (0.2 * (1 - (d.to_f / DEPTH)))
    blocks.each { |block| draw_block(pixels, width, block, d, light) }
  end
  blocks.each { |block| draw_block(pixels, width, block, 0, 1.0) }
  write_png("logo", width, height, pixels)
end

draw_spinel_block
draw_icon
draw_logo
