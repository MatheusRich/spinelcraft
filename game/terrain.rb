# The land of one seed, from noise alone. It reads no block.
class Terrain
  attr_reader :cave_shape

  CONTINENT = [-0.25, -0.17, -0.135, -0.12]
  SEA_FLOOR = [SEA - 34.0, SEA - 26.0, SEA - 8.0, SEA + 0.0]
  # The land tables follow the terrain splines of Minecraft 1.18, as Henrik
  # Kniberg showed them in "Reinventing Minecraft world generation" (2022):
  # rows at the continent noise, columns at the erosion noise. The values
  # are ours.
  LAND_CONTINENT = [-0.12, -0.115, -0.05, 0.13, 0.38, 0.73]
  EROSION = [-0.2, -0.09, -0.05, -0.047, -0.015, -0.012, 0.03, 0.045, 0.06, 0.2]
  LAND_BASE = [
    [3.0, 2.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [22.0, 20.0, 12.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0],
    [24.0, 16.0, 7.0, 6.0, 6.0, 5.0, 5.0, 4.0, 3.0, 2.0],
    [14.0, 12.0, 13.0, 12.0, 12.0, 11.0, 10.0, 8.0, 5.0, 3.0],
    [20.0, 18.0, 20.0, 45.0, 45.0, 18.0, 15.0, 12.0, 8.0, 5.0],
    [28.0, 26.0, 28.0, 68.0, 68.0, 50.0, 44.0, 34.0, 26.0, 22.0]
  ].freeze
  LAND_HILLS = [
    [10.0, 10.0, 10.0, 12.0, 10.0, 9.0, 7.0, 6.0, 4.0, 2.0],
    [10.0, 10.0, 10.0, 12.0, 10.0, 9.0, 7.0, 6.0, 4.0, 2.0],
    [50.0, 40.0, 32.0, 28.0, 26.0, 24.0, 18.0, 14.0, 6.0, 3.0],
    [45.0, 45.0, 40.0, 32.0, 30.0, 28.0, 22.0, 16.0, 7.0, 3.0],
    [45.0, 45.0, 40.0, 8.0, 8.0, 30.0, 24.0, 18.0, 7.0, 4.0],
    [45.0, 45.0, 42.0, 8.0, 8.0, 32.0, 26.0, 20.0, 9.0, 5.0]
  ].freeze
  LAND_RIDGES = [
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.8, 0.35, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.8, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.8, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    [0.8, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
  ].freeze
  EROSION_SCALE = 1500.0
  EROSION_ZONE_SCALE = 6000.0
  EROSION_ZONE_WEIGHT = 0.6
  ROUGH_EROSION = EROSION[2]
  PLATEAU_LOW_EROSION = EROSION[3]
  PLATEAU_HIGH_EROSION = EROSION[4]
  PLATEAU_TOP = 30
  FLAT_EROSION = EROSION[8]
  ISLE = 0.15
  ISLE_RISE = 180.0
  ISLE_SCALE = 220.0
  ARCHIPELAGO = 0.16
  ARCHIPELAGO_EDGE = 0.1
  ARCHIPELAGO_SCALE = 3000.0
  ISLE_HILLS = 5.0
  WARP = 90.0
  # Rivers run where the river noise is near zero, as Minecraft rivers run
  # in the valleys of its weirdness noise.
  RIVER_VALLEY = 0.024
  RIVER_SCALE = 2200.0
  RIVER_BED = SEA - 5.0
  # A river ends at a source in the hills or in a dry land. Luanti also
  # dries its rivers in dry climates (MGVALLEYS_VARY_RIVER_DEPTH in
  # mapgen_valleys.cpp).
  RIVER_TOP = 30.0
  RIVER_RISE = 16.0
  RIVER_DRY = -0.6
  RIVER_WET = 0.5
  CONTINENT_SCALE = 2000.0
  BASIN_SCALE = 8000.0
  BASIN_DEPTH = 2.6
  CLIMATE_SCALE = 1600.0
  CLIMATE_ZONE_SCALE = 6000.0
  CLIMATE_ZONE_WEIGHT = 2.5
  RIDGE_SCALE = 200.0
  RIDGE_RISE = 160.0
  SPUR_SCALE = 80.0
  SPUR = 0.4
  # The peak noise breaks the loops of the ridge lines into peaks and
  # saddles.
  PEAK_SCALE = 120.0
  SADDLE = 0.2
  # Perlin noise is 0 at whole noise positions, and x = z = 0 is one for
  # every scale. This shift moves the terrain off them, so each seed gets
  # its own land at spawn.
  SHIFT = 5000.5
  LAND_STEP = 64
  LAND_RADIUS = 4096
  # Luanti spawns at most 16 blocks above its water level
  # (MapgenV7::getSpawnLevelAtPoint in mapgen_v7.cpp). The middle of a
  # continent here is high, so the land SPAWN_REACH to each side must be
  # low too, and a valley in the mountains is no spawn.
  SPAWN_BOTTOM = 4
  SPAWN_TOP = 16
  SPAWN_REACH = 48
  SPAWN_BIOMES = [Biome::PLAINS, Biome::SAVANNA].freeze
  TOP = WY - 14.0
  PEAK = SEA + 100.0
  BEACH_TOP = SEA + 2
  SWAMP_TOP = SEA + 8
  # Minecraft places its beaches on the coast, not by height, so a low
  # field inland keeps its grass (minecraft.wiki/w/Beach).
  SHORE = -0.11
  # A rough coast is a stony shore: "made entirely of stone and variants,
  # with long strips of gravel" (minecraft.wiki/w/Stony_Shore).
  GRAVEL_STRIP = 0.2
  GRAVEL_STRIP_LENGTH = 28.0
  GRAVEL_STRIP_WIDTH = 5.0
  ROCK_LINE = SEA + 95
  SNOW_LINE = SEA + 110
  COLD_LINE = SEA + 30
  COOLING = 0.004
  # Minecraft has no clearings or groves; these values are not from the wiki.
  CLEARING_START = 0.2
  GROVE = 2.0

  def initialize(seed)
    @noise = Noise.new(seed)
    @noise2 = Noise.new(seed * 31 + 7)
    @noise3 = Noise.new(seed * 17 + 3)
    @noise4 = Noise.new(seed * 43 + 11)
    @warp_nx = SHIFT
    @warp_nz = SHIFT
    @wx = warp_x(SHIFT, SHIFT)
    @wz = warp_z(SHIFT, SHIFT)
    @continent = 0.0
    @continent_read = false
    @erosion = 0.0
    @erosion_read = false
    @cave_shape = CaveShape.new(seed)
  end

  def low_land?(x, z) = (surface_height(x, z) - SEA).between?(SPAWN_BOTTOM + 1, SPAWN_TOP)

  def spawn_land?(x, z)
    low_land?(x, z) && low_land?(x + SPAWN_REACH, z) && low_land?(x - SPAWN_REACH, z) &&
      low_land?(x, z + SPAWN_REACH) && low_land?(x, z - SPAWN_REACH) &&
      SPAWN_BIOMES.include?(biome(x, z, surface_height(x, z)))
  end

  def spawn_near_origin
    return [0, 0] if spawn_land?(0, 0)

    (LAND_STEP..LAND_RADIUS).step(LAND_STEP) do |radius|
      (-radius..radius).step(LAND_STEP) do |side|
        return [side, -radius] if spawn_land?(side, -radius)
        return [side, radius] if spawn_land?(side, radius)
        return [-radius, side] if spawn_land?(-radius, side)
        return [radius, side] if spawn_land?(radius, side)
      end
    end
    [0, 0]
  end

  # Without to_f, Spinel cannot type this loop of noise into noise.
  def warp_x(x, z) = x + @noise4.noise2(x / 160.0, z / 160.0).to_f * WARP
  # Biome follows surface_height on the same column, so the last warp is
  # kept.
  def warp(nx, nz)
    return if nx == @warp_nx && nz == @warp_nz

    @warp_nx = nx
    @warp_nz = nz
    @wx = warp_x(nx, nz)
    @wz = warp_z(nx, nz)
    @continent_read = false
    @erosion_read = false
    nil
  end

  def warp_z(x, z) = z + @noise4.noise2(x / 160.0 + 70.0, z / 160.0).to_f * WARP

  # TreasureMap#site_height reads the warp that this leaves in @wx and @wz.
  def continent(x, z)
    warp(x + SHIFT, z + SHIFT)
    unless @continent_read
      @continent = @noise.fbm2(@wx / CONTINENT_SCALE, @wz / CONTINENT_SCALE, 4) +
                   @noise.noise2(@wx / BASIN_SCALE + 600.0, @wz / BASIN_SCALE) * BASIN_DEPTH
      @continent_read = true
    end
    @continent
  end

  def surface_height(x, z) # rubocop:todo Metrics/MethodLength
    nx = x + SHIFT
    nz = z + SHIFT
    continent = continent(x, z)
    wx = @wx
    wz = @wz
    erosion = erosion(x, z)
    hills = @noise.fbm2(nx / 55.0 + 40.0, nz / 55.0, 4)
    h = hills * Terrain.land(LAND_HILLS, continent, erosion)
    if continent < LAND_CONTINENT[0]
      h += Terrain.spline(CONTINENT, SEA_FLOOR, continent)
    else
      base = Terrain.land(LAND_BASE, continent, erosion)
      h += SEA + base
      ridges = Terrain.land(LAND_RIDGES, continent, erosion)
      h += ridges(wx, wz) * ridges if ridges > 0.0
      h = river_height(base, h) if base < RIVER_TOP
    end
    ocean = Terrain.smooth((CONTINENT[2] - continent) / (CONTINENT[2] - CONTINENT[1]))
    ocean *= Terrain.smooth((@noise2.noise2(wx / ARCHIPELAGO_SCALE + 1100.0, wz / ARCHIPELAGO_SCALE) - ARCHIPELAGO) / ARCHIPELAGO_EDGE) if ocean > 0.0
    if ocean > 0.0
      dome = SEA + (@noise2.fbm2(wx / ISLE_SCALE + 500.0, wz / ISLE_SCALE, 3) - ISLE) * ISLE_RISE + hills * ISLE_HILLS
      h += (dome - h) * ocean if dome > h
    end
    # The squeeze keeps the highest peaks pointed, not flat.
    if h > PEAK
      over = h - PEAK
      h = PEAK + over * (TOP - PEAK) / (over + TOP - PEAK)
    end
    h.to_i.clamp(4, TOP.to_i)
  end

  def river_height(base, height)
    noise = river_noise
    return height if noise >= RIVER_VALLEY || height <= RIVER_BED

    width = river_width(base)
    return height if noise >= width

    RIVER_BED + (height - RIVER_BED) * Terrain.smooth(noise / width)
  end

  def river_noise = @noise3.fbm2(@wx / RIVER_SCALE + 90.0, @wz / RIVER_SCALE, 2).abs

  def river_width(base)
    RIVER_VALLEY * Terrain.smooth((RIVER_TOP - base) / RIVER_RISE) *
      Terrain.smooth((warped_humidity - RIVER_DRY) / RIVER_WET)
  end

  def warped_humidity
    @noise4.fbm2(@wx / CLIMATE_SCALE, @wz / CLIMATE_SCALE + 150.0, 2) * 2.2 +
      @noise4.noise2(@wx / CLIMATE_ZONE_SCALE + 850.0, @wz / CLIMATE_ZONE_SCALE) * CLIMATE_ZONE_WEIGHT
  end

  def erosion(x, z)
    warp(x + SHIFT, z + SHIFT)
    unless @erosion_read
      @erosion = @noise4.fbm2(@wx / EROSION_SCALE + 30.0, @wz / EROSION_SCALE, 3) +
                 @noise4.noise2(@wx / EROSION_ZONE_SCALE + 950.0, @wz / EROSION_ZONE_SCALE) * EROSION_ZONE_WEIGHT
      @erosion_read = true
    end
    @erosion
  end

  def ridges(wx, wz)
    ridge = 1.0 - @noise2.noise2(wx / RIDGE_SCALE, wz / RIDGE_SCALE).abs * 1.6
    ridge = ridge < 0.0 ? 0.0 : ridge
    spur = 1.0 - @noise3.noise2(wx / SPUR_SCALE + 70.0, wz / SPUR_SCALE).abs * 1.6
    spur = spur < 0.0 ? 0.0 : spur
    peak = Terrain.smooth((@noise.noise2(wx / PEAK_SCALE + 120.0, wz / PEAK_SCALE) + 0.1) / 0.5)
    (ridge * ridge + SPUR * spur * spur * ridge) * (SADDLE + (1.0 - SADDLE) * peak) * RIDGE_RISE
  end

  def self.smooth(t)
    t = t.clamp(0.0, 1.0)
    t * t * (3.0 - 2.0 * t)
  end

  def self.land(table, continent, erosion)
    return spline(EROSION, table[0], erosion) if continent <= LAND_CONTINENT[0]

    (1...LAND_CONTINENT.size).each do |row|
      above = LAND_CONTINENT[row]
      next unless continent < above

      below = LAND_CONTINENT[row - 1]
      low = spline(EROSION, table[row - 1], erosion)
      high = spline(EROSION, table[row], erosion)
      return low + (high - low) * (continent - below) / (above - below)
    end
    spline(EROSION, table[LAND_CONTINENT.size - 1], erosion)
  end

  def self.spline(xs, ys, v)
    return ys[0] if v <= xs[0]

    (1...xs.size).each do |i|
      return ys[i - 1] + (ys[i] - ys[i - 1]) * (v - xs[i - 1]) / (xs[i] - xs[i - 1]) if v < xs[i]
    end
    ys[xs.size - 1]
  end

  def biome(x, z, h)
    nx = x + SHIFT
    nz = z + SHIFT
    warp(nx, nz)
    wx = @wx
    wz = @wz
    t = @noise3.fbm2(wx / CLIMATE_SCALE + 300.0, wz / CLIMATE_SCALE, 2) * 2.2 +
        @noise3.noise2(wx / CLIMATE_ZONE_SCALE + 800.0, wz / CLIMATE_ZONE_SCALE) * CLIMATE_ZONE_WEIGHT
    t -= (h - COLD_LINE) * COOLING if h > COLD_LINE
    Biome.pick(t, warped_humidity, Terrain.landform(erosion(x, z), landform_height(x, z, h)))
  end

  # The hills do not change the landform, so a hill in a swamp stays swamp.
  def landform_height(x, z, height)
    continent = continent(x, z)
    return height if continent < LAND_CONTINENT[0]

    (SEA + Terrain.land(LAND_BASE, continent, erosion(x, z))).to_i
  end

  def self.landform(erosion, height)
    return Biome::ROUGH if erosion < ROUGH_EROSION
    return Biome::LOW if height <= SWAMP_TOP
    return Biome::FLAT if erosion > FLAT_EROSION
    return Biome::PLATEAU if erosion.between?(PLATEAU_LOW_EROSION, PLATEAU_HIGH_EROSION) && height >= SEA + PLATEAU_TOP

    Biome::MIDDLE
  end

  def self.beach?(top) = top <= BEACH_TOP
  def self.bare_rock?(top) = top > ROCK_LINE
  def self.tree_density(meadow) = (1.0 - meadow / CLEARING_START).clamp(0.0, GROVE)

  def shore?(x, z)
    continent = continent(x, z)
    continent < SHORE || river_valley?(continent, x, z)
  end

  # Reads the river noise at the warp of the last call to continent.
  def river_valley?(continent, x, z)
    noise = river_noise
    noise < RIVER_VALLEY && noise < river_width(Terrain.land(LAND_BASE, continent, erosion(x, z)))
  end

  def stony_shore?(x, z) = continent(x, z) < SHORE && erosion(x, z) < ROUGH_EROSION

  def stony_shore_block(x, z)
    return Block::GRAVEL if @noise3.noise2(x / GRAVEL_STRIP_LENGTH + 700.0, z / GRAVEL_STRIP_WIDTH) > GRAVEL_STRIP

    Block::STONE
  end

  # The bed of a river is dirt with disks (minecraft.wiki/w/River). A pond
  # has none: "Disks no longer generate in and around water lakes"
  # (minecraft.wiki/w/Disk).
  def water_floor(x, z)
    continent = continent(x, z)
    return Disks.floor(x, z, Block::SAND) if continent < SHORE
    return Disks.floor(x, z, Block::DIRT) if river_valley?(continent, x, z)

    Block::DIRT
  end

  def top_block(x, z, h, biome)
    top = h - 1
    block = Biome::GROUND[biome]
    if biome == Biome::SWAMP
      block = Block::WATER if top == SEA && @noise3.noise2(x / 9.0, z / 9.0 + 40.0) > -0.05
      block = Block::DIRT if top < SEA
    elsif top < SEA
      block = water_floor(x, z)
    elsif stony_shore?(x, z)
      block = stony_shore_block(x, z)
    elsif Terrain.beach?(top) && shore?(x, z)
      block = Block::SAND
    end
    block = Block::STONE if Terrain.bare_rock?(top)
    block = Block::SNOW if top > SNOW_LINE
    block
  end

  def meadow(x, z) = @noise3.noise2(x / 30.0, z / 30.0 + 11.0)

  # Reads only noise, so every chunk that a tree crosses gets the same tree.
  def tree_top(x, z)
    r = Noise.hash3(x, 0, z, 21)
    # Most rolls fail even in a grove, so they skip the meadow noise.
    return -1 if r >= Biome::MAX_TREES * GROVE

    density = Terrain.tree_density(meadow(x, z))
    return -1 if r >= Biome::MAX_TREES * density

    h = surface_height(x, z)
    biome = biome(x, z, h)
    return -1 if r >= Biome::TREES[biome] * density

    ground = top_block(x, z, h, biome)
    return -1 unless ground == Block::GRASS || ground == Block::SNOW_GRASS
    return -1 if !Terrain.beach?(h - 1) && @cave_shape.opening?(x, h - 1, z)

    h - 1
  end

end
