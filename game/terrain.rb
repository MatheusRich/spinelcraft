# The shape of the land for one seed, from noise alone: the height, the
# biome and the top block of each column, the caves and where trees stand. It
# reads no block, so it gives the same answer each time. World#generate_chunk
# fills a chunk from it, and Lod, Tint and tools/map.rb read it without a
# World.
class Terrain
  # A cave is where both cave noise fields are this close to zero (squared sum).
  CAVE_WIDTH = 0.006
  # Tunnels close in the top CAVE_ROOF blocks of a column. Below that they
  # widen over CAVE_FADE blocks to CAVE_WIDTH.
  CAVE_ROOF = 4
  CAVE_FADE = 8
  # Tunnels reach the surface only in entrance patches: where the entrance
  # noise is above ENTRANCE. Minecraft also keeps most tunnels below the
  # surface and opens a separate, rarer set of entrances.
  ENTRANCE = 0.25
  ENTRANCE_SCALE = 48.0
  # The base height of the land (BASE) at each continent noise value
  # (CONTINENT): deep ocean, ocean, coast, lowland, then highland.
  CONTINENT = [-0.25, -0.17, -0.135, -0.12, -0.07, 0.06, 0.2, 0.34]
  BASE = [SEA - 34.0, SEA - 26.0, SEA - 8.0, SEA + 0.0, SEA + 8.0, SEA + 14.0, SEA + 28.0, SEA + 40.0]
  # Islands rise in open ocean where the island noise is above ISLE. ISLE_RISE
  # is the height of a dome for each step of the noise above ISLE, and
  # ISLE_SCALE is the size of the noise in blocks.
  ISLE = 0.15
  ISLE_RISE = 180.0
  ISLE_SCALE = 220.0
  # How tall the hills on an island are.
  ISLE_HILLS = 5.0
  # How far the warp moves the positions of the large-scale noise, in blocks.
  WARP = 90.0
  # Where the river noise is below RIVER_VALLEY, the land sinks toward a river bed below the sea.
  # RIVER_SCALE is the size of the river noise in blocks: a larger scale
  # puts the rivers farther apart.
  RIVER_VALLEY = 0.021
  RIVER_SCALE = 900.0
  # The height of a river bed.
  RIVER_BED = SEA - 5.0
  # Rivers fade out over RIVER_FADE of the continent noise and end where it
  # reaches RIVER_INLAND, so the middle of a continent has no rivers.
  RIVER_INLAND = 0.1
  RIVER_FADE = 0.15
  # The size of the continent noise in blocks: oceans and continents are
  # a few thousand blocks across.
  CONTINENT_SCALE = 2000.0
  # The size of the temperature and humidity noise in blocks. A climate
  # zone is a few hundred blocks or more across.
  CLIMATE_SCALE = 1600.0
  # The landscape noise picks the kind of land inland, in regions of
  # LANDSCAPE_SCALE blocks. Below MOUNTAINS it makes mountain ranges, from
  # PLATEAU_LOW to PLATEAU_HIGH plateaus PLATEAU_RISE above the sea, and
  # above FLATLAND flat lowland. Rolling hills fill the bands between.
  # Each kind fades in over LANDSCAPE_EDGE of the noise, and a plateau over
  # the shorter PLATEAU_EDGE, so its sides are steep.
  LANDSCAPE_SCALE = 1500.0
  MOUNTAINS = -0.1
  PLATEAU_LOW = -0.06
  PLATEAU_HIGH = 0.02
  FLATLAND = 0.08
  LANDSCAPE_EDGE = 0.02
  PLATEAU_EDGE = 0.006
  PLATEAU_RISE = 55.0
  # How tall the hills are on each kind of land: HILLS on rolling hills,
  # and the others in mountain ranges, on plateaus and on flat lowland.
  # The hill noise goes from about -1 to 1.
  HILLS = 9.0
  MOUNTAIN_HILLS = 35.0
  PLATEAU_HILLS = 3.0
  FLAT_HILLS = 4.5
  # The ridges of a mountain range follow the lines where the ridge noise
  # is zero. RIDGE_SCALE is the size of that noise in blocks, and the
  # highest ridge is RIDGE_RISE above the land around it. Smaller spurs
  # of SPUR_SCALE branch off the ridges, SPUR as tall.
  RIDGE_SCALE = 200.0
  RIDGE_RISE = 160.0
  SPUR_SCALE = 80.0
  SPUR = 0.4
  # The lines of a ridge close into loops. The peak noise, of PEAK_SCALE
  # blocks, breaks them: it lifts some stretches of a ridge into peaks,
  # and lowers the others to saddles SADDLE as tall. A range is lowest at
  # its edge, RANGE_EDGE as tall, and reaches its full height RANGE_CORE
  # of the landscape noise inside it.
  PEAK_SCALE = 120.0
  SADDLE = 0.2
  RANGE_EDGE = 0.45
  RANGE_CORE = 0.12
  # Perlin noise is 0 at whole noise positions, and x = z = 0 is one for
  # every scale. This shift moves the terrain off them, so each seed gets
  # its own land at spawn.
  SHIFT = 5000.5
  # land_near_origin looks at squares 64 blocks apart, up to 4096 blocks out.
  LAND_STEP = 64
  LAND_RADIUS = 4096
  # Land never reaches TOP, and heights above PEAK squeeze toward it.
  TOP = WY - 14.0
  PEAK = SEA + 100.0
  # Heights of the ground. Land up to BEACH_TOP next to water is a
  # beach, and swamps grow up to SWAMP_TOP. The floor of the sea below
  # GRAVEL_LINE has patches of gravel. High land is bare stone above
  # ROCK_LINE and snow above SNOW_LINE.
  BEACH_TOP = SEA + 2
  SWAMP_TOP = SEA + 8
  GRAVEL_LINE = SEA - 2
  ROCK_LINE = SEA + 95
  SNOW_LINE = SEA + 110
  # The air gets colder by COOLING for each block above COLD_LINE, so
  # mountains get snowy biomes.
  COLD_LINE = SEA + 30
  COOLING = 0.004

  def initialize(seed)
    @noise = Noise.new(seed)
    @noise2 = Noise.new(seed * 31 + 7)
    @noise3 = Noise.new(seed * 17 + 3)
    @noise4 = Noise.new(seed * 43 + 11)
    # The warp of the last column (see warp), first that of column 0, 0.
    @warp_nx = SHIFT
    @warp_nz = SHIFT
    @wx = warp_x(SHIFT, SHIFT)
    @wz = warp_z(SHIFT, SHIFT)
    # The continent noise of the last column, once continent reads it.
    @continent = 0.0
    @continent_read = false
    # The 8 grid points around a block (carved?) and the 4 edges of a cell (trilinear).
    @corner_a = Array.new(8, 0.0)
    @corner_b = Array.new(8, 0.0)
    @edges = Array.new(4, 0.0)
  end

  # Land well above the sea, from the noise alone.
  def land?(x, z) = surface_height(x, z) > SEA + 4

  # The origin when it is land. Else the first land point on the squares
  # around the origin, 64 blocks apart, or the origin when no land is near.
  def land_near_origin
    return [0, 0] if land?(0, 0)

    (LAND_STEP..LAND_RADIUS).step(LAND_STEP) do |radius|
      (-radius..radius).step(LAND_STEP) do |side|
        return [side, -radius] if land?(side, -radius)
        return [side, radius] if land?(side, radius)
        return [-radius, side] if land?(-radius, side)
        return [radius, side] if land?(radius, side)
      end
    end
    [0, 0]
  end

  # The large-scale noise fields read warped positions, so coasts and
  # biome edges bend instead of making round blobs. (Noise goes back into
  # noise here, and without to_f Spinel cannot type that loop.)
  def warp_x(x, z) = x + @noise4.noise2(x / 160.0, z / 160.0).to_f * WARP
  # The warped position of column (nx, nz), into @wx and @wz. The last
  # column is kept, as biome follows surface_height on the same column.
  def warp(nx, nz)
    return if nx == @warp_nx && nz == @warp_nz

    @warp_nx = nx
    @warp_nz = nz
    @wx = warp_x(nx, nz)
    @wz = warp_z(nx, nz)
    @continent_read = false
    nil
  end

  def warp_z(x, z) = z + @noise4.noise2(x / 160.0 + 70.0, z / 160.0).to_f * WARP

  # The continent noise of column x, z (see CONTINENT). It leaves the
  # warp of the column in @wx and @wz. The last column is kept, as
  # TreasureMap#site_height reads it after surface_height.
  def continent(x, z)
    warp(x + SHIFT, z + SHIFT)
    unless @continent_read
      @continent = @noise.fbm2(@wx / CONTINENT_SCALE, @wz / CONTINENT_SCALE, 4)
      @continent_read = true
    end
    @continent
  end

  # The height of the column's top block plus one, after Minecraft 1.18.
  # The continent noise picks ocean, coast, lowland or highland, and a
  # spline turns it into a base height. Inland, the landscape noise picks
  # mountain ranges with ridges, plateaus with flat tops, rolling hills or
  # flat lowland. Rivers cut valleys down to the sea where the river noise
  # is near zero.
  def surface_height(x, z) # rubocop:todo Metrics/MethodLength
    nx = x + SHIFT
    nz = z + SHIFT
    continent = continent(x, z)
    wx = @wx
    wz = @wz
    land = @noise4.fbm2(wx / LANDSCAPE_SCALE + 30.0, wz / LANDSCAPE_SCALE, 3)
    inland = Terrain.smooth((continent + 0.1) / 0.2)
    mountains = Terrain.smooth((MOUNTAINS - land) / LANDSCAPE_EDGE) * inland
    plateau = Terrain.smooth((land - PLATEAU_LOW) / PLATEAU_EDGE) *
              Terrain.smooth((PLATEAU_HIGH - land) / PLATEAU_EDGE) * inland
    flat = Terrain.smooth((land - FLATLAND) / LANDSCAPE_EDGE)
    hills = @noise.fbm2(nx / 55.0 + 40.0, nz / 55.0, 4)
    hill_height = HILLS + (MOUNTAIN_HILLS - HILLS) * mountains + (PLATEAU_HILLS - HILLS) * plateau + (FLAT_HILLS - HILLS) * flat
    h = Terrain.spline(CONTINENT, BASE, continent) + hills * hill_height
    h += ridges(wx, wz, land) * mountains if mountains > 0.0
    # A plateau lifts the land to a flat top.
    top = SEA + PLATEAU_RISE + hills * PLATEAU_HILLS
    h += (top - h) * plateau if top > h
    # Away from the coast, the island noise lifts domes out of the deep
    # ocean. Lower domes stay under the water as shoals.
    ocean = Terrain.smooth((CONTINENT[2] - continent) / (CONTINENT[2] - CONTINENT[1]))
    if ocean > 0.0
      dome = SEA + (@noise2.fbm2(wx / ISLE_SCALE + 500.0, wz / ISLE_SCALE, 3) - ISLE) * ISLE_RISE + hills * ISLE_HILLS
      h += (dome - h) * ocean if dome > h
    end
    # A river cuts its full valley near the coast. Farther inland the
    # valley gets shallower, and it ends at RIVER_INLAND.
    fade = Terrain.smooth((RIVER_INLAND - continent) / RIVER_FADE)
    if fade > 0.0 && h > RIVER_BED
      river = @noise3.fbm2(wx / RIVER_SCALE + 90.0, wz / RIVER_SCALE, 2).abs
      if river < RIVER_VALLEY
        bed = RIVER_BED + (h - RIVER_BED) * Terrain.smooth(river / RIVER_VALLEY)
        h += (bed - h) * fade if bed < h
      end
    end
    # Above PEAK, heights squeeze toward the top limit and never reach it,
    # so the highest peaks stay pointed instead of flat.
    if h > PEAK
      over = h - PEAK
      h = PEAK + over * (TOP - PEAK) / (over + TOP - PEAK)
    end
    h.to_i.clamp(4, TOP.to_i)
  end

  # The height of the ridges, spurs and peaks of a mountain range at the
  # warped position wx, wz, where the landscape noise is land.
  def ridges(wx, wz, land)
    ridge = 1.0 - @noise2.noise2(wx / RIDGE_SCALE, wz / RIDGE_SCALE).abs * 1.6
    ridge = ridge < 0.0 ? 0.0 : ridge
    spur = 1.0 - @noise3.noise2(wx / SPUR_SCALE + 70.0, wz / SPUR_SCALE).abs * 1.6
    spur = spur < 0.0 ? 0.0 : spur
    peak = Terrain.smooth((@noise.noise2(wx / PEAK_SCALE + 120.0, wz / PEAK_SCALE) + 0.1) / 0.5)
    core = Terrain.smooth((MOUNTAINS - land) / RANGE_CORE)
    (ridge * ridge + SPUR * spur * spur * ridge) * (SADDLE + (1.0 - SADDLE) * peak) * (RANGE_EDGE + (1.0 - RANGE_EDGE) * core) * RIDGE_RISE
  end

  # 0 below 0, 1 above 1, and an S curve between.
  def self.smooth(t)
    t = t.clamp(0.0, 1.0)
    t * t * (3.0 - 2.0 * t)
  end

  # The y of v on the line through the points xs, ys (xs in rising order).
  def self.spline(xs, ys, v)
    return ys[0] if v <= xs[0]

    (1...xs.size).each do |i|
      return ys[i - 1] + (ys[i] - ys[i - 1]) * (v - xs[i - 1]) / (xs[i] - xs[i - 1]) if v < xs[i]
    end
    ys[xs.size - 1]
  end

  # The biome of a column with height h. The air gets colder up high, so
  # mountains get snow.
  def biome(x, z, h)
    nx = x + SHIFT
    nz = z + SHIFT
    warp(nx, nz)
    wx = @wx
    wz = @wz
    t = @noise3.fbm2(wx / CLIMATE_SCALE + 300.0, wz / CLIMATE_SCALE, 2) * 2.2
    t -= (h - COLD_LINE) * COOLING if h > COLD_LINE
    w = @noise4.fbm2(wx / CLIMATE_SCALE, wz / CLIMATE_SCALE + 150.0, 2) * 2.2
    Biome.pick(t, w, h <= SWAMP_TOP)
  end

  # Height bands. top is the y of the column's top block.
  def self.beach?(top) = top <= BEACH_TOP
  # High peaks are bare stone at the top and below it.
  def self.bare_rock?(top) = top > ROCK_LINE

  # The block at the top of a column before caves and plants. Swamps hold
  # pools at sea level.
  def top_block(x, z, h, biome)
    top = h - 1
    block = Biome::GROUND[biome]
    if biome == Biome::SWAMP
      block = Block::WATER if top == SEA && @noise3.noise2(x / 9.0, z / 9.0 + 40.0) > -0.05
      block = Block::DIRT if top < SEA
    elsif Terrain.beach?(top)
      block = Block::SAND
    end
    block = Block::GRAVEL if top < GRAVEL_LINE && Noise.hash3(x / 3, 0, z / 3, 5) < 20000
    block = Block::STONE if Terrain.bare_rock?(top)
    block = Block::SNOW if top > SNOW_LINE
    block
  end

  # Caves: two noise fields near zero at once trace long tunnels.
  def self.cave?(a, c, width) = a * a + c * c < width
  # False when the first field alone rules out a cave, so the second needs no sample.
  def self.cave_possible?(a, width) = a * a < width

  # The tunnel width at depth blocks below the top block of a column.
  def self.cave_width(depth)
    return 0.0 if depth <= CAVE_ROOF
    return CAVE_WIDTH if depth >= CAVE_ROOF + CAVE_FADE

    CAVE_WIDTH * (depth - CAVE_ROOF) / CAVE_FADE
  end

  # True in the patches where tunnels keep their width up to the surface.
  def entrance?(x, z) = @noise.noise2(x / ENTRANCE_SCALE + 200.0, z / ENTRANCE_SCALE) > ENTRANCE

  # The meadow noise of column x, z, from about -1 to 1. Grass and flowers
  # grow more where it is high.
  def meadow(x, z) = @noise3.noise2(x / 30.0, z / 30.0 + 11.0)

  # The two cave noise fields at a point of the cave grid, which has one point
  # every 4 blocks. World#generate_chunk and carved? both sample it here.
  def cave_a(gx, gy, gz) = @noise2.noise3(gx * 4 / 40.0, gy * 4 / 22.0, gz * 4 / 40.0)
  def cave_b(gx, gy, gz) = @noise3.noise3(gx * 4 / 40.0 + 50.0, gy * 4 / 22.0, gz * 4 / 40.0)

  # The cave test for one block of an entrance patch, from the 8 grid points
  # around it. It gives the same numbers as the chunk grid of World#generate_chunk.
  def carved?(x, y, z)
    gx = x >> 2
    gy = y >> 2
    gz = z >> 2
    n = 0
    2.times do |i|
      2.times do |j|
        2.times do |k|
          @corner_a[n] = cave_a(gx + i, gy + j, gz + k)
          @corner_b[n] = cave_b(gx + i, gy + j, gz + k)
          n += 1
        end
      end
    end
    tx = (x - gx * 4) / 4.0
    ty = (y - gy * 4) / 4.0
    tz = (z - gz * 4) / 4.0
    Terrain.cave?(trilinear(@corner_a, 0, 2, 2, tx, ty, tz), trilinear(@corner_b, 0, 2, 2, tx, ty, tz), CAVE_WIDTH)
  end

  # The top ground block of the tree that grows at column x, z, or -1. It
  # only reads noise, so every chunk that a tree crosses gets the same tree.
  def tree_top(x, z)
    r = Noise.hash3(x, 0, z, 21)
    return -1 if r >= Biome::MAX_TREES

    h = surface_height(x, z)
    biome = biome(x, z, h)
    return -1 if r >= Biome::TREES[biome]

    ground = top_block(x, z, h, biome)
    return -1 unless ground == Block::GRASS || ground == Block::SNOW_GRASS
    return -1 if !Terrain.beach?(h - 1) && entrance?(x, z) && carved?(x, h - 1, z)

    h - 1
  end

  def trilinear(g, n, gy, gz, tx, ty, tz)
    Terrain.x_edges(g, n, gy, gz, tx, @edges)
    Terrain.yz_lerp(@edges, ty, tz)
  end

  # The first step of trilinear: the 4 edges along x of the cell of grid g
  # from point n, at tx, into e (y, z: 0 0, 1 0, 0 1, 1 1).
  def self.x_edges(g, n, gy, gz, tx, e)
    sx = gy * gz
    e[0] = g[n] + (g[n + sx] - g[n]) * tx
    e[1] = g[n + gz] + (g[n + sx + gz] - g[n + gz]) * tx
    e[2] = g[n + 1] + (g[n + sx + 1] - g[n + 1]) * tx
    e[3] = g[n + gz + 1] + (g[n + sx + gz + 1] - g[n + gz + 1]) * tx
  end

  # The rest of trilinear: the edges e lerped along y at ty, then along z at tz.
  def self.yz_lerp(e, ty, tz)
    c0 = e[0] + (e[1] - e[0]) * ty
    c1 = e[2] + (e[3] - e[2]) * ty
    c0 + (c1 - c0) * tz
  end
end
