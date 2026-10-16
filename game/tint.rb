# Biome colors for grass and oak leaves (minecraft.wiki/w/Biome#Tint). The
# images have the plains colors, so a face multiplies its pixels by the
# ratio of the color of its biome to the plains color. The tint map holds
# these ratios for the loaded world, with one pixel for each square of
# GROUP x GROUP columns. The GPU blends the pixels of the map, so the colors
# change smoothly at the edge of a biome, as the biome blend of Minecraft does.
class Tint
  GROUP = 4
  # The map is a ring like the world, of Mesher::COLUMNS columns. Layer 0
  # holds the grass ratios and layer 1 the foliage ratios. TINT_SIZE in
  # gfx.rb has the same value.
  SIZE = Mesher::COLUMNS / GROUP
  # A channel of the map holds the ratio times ONE.
  ONE = 64

  attr_reader :pixels
  # True when the map changed after the last upload.
  attr_accessor :changed

  def initialize(world)
    @world = world
    @pixels = Array.new(SIZE * SIZE * 2, 0)
    @changed = false
    # The map pixel of each biome: the grass ratio, then the foliage ratio.
    @ratio = Array.new(Biome::ALL.size * 2, 0)
    Biome::ALL.size.times do |b|
      @ratio[b * 2] = Tint.ratio(Biome::GRASS_COLOR[b], Biome::GRASS_COLOR[Biome::PLAINS])
      @ratio[b * 2 + 1] = Tint.ratio(Biome::FOLIAGE_COLOR[b], Biome::FOLIAGE_COLOR[Biome::PLAINS])
    end
  end

  # The channel at bit shift of color c, divided by the same channel of
  # color base, times ONE.
  def self.channel(c, base, shift)
    d = (base >> shift) & 255
    ((((c >> shift) & 255) * ONE + d / 2) / d).clamp(0, 255)
  end

  # The ratio of color c (0xRRGGBB) to color base, as a map pixel (0xAABBGGRR).
  def self.ratio(c, base)
    (255 << 24) | (Tint.channel(c, base, 0) << 16) | (Tint.channel(c, base, 8) << 8) | Tint.channel(c, base, 16)
  end

  # Paints the squares of chunk (cx, cz) with the ratios of their biomes.
  # The biome of a square is the biome of the column at its middle.
  def paint(cx, cz)
    n = CHUNK / GROUP
    n.times do |i|
      n.times do |j|
        gx = cx * n + i
        gz = cz * n + j
        x = gx * GROUP + GROUP / 2
        z = gz * GROUP + GROUP / 2
        b = @world.biome(x, z, @world.surface_height(x, z))
        k = (gz & (SIZE - 1)) * SIZE + (gx & (SIZE - 1))
        @pixels[k] = @ratio[b * 2]
        @pixels[SIZE * SIZE + k] = @ratio[b * 2 + 1]
      end
    end
    @changed = true
  end

  # Far terrain has no map. Its faces hold their biome, and the shader reads
  # the ratios of the biome from the uniforms: at u[at], 4 floats (r, g, b,
  # 1) for each map pixel of @ratio.
  def write_uniforms(u, at)
    @ratio.size.times do |k|
      px = @ratio[k]
      u[at + k * 4] = (px & 255) / ONE.to_f
      u[at + k * 4 + 1] = ((px >> 8) & 255) / ONE.to_f
      u[at + k * 4 + 2] = ((px >> 16) & 255) / ONE.to_f
      u[at + k * 4 + 3] = 1.0
    end
  end
end
