# Builds chunk meshes: one record (two Integers) per visible block face.
# The vertex shader expands each record into two triangles.
class Mesher
  # Face order: +x, -x, +y, -y, +z, -z. Corners match CORNER in the shader.
  NORMALS = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]]
  CORNERS = [
    [[1, 0, 1], [1, 0, 0], [1, 1, 0], [1, 1, 1]], [[0, 0, 0], [0, 0, 1], [0, 1, 1], [0, 1, 0]],
    [[0, 1, 1], [1, 1, 1], [1, 1, 0], [0, 1, 0]], [[0, 0, 0], [1, 0, 0], [1, 0, 1], [0, 0, 1]],
    [[0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]], [[1, 0, 0], [0, 0, 0], [0, 1, 0], [1, 1, 0]]
  ]

  # The fields of a face record. Each field starts at bit NAME_AT of its
  # word and is NAME_BITS wide, and it starts where the field before it
  # ends. The shaders read the fields through Mesher.shader_defines, so
  # these constants are the only copy of the layout.
  # The first word: the storage column x and z, y, and the face (see
  # NORMALS and CORNER in the shader).
  X_AT = 0
  X_BITS = 10
  Y_AT = X_AT + X_BITS
  Y_BITS = 8
  Z_AT = Y_AT + Y_BITS
  Z_BITS = X_BITS
  FACE_AT = Z_AT + Z_BITS
  FACE_BITS = 4
  # The second word: the texture, the AO of the 4 corners (2 bits each),
  # the flip of the diagonal, the sky bit, the torch light, the scroll of
  # the texture (Tex.scroll), the facing and the shape of a block
  # (Block::SHAPE), and the tint (Tex.tint). A wall torch has the shape
  # TORCH_SHAPE and the facing of the torch. Only a fluid face scrolls, and
  # it has no AO, flip, facing, shape or tint: those bits hold the heights
  # of its corners (Mesher.fluid_w1).
  TEX_AT = 0
  TEX_BITS = 8
  AO_AT = TEX_AT + TEX_BITS
  AO_BITS = 8
  FLIP_AT = AO_AT + AO_BITS
  FLIP_BITS = 1
  SKY_AT = FLIP_AT + FLIP_BITS
  SKY_BITS = 1
  LIGHT_AT = SKY_AT + SKY_BITS
  LIGHT_BITS = 4
  SCROLL_AT = LIGHT_AT + LIGHT_BITS
  SCROLL_BITS = 2
  FACING_AT = SCROLL_AT + SCROLL_BITS
  FACING_BITS = 2
  SHAPE_AT = FACING_AT + FACING_BITS
  SHAPE_BITS = 3
  TINT_AT = SHAPE_AT + SHAPE_BITS
  TINT_BITS = 2
  # The 16 bits of the corner heights of a fluid face: the low ones where
  # other faces hold the AO and the flip, the high ones where they hold the
  # facing, the shape and the tint.
  HEIGHTS_LOW_AT = AO_AT
  HEIGHTS_LOW_BITS = AO_BITS + FLIP_BITS
  HEIGHTS_HIGH_AT = FACING_AT
  HEIGHTS_HIGH_BITS = 16 - HEIGHTS_LOW_BITS
  # Blocks have shapes from 0 to 5 (Block::SHAPE).
  TORCH_SHAPE = 7
  # Records hold columns of a ring as wide as the x field. The shaders wrap
  # at the same width (COLUMNS in gfx.rb).
  COLUMNS = 1 << X_BITS
  COLUMN_MASK = COLUMNS - 1

  # Light is TORCH_LIGHT at a torch, LIGHT_MAX at lava or a jack o'lantern,
  # and one less for each step, so it reaches LIGHT_MAX blocks at most.
  # minecraft.wiki/w/Light. The chunk shader shows TORCH_LIGHT and more at
  # full strength.
  TORCH_LIGHT = 14
  LIGHT_MAX = 15
  # The column masks of build hold BITS cells in each Integer, so the
  # shifts of cells_to_mesh stay far from the sign bit.
  BITS = 32
  WORDS = (WY + BITS - 1) / BITS
  WORD_MASK = (1 << BITS) - 1

  # The light flood covers the chunk and a margin that a light can cross.
  MARGIN = LIGHT_MAX + 1
  LW = CHUNK + MARGIN * 2

  # The first word of a face record.
  def self.pack(x, y, z, f) = (x << X_AT) | (y << Y_AT) | (z << Z_AT) | (f << FACE_AT)
  # The tint field of the second word. The shader multiplies the face by
  # the color of that kind in the tint map.
  def self.tint_w1(tex) = Tex.tint(tex) << TINT_AT
  def self.face_x(w0) = Mesher.field(w0, X_AT, X_BITS)
  def self.face_y(w0) = Mesher.field(w0, Y_AT, Y_BITS)
  def self.face_z(w0) = Mesher.field(w0, Z_AT, Z_BITS)
  def self.face_dir(w0) = Mesher.field(w0, FACE_AT, FACE_BITS)
  def self.face_light(w1) = Mesher.field(w1, LIGHT_AT, LIGHT_BITS)
  def self.face_tint(w1) = Mesher.field(w1, TINT_AT, TINT_BITS)
  def self.field(w, at, bits) = (w >> at) & ((1 << bits) - 1)

  # The fields of a face record as #defines for the shaders: NAME_AT and
  # NAME_MASK for each, and TORCH_SHAPE.
  def self.shader_defines
    "#define TORCH_SHAPE #{TORCH_SHAPE}u\n" +
      Mesher.define_field("X", X_AT, X_BITS) + Mesher.define_field("Y", Y_AT, Y_BITS) + Mesher.define_field("Z", Z_AT, Z_BITS) +
      Mesher.define_field("FACE", FACE_AT, FACE_BITS) + Mesher.define_field("TEX", TEX_AT, TEX_BITS) + Mesher.define_field("AO", AO_AT, AO_BITS) +
      Mesher.define_field("FLIP", FLIP_AT, FLIP_BITS) + Mesher.define_field("SKY", SKY_AT, SKY_BITS) +
      Mesher.define_field("LIGHT", LIGHT_AT, LIGHT_BITS) +
      Mesher.define_field("SCROLL", SCROLL_AT, SCROLL_BITS) + Mesher.define_field("FACING", FACING_AT, FACING_BITS) +
      Mesher.define_field("SHAPE", SHAPE_AT, SHAPE_BITS) + Mesher.define_field("TINT", TINT_AT, TINT_BITS) +
      Mesher.define_field("HEIGHTS_LOW", HEIGHTS_LOW_AT, HEIGHTS_LOW_BITS) +
      Mesher.define_field("HEIGHTS_HIGH", HEIGHTS_HIGH_AT, HEIGHTS_HIGH_BITS) + "#define HEIGHTS_LOW_BITS #{HEIGHTS_LOW_BITS}u\n"
  end

  def self.define_field(name, at, bits) = "#define #{name}_AT #{at}u\n#define #{name}_MASK #{(1 << bits) - 1}u\n"

  attr_reader :opaque, :water, :offsets, :water_offsets

  def initialize(world)
    @world = world
    @opaque = []
    @water = []
    @lists = Array.new(7) { Array.new(0, 0) }
    @offsets = Array.new(8, 0)
    @light = Array.new(LW * LW * WY, 0)
    @queue = Array.new(0, 0)
    @blocks = world.blocks
    @flood_x = 0
    @flood_z = 0
    # Empty literals infer as untyped in Spinel, so these say Integer.
    @tx = Array.new(0, 0)
    @ty = Array.new(0, 0)
    @tz = Array.new(0, 0)
    @water_offsets = [0, 0, 0, 0, 0, 0, 0, 0]
    @delta = Array.new(6, 0)
    # Flood steps: light cell offset and block offsets, in face order.
    @step_n = [LW * WY, -LW * WY, WY, -WY, 1, -1]
    @step_x = [1, -1, 0, 0, 0, 0]
    @step_y = [0, 0, 0, 0, 1, -1]
    @step_z = [0, 0, 1, -1, 0, 0]
    # 1 when block b fills its cell, so the faces next to it do not show.
    # Lava does not: its surface sinks (fluid_corners).
    @cover = Array.new(Block::COUNT, 0)
    # 1 when block b shows faces even with covers on all 6 sides: a plant,
    # or a fluid, whose top shows under a block.
    @always = Array.new(Block::COUNT, 0)
    b = 0
    while b < Block::COUNT
      @cover[b] = Block.lava?(b) ? 0 : Block::OPAQUE[b]
      @always[b] = Block.plant?(b) || Mesher.fluid(b) > 0 ? 1 : 0
      b += 1
    end
    # Masks of the columns of a chunk and of the ring around it, WORDS
    # Integers for each column (fill_masks).
    @cover_bits = Array.new((CHUNK + 2) * (CHUNK + 2) * WORDS, 0)
    @block_bits = Array.new((CHUNK + 2) * (CHUNK + 2) * WORDS, 0)
    @always_bits = Array.new((CHUNK + 2) * (CHUNK + 2) * WORDS, 0)
    @ao = Array.new(72, 0)
    @nx = Array.new(6, 0)
    @nz = Array.new(6, 0)
    f = 0
    while f < 6
      n = NORMALS[f]
      @nx[f] = n[0]
      @nz[f] = n[2]
      @delta[f] = offset(n[0], n[1], n[2])
      c = 0
      while c < 4
        corner = CORNERS[f][c]
        # The two tangent axes point toward the corner's side of the face.
        t1 = [0, 0, 0]
        t2 = [0, 0, 0]
        found = 0
        axis = 0
        while axis < 3
          if n[axis] == 0
            sign = corner[axis] == 1 ? 1 : -1
            if found == 0
              t1[axis] = sign
            else
              t2[axis] = sign
            end
            found += 1
          end
          axis += 1
        end
        base = f * 12 + c * 3
        @ao[base] = offset(n[0] + t1[0], n[1] + t1[1], n[2] + t1[2])
        @ao[base + 1] = offset(n[0] + t2[0], n[1] + t2[1], n[2] + t2[2])
        @ao[base + 2] = offset(n[0] + t1[0] + t2[0], n[1] + t1[1] + t2[1], n[2] + t1[2] + t2[2])
        c += 1
      end
      f += 1
    end
  end

  def offset(dx, dy, dz) = (dx * PZ + dz) * PY + dy

  # The block in cell i of the world store: byte i & 7 of Integer i >> 3.
  # World#block reads the same, but its callers make its i a nullable
  # Integer, and the mesher calls this for each cell.
  def cell(i) = (@blocks[i >> 3] >> ((i & 7) << 3)) & 255

  # The fluid kind of block b: 1 water, 2 lava, 0 not a fluid.
  def self.fluid(b) = Block::WATER_LEVEL[b] > 0 ? 1 : (Block.lava?(b) ? 2 : 0)

  # The second-word bits of the corner heights h of a fluid face
  # (fluid_corners), in HEIGHTS_LOW and HEIGHTS_HIGH.
  def self.fluid_w1(h) = ((h & ((1 << HEIGHTS_LOW_BITS) - 1)) << HEIGHTS_LOW_AT) | ((h >> HEIGHTS_LOW_BITS) << HEIGHTS_HIGH_AT)

  # The height of the surface of fluid kind k in the cell of block b, with
  # block over above it, as the fluid renderer of Minecraft reads it: 1
  # under the same fluid, else the level in ninths (lava drops 2 ninths
  # each step, as it spreads 3 blocks); 0 in a cell that the fluid could
  # flow into, and -1 in a solid block, which the average skips.
  def fluid_height(k, b, over)
    if Mesher.fluid(b) == k
      return 1.0 if Mesher.fluid(over) == k
      return k == 1 ? Block::WATER_LEVEL[b] / 9.0 : Block.lava_level(b) * 2 / 9.0
    end
    Block.solid?(b) ? -1.0 : 0.0
  end

  def cell_fluid_height(k, i)
    fluid_height(k, cell(i), cell(i + 1))
  end

  # A height of 0.8 or more counts 10 times in a corner, so the surface
  # stays high next to a source.
  def fluid_weight(h) = h >= 0.8 ? 10.0 : (h >= 0.0 ? 1.0 : 0.0)

  # The height of a top corner: the weighted average of the heights of the
  # cell (h), the two cells beside the corner (ha, hb) and the cell across
  # the corner (hd). The cell across counts only when a cell beside holds
  # fluid. A cell beside under the same fluid lifts the corner to the top.
  def corner_height(h, ha, hb, hd)
    return 1.0 if ha >= 1.0 || hb >= 1.0
    hd = -1.0 unless ha > 0.0 || hb > 0.0
    return 1.0 if hd >= 1.0
    sum = h * fluid_weight(h) + ha * fluid_weight(ha) + hb * fluid_weight(hb) + hd * fluid_weight(hd)
    sum / (fluid_weight(h) + fluid_weight(ha) + fluid_weight(hb) + fluid_weight(hd))
  end

  # The heights of the 4 top corners of fluid cell i of kind k, in
  # fifteenths, 4 bits each: corner (x, z) at bit 4 * (x + 2 z). Two cells
  # that share a corner give it the same height, so the surface has no
  # gaps. Each corner is at least 1, above the floor of the cell.
  def fluid_corners(i, k)
    h = cell_fluid_height(k, i)
    return 0xFFFF if h >= 1.0
    q = 0
    cz = 0
    while cz < 2
      cx = 0
      while cx < 2
        sx = @delta[cx == 1 ? 0 : 1]
        sz = @delta[cz == 1 ? 4 : 5]
        top = corner_height(h, cell_fluid_height(k, i + sx), cell_fluid_height(k, i + sz), cell_fluid_height(k, i + sx + sz))
        v = (top * 15.0 + 0.5).to_i
        v = 1 if v < 1
        q |= v << (4 * (cx + 2 * cz))
        cx += 1
      end
      cz += 1
    end
    q
  end

  # Meshes world chunk (cx, cz). It and the 8 chunks around it must be loaded.
  def build(cx, cz)
    @opaque.clear
    @water.clear
    @lists.each { |l| l.clear }
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    @tx.clear
    @ty.clear
    @tz.clear
    # Lights in this chunk and the 8 around it can reach it.
    ncx = cx - 1
    while ncx <= cx + 1
      ncz = cz - 1
      while ncz <= cz + 1
        torches = @world.torches_of(ncx, ncz)
        k = 0
        while k < torches.size
          tx = torches[k]
          tz = torches[k + 2]
          if tx > x0 - MARGIN && tx < x0 + CHUNK + LIGHT_MAX && tz > z0 - MARGIN && tz < z0 + CHUNK + LIGHT_MAX
            @tx << tx
            @ty << torches[k + 1]
            @tz << tz
          end
          k += 3
        end
        ncz += 1
      end
      ncx += 1
    end
    lit = !@tx.empty?
    if lit
      @flood_x = x0 - MARGIN
      @flood_z = z0 - MARGIN
      flood(x0, z0)
    end
    # Masks of each column of the chunk and of the ring around it. They
    # show which cells can have a face (cells_to_mesh), so the walk skips
    # the cells with covers on all sides.
    row = CHUNK + 2
    fx = 0
    while fx < row
      fz = 0
      while fz < row
        fill_masks((fx * row + fz) * WORDS, World.index(x0 + fx - 1, 0, z0 + fz - 1))
        fz += 1
      end
      fx += 1
    end
    x = x0
    while x < x0 + CHUNK
      z = z0
      while z < z0 + CHUNK
        base = World.index(x, 0, z)
        at = ((x - x0 + 1) * row + z - z0 + 1) * WORDS
        w = 0
        while w < WORDS
          # Up the column, one cell for each bit, lowest first.
          todo = cells_to_mesh(at, w, row * WORDS)
          while todo != 0
            low = todo & -todo
            todo ^= low
            y = w * BITS + low.bit_length - 1
            mesh_cell(x, y, z, base + y, lit)
          end
          w += 1
        end
        z += 1
      end
      x += 1
    end
    finish
  end

  # Fills the masks of the column at index base into the WORDS Integers
  # from at: bit y of @cover_bits when its block covers its cell, of
  # @block_bits when it is not air, and of @always_bits when it always
  # shows (@always).
  def fill_masks(at, base)
    top = @world.column_top(base)
    w = 0
    while w < WORDS
      covers = 0
      blocks = 0
      always = 0
      y = w * BITS
      last = y + BITS - 1
      last = top if top < last
      bit = 1
      while y <= last
        b = cell(base + y)
        covers |= bit if @cover[b] == 1
        blocks |= bit if b != Block::AIR
        always |= bit if @always[b] == 1
        bit <<= 1
        y += 1
      end
      @cover_bits[at + w] = covers
      @block_bits[at + w] = blocks
      @always_bits[at + w] = always
      w += 1
    end
  end

  # The bits of word w of the column masks at `at` whose cells can show a
  # face: blocks that are not air, with no cover on a side, or that always
  # show. side is the step from a column to the next one along x.
  def cells_to_mesh(at, w, side)
    c = at + w
    covers = @cover_bits[c]
    # Bit y of up says whether the cell above y covers, of down the one below.
    up = covers >> 1
    up |= (@cover_bits[c + 1] & 1) << (BITS - 1) if w + 1 < WORDS
    down = (covers << 1) & WORD_MASK
    down |= @cover_bits[c - 1] >> (BITS - 1) if w > 0
    shut = up & down & @cover_bits[c - side] & @cover_bits[c + side] & @cover_bits[c - WORDS] & @cover_bits[c + WORDS]
    @block_bits[c] & (~shut | @always_bits[c])
  end

  # The faces of the block in cell i, at x, y, z (see build). lit is true
  # when torch light reaches the chunk.
  def mesh_cell(x, y, z, i, lit)
    # Vertices hold the storage column; the shader finds the world one.
    lx = x & LMASK
    lz = z & LMASK
    id = cell(i)
    if Block.plant?(id)
      sky = y >= @world.height[lx * WZ + lz] ? 1 : 0
      w1 = Block::TOP[id] | (255 << AO_AT) | (sky << SKY_AT) | Mesher.tint_w1(Block::TOP[id])
      w1 |= torch_light(x, y, z) << LIGHT_AT if lit
      w1 |= (Block::FACING[id] << FACING_AT) | (TORCH_SHAPE << SHAPE_AT) if Block.wall_torch?(id)
      plants = @lists[6]
      f = 6
      while f < 10
        plants << Mesher.pack(lx, y, lz, f)
        plants << w1
        f += 1
      end
      return
    end
    kind = Mesher.fluid(id)
    corners = kind > 0 ? fluid_corners(i, kind) : 0
    front = Block::FACING[id] >= 0 ? Block::DIR_FACE[Block::FACING[id]] : -1
    # A block with a shape is smaller than its cell, so all its faces show.
    shape = Block::SHAPE[id]
    f = 0
    while f < 6
      nb = cell(i + @delta[f])
      visible = if kind > 0
        # A fluid shows no face to the same fluid. Its top shows
        # under a block unless the surface is at the top of the cell.
        Mesher.fluid(nb) != kind && (@cover[nb] == 0 || (f == 2 && corners != 0xFFFF))
      else
        # Lava under lava fills its cell.
        @cover[nb] == 0 && !(nb == id && id == Block::GLASS) && !(Block.lava?(nb) && Block.lava?(cell(i + @delta[f] + 1)))
      end
      visible = true if shape > 0
      visible = false if f == 3 && y == 0
      if visible
        tex = f == 2 ? Block::TOP[id] : (f == 3 ? Block::BOTTOM[id] : (f == front ? Block::FRONT[id] : Block::SIDE[id]))
        ny = y + (f == 2 ? 1 : (f == 3 ? -1 : 0))
        sx = x + @nx[f]
        sz = z + @nz[f]
        sky = ny >= @world.height[(sx & LMASK) * WZ + (sz & LMASK)] ? 1 : 0
        w0 = Mesher.pack(lx, y, lz, f)
        if kind > 0
          # A fluid face has no AO: it holds the heights of its corners.
          w1 = tex | Mesher.fluid_w1(corners) | (sky << SKY_AT) | (Tex.scroll(tex) << SCROLL_AT)
          w1 |= torch_light(sx, ny, sz) << LIGHT_AT if lit
          if kind == 1
            @water << w0
            @water << w1
          else
            w1 = (w1 & ~(((1 << LIGHT_BITS) - 1) << LIGHT_AT)) | (LIGHT_MAX << LIGHT_AT)
            list = @lists[f]
            list << w0
            list << w1
          end
        else
          a = f * 12
          ao0 = ao_value(Block::OCCLUDES[cell(i + @ao[a])], Block::OCCLUDES[cell(i + @ao[a + 1])], Block::OCCLUDES[cell(i + @ao[a + 2])])
          ao1 = ao_value(Block::OCCLUDES[cell(i + @ao[a + 3])], Block::OCCLUDES[cell(i + @ao[a + 4])], Block::OCCLUDES[cell(i + @ao[a + 5])])
          ao2 = ao_value(Block::OCCLUDES[cell(i + @ao[a + 6])], Block::OCCLUDES[cell(i + @ao[a + 7])], Block::OCCLUDES[cell(i + @ao[a + 8])])
          ao3 = ao_value(Block::OCCLUDES[cell(i + @ao[a + 9])], Block::OCCLUDES[cell(i + @ao[a + 10])], Block::OCCLUDES[cell(i + @ao[a + 11])])
          flip = (ao0 - ao2).abs > (ao1 - ao3).abs ? 1 : 0
          w1 = tex | (ao0 << AO_AT) | (ao1 << (AO_AT + 2)) | (ao2 << (AO_AT + 4)) | (ao3 << (AO_AT + 6)) | (flip << FLIP_AT) | (sky << SKY_AT) |
               Mesher.tint_w1(tex)
          w1 |= torch_light(sx, ny, sz) << LIGHT_AT if lit
          # A jack o'lantern glows on each face, as lava does.
          w1 = (w1 & ~(((1 << LIGHT_BITS) - 1) << LIGHT_AT)) | (LIGHT_MAX << LIGHT_AT) if Block.jack_o_lantern?(id)
          # A block with a shape has no AO. A shape without a facing
          # (a cactus) draws as if it faces +x.
          w1 |= (255 << AO_AT) | ((Block::FACING[id] < 0 ? 0 : Block::FACING[id]) << FACING_AT) | (shape << SHAPE_AT) if shape > 0
          list = @lists[f]
          list << w0
          list << w1
        end
      end
      f += 1
    end
  end

  # Joins the per-direction lists; offsets are in faces.
  def finish
    f = 0
    while f < 7
      @offsets[f] = @opaque.size / 2
      @opaque.concat(@lists[f])
      f += 1
    end
    @offsets[7] = @opaque.size / 2
    i = 1
    while i < 8
      @water_offsets[i] = @water.size / 2
      i += 1
    end
  end

  # Spreads the light of torches, lava and jack o'lanterns through cells
  # that are not opaque, one less per step, so walls stop it. Covers the
  # chunk plus a margin.
  def flood(x0, z0)
    # Only the cells in the last queue have light, so clear just those.
    k = 0
    while k < @queue.size
      @light[@queue[k]] = 0
      k += 1
    end
    @queue.clear
    bx = x0 - MARGIN
    bz = z0 - MARGIN
    k = 0
    while k < @tx.size
      lx = @tx[k] - bx
      lz = @tz[k] - bz
      if lx >= 0 && lz >= 0 && lx < LW && lz < LW
        n = (lx * LW + lz) * WY + @ty[k]
        @light[n] = Block.torch?(@world.get(@tx[k], @ty[k], @tz[k])) ? TORCH_LIGHT : LIGHT_MAX
        @queue << n
      end
      k += 1
    end
    opaque = Block::OPAQUE
    head = 0
    while head < @queue.size
      # to_i: the queue feeds itself, and without it Spinel infers its
      # elements as untyped (an inference transient).
      n = @queue[head].to_i
      head += 1
      l = @light[n] - 1
      next if l <= 0
      qy = n % WY
      qz = (n / WY) % LW
      qx = n / WY / LW
      d = 0
      while d < 6
        inside = d == 0 ? qx + 1 < LW : (d == 1 ? qx > 0 : (d == 2 ? qz + 1 < LW : (d == 3 ? qz > 0 : (d == 4 ? qy + 1 < WY : qy > 0))))
        m = n + @step_n[d]
        if inside && @light[m] < l
          # Sideways steps may cross the storage wrap, so the block index is
          # computed again, not offset.
          q = ((((qx + bx + @step_x[d]) & LMASK) + 1) * PZ + ((qz + bz + @step_z[d]) & LMASK) + 1) * PY + qy + @step_y[d] + 1
          if opaque[cell(q)] == 0
            @light[m] = l
            @queue << m
          end
        end
        d += 1
      end
    end
  end

  def torch_light(x, y, z)
    lx = x - @flood_x
    lz = z - @flood_z
    return 0 if lx < 0 || lz < 0 || lx >= LW || lz >= LW || y < 0 || y >= WY
    @light[(lx * LW + lz) * WY + y]
  end

  def ao_value(side1, side2, corner)
    return 0 if side1 + side2 == 2
    3 - side1 - side2 - corner
  end
end
