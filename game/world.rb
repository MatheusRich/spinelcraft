# Block storage, the chunks around the player, and the store of changed
# chunks. ChunkGenerator makes the blocks of a new chunk.
WY = 256
PY = WY + 2
# The y of the top water block of the sea. Minecraft has it at y 62, but
# its world goes down to y -64 (minecraft.wiki/w/Altitude).
SEA = 64
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

  attr_reader :blocks, :height, :chunk_torches, :slot_cx, :slot_cz, :store

  def initialize(seed)
    # Eight blocks per Integer, one byte each; see block.
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
    @generator = ChunkGenerator.new(self, seed)
  end

  # The noise of the terrain (see ChunkGenerator).
  def terrain = @generator.terrain

  # Spinel cannot type the positions that the game code gives World (from
  # the player, the mobs or the flow queue). So get, set and the chunk
  # lookups call to_i before they use index or slot, and the generator and
  # the mesher stay unboxed. The to_i in index lets Spinel type block and
  # put_block before its inference stops at its round limit.
  def self.index(x, y, z) = ((((x & LMASK) + 1) * PZ + (z & LMASK) + 1) * PY + y + 1).to_i
  # Block i of a packed store: byte i & 7 of Integer i >> 3. The shift
  # keeps the sign, and the mask drops it.
  def block(i) = (@blocks[i >> 3] >> ((i & 7) << 3)) & 255

  # The bits that put_block keeps of an Integer of the store, for each byte.
  # Byte 7 holds the sign bit, and 255 << 56 is too large for an Integer.
  KEEP = [~255, ~(255 << 8), ~(255 << 16), ~(255 << 24), ~(255 << 32), ~(255 << 40), ~(255 << 48), (1 << 56) - 1]

  def put_block(i, block)
    j = i >> 3
    k = i & 7
    # An id from 128 goes into byte 7 as a negative number, so the shift
    # does not pass the sign bit.
    v = k == 7 ? ((block ^ 128) - 128) << 56 : block << (k << 3)
    @blocks[j] = (@blocks[j] & KEEP[k]) | v
  end

  def self.slot(cx, cz) = (cx & RING_MASK) * RING + (cz & RING_MASK)

  # Appends the offsets of the square rings 0 to max to dxs and dzs, nearest
  # ring first.
  def self.square_rings(max, dxs, dzs)
    (0..max).each do |r|
      (-r..r).each do |dx|
        (-r..r).each do |dz|
          if dx.abs == r || dz.abs == r
            dxs << dx
            dzs << dz
          end
        end
      end
    end
    nil
  end
  # A unique Integer for a block anywhere in the world (chest keys). The
  # to_i lets Spinel type the key when the position is untyped, as in index.
  def self.key(x, y, z) = (((((x + KEY_OFF) << 26) | (z + KEY_OFF)) << 8) | y).to_i
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

  # Ground above the beach with no tree or water on top.
  def dry_land?(x, z)
    h = height_at(x, z)
    block = get(x, h - 1, z)
    h > SEA + 2 && !Block.leaves?(block) && !Block.water?(block)
  end

  # A door is two blocks tall. It stands on a solid block that is not a
  # door, and no door stands right above it, so each half has one partner.
  # The upper half takes the place of a block that Block.replaceable?
  # names, as the lower half does.
  def door_fits?(x, y, z)
    below = get(x, y - 1, z)
    Block.solid?(below) && !Block.door?(below) && Block.replaceable?(get(x, y + 1, z)) && !Block.door?(get(x, y + 2, z))
  end

  # True when the cells around x, y, z give block what Block::HOLD says
  # that it needs to stay at x, y, z. The block in the cell itself does
  # not count, so a block can ask before it goes there.
  def can_hold?(block, x, y, z)
    ix = x.to_i
    iy = y.to_i
    iz = z.to_i
    hold = Block::HOLD[block]
    return true if hold == Block::HOLD_NONE
    return wall_holds?(ix, iy, iz, Block::FACING[block]) if hold == Block::HOLD_WALL

    ground = get(ix, iy - 1, iz)
    return Block.solid?(ground) if hold == Block::HOLD_FLOOR
    return Block.soil?(ground) if hold == Block::HOLD_SOIL
    return Block.soil?(ground) || ground == Block::SAND if hold == Block::HOLD_SOIL_OR_SAND
    return !Block.replaceable?(ground) if hold == Block::HOLD_FALL
    return false unless ground == Block::SAND || ground == Block::CACTUS

    cactus_room?(ix, iy, iz)
  end

  # True when the wall of a block at x, y, z that faces dir is solid, or
  # is in a chunk that is not loaded. get gives air there, but the wall
  # can still be solid.
  def wall_holds?(x, y, z, dir)
    wall_x = x - Block::DIR_DX[dir]
    wall_z = z - Block::DIR_DZ[dir]
    !loaded?(wall_x, wall_z) || Block.solid?(get(wall_x, y, wall_z))
  end

  # True when no solid block or lava is beside x, y, z, and no water or
  # lava is above it (see Block::HOLD_CACTUS).
  def cactus_room?(x, y, z)
    above = get(x, y + 1, z)
    return false if Block.water?(above) || Block.lava?(above)

    dir = 0
    while dir < 4
      side = get(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir])
      return false if Block.solid?(side) || Block.lava?(side)

      dir += 1
    end
    true
  end

  # The y of the other half of the door at x, y, z.
  def door_partner(x, y, z) = Block.door?(get(x, y + 1, z)) ? y + 1 : y - 1

  # True when lava is on a side of x, y, z.
  def near_lava?(x, y, z)
    Block.lava?(get(x + 1, y, z)) || Block.lava?(get(x - 1, y, z)) || Block.lava?(get(x, y + 1, z)) ||
      Block.lava?(get(x, y - 1, z)) || Block.lava?(get(x, y, z + 1)) || Block.lava?(get(x, y, z - 1))
  end

  # True when water is on a side of x, y, z or above it. Water under
  # lava does not cool it.
  def touches_water?(x, y, z)
    Block.water?(get(x + 1, y, z)) || Block.water?(get(x - 1, y, z)) ||
      Block.water?(get(x, y + 1, z)) || Block.water?(get(x, y, z + 1)) || Block.water?(get(x, y, z - 1))
  end

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
        ((z - half).floor..z1).each do |bz|
          return true if block_in_box?(get(bx, by, bz), bx, by, bz, x, y, z, half, tall)
        end
        by += 1
      end
      bx += 1
    end
    false
  end

  # True when block is solid and its box (Block.box_hx and the others) in the
  # cell bx, by, bz overlaps the box of solid_in_box?.
  def block_in_box?(block, bx, by, bz, x, y, z, half, tall)
    return false unless Block.solid?(block)

    y0 = by + Block.box_dy(block)
    (bx + 0.5 + Block.box_dx(block) - x).abs < Block.box_hx(block) + half && (bz + 0.5 + Block.box_dz(block) - z).abs < Block.box_hz(block) + half &&
      y0 < y + tall && y0 + Block.box_top(block) > y
  end

  # True when the body with the box of solid_in_box? touches a cactus. In
  # Minecraft, a body touches each cell that its box overlaps, and a body
  # that leans on the side of a cactus is 1/16 into its cell. The test
  # reaches CACTUS_REACH below the feet, so a body that stands on a cactus
  # touches it too. minecraft.wiki/w/Cactus does not confirm the top for
  # Java Edition.
  CACTUS_REACH = 0.01

  def cactus_in_box?(x, y, z, half, tall)
    x = x.to_f
    y = y.to_f
    z = z.to_f
    x1 = (x + half).floor
    y1 = (y + tall).floor
    z1 = (z + half).floor
    bx = (x - half).floor
    while bx <= x1
      by = (y - CACTUS_REACH).floor
      while by <= y1
        ((z - half).floor..z1).each { |bz| return true if get(bx, by, bz) == Block::CACTUS }
        by += 1
      end
      bx += 1
    end
    false
  end

  # The nearest face of the solid blocks that overlap the box of
  # solid_in_box?, on the x axis (axis 0), the y axis (axis 1) or the z axis
  # (axis 2): the lowest face when dir is 1, and the highest when dir is -1.
  # A move along that axis stops at this face.
  def box_edge(x, y, z, half, tall, axis, dir) # rubocop:todo Metrics/MethodLength
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
          block = get(bx, by, bz)
          if block_in_box?(block, bx, by, bz, x, y, z, half, tall)
            lo = axis == 0 ? bx + 0.5 + Block.box_dx(block) - Block.box_hx(block) : (axis == 1 ? by + Block.box_dy(block) : bz + 0.5 + Block.box_dz(block) - Block.box_hz(block))
            hi = axis == 0 ? bx + 0.5 + Block.box_dx(block) + Block.box_hx(block) : (axis == 1 ? by + Block.box_dy(block) + Block.box_top(block) : bz + 0.5 + Block.box_dz(block) + Block.box_hz(block))
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

  # Stores block at index i and in the padding copy of an edge column.
  def write(i, lx, lz, block)
    put_block(i, block)
    return if lx != 0 && lx != LMASK && lz != 0 && lz != LMASK

    ex = lx == 0 ? WX * PZ * PY : (lx == LMASK ? -WX * PZ * PY : 0)
    ez = lz == 0 ? WZ * PY : (lz == LMASK ? -WZ * PY : 0)
    put_block(i + ex, block) if ex != 0
    put_block(i + ez, block) if ez != 0
    put_block(i + ex + ez, block) if ex != 0 && ez != 0
  end

  # Copies the edge columns of a chunk into the padding.
  def mirror_edges(cx, cz)
    lx0 = (cx & RING_MASK) * CHUNK
    lz0 = (cz & RING_MASK) * CHUNK
    return if lx0 != 0 && lx0 + CHUNK != WX && lz0 != 0 && lz0 + CHUNK != WZ

    lx = lx0
    while lx < lx0 + CHUNK
      (lz0...lz0 + CHUNK).each do |lz|
        if lx == 0 || lx == LMASK || lz == 0 || lz == LMASK
          base = World.index(lx, 0, lz)
          WY.times { |y| write(base + y, lx, lz, block(base + y)) }
        end
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
      @generator.generate(cx, cz)
      @edited[s] = 0
    else
      unpack_chunk(cx, cz, data)
      @store.delete(key)
      @edited[s] = 1
    end
    mirror_edges(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    (x0...x0 + CHUNK).each { |x| (z0...z0 + CHUNK).each { |z| update_height(x, z) } }
    # A generated chunk has no torches and no lava above LAVA_LEVEL.
    find_torches(cx, cz, data.nil? ? ChunkGenerator::LAVA_LEVEL + 1 : WY)
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
    (x0...x0 + CHUNK).each do |x|
      (z0...z0 + CHUNK).each do |z|
        base = World.index(x, 0, z)
        WY.times { |y| col[y] = block(base + y) }
        parts << col.pack("C*")
      end
    end
    parts.join
  end

  def unpack_chunk(cx, cz, data)
    k = 0
    (cx * CHUNK...cx * CHUNK + CHUNK).each do |x|
      (cz * CHUNK...cz * CHUNK + CHUNK).each do |z|
        base = World.index(x, 0, z)
        WY.times do |y|
          put_block(base + y, data.getbyte(k) || 0)
          k += 1
        end
      end
    end
  end

  # Every edited chunk: the store plus the edited loaded chunks.
  def edited_chunks
    out = {}
    @store.each { |k, v| out[k] = v }
    (CX * CZ).times do |s|
      out[World.chunk_key(@slot_cx[s], @slot_cz[s])] = chunk_bytes(@slot_cx[s], @slot_cz[s]) if @edited[s] == 1
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
    6.times do |d|
      nx = x + (d == 0 ? 1 : (d == 1 ? -1 : 0))
      ny = y + (d == 2 ? 1 : (d == 3 ? -1 : 0))
      nz = z + (d == 4 ? 1 : (d == 5 ? -1 : 0))
      if inside?(nx, ny, nz) && block(World.index(nx, ny, nz)) == Block::LAVA && !listed?(nx, ny, nz)
        add_torch(nx, ny, nz)
      end
    end
  end

  def listed?(x, y, z)
    list = @chunk_torches[World.slot(x >> 4, z >> 4)]
    (0...list.size).step(3) { |k| return true if list[k] == x && list[k + 1] == y && list[k + 2] == z }
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

  # Lists the torches, the jack o'lanterns and the exposed lava below
  # height top.
  def find_torches(cx, cz, top)
    @chunk_torches[World.slot(cx, cz)].clear
    x = cx * CHUNK
    while x < cx * CHUNK + CHUNK
      z = cz * CHUNK
      while z < cz * CHUNK + CHUNK
        base = World.index(x, 0, z)
        top.times do |y|
          b = block(base + y)
          add_torch(x, y, z) if Block.torch?(b) || Block.jack_o_lantern?(b) || (b == Block::LAVA && exposed?(base + y))
        end
        z += 1
      end
      x += 1
    end
  end

  def update_height(x, z)
    base = World.index(x, 0, z)
    y = column_top(base)
    while y >= 0 && !Block.blocks_light(block(base + y))
      y -= 1
    end
    @height[(x & LMASK) * WZ + (z & LMASK)] = y + 1
  end

  # The y of the highest block that is not air in the column at index
  # base, or -1. Most of a column is air, so it skips 8 blocks of air at a
  # time where an Integer of the store holds only air.
  def column_top(base)
    y = WY - 1
    while y >= 0 && ((base + y) & 7) != 7 && block(base + y) == Block::AIR
      y -= 1
    end
    while y >= 7 && @blocks[(base + y) >> 3] == 0
      y -= 8
    end
    while y >= 0 && block(base + y) == Block::AIR
      y -= 1
    end
    y
  end

  # Fills the column at index base with air from y to the top, 8 blocks
  # at a time where it can.
  def clear_above(base, y)
    i = base + y
    top = base + WY
    while i < top && (i & 7) != 0
      put_block(i, Block::AIR)
      i += 1
    end
    while i + 8 <= top
      @blocks[i >> 3] = 0
      i += 8
    end
    while i < top
      put_block(i, Block::AIR)
      i += 1
    end
  end

  # Writes a generated block when it is inside chunk x0, z0.
  def put(x, y, z, block, x0, z0)
    return if x < x0 || z < z0 || x >= x0 + CHUNK || z >= z0 + CHUNK || y < 0 || y >= WY

    put_block(World.index(x, y, z), block)
  end

  # True when the generated block at x, y, z is air and inside chunk x0, z0.
  def air_in?(x, y, z, x0, z0)
    return false if x < x0 || z < z0 || x >= x0 + CHUNK || z >= z0 + CHUNK || y < 0 || y >= WY

    block(World.index(x, y, z)) == Block::AIR
  end
end
