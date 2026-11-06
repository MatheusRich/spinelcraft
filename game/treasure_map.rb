# The treasure sites: on islands in open ocean and on peaks above the
# clouds, at most one in each cell. It reads only noise.
class TreasureMap
  # With cells of 1024 blocks, a world of 8000 x 8000 blocks has 19 to 32
  # chests (seeds 1337, 42 and 7). This is not a Minecraft value.
  CELL_BITS = 10
  CELL = 1 << CELL_BITS
  # An island is about 60 blocks across, and a step of 8 finds about as
  # many sites as 16.
  STEP = 16
  RISE = 4
  # Minecraft has no site above the clouds.
  CLOUD_TOP = 196
  GROUND = [Block::GRASS, Block::SNOW_GRASS, Block::SAND, Block::SNOW]
  # The margin keeps a large island at the edge of a cell from getting two
  # chests next to each other.
  MARGIN = 32

  def self.inside?(x) = (x & (CELL - 1)).between?(MARGIN, CELL - MARGIN - 1)

  def initialize(terrain)
    @terrain = terrain
    @sites = {}
    nil
  end

  def site(cell_x, cell_z)
    key = World.chunk_key(cell_x, cell_z)
    @sites[key] = find(cell_x * CELL, cell_z * CELL) unless @sites.key?(key)
    @sites[key]
  end

  def site_at(x, z) = site(x >> CELL_BITS, z >> CELL_BITS)

  # When no column near the island holds a chest, the peak can still hold
  # one.
  def find(x0, z0)
    island = TreasureSite.new(0, SEA + RISE, 0)
    peak = TreasureSite.new(0, CLOUD_TOP, 0)
    (x0 + MARGIN...x0 + CELL - MARGIN).step(STEP) do |x|
      (z0 + MARGIN...z0 + CELL - MARGIN).step(STEP) do |z|
        height = site_height(x, z)
        if height > peak.chest_y
          peak = TreasureSite.new(x, height, z)
        elsif height > island.chest_y && height <= CLOUD_TOP
          island = TreasureSite.new(x, height, z)
        end
      end
    end
    if island.chest_y > SEA + RISE
      site = refine(island.chest_x, island.chest_z, SEA + RISE)
      return site if site.found?
    end
    return refine(peak.chest_x, peak.chest_z, CLOUD_TOP) if peak.chest_y > CLOUD_TOP

    TreasureSite.none
  end

  def site_height(x, z)
    height = @terrain.surface_height(x, z)
    return height if height > CLOUD_TOP || @terrain.continent(x, z) < Terrain::CONTINENT[1]

    0
  end

  # The cell of a site is the one cell whose chunks put its chest
  # (ChunkGenerator#treasure_chest).
  def refine(x, z, floor)
    best = floor
    site = TreasureSite.none
    (-STEP / 2..STEP / 2).each do |dx|
      (-STEP / 2..STEP / 2).each do |dz|
        next unless TreasureMap.inside?(x + dx)
        next unless TreasureMap.inside?(z + dz)

        height = site_height(x + dx, z + dz)
        next if height <= best || !holds_chest?(x + dx, z + dz, height)

        best = height
        site = TreasureSite.new(x + dx, height, z + dz)
      end
    end
    site
  end

  def holds_chest?(x, z, height)
    return false if @terrain.tree_top(x, z) >= 0
    return false if @terrain.cave_shape.opening?(x, height - 1, z)

    GROUND.include?(@terrain.top_block(x, z, height, @terrain.biome(x, z, height)))
  end
end

# No site when chest_y is -1. The names are not x, y and z: Spinel would
# then look for a TreasureSite in each call of x on a value that it
# cannot type.
class TreasureSite
  attr_reader :chest_x, :chest_y, :chest_z

  def self.none = TreasureSite.new(0, -1, 0)

  def initialize(chest_x, chest_y, chest_z)
    @chest_x = chest_x
    @chest_y = chest_y
    @chest_z = chest_z
    nil
  end

  def found? = @chest_y >= 0

  def distance(x, z)
    dx = @chest_x + 0.5 - x
    dz = @chest_z + 0.5 - z
    Math.sqrt(dx * dx + dz * dz)
  end
end
