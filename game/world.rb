# Chunk generation, block storage, and the store of changed chunks.
WY = 96
PY = WY + 2
SEA = 34
CHUNK = 16
# The loaded area is a ring of RING x RING chunk slots that moves with the
# player: world chunk (cx, cz) lives in slot (cx & RING_MASK, cz & RING_MASK).
RING = 64
RING_MASK = RING - 1
# Block storage per side; world x lives in storage column x & LMASK.
WX = RING * CHUNK
WZ = WX
LMASK = WX - 1
# One padding column on each side holds a copy of the opposite edge column,
# so neighbor offsets also work across the wrap.
PX = WX + 2
PZ = WZ + 2
CX = RING
CZ = RING
# Bytes of one chunk in a save: 16 x 16 columns of WY blocks.
CHUNK_BYTES = CHUNK * CHUNK * WY

class World
  # Slot owner of an empty slot.
  NONE = -(1 << 40)
  # Moves world coordinates to positive numbers for keys.
  KEY_OFF = 1 << 24
  # Cave noise grid of one chunk: a point every 4 blocks.
  GX = CHUNK / 4 + 1
  GY = WY / 4 + 1
  # A cave is where both cave noise fields are this close to zero (squared sum).
  CAVE_WIDTH = 0.006
  # Caves at this height and below fill with lava.
  LAVA_LEVEL = 9
  # The base height of the land (BASE) at each continent noise value
  # (CONTINENT): deep ocean, ocean, coast, lowland, then highland.
  CONTINENT = [-0.25, -0.17, -0.135, -0.12, -0.07, 0.06, 0.2, 0.34]
  BASE = [SEA - 17.0, SEA - 14.0, SEA - 4.0, SEA + 0.0, SEA + 5.0, SEA + 9.0, SEA + 16.0, SEA + 21.0]
  # Islands rise in open ocean where the island noise is above ISLE. ISLE_RISE
  # is the height of a dome for each step of the noise above ISLE, and
  # ISLE_SCALE is the size of the noise in blocks.
  ISLE = 0.15
  ISLE_RISE = 100.0
  ISLE_SCALE = 220.0
  # How far the warp moves the positions of the large-scale noise, in blocks.
  WARP = 90.0
  # Where the river noise is below RIVER_VALLEY, the land sinks toward a river bed below the sea.
  # RIVER_SCALE is the size of the river noise in blocks: a larger scale
  # puts the rivers farther apart.
  RIVER_VALLEY = 0.021
  RIVER_SCALE = 900.0
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
  PLATEAU_RISE = 20.0
  # Perlin noise is 0 at whole noise positions, and x = z = 0 is one for
  # every scale. This shift moves the terrain off them, so each seed gets
  # its own land at spawn.
  SHIFT = 5000.5
  # Land never reaches TOP, and heights above PEAK squeeze toward it.
  TOP = WY - 14.0
  PEAK = SEA + 34.0
  # The shortest trunk of each tree kind (Biome::OAK and so on), one
  # entry for each of Biome::TREE_KINDS.
  TRUNK = [4, 5, 5, 4]
  # The wood of each tree kind (Block::OAK_WOOD and so on). The game has no
  # acacia or jungle wood, so those trees have oak wood.
  WOOD = [Block::OAK_WOOD, Block::SPRUCE_WOOD, Block::OAK_WOOD, Block::OAK_WOOD]
  # How far leaves reach from the root of a tree: a giant jungle tree
  # grows a branch 5 blocks long, and the leaves at its end reach 3 more.
  TREE_REACH = 8

  attr_reader :blocks, :height, :chunk_torches, :slot_cx, :slot_cz, :edited, :store, :seed

  def initialize(seed)
    @seed = seed
    # Eight blocks per Integer (block ids fit in 7 bits); see World.byte.
    @blocks = Array.new(PX * PY * PZ / 8 + 1, 0)
    @height = Array.new(WX * WZ, 0)
    # Torch and exposed lava cells as x, y, z triples, one list for each slot.
    @chunk_torches = Array.new(CX * CZ) { Array.new(0, 0) }
    # The world chunk in each slot, and 1 when it differs from the generator.
    @slot_cx = Array.new(CX * CZ, NONE)
    @slot_cz = Array.new(CX * CZ, NONE)
    @edited = Array.new(CX * CZ, 0)
    # Bytes of edited chunks that are not loaded, by chunk key.
    @store = {}
    @no_torches = Array.new(0, 0)
    @col_h = Array.new(CHUNK * CHUNK, 0)
    @col_b = Array.new(CHUNK * CHUNK, 0)
    @cave_a = Array.new(GX * GY * GX, 0.0)
    @cave_b = Array.new(GX * GY * GX, 0.0)
    @corner_a = Array.new(8, 0.0)
    @corner_b = Array.new(8, 0.0)
    @noise = Noise.new(seed)
    @noise2 = Noise.new(seed * 31 + 7)
    @noise3 = Noise.new(seed * 17 + 3)
    @noise4 = Noise.new(seed * 43 + 11)
    # The log and the leaves of the tree that the generator grows (see use_wood).
    @log = Block::OAK_LOG
    @leaves = Block::OAK_LEAVES
    # A tree that grows from a sapling (see plan_tree): its changes as x, y,
    # z, block quads, and the keys of the cells that they change.
    @planning = false
    @plan = Array.new(0, 0)
    @plan_cells = {}
    @plan_blocked = false
  end

  # Spinel cannot type the positions that the game code gives World (from
  # the player, the mobs or the flow queue). So get, set and the chunk
  # lookups call to_i before they use index or slot, and the generator and
  # the mesher stay unboxed. The to_i in index lets Spinel type block and
  # put_block before its inference stops at its round limit.
  def self.index(x, y, z) = ((((x & LMASK) + 1) * PZ + (z & LMASK) + 1) * PY + y + 1).to_i
  # Block i of a packed store: byte i & 7 of Integer i >> 3.
  def self.byte(a, i) = (a[i >> 3] >> ((i & 7) << 3)) & 127

  def block(i) = (@blocks[i >> 3] >> ((i & 7) << 3)) & 127

  def put_block(i, b)
    j = i >> 3
    s = (i & 7) << 3
    @blocks[j] = (@blocks[j] & ~(127 << s)) | (b << s)
  end

  def self.slot(cx, cz) = (cx & RING_MASK) * RING + (cz & RING_MASK)
  # A unique Integer for a block anywhere in the world (chest keys).
  def self.key(x, y, z) = ((((x + KEY_OFF) << 26) | (z + KEY_OFF)) << 7) | y
  def self.chunk_key(cx, cz) = ((cx + KEY_OFF) << 26) | (cz + KEY_OFF)

  def chunk_loaded?(cx, cz)
    icx = cx.to_i
    icz = cz.to_i
    s = World.slot(icx, icz)
    @slot_cx[s] == icx && @slot_cz[s] == icz
  end

  def loaded?(x, z) = chunk_loaded?(x >> 4, z >> 4)
  def inside?(x, y, z) = y >= 0 && y < WY && loaded?(x, z)
  def height_at(x, z) = @height[(x & LMASK) * WZ + (z & LMASK)]
  # True when nothing above x, y, z stops the rain.
  def under_sky?(x, y, z) = height_at(x.floor, z.floor) <= y.floor

  # The light list of a loaded chunk, else an empty list. (An Array-or-nil
  # return makes Spinel box the elements.)
  def torches_of(cx, cz) = chunk_loaded?(cx, cz) ? @chunk_torches[World.slot(cx.to_i, cz.to_i)] : @no_torches

  def get(x, y, z)
    ix = x.to_i
    iy = y.to_i
    iz = z.to_i
    return Block::AIR unless inside?(ix, iy, iz)
    block(World.index(ix, iy, iz))
  end

  # True when a solid block overlaps the box of half width half and height
  # tall that stands on x, y, z.
  def solid_in_box?(x, y, z, half, tall)
    x1 = (x + half).floor
    y1 = (y + tall).floor
    z1 = (z + half).floor
    bx = (x - half).floor
    while bx <= x1
      by = y.floor
      while by <= y1
        bz = (z - half).floor
        while bz <= z1
          return true if block_in_box?(get(bx, by, bz), bx, by, bz, x, y, z, half, tall)
          bz += 1
        end
        by += 1
      end
      bx += 1
    end
    false
  end

  # True when b is solid and its box (Block.box_hx and the others) in the
  # cell bx, by, bz overlaps the box of solid_in_box?.
  def block_in_box?(b, bx, by, bz, x, y, z, half, tall)
    return false unless Block.solid?(b)
    y0 = by + Block.box_dy(b)
    (bx + 0.5 + Block.box_dx(b) - x).abs < Block.box_hx(b) + half && (bz + 0.5 + Block.box_dz(b) - z).abs < Block.box_hz(b) + half &&
      y0 < y + tall && y0 + Block.box_top(b) > y
  end

  # The nearest face of the solid blocks that overlap the box of
  # solid_in_box?, on the x axis (axis 0), the y axis (axis 1) or the z axis
  # (axis 2): the lowest face when dir is 1, and the highest when dir is -1.
  # A move along that axis stops at this face.
  def box_edge(x, y, z, half, tall, axis, dir)
    edge = dir > 0 ? 1.0e9 : -1.0e9
    x1 = (x + half).floor
    y1 = (y + tall).floor
    z1 = (z + half).floor
    bx = (x - half).floor
    while bx <= x1
      by = y.floor
      while by <= y1
        bz = (z - half).floor
        while bz <= z1
          b = get(bx, by, bz)
          if block_in_box?(b, bx, by, bz, x, y, z, half, tall)
            lo = axis == 0 ? bx + 0.5 + Block.box_dx(b) - Block.box_hx(b) : (axis == 1 ? by + Block.box_dy(b) : bz + 0.5 + Block.box_dz(b) - Block.box_hz(b))
            hi = axis == 0 ? bx + 0.5 + Block.box_dx(b) + Block.box_hx(b) : (axis == 1 ? by + Block.box_dy(b) + Block.box_top(b) : bz + 0.5 + Block.box_dz(b) + Block.box_hz(b))
            if dir > 0
              edge = lo if lo < edge
            elsif hi > edge
              edge = hi
            end
          end
          bz += 1
        end
        by += 1
      end
      bx += 1
    end
    edge
  end

  def set(x, y, z, b)
    ix = x.to_i
    iy = y.to_i
    iz = z.to_i
    v = b.to_i
    return unless inside?(ix, iy, iz)
    i = World.index(ix, iy, iz)
    remove_torch(ix, iy, iz) if Block.emits?(block(i))
    write(i, ix & LMASK, iz & LMASK, v)
    @edited[World.slot(ix >> 4, iz >> 4)] = 1
    add_torch(ix, iy, iz) if Block.emits?(v)
    update_height(ix, iz)
    expose_lava(ix, iy, iz) if Block::OPAQUE[v] == 0
  end

  # Stores b at index i and in the padding copy of an edge column.
  def write(i, lx, lz, b)
    put_block(i, b)
    return if lx != 0 && lx != LMASK && lz != 0 && lz != LMASK
    ex = lx == 0 ? WX * PZ * PY : (lx == LMASK ? -WX * PZ * PY : 0)
    ez = lz == 0 ? WZ * PY : (lz == LMASK ? -WZ * PY : 0)
    put_block(i + ex, b) if ex != 0
    put_block(i + ez, b) if ez != 0
    put_block(i + ex + ez, b) if ex != 0 && ez != 0
  end

  # Copies the edge columns of a chunk into the padding.
  def mirror_edges(cx, cz)
    lx0 = (cx & RING_MASK) * CHUNK
    lz0 = (cz & RING_MASK) * CHUNK
    return if lx0 != 0 && lx0 + CHUNK != WX && lz0 != 0 && lz0 + CHUNK != WZ
    lx = lx0
    while lx < lx0 + CHUNK
      lz = lz0
      while lz < lz0 + CHUNK
        if lx == 0 || lx == LMASK || lz == 0 || lz == LMASK
          base = World.index(lx, 0, lz)
          y = 0
          while y < WY
            write(base + y, lx, lz, block(base + y))
            y += 1
          end
        end
        lz += 1
      end
      lx += 1
    end
  end

  # Puts world chunk (cx, cz) in its slot: from the store when it was
  # edited, else from the generator. An edited chunk in the slot goes to
  # the store first.
  def load_chunk(cx, cz)
    s = World.slot(cx, cz)
    unload(s)
    @slot_cx[s] = cx
    @slot_cz[s] = cz
    key = World.chunk_key(cx, cz)
    data = @store[key]
    if data.nil?
      generate_chunk(cx, cz)
      @edited[s] = 0
    else
      unpack_chunk(cx, cz, data)
      @store.delete(key)
      @edited[s] = 1
    end
    mirror_edges(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    x = x0
    while x < x0 + CHUNK
      z = z0
      while z < z0 + CHUNK
        update_height(x, z)
        z += 1
      end
      x += 1
    end
    # A generated chunk has no torches and no lava above LAVA_LEVEL.
    find_torches(cx, cz, data.nil? ? LAVA_LEVEL + 1 : WY)
  end

  def unload(s)
    return if @slot_cx[s] == NONE
    @store[World.chunk_key(@slot_cx[s], @slot_cz[s])] = chunk_bytes(@slot_cx[s], @slot_cz[s]) if @edited[s] == 1
    @slot_cx[s] = NONE
    @slot_cz[s] = NONE
    @edited[s] = 0
    @chunk_torches[s].clear
  end

  # The blocks of a loaded chunk, one column of WY bytes after another.
  def chunk_bytes(cx, cz)
    parts = []
    col = Array.new(WY, 0)
    x0 = cx.to_i * CHUNK
    z0 = cz.to_i * CHUNK
    x = x0
    while x < x0 + CHUNK
      z = z0
      while z < z0 + CHUNK
        base = World.index(x, 0, z)
        y = 0
        while y < WY
          col[y] = block(base + y)
          y += 1
        end
        parts << col.pack("C*")
        z += 1
      end
      x += 1
    end
    parts.join
  end

  def unpack_chunk(cx, cz, data)
    k = 0
    x = cx * CHUNK
    while x < cx * CHUNK + CHUNK
      z = cz * CHUNK
      while z < cz * CHUNK + CHUNK
        base = World.index(x, 0, z)
        y = 0
        while y < WY
          put_block(base + y, data.getbyte(k) || 0)
          k += 1
          y += 1
        end
        z += 1
      end
      x += 1
    end
  end

  # Every edited chunk: the store plus the edited loaded chunks.
  def edited_chunks
    out = {}
    @store.each { |k, v| out[k] = v }
    s = 0
    while s < CX * CZ
      out[World.chunk_key(@slot_cx[s], @slot_cz[s])] = chunk_bytes(@slot_cx[s], @slot_cz[s]) if @edited[s] == 1
      s += 1
    end
    out
  end

  # Buried lava lights nothing, so it joins the light list only once a
  # neighbor opens up.
  def exposed?(i)
    opaque = Block::OPAQUE
    opaque[block(i + 1)] == 0 || opaque[block(i - 1)] == 0 || opaque[block(i + PY)] == 0 ||
      opaque[block(i - PY)] == 0 || opaque[block(i + PZ * PY)] == 0 || opaque[block(i - PZ * PY)] == 0
  end

  def expose_lava(x, y, z)
    d = 0
    while d < 6
      nx = x + (d == 0 ? 1 : (d == 1 ? -1 : 0))
      ny = y + (d == 2 ? 1 : (d == 3 ? -1 : 0))
      nz = z + (d == 4 ? 1 : (d == 5 ? -1 : 0))
      if inside?(nx, ny, nz) && block(World.index(nx, ny, nz)) == Block::LAVA && !listed?(nx, ny, nz)
        add_torch(nx, ny, nz)
      end
      d += 1
    end
  end

  def listed?(x, y, z)
    list = @chunk_torches[World.slot(x >> 4, z >> 4)]
    k = 0
    while k < list.size
      return true if list[k] == x && list[k + 1] == y && list[k + 2] == z
      k += 3
    end
    false
  end

  def add_torch(x, y, z)
    @chunk_torches[World.slot(x >> 4, z >> 4)] << x << y << z
  end

  def remove_torch(x, y, z)
    list = @chunk_torches[World.slot(x >> 4, z >> 4)]
    k = 0
    while k < list.size
      if list[k] == x && list[k + 1] == y && list[k + 2] == z
        list.slice!(k, 3)
        return
      end
      k += 3
    end
  end

  # Lists the torches and the exposed lava below height top.
  def find_torches(cx, cz, top)
    @chunk_torches[World.slot(cx, cz)].clear
    x = cx * CHUNK
    while x < cx * CHUNK + CHUNK
      z = cz * CHUNK
      while z < cz * CHUNK + CHUNK
        base = World.index(x, 0, z)
        y = 0
        while y < top
          b = block(base + y)
          add_torch(x, y, z) if Block.torch?(b) || (b == Block::LAVA && exposed?(base + y))
          y += 1
        end
        z += 1
      end
      x += 1
    end
  end

  def update_height(x, z)
    base = World.index(x, 0, z)
    y = WY - 1
    while y >= 0 && !Block.blocks_light(block(base + y))
      y -= 1
    end
    @height[(x & LMASK) * WZ + (z & LMASK)] = y + 1
  end

  # The large-scale noise fields read warped positions, so coasts and
  # biome edges bend instead of making round blobs. (Noise goes back into
  # noise here, and without to_f Spinel cannot type that loop.)
  def warp_x(x, z) = x + @noise4.noise2(x / 160.0, z / 160.0).to_f * WARP
  def warp_z(x, z) = z + @noise4.noise2(x / 160.0 + 70.0, z / 160.0).to_f * WARP

  # The height of the column's top block plus one, after Minecraft 1.18.
  # The continent noise picks ocean, coast, lowland or highland, and a
  # spline turns it into a base height. Inland, the landscape noise picks
  # mountain ranges with ridges, plateaus with flat tops, rolling hills or
  # flat lowland. Rivers cut valleys down to the sea where the river noise
  # is near zero.
  def surface_height(x, z)
    nx = x + SHIFT
    nz = z + SHIFT
    wx = warp_x(nx, nz)
    wz = warp_z(nx, nz)
    continent = @noise.fbm2(wx / CONTINENT_SCALE, wz / CONTINENT_SCALE, 4)
    land = @noise4.fbm2(wx / LANDSCAPE_SCALE + 30.0, wz / LANDSCAPE_SCALE, 3)
    inland = World.smooth((continent + 0.1) / 0.2)
    mountains = World.smooth((MOUNTAINS - land) / LANDSCAPE_EDGE) * inland
    plateau = World.smooth((land - PLATEAU_LOW) / PLATEAU_EDGE) *
              World.smooth((PLATEAU_HIGH - land) / PLATEAU_EDGE) * inland
    flat = World.smooth((land - FLATLAND) / LANDSCAPE_EDGE)
    hills = @noise.fbm2(nx / 55.0 + 40.0, nz / 55.0, 4)
    ridge = 1.0 - @noise2.noise2(wx / 90.0, wz / 90.0).abs * 1.6
    ridge = ridge < 0.0 ? 0.0 : ridge
    h = World.spline(CONTINENT, BASE, continent) + hills * (6.0 + 13.0 * mountains - 4.0 * plateau - 3.0 * flat) +
        ridge * ridge * 46.0 * mountains
    # A plateau lifts the land to a flat top.
    top = SEA + PLATEAU_RISE + hills * 2.0
    h += (top - h) * plateau if top > h
    # Away from the coast, the island noise lifts domes out of the deep
    # ocean. Lower domes stay under the water as shoals.
    ocean = World.smooth((CONTINENT[2] - continent) / (CONTINENT[2] - CONTINENT[1]))
    if ocean > 0.0
      dome = SEA + (@noise2.fbm2(wx / ISLE_SCALE + 500.0, wz / ISLE_SCALE, 3) - ISLE) * ISLE_RISE + hills * 3.0
      h += (dome - h) * ocean if dome > h
    end
    # A river cuts its full valley near the coast. Farther inland the
    # valley gets shallower, and it ends at RIVER_INLAND.
    river = @noise3.fbm2(wx / RIVER_SCALE + 90.0, wz / RIVER_SCALE, 2).abs
    fade = World.smooth((RIVER_INLAND - continent) / RIVER_FADE)
    if fade > 0.0 && river < RIVER_VALLEY && h > SEA - 3.0
      bed = SEA - 3.0 + (h - SEA + 3.0) * World.smooth(river / RIVER_VALLEY)
      h += (bed - h) * fade if bed < h
    end
    # Above PEAK, heights squeeze toward the top limit and never reach it,
    # so the highest peaks stay pointed instead of flat.
    if h > PEAK
      over = h - PEAK
      h = PEAK + over * (TOP - PEAK) / (over + TOP - PEAK)
    end
    h.to_i.clamp(4, TOP.to_i)
  end

  # 0 below 0, 1 above 1, and an S curve between.
  def self.smooth(t)
    t = t.clamp(0.0, 1.0)
    t * t * (3.0 - 2.0 * t)
  end

  # The y of v on the line through the points xs, ys (xs in rising order).
  def self.spline(xs, ys, v)
    return ys[0] if v <= xs[0]
    i = 1
    while i < xs.size
      return ys[i - 1] + (ys[i] - ys[i - 1]) * (v - xs[i - 1]) / (xs[i] - xs[i - 1]) if v < xs[i]
      i += 1
    end
    ys[xs.size - 1]
  end

  # The biome of a column with height h. The air gets colder up high, so
  # mountains get snow.
  def biome(x, z, h)
    nx = x + SHIFT
    nz = z + SHIFT
    wx = warp_x(nx, nz)
    wz = warp_z(nx, nz)
    t = @noise3.fbm2(wx / CLIMATE_SCALE + 300.0, wz / CLIMATE_SCALE, 2) * 2.2
    t -= (h - SEA - 12) * 0.012 if h > SEA + 12
    w = @noise4.fbm2(wx / CLIMATE_SCALE, wz / CLIMATE_SCALE + 150.0, 2) * 2.2
    Biome.pick(t, w, h <= SEA + 5)
  end

  # Height bands. top is the y of the column's top block.
  def beach?(top) = top <= SEA + 1
  # High peaks are bare stone at the top and below it.
  def bare_rock?(top) = top > SEA + 37

  # The block at the top of a column before caves and plants. Swamps hold
  # pools at sea level.
  def top_block(x, z, h, biome)
    top = h - 1
    b = Biome::GROUND[biome]
    if biome == Biome::SWAMP
      b = Block::WATER if top == SEA && @noise3.noise2(x / 9.0, z / 9.0 + 40.0) > -0.05
      b = Block::DIRT if top < SEA
    elsif beach?(top)
      b = Block::SAND
    end
    b = Block::GRAVEL if top < SEA - 2 && Noise.hash3(x / 3, 0, z / 3, 5) < 20000
    b = Block::STONE if bare_rock?(top)
    b = Block::SNOW if top > SEA + 39
    b
  end

  # Caves: two noise fields near zero at once trace long tunnels.
  def cave?(a, c) = a * a + c * c < CAVE_WIDTH
  # False when the first field alone rules out a cave, so the second needs no sample.
  def cave_possible?(a) = a * a < CAVE_WIDTH

  # The two cave noise fields at a point of the cave grid, which has one point
  # every 4 blocks. generate_chunk and carved? both sample it here.
  def cave_a(gx, gy, gz) = @noise2.noise3(gx * 4 / 40.0, gy * 4 / 22.0, gz * 4 / 40.0)
  def cave_b(gx, gy, gz) = @noise3.noise3(gx * 4 / 40.0 + 50.0, gy * 4 / 22.0, gz * 4 / 40.0)

  # The cave test for one block, from the 8 grid points around it. It gives
  # the same numbers as the chunk grid in generate_chunk.
  def carved?(x, y, z)
    gx = x >> 2
    gy = y >> 2
    gz = z >> 2
    n = 0
    i = 0
    while i < 2
      j = 0
      while j < 2
        k = 0
        while k < 2
          @corner_a[n] = cave_a(gx + i, gy + j, gz + k)
          @corner_b[n] = cave_b(gx + i, gy + j, gz + k)
          n += 1
          k += 1
        end
        j += 1
      end
      i += 1
    end
    tx = (x - gx * 4) / 4.0
    ty = (y - gy * 4) / 4.0
    tz = (z - gz * 4) / 4.0
    cave?(trilinear(@corner_a, 0, 2, 2, tx, ty, tz), trilinear(@corner_b, 0, 2, 2, tx, ty, tz))
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
    return -1 if !beach?(h - 1) && carved?(x, h - 1, z)
    h - 1
  end

  def generate_chunk(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        h = surface_height(x0 + lx, z0 + lz)
        @col_h[lx * CHUNK + lz] = h
        @col_b[lx * CHUNK + lz] = biome(x0 + lx, z0 + lz, h)
        lz += 1
      end
      lx += 1
    end

    # Coarse 3D noise for caves, sampled every 4 blocks and interpolated.
    gx0 = x0 >> 2
    gz0 = z0 >> 2
    i = 0
    while i < GX
      j = 0
      while j < GY
        k = 0
        while k < GX
          n = (i * GY + j) * GX + k
          @cave_a[n] = cave_a(gx0 + i, j, gz0 + k)
          @cave_b[n] = cave_b(gx0 + i, j, gz0 + k)
          k += 1
        end
        j += 1
      end
      i += 1
    end

    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        x = x0 + lx
        z = z0 + lz
        h = @col_h[lx * CHUNK + lz]
        biome = @col_b[lx * CHUNK + lz]
        top = h - 1
        surface = top_block(x, z, h, biome)
        base = World.index(x, 0, z)
        y = 0
        while y < h
          b = Block::STONE
          if y == 0
            b = Block::BEDROCK
          elsif y == top
            b = surface
          elsif y > top - 4
            b = surface == Block::SAND ? Block::SAND : Block::DIRT
            b = Block::STONE if bare_rock?(top)
          end
          if b == Block::STONE
            if Noise.hash3(x >> 1, y >> 1, z >> 1, 11) < 1100 && Noise.hash3(x, y, z, 12) < 40000
              b = Block::COAL
            elsif y < 50 && Noise.hash3(x >> 1, y >> 1, z >> 1, 13) < 600 && Noise.hash3(x, y, z, 14) < 36000
              b = Block::IRON
            elsif y < 16 && Noise.hash3(x >> 1, y >> 1, z >> 1, 15) < 160 && Noise.hash3(x, y, z, 16) < 30000
              b = Block::DIAMOND
            end
          end
          if y > 1 && (y < top - 2 || (!beach?(top) && y <= top))
            fx = lx / 4.0
            fy = y / 4.0
            fz = lz / 4.0
            ix = fx.to_i
            iy = fy.to_i
            iz = fz.to_i
            n = (ix * GY + iy) * GX + iz
            a = trilinear(@cave_a, n, GY, GX, fx - ix, fy - iy, fz - iz)
            if cave_possible?(a)
              c = trilinear(@cave_b, n, GY, GX, fx - ix, fy - iy, fz - iz)
              b = (y <= LAVA_LEVEL ? Block::LAVA : Block::AIR) if cave?(a, c)
            end
          end
          put_block(base + y, b)
          y += 1
        end
        while y < WY
          put_block(base + y, y <= SEA ? Block::WATER : Block::AIR)
          y += 1
        end
        lz += 1
      end
      lx += 1
    end
    decorate(cx, cz)
  end

  def trilinear(g, n, gy, gz, tx, ty, tz)
    sx = gy * gz
    c00 = g[n] + (g[n + sx] - g[n]) * tx
    c10 = g[n + gz] + (g[n + sx + gz] - g[n + gz]) * tx
    c01 = g[n + 1] + (g[n + sx + 1] - g[n + 1]) * tx
    c11 = g[n + gz + 1] + (g[n + sx + gz + 1] - g[n + gz + 1]) * tx
    c0 = c00 + (c10 - c00) * ty
    c1 = c01 + (c11 - c01) * ty
    c0 + (c1 - c0) * tz
  end

  # Trees (also those that grow next door and reach in), then plants and cacti.
  def decorate(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    x = x0 - TREE_REACH
    while x < x0 + CHUNK + TREE_REACH
      z = z0 - TREE_REACH
      while z < z0 + CHUNK + TREE_REACH
        top = tree_top(x, z)
        tree(x, top + 1, z, x0, z0, biome(x, z, top + 1)) if top >= 0
        z += 1
      end
      x += 1
    end
    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        x = x0 + lx
        z = z0 + lz
        top = @col_h[lx * CHUNK + lz] - 1
        biome = @col_b[lx * CHUNK + lz]
        ground = block(World.index(x, top, z))
        if ground == Block::GRASS && block(World.index(x, top + 1, z)) == Block::AIR
          p = Noise.hash3(x, 2, z, 25)
          meadow = @noise3.noise2(x / 30.0, z / 30.0 + 11.0)
          if p < Biome::GRASS[biome] + (meadow * 12000.0).to_i
            put(x, top + 1, z, Block::TALL_GRASS, x0, z0)
          elsif p >= 65536 - Biome::FLOWERS[biome] && meadow > -0.05
            put(x, top + 1, z, (x + z) % 3 == 0 ? Block::ROSE : Block::DANDELION, x0, z0)
          end
        elsif ground == Block::SAND && biome == Biome::DESERT && !beach?(top) && Noise.hash3(x, 0, z, 21) < 350
          tall = 1 + Noise.hash3(x, 1, z, 22) % 3
          i = 0
          while i < tall
            put(x, top + 1 + i, z, Block::CACTUS, x0, z0)
            i += 1
          end
        end
        lz += 1
      end
      lx += 1
    end
  end

  # Writes a generated block when it is inside chunk x0, z0. While
  # plan_tree plans a tree, it adds the block to the plan instead, and
  # air_in? looks at the loaded world and at the plan.
  def put(x, y, z, b, x0, z0)
    return plan(x, y, z, b) if @planning
    return if x < x0 || z < z0 || x >= x0 + CHUNK || z >= z0 + CHUNK || y < 0 || y >= WY
    put_block(World.index(x, y, z), b)
  end

  def air_in?(x, y, z, x0, z0)
    return !@plan_cells.key?(World.key(x, y, z)) && get(x, y, z) == Block::AIR if @planning
    return false if x < x0 || z < z0 || x >= x0 + CHUNK || z >= z0 + CHUNK || y < 0 || y >= WY
    block(World.index(x, y, z)) == Block::AIR
  end

  # The changes of a tree of wood (Block::OAK_WOOD and so on) that grows
  # from the sapling at x, y, z, as x, y, z, block quads. The tree has the
  # shape of the generator's tree of its wood. Unlike the generator, it
  # only replaces air, leaves and plants, so it does not break what the
  # player built. The list is empty when something else is in the way of
  # a log. An oak grows as a large oak 1 time in 10 (minecraft.wiki/w/Oak
  # gives this chance for Alpha, "including from saplings").
  def plan_tree(gx, gy, gz, wood)
    # The shapes keep Integer positions, as get does (see World.index).
    x = gx.to_i
    y = gy.to_i
    z = gz.to_i
    @planning = true
    @plan = Array.new(0, 0)
    @plan_cells = {}
    @plan_blocked = false
    use_wood(wood)
    if wood == Block::SPRUCE_WOOD
      spruce(x, y, z, 0, 0)
    elsif wood == Block::BIRCH_WOOD
      oak(x, y, z, 5 + Noise.hash3(x, y, z, 23) % 3, 0, 0)
    elsif Noise.hash3(x, y, z, 28) < 6554
      large_oak(x, y, z, 0, 0)
    else
      oak(x, y, z, TRUNK[Biome::OAK] + Noise.hash3(x, y, z, 23) % 3, 0, 0)
    end
    @planning = false
    @plan_blocked ? Array.new(0, 0) : @plan
  end

  # Adds block b at x, y, z to the tree that plan_tree grows. A log blocks
  # the tree when the cell holds something other than air, leaves or a
  # plant, and dirt only replaces grass.
  def plan(x, y, z, b)
    old = get(x, y, z)
    if b == Block::DIRT
      return unless old == Block::GRASS || old == Block::SNOW_GRASS
    elsif Block.log?(b) && !(old == Block::AIR || Block.leaves?(old) || Block.plant?(old))
      @plan_blocked = true
      return
    end
    @plan_cells[World.key(x, y, z)] = b
    @plan << x << y << z << b
  end

  # A tree of the biome on the ground below x, y, z. The biome picks the
  # kind of tree (Biome::TREE), and the kind picks among its shapes.
  def tree(x, y, z, x0, z0, biome)
    kind = Biome::TREE[biome]
    use_wood(WOOD[kind])
    if kind == Biome::ACACIA
      acacia(x, y, z, x0, z0)
    elsif kind == Biome::SPRUCE
      Noise.hash3(x, y, z, 31) < Biome::PINES[biome] ? pine(x, y, z, x0, z0) : spruce(x, y, z, x0, z0)
    elsif kind == Biome::JUNGLE_TREE
      jungle(x, y, z, x0, z0)
    elsif Noise.hash3(x, y, z, 32) < Biome::BIRCHES[biome]
      use_wood(Block::BIRCH_WOOD)
      # Birches "grow to be 5 to 7 blocks tall" (minecraft.wiki/w/Birch).
      oak(x, y, z, 5 + Noise.hash3(x, y, z, 23) % 3, x0, z0)
    elsif Noise.hash3(x, y, z, 28) < Biome::LARGE_OAKS[biome]
      large_oak(x, y, z, x0, z0)
    else
      oak(x, y, z, TRUNK[Biome::OAK] + Noise.hash3(x, y, z, 23) % 3, x0, z0)
    end
  end

  # The trees that the generator grows next have the log and the leaves of
  # wood (Block::OAK_WOOD and so on).
  def use_wood(wood)
    @log = Block::LOGS[wood]
    @leaves = Block::LEAVES[wood]
  end

  # An oak on the ground below x, y, z: a trunk of tall logs under two
  # wide layers and two small layers of leaves, with some corners missing.
  # Small jungle trees have this shape too.
  def oak(x, y, z, tall, x0, z0)
    return if y + tall + 2 >= WY
    logs(x, y, z, tall, x0, z0)
    top = y + tall
    ly = top - 2
    while ly <= top + 1
      radius = ly >= top ? 1 : 2
      dx = -radius
      while dx <= radius
        dz = -radius
        while dz <= radius
          corner = dx.abs == radius && dz.abs == radius
          skip = corner && (ly == top + 1 || Noise.hash3(x + dx, ly, z + dz, 24) < 32000)
          put(x + dx, ly, z + dz, @leaves, x0, z0) if !skip && air_in?(x + dx, ly, z + dz, x0, z0)
          dz += 1
        end
        dx += 1
      end
      ly += 1
    end
  end

  # A tree of the jungle on the ground below x, y, z: a large oak, a bush,
  # a giant jungle tree or a small jungle tree. minecraft.wiki/w/Jungle
  # names them all, and says that the oaks there are "more commonly
  # large". The wiki does not confirm the shares of 10%, 45%, 15% and 30%:
  # they copy the jungle trees in the game code.
  def jungle(x, y, z, x0, z0)
    r = Noise.hash3(x, y, z, 28)
    if r < 6554
      large_oak(x, y, z, x0, z0)
    elsif r < 36045
      jungle_bush(x, y, z, x0, z0)
    elsif r < 45875
      giant_jungle_tree(x, y, z, x0, z0)
    else
      # The trunk "can extend up to 10 blocks tall" (minecraft.wiki/w/Jungle_tree).
      oak(x, y, z, TRUNK[Biome::JUNGLE_TREE] + Noise.hash3(x, y, z, 23) % 7, x0, z0)
    end
  end

  # A jungle bush on the ground below x, y, z: one log, in 3 layers of
  # leaves that reach 3, 2 and 1 blocks out from the bottom up, with some
  # corners missing. minecraft.wiki/w/Jungle_Bush says "1-2 jungle logs"
  # in "1-3 layers" of leaves. The wiki does not confirm the reach: it
  # copies the bush in the game code.
  def jungle_bush(x, y, z, x0, z0)
    return if y + 3 >= WY
    logs(x, y, z, 1, x0, z0)
    ly = 0
    while ly < 3
      radius = 3 - ly
      dx = -radius
      while dx <= radius
        dz = -radius
        while dz <= radius
          skip = dx.abs == radius && dz.abs == radius && Noise.hash3(x + dx, y + ly, z + dz, 24) < 32768
          put(x + dx, y + ly, z + dz, @leaves, x0, z0) if !skip && air_in?(x + dx, y + ly, z + dz, x0, z0)
          dz += 1
        end
        dx += 1
      end
      ly += 1
    end
  end

  # A giant jungle tree on the ground below x, y, z: a trunk of 2 x 2 logs
  # with a wide crown on top, and branches in its upper half that end in
  # small crowns. minecraft.wiki/w/Jungle_tree says that they "can grow up
  # to 32 blocks high", with "between one and six branches". The wiki does
  # not confirm the other numbers: they copy the mega jungle tree in the
  # game code.
  def giant_jungle_tree(x, y, z, x0, z0)
    r = Noise.hash3(x, y, z, 23)
    tall = 10 + r % 3 + r / 3 % 20
    return if y + tall >= WY
    # Each log of the 2 x 2 trunk goes down to the ground of its own column.
    a = 0
    while a < 4
      cx = x + a % 2
      cz = z + a / 2
      ground = a == 0 ? y : [y, surface_height(cx, cz)].min
      logs(cx, ground, cz, y + tall - ground, x0, z0)
      a += 1
    end
    jungle_crown(x, y + tall, z, 3, 3, true, x0, z0)
    i = tall - 2 - r / 60 % 4
    while i > tall / 2
      b = Noise.hash3(x, y + i, z, 29)
      angle = b / 65536.0 * 2.0 * Math::PI
      bx = 0
      bz = 0
      l = 0
      while l < 5
        bx = (1.5 + Math.cos(angle) * l).to_i
        bz = (1.5 + Math.sin(angle) * l).to_i
        put(x + bx, y + i - 3 + l / 2, z + bz, @log, x0, z0)
        l += 1
      end
      b = Noise.hash3(x, y + i, z, 30)
      jungle_crown(x + bx, y + i, z + bz, 1, 2 + b % 2, false, x0, z0)
      i -= 2 + b / 2 % 4
    end
  end

  # The crown of a giant jungle tree: layers of leaves from x, y, z down,
  # that reach r blocks, then r + 1 and so on. Each layer is round, and
  # dx + dz stays below 7. A wide crown is around the 2 x 2 trunk that x,
  # z is the corner of.
  def jungle_crown(x, y, z, r, layers, wide, x0, z0)
    w = wide ? 1 : 0
    i = 0
    while i < layers
      reach = r + i
      dx = -reach
      while dx <= reach + w
        dz = -reach
        while dz <= reach + w
          ax = dx.abs
          az = dz.abs
          ax = (dx - 1).abs if wide && dx > 0
          az = (dz - 1).abs if wide && dz > 0
          if ax + az < 7 && ax * ax + az * az <= reach * reach && air_in?(x + dx, y - i, z + dz, x0, z0)
            put(x + dx, y - i, z + dz, @leaves, x0, z0)
          end
          dz += 1
        end
        dx += 1
      end
      i += 1
    end
  end

  # A spruce on the ground below x, y, z: a trunk of 5 to 8 logs with 1
  # or 2 bare logs at the bottom. From the top down, the layers of leaves
  # grow wider and then narrow again, and each narrow layer is wider than
  # the narrow layer above it, up to a widest reach of 2 or 3. The top
  # layer is 0 to 2 blocks above the trunk. minecraft.wiki/w/Spruce says
  # that "the leaves tend to grow in discrete rows". The wiki does not
  # confirm the numbers: they copy the spruce feature in the game code.
  def spruce(x, y, z, x0, z0)
    r = Noise.hash3(x, y, z, 23)
    tall = TRUNK[Biome::SPRUCE] + r % 3 + r / 3 % 2
    r /= 6
    bare = 1 + r % 2
    widest = 2 + r / 2 % 2
    above = r / 4 % 3
    reach = r / 12 % 2
    return if y + tall + above >= WY
    logs(x, y, z, tall, x0, z0)
    top = y + tall
    low = top - [4, tall - bare].max
    step = 1
    narrow = 0
    ly = top + above
    while ly >= low
      leaf_row(x, ly, z, reach, x0, z0)
      if reach >= step
        reach = narrow
        narrow = 1
        step = [step + 1, widest].min
      else
        reach += 1
      end
      ly -= 1
    end
  end

  # A pine on the ground below x, y, z: a tall bare trunk of 6 to 10 logs
  # with a few small layers of leaves at the top. minecraft.wiki/w/Spruce
  # says that pines are "a fairly tall variant of spruces" "with only a
  # few leaves at the top". The wiki does not confirm the numbers: they
  # copy the pine feature in the game code.
  def pine(x, y, z, x0, z0)
    r = Noise.hash3(x, y, z, 23)
    tall = 6 + r % 5
    layers = 4 + r / 5 % 2
    return if y + tall + 1 >= WY
    logs(x, y, z, tall, x0, z0)
    top = y + tall
    i = 0
    while i < layers
      leaf_row(x, top + 1 - i, z, i == 0 || i == layers - 1 ? 0 : 1, x0, z0)
      i += 1
    end
  end

  # A trunk of tall logs up from x, y, z, on dirt.
  def logs(x, y, z, tall, x0, z0)
    i = 0
    while i < tall
      put(x, y + i, z, @log, x0, z0)
      i += 1
    end
    put(x, y - 1, z, Block::DIRT, x0, z0)
  end

  # A square layer of leaves around x, y, z that reaches out r blocks,
  # without its corners.
  def leaf_row(x, y, z, r, x0, z0)
    dx = -r
    while dx <= r
      dz = -r
      while dz <= r
        if (dx.abs < r || dz.abs < r || r == 0) && air_in?(x + dx, y, z + dz, x0, z0)
          put(x + dx, y, z + dz, @leaves, x0, z0)
        end
        dz += 1
      end
      dx += 1
    end
  end

  # A large oak on the ground below x, y, z: a tall trunk with a branch on
  # most layers of its upper part, and a ball of leaves at the top and at
  # the end of each branch. minecraft.wiki/w/Oak says only that "they
  # often have branches", and that the sapling needs 4 to 14 blocks of
  # space. The heights and the branch lengths copy the fancy trunk in the
  # game code. The wiki does not confirm them.
  def large_oak(x, y, z, x0, z0)
    tall = 5 + Noise.hash3(x, y, z, 23) % 12
    return if y + tall >= WY
    trunk = (tall * 0.618).floor
    limb(x, y, z, x, y + trunk, z, x0, z0)
    limb(x, y + trunk, z, x, y + tall - 5, z, x0, z0)
    oak_ball(x, y + tall - 5, z, x0, z0)
    put(x, y - 1, z, Block::DIRT, x0, z0)
    n = tall - 5
    while n >= 0
      spread = large_oak_spread(tall, n)
      if spread >= 0.0
        reach = spread * (Noise.hash3(x, y + n, z, 29) / 65536.0 + 0.328)
        angle = Noise.hash3(x, y + n, z, 30) / 65536.0 * 2.0 * Math::PI
        ex = x + (reach * Math.sin(angle) + 0.5).floor
        ez = z + (reach * Math.cos(angle) + 0.5).floor
        ey = y + n - 1
        # The branch rises from the trunk by about 2 blocks for each 5 out.
        rise = ey - Math.sqrt(((x - ex) * (x - ex) + (z - ez) * (z - ez)).to_f) * 0.381
        base = rise > y + trunk ? y + trunk : rise.to_i
        # Branches that start low on the trunk do not grow.
        if base - y >= tall * 0.2
          limb(x, base, z, ex, ey, ez, x0, z0)
          oak_ball(ex, ey, ez, x0, z0)
        end
      end
      n -= 1
    end
  end

  # How far out a large oak that is tall blocks high grows the branch at
  # n blocks above the ground, or -1.0 below 30% of its height. Branches
  # are longest at half the height, so the crown is round.
  def large_oak_spread(tall, n)
    return -1.0 if n < tall * 0.3
    half = tall / 2.0
    d = half - n
    return 0.0 if d.abs >= half
    Math.sqrt(half * half - d * d) * 0.5
  end

  # A straight line of logs from one block to another, both included.
  def limb(sx, sy, sz, ex, ey, ez, x0, z0)
    dx = ex - sx
    dy = ey - sy
    dz = ez - sz
    steps = [dx.abs, dy.abs, dz.abs].max
    i = 0
    while i <= steps
      t = steps == 0 ? 0.0 : i.to_f / steps
      put(sx + (0.5 + t * dx).floor, sy + (0.5 + t * dy).floor, sz + (0.5 + t * dz).floor, @log, x0, z0)
      i += 1
    end
  end

  # A ball of leaves 5 blocks tall on the end of a large oak branch at x,
  # y, z. A layer keeps each block whose far corner is within r of the
  # branch end: a plus at the bottom and at the top (r = 2), and 5 x 5
  # without the corners between them (r = 3).
  def oak_ball(x, y, z, x0, z0)
    ly = 0
    while ly <= 4
      r = ly == 0 || ly == 4 ? 2 : 3
      dx = -r
      while dx <= r
        dz = -r
        while dz <= r
          ax = dx.abs + 0.5
          az = dz.abs + 0.5
          if ax * ax + az * az <= r * r && air_in?(x + dx, y + ly, z + dz, x0, z0)
            put(x + dx, y + ly, z + dz, @leaves, x0, z0)
          end
          dz += 1
        end
        dx += 1
      end
      ly += 1
    end
  end

  # An acacia on the ground below x, y, z. Near its top, the trunk leans
  # 1 to 3 blocks to one side. Most acacias also fork a shorter branch
  # that grows out on a diagonal, with a smaller crown.
  # minecraft.wiki/w/Tree_definition (forking_trunk_placer) gives this
  # shape. The wiki does not confirm the heights and the odds: they copy
  # the acacia feature in the game code.
  def acacia(x, y, z, x0, z0)
    r = Noise.hash3(x, y, z, 23)
    tall = TRUNK[Biome::ACACIA] + r % 3 + r / 3 % 3
    return if y + tall + 2 >= WY
    r /= 9
    dir = r % 4
    bend = tall - 1 - r / 4 % 4
    lean = 3 - r / 16 % 3
    tx = x
    tz = z
    i = 0
    while i < tall
      if i >= bend && lean > 0
        tx += Block::DIR_DX[dir]
        tz += Block::DIR_DZ[dir]
        lean -= 1
      end
      put(tx, y + i, tz, @log, x0, z0)
      i += 1
    end
    put(x, y - 1, z, Block::DIRT, x0, z0)
    r = Noise.hash3(x, y, z, 27)
    side = r % 4
    if side != dir
      i = bend - 1 - r / 4 % 2
      left = 1 + r / 8 % 3
      bx = x
      bz = z
      top = -1
      while i < tall && left > 0
        if i >= 1
          bx += Block::DIR_DX[side]
          bz += Block::DIR_DZ[side]
          put(bx, y + i, bz, @log, x0, z0)
          top = y + i
        end
        i += 1
        left -= 1
      end
      acacia_crown(bx, top, bz, 2, x0, z0) if top >= 0
    end
    acacia_crown(tx, y + tall - 1, tz, 3, x0, z0)
  end

  # The flat crown of an acacia on the log at x, y, z. Level with the
  # log, the leaves reach out `reach` blocks, without the corners. One
  # layer above, they cover the 3 x 3 blocks over the log, and a crown
  # that reaches 3 adds one block at the middle of each side.
  def acacia_crown(x, y, z, reach, x0, z0)
    leaf_row(x, y, z, reach, x0, z0)
    dx = -reach
    while dx <= reach
      dz = -reach
      while dz <= reach
        ax = dx.abs
        az = dz.abs
        if ((ax <= 1 && az <= 1) || ax + az < reach) && air_in?(x + dx, y + 1, z + dz, x0, z0)
          put(x + dx, y + 1, z + dz, @leaves, x0, z0)
        end
        dz += 1
      end
      dx += 1
    end
  end
end
