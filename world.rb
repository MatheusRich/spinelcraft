module Block
  AIR = 0
  GRASS = 1
  DIRT = 2
  STONE = 3
  SAND = 4
  WATER = 5
  LOG = 6
  LEAVES = 7
  PLANKS = 8
  COBBLE = 9
  GLASS = 10
  SNOW_GRASS = 11
  BEDROCK = 12
  BRICK = 13
  COAL = 14
  IRON = 15
  GRAVEL = 16
  DIAMOND = 17
  CACTUS = 18
  SNOW = 19
  TALL_GRASS = 20
  ROSE = 21
  DANDELION = 22
  TORCH = 23
  PORKCHOP = 24
  WOOD_PICK = 25
  STONE_PICK = 26
  IRON_PICK = 27
  DIAMOND_PICK = 28
  # Flowing water: FLOW + level - 1 for levels 1..7 (a source is level 8).
  FLOW = 29
  BOW = 36
  ARROW = 37
  # Lava: a source is level 4; LAVA_FLOW + level - 1 for flowing levels 1..3.
  LAVA = 38
  LAVA_FLOW = 39
  WOOL = 42
  BED = 43
  CHEST = 44
  COUNT = 45

  NAMES = ["AIR", "GRASS", "DIRT", "STONE", "SAND", "WATER", "LOG", "LEAVES", "PLANKS", "COBBLESTONE",
           "GLASS", "SNOWY GRASS", "BEDROCK", "BRICKS", "COAL ORE", "IRON ORE", "GRAVEL", "DIAMOND ORE",
           "CACTUS", "SNOW", "TALL GRASS", "ROSE", "DANDELION", "TORCH", "PORKCHOP", "WOODEN PICKAXE", "STONE PICKAXE", "IRON PICKAXE", "DIAMOND PICKAXE", "WATER", "WATER", "WATER", "WATER", "WATER", "WATER", "WATER", "BOW", "ARROW", "LAVA", "LAVA", "LAVA", "LAVA", "WOOL", "BED", "CHEST"]
  TOP = [0, Tex::GRASS_TOP, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_TOP, Tex::LEAVES,
         Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON,
         Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_TOP, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_TOP, Tex::CHEST_TOP]
  SIDE = [0, Tex::GRASS_SIDE, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_SIDE, Tex::LEAVES,
          Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW_SIDE, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON,
          Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_SIDE, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_SIDE, Tex::CHEST_SIDE]
  BOTTOM = [0, Tex::DIRT, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_TOP, Tex::LEAVES,
            Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::DIRT, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON,
            Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_TOP, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::PLANKS, Tex::CHEST_TOP]
  # Integer 0/1 tables: Spinel keeps Integer arrays unboxed.
  # Hides the faces behind it.
  OPAQUE = [0, 1, 1, 1, 1, 0, 1, 0, 1, 1,
            0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1]
  # Darkens ambient occlusion corners.
  OCCLUDES = [0, 1, 1, 1, 1, 0, 1, 1, 1, 1,
              0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1]
  # Stops the player.
  SOLID = [0, 1, 1, 1, 1, 0, 1, 1, 1, 1,
           1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1]
  # Drawn as two crossed quads instead of a cube.
  PLANT = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Seconds to break by hand in survival; negative never breaks.
  HARDNESS = [0.0, 0.6, 0.5, 1.6, 0.5, -1.0, 1.2, 0.2, 1.0, 1.8, 0.3, 0.6, -1.0, 2.0, 2.2, 2.6, 0.6, 3.0, 0.4, 0.2, 0.0, 0.0, 0.0, 0.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 0.8, 0.3, 1.0]
  # What breaking the block gives in survival.
  DROPS = [0, DIRT, DIRT, COBBLE, SAND, 0, LOG, 0, PLANKS, COBBLE, 0, DIRT, 0, BRICK, COAL, IRON, GRAVEL, DIAMOND, CACTUS, SNOW, 0, ROSE, DANDELION, TORCH, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, WOOL, BED, CHEST]
  # Pickaxe tier a block needs to drop anything: 1 wood, 2 stone, 3 iron.
  NEEDS_PICK = [0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Pickaxe tier of an item (0 for everything that is not a pickaxe).
  PICK_TIER = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Water level: 8 for a source, 1..7 for flowing water, 0 for anything else.
  WATER_LEVEL = [0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  def self.blocks_light(b) = b != AIR && b != GLASS && PLANT[b] == 0
  def self.water?(b) = WATER_LEVEL[b] > 0
  # Things that live in the inventory but are never placed.
  def self.item?(b) = (b >= PORKCHOP && b <= DIAMOND_PICK) || b == BOW || b == ARROW
  def self.lava?(b) = b >= LAVA && b < LAVA_FLOW + 3
  def self.lava_level(b) = b == LAVA ? 4 : (lava?(b) ? b - LAVA_FLOW + 1 : 0)
  # Torches and lava sources light their surroundings.
  def self.emits?(b) = b == TORCH || b == LAVA
end

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

class Noise
  def initialize(seed)
    p = (0...256).to_a
    rng = seed & 0x7fffffff
    i = 255
    while i > 0
      rng = (rng * 1103515245 + 12345) & 0x7fffffff
      j = rng % (i + 1)
      t = p[i]
      p[i] = p[j]
      p[j] = t
      i -= 1
    end
    @perm = Array.new(512, 0)
    i = 0
    while i < 512
      @perm[i] = p[i & 255]
      i += 1
    end
  end

  def fade(t) = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

  def grad2(h, x, y)
    case h & 7
    when 0 then x + y
    when 1 then -x + y
    when 2 then x - y
    when 3 then -x - y
    when 4 then x
    when 5 then -x
    when 6 then y
    else -y
    end
  end

  def grad3(h, x, y, z)
    case h & 15
    when 0, 12 then x + y
    when 1, 14 then -x + y
    when 2 then x - y
    when 3 then -x - y
    when 4 then x + z
    when 5 then -x + z
    when 6 then x - z
    when 7 then -x - z
    when 8 then y + z
    when 9, 13 then -y + z
    when 10 then y - z
    else -y - z
    end
  end

  def noise2(x, y)
    xi = x.floor
    yi = y.floor
    xf = x - xi
    yf = y - yi
    xa = xi & 255
    ya = yi & 255
    u = fade(xf)
    v = fade(yf)
    aa = @perm[@perm[xa] + ya]
    ab = @perm[@perm[xa] + ya + 1]
    ba = @perm[@perm[xa + 1] + ya]
    bb = @perm[@perm[xa + 1] + ya + 1]
    x1 = grad2(aa, xf, yf) + (grad2(ba, xf - 1.0, yf) - grad2(aa, xf, yf)) * u
    x2 = grad2(ab, xf, yf - 1.0) + (grad2(bb, xf - 1.0, yf - 1.0) - grad2(ab, xf, yf - 1.0)) * u
    (x1 + (x2 - x1) * v) * 0.7
  end

  def noise3(x, y, z)
    xi = x.floor
    yi = y.floor
    zi = z.floor
    xf = x - xi
    yf = y - yi
    zf = z - zi
    xa = xi & 255
    ya = yi & 255
    za = zi & 255
    u = fade(xf)
    v = fade(yf)
    w = fade(zf)
    a = @perm[xa] + ya
    aa = @perm[a] + za
    ab = @perm[a + 1] + za
    b = @perm[xa + 1] + ya
    ba = @perm[b] + za
    bb = @perm[b + 1] + za
    l1 = lerp(lerp(grad3(@perm[aa], xf, yf, zf), grad3(@perm[ba], xf - 1.0, yf, zf), u),
              lerp(grad3(@perm[ab], xf, yf - 1.0, zf), grad3(@perm[bb], xf - 1.0, yf - 1.0, zf), u), v)
    l2 = lerp(lerp(grad3(@perm[aa + 1], xf, yf, zf - 1.0), grad3(@perm[ba + 1], xf - 1.0, yf, zf - 1.0), u),
              lerp(grad3(@perm[ab + 1], xf, yf - 1.0, zf - 1.0), grad3(@perm[bb + 1], xf - 1.0, yf - 1.0, zf - 1.0), u), v)
    lerp(l1, l2, w)
  end

  def lerp(a, b, t) = a + (b - a) * t

  def fbm2(x, y, octaves)
    sum = 0.0
    amp = 1.0
    freq = 1.0
    norm = 0.0
    i = 0
    while i < octaves
      sum += noise2(x * freq, y * freq) * amp
      norm += amp
      # `x *= k` in a loop makes Spinel box x as a possible bigint.
      amp /= 2.0
      freq += freq
      i += 1
    end
    sum / norm
  end
end

def hash3(x, y, z, salt)
  h = (x * 73856093 + y * 19349663 + z * 83492791 + salt * 2654435761) & 0xffffffff
  h = ((h ^ (h >> 15)) * 2146121005) & 0xffffffff
  h = ((h ^ (h >> 13)) * 1798096565) & 0xffffffff
  (h ^ (h >> 16)) & 0xffff
end

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

  # The light list of a loaded chunk, else an empty list. (An Array-or-nil
  # return makes Spinel box the elements.)
  def torches_of(cx, cz) = chunk_loaded?(cx, cz) ? @chunk_torches[World.slot(cx, cz)] : @no_torches

  def get(x, y, z)
    return Block::AIR unless inside?(x, y, z)
    block(World.index(x, y, z))
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
    b = Block::GRAVEL if top < SEA - 2 && hash3(x / 3, 0, z / 3, 5) < 20000
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
    return -1 unless tree_roll?(x, z, hash3(x, 0, z, 21))
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
            if hash3(x >> 1, y >> 1, z >> 1, 11) < 1100 && hash3(x, y, z, 12) < 40000
              b = Block::COAL
            elsif y < 50 && hash3(x >> 1, y >> 1, z >> 1, 13) < 600 && hash3(x, y, z, 14) < 36000
              b = Block::IRON
            elsif y < 16 && hash3(x >> 1, y >> 1, z >> 1, 15) < 160 && hash3(x, y, z, 16) < 30000
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
        r = hash3(x, 0, z, 21)
        if ground == Block::GRASS && !tree_roll?(x, z, r) && block(World.index(x, top + 1, z)) == Block::AIR
          p = hash3(x, 2, z, 25)
          meadow = @noise3.noise2(x / 30.0, z / 30.0 + 11.0)
          if p < 9000 + (meadow * 12000.0).to_i
            put(x, top + 1, z, Block::TALL_GRASS, x0, z0)
          elsif p > 63800 && meadow > -0.05
            put(x, top + 1, z, (x + z) % 3 == 0 ? Block::ROSE : Block::DANDELION, x0, z0)
          end
        elsif ground == Block::SAND && desert?(@col_t[lx * CHUNK + lz]) && !beach?(top) && r < 350
          tall = 1 + hash3(x, 1, z, 22) % 3
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
    tall = 4 + hash3(x, y, z, 23) % 3
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
          skip = corner && (ly == top + 1 || hash3(x + dx, ly, z + dz, 24) < 32000)
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
