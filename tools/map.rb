# Draws a map of the generated world, without the game. Runs under CRuby.
#   ruby tools/map.rb [OUT]
# It writes OUT-top.png, a map from above, and OUT-tilt.png, the same land
# seen at a slant from the south (OUT is "map" by default). Land has the
# color of its biome and the light from the north-west; snow is white, bare
# rock gray, and water darker where it is deeper. Spawn is a red dot.
# SEED (1337), SIZE (8000 blocks across), STEP (8 blocks for each pixel)
# and LIFT (6, how much taller the slanted view draws the land) change it.
require "zlib"
require_relative "../game/rng"
require_relative "../game/textures"
require_relative "../game/block"
require_relative "../game/biome"
require_relative "../game/noise"
require_relative "../game/world"

# Biome colors: plains, forest, taiga, snowy taiga, tundra, desert,
# savanna, jungle and swamp (the order of Biome::ALL).
BIOME_RGB = [[141, 179, 96], [40, 120, 50], [50, 110, 95], [190, 215, 215], [240, 244, 248],
             [232, 205, 130], [190, 175, 95], [60, 150, 30], [90, 120, 80]]

def write_png(path, w, h, rgb)
  rows = String.new(capacity: (w * 3 + 1) * h)
  h.times { |y| rows << "\0" << rgb[y * w * 3, w * 3].pack("C*") }
  chunk = ->(type, data) { [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N") }
  File.binwrite(path, "\x89PNG\r\n\x1a\n".b + chunk.("IHDR", [w, h, 8, 2, 0, 0, 0].pack("NNCCCCC")) +
                      chunk.("IDAT", Zlib::Deflate.deflate(rows)) + chunk.("IEND", ""))
end

out = ARGV[0] || "map"
world = World.new((ENV["SEED"] || "1337").to_i)
step = (ENV["STEP"] || "8").to_i
n = (ENV["SIZE"] || "8000").to_i / step
lift = (ENV["LIFT"] || "6").to_f
x0 = -n / 2 * step

# The top of each column (water counts as its surface) and its color.
top = Array.new(n * n, 0)
color = Array.new(n * n * 3, 0)
land = Array.new(n * n, false)
n.times do |j|
  n.times do |i|
    x = x0 + i * step
    z = x0 + j * step
    h = world.surface_height(x, z)
    k = j * n + i
    rgb = if h - 1 < SEA
            t = [(SEA - h + 1) / 18.0, 1.0].min
            top[k] = SEA
            [(100 - 80 * t).to_i, (170 - 130 * t).to_i, (240 - 120 * t).to_i]
          else
            top[k] = h - 1
            land[k] = true
            b = world.biome(x, z, h)
            ground = world.top_block(x, z, h, b)
            if ground == Block::SNOW then [250, 250, 255]
            elsif ground == Block::STONE then [150, 150, 150]
            elsif ground == Block::SAND && b != Biome::DESERT then [225, 210, 160]
            else BIOME_RGB[b]
            end
          end
    color[k * 3, 3] = rgb
  end
end

# Light from the north-west: a slope that faces it is brighter.
n.times do |j|
  n.times do |i|
    k = j * n + i
    next unless land[k]
    dx = top[j * n + [i + 1, n - 1].min] - top[j * n + [i - 1, 0].max]
    dz = top[[j + 1, n - 1].min * n + i] - top[[j - 1, 0].max * n + i]
    shade = (1.0 - (dx + dz) * 0.06).clamp(0.6, 1.3)
    3.times { |c| color[k * 3 + c] = (color[k * 3 + c] * shade).round.clamp(0, 255) }
  end
end
mid = (n / 2 * n + n / 2) * 3
color[mid, 3] = [255, 0, 0]
write_png("#{out}-top.png", n, n, color)

# The slanted view: each row of the map moves down by `slant` pixels, and
# each block of height lifts a column by `rise` pixels. Rows draw from the
# front to the back, and a pixel that a nearer column covers stays.
slant = 0.6
rise = lift / step
height = (n * slant + WY * rise).ceil + 1
img = [200, 225, 250] * (n * height)
covered = Array.new(n, height)
(n - 1).downto(0) do |j|
  n.times do |i|
    k = j * n + i
    y_top = (j * slant + (WY - top[k]) * rise).round
    next if y_top >= covered[i]
    rgb = color[k * 3, 3]
    # The front row shows the cut through the ground, in the color of earth.
    side = j == n - 1 ? [120, 100, 80] : rgb.map { |v| (v * 0.7).round }
    y = y_top
    while y < covered[i]
      img[(y * n + i) * 3, 3] = y == y_top ? rgb : side
      y += 1
    end
    covered[i] = y_top
  end
end
write_png("#{out}-tilt.png", n, height, img)
puts "#{out}-top.png and #{out}-tilt.png: #{n * step} blocks across, #{step} blocks for each pixel"
