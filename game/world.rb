# Chunk generation, block storage, and the store of changed chunks.
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
  # Cave noise grid of one chunk: a point every 4 blocks.
  GX = CHUNK / 4 + 1
  GY = WY / 4 + 1
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
  # Caves at this height and below fill with lava. Minecraft fills them
  # below y -54, 10 layers above the bottom of its world
  # (minecraft.wiki/w/Altitude).
  LAVA_LEVEL = 9
  # Ores copy the ore veins of Minecraft Java (minecraft.wiki/w/Ore_(feature)).
  # The world of Minecraft starts at y MC_BOTTOM, and the top water block
  # of its sea is at y MC_SEA (minecraft.wiki/w/Altitude). This world
  # starts at y 1, above the bedrock. So each layer from y 1 to the sea
  # stands for 2 layers of Minecraft and holds the ore of both (mc_y).
  # Above the sea, each layer stands for 1 layer.
  MC_BOTTOM = -64
  MC_SEA = 62
  # The average number of blocks in a vein of spawn size 4, 8, 9, 12 and
  # 17, in solid stone. The wiki gives only the largest numbers (5, 10,
  # 13, 23 and 37). It does not give the averages: they come from a run
  # of the vein algorithm of Minecraft.
  VEIN_4 = 2.0
  VEIN_8 = 5.7
  VEIN_9 = 6.8
  VEIN_12 = 11.6
  VEIN_17 = 22.2
  # The average diamond vein that starts in the world. Of each chunk's 7
  # veins of size 4, 4 of size 8 and 1/9 of size 12, half start below
  # MC_BOTTOM. The 2 veins of size 8 from y -64 to -4 all start in it.
  # minecraft.wiki/w/Diamond_Ore
  DIAMOND_VEIN = (3.5 * VEIN_4 + 2.0 * VEIN_8 + 0.5 / 9 * VEIN_12 + 2.0 * VEIN_8) / (3.5 + 2.0 + 0.5 / 9 + 2.0)
  # A cell of stone holds a clump of an ore at the odds of that ore at
  # the y of the block, out of 65536 (ore_odds). A coal cell is 4 x 2 x 4
  # blocks, and an iron, diamond or spinel cell is 2 x 2 x 2. Each block of a
  # clump is ore at the FILL odds, so a clump holds the average vein.
  COAL_CELL = 32
  # The coal rolls of one column of coal cells: one for each 2 layers.
  COAL_ROLLS = WY / 2
  ORE_CELL = 8
  COAL_FILL = (65536 * VEIN_17 / COAL_CELL).to_i
  IRON_FILL = (65536 * VEIN_9 / ORE_CELL).to_i
  DIAMOND_FILL = (65536 * DIAMOND_VEIN / ORE_CELL).to_i
  SPINEL_FILL = (65536 * VEIN_9 / ORE_CELL).to_i
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
  # Dirt and sand lie SOIL_DEPTH deep, and sand lies on sandstone
  # (minecraft.wiki/w/Sand). The wiki does not give the depth of the
  # sandstone.
  SOIL_DEPTH = 4
  SANDSTONE_DEPTH = 4
  # Dry grass per 65536 columns of desert sand. minecraft.wiki/w/Short_Dry_Grass
  # says only that it generates often in deserts, so the number is a guess.
  DESERT_DRY_GRASS = 1500
  SNOW_LINE = SEA + 110
  # The air gets colder by COOLING for each block above COLD_LINE, so
  # mountains get snowy biomes.
  COLD_LINE = SEA + 30
  COOLING = 0.004
  # The shortest trunk of each tree kind (Biome::OAK and so on), one
  # entry for each of Biome::TREE_KINDS.
  TRUNK = [4, 5, 5, 4]
  # The wood of each tree kind (Block::OAK_WOOD and so on). The game has no
  # acacia or jungle wood, so those trees have oak wood.
  WOOD = [Block::OAK_WOOD, Block::SPRUCE_WOOD, Block::OAK_WOOD, Block::OAK_WOOD]
  # How far leaves reach from the root of a tree: a giant jungle tree
  # grows a branch 5 blocks long, and the leaves at its end reach 3 more.
  TREE_REACH = 8

  attr_reader :blocks, :height, :chunk_torches, :slot_cx, :slot_cz, :store

  def initialize(seed) # rubocop:todo Metrics/MethodLength
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
    @col_h = Array.new(CHUNK * CHUNK, 0)
    @col_b = Array.new(CHUNK * CHUNK, 0)
    @cave_a = Array.new(GX * GY * GX, 0.0)
    @cave_b = Array.new(GX * GY * GX, 0.0)
    # 1 for each cell of the cave grid that can hold a cave (see cave_cell).
    @cave_cell = Array.new(GX * GY * GX, 0)
    # The edges along x of a cave grid cell, of the two fields (x_edges).
    @edges_a = Array.new(4, 0.0)
    @edges_c = Array.new(4, 0.0)
    @corner_a = Array.new(8, 0.0)
    @corner_b = Array.new(8, 0.0)
    @coal_odds = Array.new(WY, 0)
    @iron_odds = Array.new(WY, 0)
    @diamond_odds = Array.new(WY, 0)
    @spinel_odds = Array.new(WY, 0)
    @coal_rolls = Array.new(16 * COAL_ROLLS, 0)
    y = 0
    while y < WY
      @coal_odds[y] = World.ore_odds(World.ore_at(Block::COAL_ORE, y), COAL_CELL, VEIN_17)
      @iron_odds[y] = World.ore_odds(World.ore_at(Block::IRON, y), ORE_CELL, VEIN_9)
      @diamond_odds[y] = World.ore_odds(World.ore_at(Block::DIAMOND, y), ORE_CELL, DIAMOND_VEIN)
      @spinel_odds[y] = World.ore_odds(World.ore_at(Block::SPINEL_ORE, y), ORE_CELL, VEIN_9)
      y += 1
    end
    @noise = Noise.new(seed)
    @noise2 = Noise.new(seed * 31 + 7)
    @noise3 = Noise.new(seed * 17 + 3)
    @noise4 = Noise.new(seed * 43 + 11)
    # The warp of the last column (see warp), first that of column 0, 0.
    @warp_nx = SHIFT
    @warp_nz = SHIFT
    @wx = warp_x(SHIFT, SHIFT)
    @wz = warp_z(SHIFT, SHIFT)
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
  # Block i of a packed store: byte i & 7 of Integer i >> 3. The shift
  # keeps the sign, and the mask drops it.
  def block(i) = (@blocks[i >> 3] >> ((i & 7) << 3)) & 255

  # The bits that put_block keeps of an Integer of the store, for each byte.
  # Byte 7 holds the sign bit, and 255 << 56 is too large for an Integer.
  KEEP = [~255, ~(255 << 8), ~(255 << 16), ~(255 << 24), ~(255 << 32), ~(255 << 40), ~(255 << 48), (1 << 56) - 1]

  def put_block(i, b)
    j = i >> 3
    k = i & 7
    # An id from 128 goes into byte 7 as a negative number, so the shift
    # does not pass the sign bit.
    v = k == 7 ? ((b ^ 128) - 128) << 56 : b << (k << 3)
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
  # A unique Integer for a block anywhere in the world (chest keys).
  def self.key(x, y, z) = ((((x + KEY_OFF) << 26) | (z + KEY_OFF)) << 8) | y
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

  # Land well above the sea, from the noise alone.
  def land?(x, z) = surface_height(x, z) > SEA + 4

  # Ground above the beach with no tree or water on top.
  def dry_land?(x, z)
    h = height_at(x, z)
    b = get(x, h - 1, z)
    h > SEA + 2 && !Block.leaves?(b) && !Block.water?(b)
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

  # True when b is solid and its box (Block.box_hx and the others) in the
  # cell bx, by, bz overlaps the box of solid_in_box?.
  def block_in_box?(b, bx, by, bz, x, y, z, half, tall)
    return false unless Block.solid?(b)
    y0 = by + Block.box_dy(b)
    (bx + 0.5 + Block.box_dx(b) - x).abs < Block.box_hx(b) + half && (bz + 0.5 + Block.box_dz(b) - z).abs < Block.box_hz(b) + half &&
      y0 < y + tall && y0 + Block.box_top(b) > y
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
    (x0...x0 + CHUNK).each { |x| (z0...z0 + CHUNK).each { |z| update_height(x, z) } }
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
  end

  def warp_z(x, z) = z + @noise4.noise2(x / 160.0 + 70.0, z / 160.0).to_f * WARP

  # The height of the column's top block plus one, after Minecraft 1.18.
  # The continent noise picks ocean, coast, lowland or highland, and a
  # spline turns it into a base height. Inland, the landscape noise picks
  # mountain ranges with ridges, plateaus with flat tops, rolling hills or
  # flat lowland. Rivers cut valleys down to the sea where the river noise
  # is near zero.
  def surface_height(x, z) # rubocop:todo Metrics/MethodLength
    nx = x + SHIFT
    nz = z + SHIFT
    warp(nx, nz)
    wx = @wx
    wz = @wz
    continent = @noise.fbm2(wx / CONTINENT_SCALE, wz / CONTINENT_SCALE, 4)
    land = @noise4.fbm2(wx / LANDSCAPE_SCALE + 30.0, wz / LANDSCAPE_SCALE, 3)
    inland = World.smooth((continent + 0.1) / 0.2)
    mountains = World.smooth((MOUNTAINS - land) / LANDSCAPE_EDGE) * inland
    plateau = World.smooth((land - PLATEAU_LOW) / PLATEAU_EDGE) *
              World.smooth((PLATEAU_HIGH - land) / PLATEAU_EDGE) * inland
    flat = World.smooth((land - FLATLAND) / LANDSCAPE_EDGE)
    hills = @noise.fbm2(nx / 55.0 + 40.0, nz / 55.0, 4)
    hill_height = HILLS + (MOUNTAIN_HILLS - HILLS) * mountains + (PLATEAU_HILLS - HILLS) * plateau + (FLAT_HILLS - HILLS) * flat
    h = World.spline(CONTINENT, BASE, continent) + hills * hill_height
    h += ridges(wx, wz, land) * mountains if mountains > 0.0
    # A plateau lifts the land to a flat top.
    top = SEA + PLATEAU_RISE + hills * PLATEAU_HILLS
    h += (top - h) * plateau if top > h
    # Away from the coast, the island noise lifts domes out of the deep
    # ocean. Lower domes stay under the water as shoals.
    ocean = World.smooth((CONTINENT[2] - continent) / (CONTINENT[2] - CONTINENT[1]))
    if ocean > 0.0
      dome = SEA + (@noise2.fbm2(wx / ISLE_SCALE + 500.0, wz / ISLE_SCALE, 3) - ISLE) * ISLE_RISE + hills * ISLE_HILLS
      h += (dome - h) * ocean if dome > h
    end
    # A river cuts its full valley near the coast. Farther inland the
    # valley gets shallower, and it ends at RIVER_INLAND.
    fade = World.smooth((RIVER_INLAND - continent) / RIVER_FADE)
    if fade > 0.0 && h > RIVER_BED
      river = @noise3.fbm2(wx / RIVER_SCALE + 90.0, wz / RIVER_SCALE, 2).abs
      if river < RIVER_VALLEY
        bed = RIVER_BED + (h - RIVER_BED) * World.smooth(river / RIVER_VALLEY)
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

  # The y in Minecraft of layer y. Below the sea, layer y also stands for
  # the layer above that y in Minecraft.
  def self.mc_y(y)
    return y - SEA + MC_SEA if y >= SEA
    MC_BOTTOM + (y - 1) * 2
  end

  # The blocks of an ore in each chunk at layer y, in solid stone.
  def self.ore_at(ore, y)
    m = World.mc_y(y)
    return World.mc_ore(ore, m) if y >= SEA
    World.mc_ore(ore, m) + World.mc_ore(ore, m + 1)
  end

  # The blocks of an ore in each chunk of Minecraft at its layer m, in
  # solid stone: the veins that start at m, times the blocks of a vein.
  def self.mc_ore(ore, m)
    # 20 veins of size 17 in a triangle from y 0 to 192, and 30 spread
    # evenly from y 136 to 320. minecraft.wiki/w/Coal_Ore
    return VEIN_17 * (20 * World.peaked(m, 0, 192) + 30 * World.even(m, 136, 320)) if ore == Block::COAL_ORE
    # 90 veins of size 9 in a triangle from y 80 to 384, 10 in a triangle
    # from y -24 to 56, and 10 of size 4 spread evenly from y -64 to 72.
    # minecraft.wiki/w/Iron_Ore
    return VEIN_9 * (90 * World.peaked(m, 80, 384) + 10 * World.peaked(m, -24, 56)) + VEIN_4 * 10 * World.even(m, -64, 72) if ore == Block::IRON
    # Spinel copies gold ore: 4 veins of size 9 from y -64 to 32, most of
    # them near y -16, and half a vein of size 9 spread evenly from y -64
    # to -48. minecraft.wiki/w/Gold_Ore gives the veins as 0 to 13 blocks,
    # the largest of size 9. The wiki also says that half of these blocks
    # do not generate where they touch air. The game skips that rule. It
    # also skips the extra gold of the badlands, a biome that it does not
    # have.
    return VEIN_9 * (4 * World.peaked(m, -64, 32) + 0.5 * World.even(m, -64, -48)) if ore == Block::SPINEL_ORE
    # 7 veins of size 4, 4 of size 8 and 1/9 of size 12 in a triangle
    # that ends at y 16, and 2 of size 8 spread evenly from y -64 to -4.
    # minecraft.wiki/w/Diamond_Ore gives the range of the triangle as
    # -64 to 16 and says that the ore is more common lower down. The
    # wiki does not give the bottom of the triangle, -144 in the data of
    # the game, 80 layers below the bottom of the world.
    (7 * VEIN_4 + 4 * VEIN_8 + VEIN_12 / 9) * World.peaked(m, -144, 16) + 2 * VEIN_8 * World.even(m, -64, -4)
  end

  # The share of the veins that start at layer m, for veins in a triangle
  # from y low to high.
  def self.peaked(m, low, high)
    World.triangle(m, low.to_f, (low + high) / 2.0, high.to_f) * 2.0 / (high - low)
  end

  # The share of the veins that start at layer m, for veins spread evenly
  # from y low to high.
  def self.even(m, low, high)
    return 0.0 if m < low || m > high
    1.0 / (high - low + 1)
  end

  # The odds out of 65536 that a cell of `cell` blocks holds a clump, for
  # `blocks` of the ore in each layer of a chunk and clumps of `vein`
  # blocks.
  def self.ore_odds(blocks, cell, vein) = (blocks * 256 * cell / vein).round

  # 1 at peak, 0 at low and high and beyond, and a straight line between.
  def self.triangle(y, low, peak, high)
    return 0.0 if y <= low || y >= high
    y < peak ? (y - low) / (peak - low) : (high - y) / (high - peak)
  end

  # The height of the ridges, spurs and peaks of a mountain range at the
  # warped position wx, wz, where the landscape noise is land.
  def ridges(wx, wz, land)
    ridge = 1.0 - @noise2.noise2(wx / RIDGE_SCALE, wz / RIDGE_SCALE).abs * 1.6
    ridge = ridge < 0.0 ? 0.0 : ridge
    spur = 1.0 - @noise3.noise2(wx / SPUR_SCALE + 70.0, wz / SPUR_SCALE).abs * 1.6
    spur = spur < 0.0 ? 0.0 : spur
    peak = World.smooth((@noise.noise2(wx / PEAK_SCALE + 120.0, wz / PEAK_SCALE) + 0.1) / 0.5)
    core = World.smooth((MOUNTAINS - land) / RANGE_CORE)
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
  def beach?(top) = top <= BEACH_TOP
  # High peaks are bare stone at the top and below it.
  def bare_rock?(top) = top > ROCK_LINE

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
    b = Block::GRAVEL if top < GRAVEL_LINE && Noise.hash3(x / 3, 0, z / 3, 5) < 20000
    b = Block::STONE if bare_rock?(top)
    b = Block::SNOW if top > SNOW_LINE
    b
  end

  # Caves: two noise fields near zero at once trace long tunnels.
  def cave?(a, c, width) = a * a + c * c < width
  # False when the first field alone rules out a cave, so the second needs no sample.
  def cave_possible?(a, width) = a * a < width

  # The tunnel width at depth blocks below the top block of a column.
  def cave_width(depth)
    return 0.0 if depth <= CAVE_ROOF
    return CAVE_WIDTH if depth >= CAVE_ROOF + CAVE_FADE
    CAVE_WIDTH * (depth - CAVE_ROOF) / CAVE_FADE
  end

  # True in the patches where tunnels keep their width up to the surface.
  def entrance?(x, z) = @noise.noise2(x / ENTRANCE_SCALE + 200.0, z / ENTRANCE_SCALE) > ENTRANCE

  # The two cave noise fields at a point of the cave grid, which has one point
  # every 4 blocks. generate_chunk and carved? both sample it here.
  def cave_a(gx, gy, gz) = @noise2.noise3(gx * 4 / 40.0, gy * 4 / 22.0, gz * 4 / 40.0)
  def cave_b(gx, gy, gz) = @noise3.noise3(gx * 4 / 40.0 + 50.0, gy * 4 / 22.0, gz * 4 / 40.0)

  # The cave test for one block of an entrance patch, from the 8 grid points
  # around it. It gives the same numbers as the chunk grid in generate_chunk.
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
    cave?(trilinear(@corner_a, 0, 2, 2, tx, ty, tz), trilinear(@corner_b, 0, 2, 2, tx, ty, tz), CAVE_WIDTH)
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
    return -1 if !beach?(h - 1) && entrance?(x, z) && carved?(x, h - 1, z)
    h - 1
  end

  def generate_chunk(cx, cz) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    highest = 0
    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        h = surface_height(x0 + lx, z0 + lz)
        @col_h[lx * CHUNK + lz] = h
        @col_b[lx * CHUNK + lz] = biome(x0 + lx, z0 + lz, h)
        highest = h if h > highest
        lz += 1
      end
      lx += 1
    end

    # The rolls of the 4 x 4 columns of coal cells in the chunk, one for
    # each 2 layers. The 16 block columns of a cell column read them.
    i = 0
    while i < 16
      j = 0
      while j <= highest >> 1
        @coal_rolls[i * COAL_ROLLS + j] = Noise.hash3((x0 >> 2) + (i >> 2), j, (z0 >> 2) + (i & 3), 13)
        j += 1
      end
      i += 1
    end

    # Coarse 3D noise for caves, sampled every 4 blocks and interpolated.
    # Caves stay below the top block of a column, so the grid stops at the
    # layer above the highest top block.
    gx0 = x0 >> 2
    gz0 = z0 >> 2
    gy = (highest - 1) / 4 + 2
    gy = GY if gy > GY
    i = 0
    while i < GX
      j = 0
      while j < gy
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
    (GX - 1).times do |i|
      (gy - 1).times do |j|
        (GX - 1).times do |k|
          n = (i * GY + j) * GX + k
          @cave_cell[n] = cave_cell(n)
        end
      end
    end

    CHUNK.times do |lx|
      CHUNK.times do |lz|
        x = x0 + lx
        z = z0 + lz
        h = @col_h[lx * CHUNK + lz]
        biome = @col_b[lx * CHUNK + lz]
        top = h - 1
        surface = top_block(x, z, h, biome)
        entrance = entrance?(x, z)
        base = World.index(x, 0, z)
        # The column's place in the cave grid. The 4 layers of a grid cell
        # share its edges along x (x_edges), so they are read once a layer.
        fx = lx / 4.0
        fz = lz / 4.0
        ix = fx.to_i
        iz = fz.to_i
        a_layer = -1
        c_layer = -1
        # Two layers share the rolls for ore.
        roll_y = -1
        r = 0
        coal_r = 0
        coal_cells = ((lx >> 2) * 4 + (lz >> 2)) * COAL_ROLLS
        y = 0
        while y < h
          b = Block::STONE
          if y == 0
            b = Block::BEDROCK
          elsif y == top
            b = surface
          elsif y > top - SOIL_DEPTH
            b = surface == Block::SAND ? Block::SAND : Block::DIRT
            b = Block::STONE if bare_rock?(top)
          elsif y > top - SOIL_DEPTH - SANDSTONE_DEPTH && surface == Block::SAND
            b = Block::SANDSTONE
          end
          if y > 1 && (y < top - 2 || (!beach?(top) && y <= top))
            fy = y / 4.0
            iy = fy.to_i
            n = (ix * GY + iy) * GX + iz
            if @cave_cell[n] == 1
              width = entrance ? CAVE_WIDTH : cave_width(top - y)
              if iy != a_layer
                a_layer = iy
                x_edges(@cave_a, n, GY, GX, fx - ix, @edges_a)
              end
              a = yz_lerp(@edges_a, fy - iy, fz - iz)
              if cave_possible?(a, width)
                if iy != c_layer
                  c_layer = iy
                  x_edges(@cave_b, n, GY, GX, fx - ix, @edges_c)
                end
                c = yz_lerp(@edges_c, fy - iy, fz - iz)
                b = (y <= LAVA_LEVEL ? Block::LAVA : Block::AIR) if cave?(a, c, width)
              end
            end
          end
          if b == Block::STONE
            # A roll for the coal cell and a roll for the iron, diamond or
            # spinel cell pick the ore, and a roll for the block leaves gaps in
            # the clump. Spinel takes the top of the roll. Its range then
            # starts at the same roll in both layers of a cell, even where
            # the odds of iron and diamond change from layer to layer.
            if (y >> 1) != roll_y
              roll_y = y >> 1
              coal_r = @coal_rolls[coal_cells + roll_y]
              r = Noise.hash3(x >> 1, roll_y, z >> 1, 11)
            end
            iron = @iron_odds[y]
            if coal_r < @coal_odds[y]
              b = Block::COAL_ORE if Noise.hash3(x, y, z, 12) < COAL_FILL
            elsif r < iron
              b = Block::IRON if Noise.hash3(x, y, z, 14) < IRON_FILL
            elsif r < iron + @diamond_odds[y]
              b = Block::DIAMOND if Noise.hash3(x, y, z, 16) < DIAMOND_FILL
            elsif r >= 65536 - @spinel_odds[y]
              b = Block::SPINEL_ORE if Noise.hash3(x, y, z, 18) < SPINEL_FILL
            end
          end
          put_block(base + y, b)
          y += 1
        end
        while y <= SEA
          put_block(base + y, Block::WATER)
          y += 1
        end
        clear_above(base, y)
      end
    end
    decorate(cx, cz)
  end

  # 1 when the cell of the cave grid from point n can hold a cave, else 0.
  # Inside the cell, the first cave field mixes the values at its 8
  # corners. When all of them are too far from zero on one side, every
  # block of the cell is too.
  def cave_cell(n)
    low = 1.0
    high = -1.0
    2.times do |di|
      2.times do |dj|
        2.times do |dk|
          a = @cave_a[n + (di * GY + dj) * GX + dk]
          low = a if a < low
          high = a if a > high
        end
      end
    end
    cave_possible?(low, CAVE_WIDTH) || cave_possible?(high, CAVE_WIDTH) || (low < 0.0 && high > 0.0) ? 1 : 0
  end

  def trilinear(g, n, gy, gz, tx, ty, tz)
    x_edges(g, n, gy, gz, tx, @edges_a)
    yz_lerp(@edges_a, ty, tz)
  end

  # The first step of trilinear: the 4 edges along x of the cell of grid g
  # from point n, at tx, into e (y, z: 0 0, 1 0, 0 1, 1 1).
  def x_edges(g, n, gy, gz, tx, e)
    sx = gy * gz
    e[0] = g[n] + (g[n + sx] - g[n]) * tx
    e[1] = g[n + gz] + (g[n + sx + gz] - g[n + gz]) * tx
    e[2] = g[n + 1] + (g[n + sx + 1] - g[n + 1]) * tx
    e[3] = g[n + gz + 1] + (g[n + sx + gz + 1] - g[n + gz + 1]) * tx
  end

  # The rest of trilinear: the edges e lerped along y at ty, then along z at tz.
  def yz_lerp(e, ty, tz)
    c0 = e[0] + (e[1] - e[0]) * ty
    c1 = e[2] + (e[3] - e[2]) * ty
    c0 + (c1 - c0) * tz
  end

  # A chunk has a pumpkin patch 1 time in 32 (minecraft.wiki/w/Pumpkin).
  # The patch fills about a quarter of the grass PATCH_REACH blocks or
  # less from its center. The wiki does not give the size of a patch. The
  # center stays PATCH_REACH blocks from the chunk edges, so the patch
  # does not need the chunks next door.
  PATCH_ODDS = 65536 / 32
  PATCH_REACH = 3
  PATCH_FILL = 65536 / 4

  # Trees (also those that grow next door and reach in), then plants and cacti.
  def decorate(cx, cz) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    patch = Noise.hash3(cx, 0, cz, 40) < PATCH_ODDS
    span = CHUNK - PATCH_REACH * 2
    patch_x = x0 + PATCH_REACH + Noise.hash3(cx, 1, cz, 40) % span
    patch_z = z0 + PATCH_REACH + Noise.hash3(cx, 2, cz, 40) % span
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
    CHUNK.times do |lx|
      CHUNK.times do |lz|
        x = x0 + lx
        z = z0 + lz
        top = @col_h[lx * CHUNK + lz] - 1
        biome = @col_b[lx * CHUNK + lz]
        ground = block(World.index(x, top, z))
        if ground == Block::GRASS && block(World.index(x, top + 1, z)) == Block::AIR
          p = Noise.hash3(x, 2, z, 25)
          meadow = @noise3.noise2(x / 30.0, z / 30.0 + 11.0)
          if patch && (x - patch_x).abs <= PATCH_REACH && (z - patch_z).abs <= PATCH_REACH && Noise.hash3(x, 3, z, 40) < PATCH_FILL
            put(x, top + 1, z, Block::PUMPKIN, x0, z0)
          elsif p < Biome::GRASS[biome] + (meadow * 12000.0).to_i
            put(x, top + 1, z, Block::TALL_GRASS, x0, z0)
          elsif p >= 65536 - Biome::FLOWERS[biome] && meadow > -0.05
            put(x, top + 1, z, (x + z) % 3 == 0 ? Block::ROSE : Block::DANDELION, x0, z0)
          end
        elsif ground == Block::SAND && biome == Biome::DESERT && !beach?(top)
          r = Noise.hash3(x, 0, z, 21)
          if r < 350
            tall = 1 + Noise.hash3(x, 1, z, 22) % 3
            tall.times { |i| put(x, top + 1 + i, z, Block::CACTUS, x0, z0) }
          elsif r < 350 + DESERT_DRY_GRASS
            put(x, top + 1, z, Block::DRY_GRASS, x0, z0)
          end
        end
      end
    end
    if Noise.hash3(cx, 3, cz, 40) < WELL_ODDS
      span = CHUNK - WELL_REACH * 2
      wx = x0 + WELL_REACH + Noise.hash3(cx, 4, cz, 40) % span
      wz = z0 + WELL_REACH + Noise.hash3(cx, 5, cz, 40) % span
      top = well_top(wx, wz)
      well(wx, top, wz, x0, z0) if top >= 0
    end
  end

  # A desert well in about 1 of 1000 chunks (minecraft.wiki/w/Desert_Well).
  # Its center stays WELL_REACH blocks from the chunk edges, so the well
  # does not need the chunks next door.
  WELL_ODDS = 65536 / 1000
  WELL_REACH = 2

  # The y of the top block at the center of a well at x, z, or -1. Each
  # column under the well is desert sand, as high as the center or 1
  # higher, so no part of the well hangs over air.
  def well_top(x, z)
    h = surface_height(x, z)
    (-WELL_REACH..WELL_REACH).each do |dx|
      (-WELL_REACH..WELL_REACH).each do |dz|
        ch = surface_height(x + dx, z + dz)
        return -1 if ch < h || ch > h + 1 || beach?(ch - 1)
        biome = biome(x + dx, z + dz, ch)
        return -1 if biome != Biome::DESERT || top_block(x + dx, z + dz, ch, biome) != Block::SAND
        return -1 if entrance?(x + dx, z + dz) && carved?(x + dx, ch - 1, z + dz)
      end
    end
    h - 1
  end

  # Puts a desert well on the top block top at x, z, as in Minecraft
  # (minecraft.wiki/w/Desert_Well/Structure). The game has no slabs, so
  # sandstone takes their place.
  def well(x, top, z, x0, z0)
    (-2..4).each do |dy|
      (-WELL_REACH..WELL_REACH).each do |dx|
        (-WELL_REACH..WELL_REACH).each { |dz| put(x + dx, top + dy, z + dz, well_block(dx, dy, dz), x0, z0) }
      end
    end
  end

  # The block of a well at dx, dz from its center and dy from its top
  # block. Two layers of sandstone go under a cross of sand, the cross
  # holds water at the ground, and a rim 1 high goes around it. Pillars on
  # the 4 corners of the 3 x 3 around the cross hold a roof of 3 x 3.
  # Under the center, 2 blocks are suspicious sand in Minecraft. The game
  # has no suspicious sand, so plain sand takes its place.
  def well_block(dx, dy, dz)
    cross = dx.abs + dz.abs <= 1
    if dy <= 1
      return dx == 0 && dz == 0 ? Block::SAND : Block::SANDSTONE if dy == -2
      return Block::SANDSTONE unless cross
      return Block::SAND if dy == -1
      return dy == 0 ? Block::WATER : Block::AIR
    end
    return dx.abs <= 1 && dz.abs <= 1 ? Block::SANDSTONE : Block::AIR if dy == 4
    dx.abs == 1 && dz.abs == 1 ? Block::SANDSTONE : Block::AIR
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
      (-radius..radius).each do |dx|
        (-radius..radius).each do |dz|
          corner = dx.abs == radius && dz.abs == radius
          skip = corner && (ly == top + 1 || Noise.hash3(x + dx, ly, z + dz, 24) < 32000)
          put(x + dx, ly, z + dz, @leaves, x0, z0) if !skip && air_in?(x + dx, ly, z + dz, x0, z0)
        end
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
    3.times do |ly|
      radius = 3 - ly
      (-radius..radius).each do |dx|
        (-radius..radius).each do |dz|
          skip = dx.abs == radius && dz.abs == radius && Noise.hash3(x + dx, y + ly, z + dz, 24) < 32768
          put(x + dx, y + ly, z + dz, @leaves, x0, z0) if !skip && air_in?(x + dx, y + ly, z + dz, x0, z0)
        end
      end
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
    4.times do |a|
      cx = x + a % 2
      cz = z + a / 2
      ground = a == 0 ? y : [y, surface_height(cx, cz)].min
      logs(cx, ground, cz, y + tall - ground, x0, z0)
    end
    jungle_crown(x, y + tall, z, 3, 3, true, x0, z0)
    i = tall - 2 - r / 60 % 4
    while i > tall / 2
      b = Noise.hash3(x, y + i, z, 29)
      angle = b / 65536.0 * 2.0 * Math::PI
      bx = 0
      bz = 0
      5.times do |l|
        bx = (1.5 + Math.cos(angle) * l).to_i
        bz = (1.5 + Math.sin(angle) * l).to_i
        put(x + bx, y + i - 3 + l / 2, z + bz, @log, x0, z0)
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
    layers.times do |i|
      reach = r + i
      (-reach..reach + w).each do |dx|
        (-reach..reach + w).each do |dz|
          ax = dx.abs
          az = dz.abs
          ax = (dx - 1).abs if wide && dx > 0
          az = (dz - 1).abs if wide && dz > 0
          if ax + az < 7 && ax * ax + az * az <= reach * reach && air_in?(x + dx, y - i, z + dz, x0, z0)
            put(x + dx, y - i, z + dz, @leaves, x0, z0)
          end
        end
      end
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
    (top + above).downto(low) do |ly|
      leaf_row(x, ly, z, reach, x0, z0)
      if reach >= step
        reach = narrow
        narrow = 1
        step = [step + 1, widest].min
      else
        reach += 1
      end
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
    layers.times { |i| leaf_row(x, top + 1 - i, z, i == 0 || i == layers - 1 ? 0 : 1, x0, z0) }
  end

  # A trunk of tall logs up from x, y, z, on dirt.
  def logs(x, y, z, tall, x0, z0)
    tall.times { |i| put(x, y + i, z, @log, x0, z0) }
    put(x, y - 1, z, Block::DIRT, x0, z0)
  end

  # A square layer of leaves around x, y, z that reaches out r blocks,
  # without its corners.
  def leaf_row(x, y, z, r, x0, z0)
    (-r..r).each do |dx|
      (-r..r).each do |dz|
        if (dx.abs < r || dz.abs < r || r == 0) && air_in?(x + dx, y, z + dz, x0, z0)
          put(x + dx, y, z + dz, @leaves, x0, z0)
        end
      end
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
    (tall - 5).downto(0) do |n|
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
    (0..steps).each do |i|
      t = steps == 0 ? 0.0 : i.to_f / steps
      put(sx + (0.5 + t * dx).floor, sy + (0.5 + t * dy).floor, sz + (0.5 + t * dz).floor, @log, x0, z0)
    end
  end

  # A ball of leaves 5 blocks tall on the end of a large oak branch at x,
  # y, z. A layer keeps each block whose far corner is within r of the
  # branch end: a plus at the bottom and at the top (r = 2), and 5 x 5
  # without the corners between them (r = 3).
  def oak_ball(x, y, z, x0, z0)
    (0..4).each do |ly|
      r = ly == 0 || ly == 4 ? 2 : 3
      (-r..r).each do |dx|
        (-r..r).each do |dz|
          ax = dx.abs + 0.5
          az = dz.abs + 0.5
          if ax * ax + az * az <= r * r && air_in?(x + dx, y + ly, z + dz, x0, z0)
            put(x + dx, y + ly, z + dz, @leaves, x0, z0)
          end
        end
      end
    end
  end

  # An acacia on the ground below x, y, z. Near its top, the trunk leans
  # 1 to 3 blocks to one side. Most acacias also fork a shorter branch
  # that grows out on a diagonal, with a smaller crown.
  # minecraft.wiki/w/Tree_definition (forking_trunk_placer) gives this
  # shape. The wiki does not confirm the heights and the odds: they copy
  # the acacia feature in the game code.
  def acacia(x, y, z, x0, z0) # rubocop:todo Metrics/MethodLength
    r = Noise.hash3(x, y, z, 23)
    tall = TRUNK[Biome::ACACIA] + r % 3 + r / 3 % 3
    return if y + tall + 2 >= WY
    r /= 9
    dir = r % 4
    bend = tall - 1 - r / 4 % 4
    lean = 3 - r / 16 % 3
    tx = x
    tz = z
    tall.times do |i|
      if i >= bend && lean > 0
        tx += Block::DIR_DX[dir]
        tz += Block::DIR_DZ[dir]
        lean -= 1
      end
      put(tx, y + i, tz, @log, x0, z0)
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
    (-reach..reach).each do |dx|
      (-reach..reach).each do |dz|
        ax = dx.abs
        az = dz.abs
        if ((ax <= 1 && az <= 1) || ax + az < reach) && air_in?(x + dx, y + 1, z + dz, x0, z0)
          put(x + dx, y + 1, z + dz, @leaves, x0, z0)
        end
      end
    end
  end
end
