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
    @col_t = Array.new(CHUNK * CHUNK, 0.0)
    @cave_a = Array.new(GX * GY * GX, 0.0)
    @cave_b = Array.new(GX * GY * GX, 0.0)
    @corner_a = Array.new(8, 0.0)
    @corner_b = Array.new(8, 0.0)
    @noise = Noise.new(seed)
    @noise2 = Noise.new(seed * 31 + 7)
    @noise3 = Noise.new(seed * 17 + 3)
  end

  def self.index(x, y, z) = (((x & LMASK) + 1) * PZ + (z & LMASK) + 1) * PY + y + 1
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
    s = World.slot(cx, cz)
    @slot_cx[s] == cx && @slot_cz[s] == cz
  end

  def loaded?(x, z) = chunk_loaded?(x >> 4, z >> 4)
  def inside?(x, y, z) = y >= 0 && y < WY && loaded?(x, z)
  def height_at(x, z) = @height[(x & LMASK) * WZ + (z & LMASK)]
  # True when nothing above x, y, z stops the rain.
  def under_sky?(x, y, z) = height_at(x.floor, z.floor) <= y.floor

  # The light list of a loaded chunk, else an empty list. (An Array-or-nil
  # return makes Spinel box the elements.)
  def torches_of(cx, cz) = chunk_loaded?(cx, cz) ? @chunk_torches[World.slot(cx, cz)] : @no_torches

  def get(x, y, z)
    return Block::AIR unless inside?(x, y, z)
    block(World.index(x, y, z))
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
          return true if Block.solid?(get(bx, by, bz))
          bz += 1
        end
        by += 1
      end
      bx += 1
    end
    false
  end

  def set(x, y, z, b)
    return unless inside?(x, y, z)
    # Spinel widens b (it comes from the inventory); to_i gives the writers
    # an Integer, so the generator's writes stay unboxed.
    v = b.to_i
    i = World.index(x, y, z)
    remove_torch(x, y, z) if Block.emits?(block(i))
    write(i, x & LMASK, z & LMASK, v)
    @edited[World.slot(x >> 4, z >> 4)] = 1
    add_torch(x, y, z) if Block.emits?(v)
    update_height(x, z)
    expose_lava(x, y, z) if Block::OPAQUE[v] == 0
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
    x = cx * CHUNK
    while x < cx * CHUNK + CHUNK
      z = cz * CHUNK
      while z < cz * CHUNK + CHUNK
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
          add_torch(x, y, z) if b == Block::TORCH || (b == Block::LAVA && exposed?(base + y))
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

  def surface_height(x, z)
    nx = x / 1.0
    nz = z / 1.0
    continent = @noise.fbm2(nx / 220.0, nz / 220.0, 3)
    hills = @noise.fbm2(nx / 55.0 + 40.0, nz / 55.0, 4)
    ridge = 1.0 - @noise2.noise2(nx / 70.0, nz / 70.0).abs * 1.6
    ridge = ridge < 0.0 ? 0.0 : ridge
    mask = (@noise2.fbm2(nx / 150.0 + 9.0, nz / 150.0, 2) + 0.12) * 2.5
    mask = mask.clamp(0.0, 1.0)
    h = SEA + 1.0 + continent * 34.0 + hills * 7.0 + mask * ridge * ridge * 40.0
    h.to_i.clamp(4, WY - 14)
  end

  def temperature(x, z) = @noise3.fbm2(x / 110.0 + 300.0, z / 110.0, 2) * 1.8

  # Climate and height bands. t is the temperature, top the y of the column's top block.
  def desert?(t) = t > 0.28
  def beach?(top) = top <= SEA + 1
  # High peaks are bare stone at the top and below it.
  def bare_rock?(top) = top > SEA + 40

  # The block at the top of a column before caves and plants.
  def top_block(x, z, h, t)
    top = h - 1
    snowy = t < -0.3 || top > SEA + 34
    b = beach?(top) || desert?(t) ? Block::SAND : (snowy ? Block::SNOW_GRASS : Block::GRASS)
    b = Block::GRAVEL if top < SEA - 2 && Noise.hash3(x / 3, 0, z / 3, 5) < 20000
    b = Block::STONE if bare_rock?(top)
    b = Block::SNOW if top > SEA + 44
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
    return -1 unless tree_roll?(x, z, Noise.hash3(x, 0, z, 21))
    h = surface_height(x, z)
    ground = top_block(x, z, h, temperature(x, z))
    return -1 unless ground == Block::GRASS || ground == Block::SNOW_GRASS
    return -1 if !beach?(h - 1) && carved?(x, h - 1, z)
    h - 1
  end

  # Forests get more trees.
  def tree_roll?(x, z, r) = r < 300 || (r < 2600 && @noise3.fbm2(x / 90.0, z / 90.0 + 70.0, 2) > 0.15)

  def generate_chunk(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        @col_h[lx * CHUNK + lz] = surface_height(x0 + lx, z0 + lz)
        @col_t[lx * CHUNK + lz] = temperature(x0 + lx, z0 + lz)
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
        t = @col_t[lx * CHUNK + lz]
        top = h - 1
        sandy = beach?(top) || desert?(t)
        surface = top_block(x, z, h, t)
        base = World.index(x, 0, z)
        y = 0
        while y < h
          b = Block::STONE
          if y == 0
            b = Block::BEDROCK
          elsif y == top
            b = surface
          elsif y > top - 4
            b = sandy ? Block::SAND : Block::DIRT
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
    x = x0 - 2
    while x < x0 + CHUNK + 2
      z = z0 - 2
      while z < z0 + CHUNK + 2
        top = tree_top(x, z)
        tree(x, top + 1, z, x0, z0) if top >= 0
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
        ground = block(World.index(x, top, z))
        r = Noise.hash3(x, 0, z, 21)
        if ground == Block::GRASS && !tree_roll?(x, z, r) && block(World.index(x, top + 1, z)) == Block::AIR
          p = Noise.hash3(x, 2, z, 25)
          meadow = @noise3.noise2(x / 30.0, z / 30.0 + 11.0)
          if p < 9000 + (meadow * 12000.0).to_i
            put(x, top + 1, z, Block::TALL_GRASS, x0, z0)
          elsif p > 63800 && meadow > -0.05
            put(x, top + 1, z, (x + z) % 3 == 0 ? Block::ROSE : Block::DANDELION, x0, z0)
          end
        elsif ground == Block::SAND && desert?(@col_t[lx * CHUNK + lz]) && !beach?(top) && r < 350
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

  # Writes a generated block when it is inside chunk x0, z0.
  def put(x, y, z, b, x0, z0)
    return if x < x0 || z < z0 || x >= x0 + CHUNK || z >= z0 + CHUNK || y < 0 || y >= WY
    put_block(World.index(x, y, z), b)
  end

  def air_in?(x, y, z, x0, z0)
    return false if x < x0 || z < z0 || x >= x0 + CHUNK || z >= z0 + CHUNK || y < 0 || y >= WY
    block(World.index(x, y, z)) == Block::AIR
  end

  def tree(x, y, z, x0, z0)
    tall = 4 + Noise.hash3(x, y, z, 23) % 3
    return if y + tall + 2 >= WY
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
          put(x + dx, ly, z + dz, Block::LEAVES, x0, z0) if !skip && air_in?(x + dx, ly, z + dz, x0, z0)
          dz += 1
        end
        dx += 1
      end
      ly += 1
    end
    i = 0
    while i < tall
      put(x, y + i, z, Block::LOG, x0, z0)
      i += 1
    end
    put(x, y - 1, z, Block::DIRT, x0, z0)
  end
end
