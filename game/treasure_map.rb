# The sites of the treasure chests: on the islands in open ocean, one at
# most in each cell of CELL x CELL blocks. Like Terrain, it reads only the
# noise, so it gives the same sites each time. ChunkGenerator puts a chest
# on each site, and tools/map.rb draws them.
class TreasureMap
  # The size of a cell in blocks: 1 << CELL_BITS. With 512, about one
  # island in two gets a chest, and almost no island gets two. This is not
  # a Minecraft value.
  CELL_BITS = 9
  CELL = 1 << CELL_BITS
  # The search reads one column in STEP on x and on z. Then it reads each
  # column within STEP / 2 of the highest one.
  STEP = 8
  # The ground of a site is at least RISE blocks above the sea.
  RISE = 4
  # The top blocks that a chest can stand on.
  GROUND = [Block::GRASS, Block::SNOW_GRASS, Block::SAND, Block::SNOW]
  # An island near the edge of a cell can get the sites of two cells. So a
  # site closer than GAP blocks (on x and on z) to the site that the
  # search found in a cell before it is no site, also when the GAP test
  # drops that site in its turn. The cells before a cell are the 4 cells next to
  # it that come first when the cells go in rows along x, one row of z
  # after another (BEFORE_X, BEFORE_Z).
  GAP = 64
  BEFORE_X = [-1, -1, 0, 1]
  BEFORE_Z = [0, -1, -1, -1]

  def initialize(terrain)
    @terrain = terrain
    # The site that the search found in each cell, before the GAP test,
    # by World.chunk_key.
    @found = {}
    nil
  end

  # The site of the cell cell_x, cell_z. The search reads each cell once.
  def site(cell_x, cell_z) = apart(found(cell_x, cell_z), cell_x, cell_z)

  # The site that the search finds in the cell, before the GAP test.
  def found(cell_x, cell_z)
    key = World.chunk_key(cell_x, cell_z)
    @found[key] = find(cell_x * CELL, cell_z * CELL) unless @found.key?(key)
    @found[key]
  end

  # site, or no site when it is too close to the site of a cell before
  # the cell cell_x, cell_z.
  def apart(site, cell_x, cell_z)
    return site unless site.found?

    BEFORE_X.size.times do |before|
      return TreasureSite.none if site.near?(found(cell_x + BEFORE_X[before], cell_z + BEFORE_Z[before]), GAP)
    end
    site
  end

  # The site of the cell around the block x, z (Integers).
  def site_at(x, z) = site(x >> CELL_BITS, z >> CELL_BITS)

  # The highest dry column of the cell with its corner at x0, z0 that is
  # in open ocean, then the highest column near it that a chest can stand
  # on.
  def find(x0, z0)
    best = SEA + RISE
    best_x = 0
    best_z = 0
    (0...CELL).step(STEP) do |dx|
      (0...CELL).step(STEP) do |dz|
        height = island_height(x0 + dx, z0 + dz)
        next if height <= best

        best = height
        best_x = x0 + dx
        best_z = z0 + dz
      end
    end
    return TreasureSite.none if best == SEA + RISE

    refine(best_x, best_z)
  end

  # The height of column x, z when it is in open ocean, else 0.
  def island_height(x, z)
    return 0 unless @terrain.continent(x, z) < Terrain::CONTINENT[1]

    @terrain.surface_height(x, z)
  end

  # The highest column within STEP / 2 of x, z and in its cell where a
  # chest can stand. The cell of a site is the one cell whose chunks put
  # its chest (ChunkGenerator#treasure_chest).
  def refine(x, z)
    best = SEA + RISE
    site = TreasureSite.none
    (-STEP / 2..STEP / 2).each do |dx|
      (-STEP / 2..STEP / 2).each do |dz|
        next unless (x + dx) >> CELL_BITS == x >> CELL_BITS && (z + dz) >> CELL_BITS == z >> CELL_BITS

        height = island_height(x + dx, z + dz)
        next if height <= best || !holds_chest?(x + dx, z + dz, height)

        best = height
        site = TreasureSite.new(x + dx, height, z + dz)
      end
    end
    site
  end

  # True when a chest can stand on column x, z of height: no tree grows
  # there, and no cave opens its top block.
  def holds_chest?(x, z, height)
    return false if @terrain.tree_top(x, z) >= 0
    return false if @terrain.entrance?(x, z) && @terrain.carved?(x, height - 1, z)

    GROUND.include?(@terrain.top_block(x, z, height, @terrain.biome(x, z, height)))
  end
end

# The cell of a treasure chest, or no site when chest_y is -1. The names
# are not x, y and z: Spinel would then look for a TreasureSite in each
# call of x on a value that it cannot type.
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

  # The distance on x and z from the middle of the top of the chest to x, z.
  def distance(x, z)
    dx = @chest_x + 0.5 - x
    dz = @chest_z + 0.5 - z
    Math.sqrt(dx * dx + dz * dz)
  end

  # True when other is a site and is less than reach blocks away on x and
  # on z.
  def near?(other, reach) = other.found? && (other.chest_x - @chest_x).abs < reach && (other.chest_z - @chest_z).abs < reach
end
