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
  # The first word: the storage column x and z, y, the face (see
  # NORMALS and CORNER in the shader), and the high bit of the tint.
  X_AT = 0
  X_BITS = 10
  Y_AT = X_AT + X_BITS
  Y_BITS = 7
  Z_AT = Y_AT + Y_BITS
  Z_BITS = X_BITS
  FACE_AT = Z_AT + Z_BITS
  FACE_BITS = 4
  TINT_HIGH_AT = FACE_AT + FACE_BITS
  TINT_HIGH_BITS = 1
  # The second word: the texture, the AO of the 4 corners (2 bits each),
  # the flip of the diagonal, the sky bit, the sunk bit of a water surface,
  # the torch light, the scroll of the texture (Tex.scroll), the facing
  # and the shape of a block (Block::SHAPE), and the low bit of the tint.
  # A sunk water surface keeps 8 - its level in the low 3 bits of AO.
  TEX_AT = 0
  TEX_BITS = 8
  AO_AT = TEX_AT + TEX_BITS
  AO_BITS = 8
  FLIP_AT = AO_AT + AO_BITS
  FLIP_BITS = 1
  SKY_AT = FLIP_AT + FLIP_BITS
  SKY_BITS = 1
  SUNK_AT = SKY_AT + SKY_BITS
  SUNK_BITS = 1
  LIGHT_AT = SUNK_AT + SUNK_BITS
  LIGHT_BITS = 4
  SCROLL_AT = LIGHT_AT + LIGHT_BITS
  SCROLL_BITS = 2
  FACING_AT = SCROLL_AT + SCROLL_BITS
  FACING_BITS = 3
  SHAPE_AT = FACING_AT + FACING_BITS
  SHAPE_BITS = 3
  TINT_LOW_AT = SHAPE_AT + SHAPE_BITS
  TINT_LOW_BITS = 1
  # Records hold columns of a ring as wide as the x field. The shaders wrap
  # at the same width (COLUMNS in gfx.rb).
  COLUMNS = 1 << X_BITS
  COLUMN_MASK = COLUMNS - 1

  # Torch light is LIGHT_MAX at a torch and one less for each step, so it
  # reaches LIGHT_MAX blocks at most. The chunk shader divides by the same value.
  LIGHT_MAX = 14
  # The light flood covers the chunk and a margin that a light can cross.
  MARGIN = LIGHT_MAX + 1
  LW = CHUNK + MARGIN * 2

  # The first word of a face record.
  def self.pack(x, y, z, f) = (x << X_AT) | (y << Y_AT) | (z << Z_AT) | (f << FACE_AT)
  # The tint of a face (Tex.tint) has its high bit in the first word and
  # its low bit in the second word. The shader multiplies the face by the
  # color of that kind in the tint map.
  def self.tint_w0(tex) = (Tex.tint(tex) >> 1) << TINT_HIGH_AT
  def self.tint_w1(tex) = (Tex.tint(tex) & 1) << TINT_LOW_AT
  def self.face_x(w0) = Mesher.field(w0, X_AT, X_BITS)
  def self.face_y(w0) = Mesher.field(w0, Y_AT, Y_BITS)
  def self.face_z(w0) = Mesher.field(w0, Z_AT, Z_BITS)
  def self.face_dir(w0) = Mesher.field(w0, FACE_AT, FACE_BITS)
  def self.face_light(w1) = Mesher.field(w1, LIGHT_AT, LIGHT_BITS)
  def self.face_tint(w0, w1) = (Mesher.field(w0, TINT_HIGH_AT, TINT_HIGH_BITS) << 1) | Mesher.field(w1, TINT_LOW_AT, TINT_LOW_BITS)
  def self.field(w, at, bits) = (w >> at) & ((1 << bits) - 1)

  # The fields of a face record as #defines for the shaders: NAME_AT and
  # NAME_MASK for each.
  def self.shader_defines
    Mesher.define_field("X", X_AT, X_BITS) + Mesher.define_field("Y", Y_AT, Y_BITS) + Mesher.define_field("Z", Z_AT, Z_BITS) +
      Mesher.define_field("FACE", FACE_AT, FACE_BITS) + Mesher.define_field("TINT_HIGH", TINT_HIGH_AT, TINT_HIGH_BITS) +
      Mesher.define_field("TEX", TEX_AT, TEX_BITS) + Mesher.define_field("AO", AO_AT, AO_BITS) +
      Mesher.define_field("FLIP", FLIP_AT, FLIP_BITS) + Mesher.define_field("SKY", SKY_AT, SKY_BITS) +
      Mesher.define_field("SUNK", SUNK_AT, SUNK_BITS) + Mesher.define_field("LIGHT", LIGHT_AT, LIGHT_BITS) +
      Mesher.define_field("SCROLL", SCROLL_AT, SCROLL_BITS) + Mesher.define_field("FACING", FACING_AT, FACING_BITS) +
      Mesher.define_field("SHAPE", SHAPE_AT, SHAPE_BITS) + Mesher.define_field("TINT_LOW", TINT_LOW_AT, TINT_LOW_BITS)
  end

  def self.define_field(name, at, bits) = "#define #{name}_AT #{at}u\n#define #{name}_MASK #{(1 << bits) - 1}u\n"

  attr_reader :opaque, :water, :offsets

  def initialize(world)
    @world = world
    @opaque = []
    @water = []
    @lists = Array.new(7) { Array.new(0, 0) }
    @offsets = Array.new(8, 0)
    @light = Array.new(LW * LW * WY, 0)
    @queue = Array.new(0, 0)
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

  # Meshes world chunk (cx, cz). It and the 8 chunks around it must be loaded.
  def build(cx, cz)
    @opaque.clear
    @water.clear
    @lists.each { |l| l.clear }
    blocks = @world.blocks
    height = @world.height
    opaque = Block::OPAQUE
    occludes = Block::OCCLUDES
    water_level = Block::WATER_LEVEL
    py = PY
    dx = PZ * PY
    top_tex = Block::TOP
    side_tex = Block::SIDE
    bottom_tex = Block::BOTTOM
    front_tex = Block::FRONT
    facing = Block::FACING
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
    x = x0
    while x < x0 + CHUNK
      z = z0
      while z < z0 + CHUNK
        base = World.index(x, 0, z)
        # Vertices hold the storage column; the shader finds the world one.
        lx = x & LMASK
        lz = z & LMASK
        ymax = WY - 1
        while ymax > 0 && World.byte(blocks, base + ymax) == Block::AIR
          ymax -= 1
        end
        # Going up the column, the block above becomes the next block, and
        # the block becomes the one below.
        id = World.byte(blocks, base)
        below = World.byte(blocks, base - 1)
        y = 0
        while y <= ymax
          i = base + y
          above = World.byte(blocks, i + 1)
          if Block.plant?(id)
            sky = y >= height[lx * WZ + lz] ? 1 : 0
            w1 = top_tex[id] | (255 << AO_AT) | (sky << SKY_AT) | Mesher.tint_w1(top_tex[id])
            w1 |= torch_light(x, y, z) << LIGHT_AT if lit
            # The facing field holds 1 + the facing of a wall torch.
            w1 |= (Block::FACING[id] + 1) << FACING_AT if Block.wall_torch?(id)
            plants = @lists[6]
            f = 6
            while f < 10
              plants << (Mesher.pack(lx, y, lz, f) | Mesher.tint_w0(top_tex[id]))
              plants << w1
              f += 1
            end
          elsif id != Block::AIR && (opaque[above] + opaque[below] + opaque[World.byte(blocks, i + py)] + opaque[World.byte(blocks, i - py)] + opaque[World.byte(blocks, i + dx)] + opaque[World.byte(blocks, i - dx)] < 6 || water_level[id] > 0)
            water = water_level[id] > 0
            front = facing[id] >= 0 ? Block::DIR_FACE[facing[id]] : -1
            # A block with a shape is smaller than its cell, so all its faces show.
            shape = Block::SHAPE[id]
            f = 0
            while f < 6
              nb = World.byte(blocks, i + @delta[f])
              visible = if water
                water_level[nb] == 0 && opaque[nb] == 0
              else
                opaque[nb] == 0 && !(nb == id && id == Block::GLASS)
              end
              visible = true if shape > 0
              visible = false if f == 3 && y == 0
              if visible
                tex = f == 2 ? top_tex[id] : (f == 3 ? bottom_tex[id] : (f == front ? front_tex[id] : side_tex[id]))
                ny = y + (f == 2 ? 1 : (f == 3 ? -1 : 0))
                sx = x + @nx[f]
                sz = z + @nz[f]
                sky = ny >= height[(sx & LMASK) * WZ + (sz & LMASK)] ? 1 : 0
                w0 = Mesher.pack(lx, y, lz, f) | Mesher.tint_w0(tex)
                if water
                  low = water_level[above] > 0 ? 0 : 1
                  w1 = tex | (low == 1 ? (8 - water_level[id]) << AO_AT : 255 << AO_AT) | (sky << SKY_AT) | (low << SUNK_AT) | (Tex.scroll(tex) << SCROLL_AT)
                  w1 |= torch_light(sx, ny, sz) << LIGHT_AT if lit
                  @water << w0
                  @water << w1
                else
                  a = f * 12
                  ao0 = ao_value(occludes[World.byte(blocks, i + @ao[a])], occludes[World.byte(blocks, i + @ao[a + 1])], occludes[World.byte(blocks, i + @ao[a + 2])])
                  ao1 = ao_value(occludes[World.byte(blocks, i + @ao[a + 3])], occludes[World.byte(blocks, i + @ao[a + 4])], occludes[World.byte(blocks, i + @ao[a + 5])])
                  ao2 = ao_value(occludes[World.byte(blocks, i + @ao[a + 6])], occludes[World.byte(blocks, i + @ao[a + 7])], occludes[World.byte(blocks, i + @ao[a + 8])])
                  ao3 = ao_value(occludes[World.byte(blocks, i + @ao[a + 9])], occludes[World.byte(blocks, i + @ao[a + 10])], occludes[World.byte(blocks, i + @ao[a + 11])])
                  flip = (ao0 - ao2).abs > (ao1 - ao3).abs ? 1 : 0
                  w1 = tex | (ao0 << AO_AT) | (ao1 << (AO_AT + 2)) | (ao2 << (AO_AT + 4)) | (ao3 << (AO_AT + 6)) | (flip << FLIP_AT) | (sky << SKY_AT) |
                       (Tex.scroll(tex) << SCROLL_AT) | Mesher.tint_w1(tex)
                  w1 |= torch_light(sx, ny, sz) << LIGHT_AT if lit
                  w1 = (w1 & ~(15 << LIGHT_AT)) | (LIGHT_MAX << LIGHT_AT) if Block.lava?(id)
                  # A block with a shape has no AO. The facing field holds 1 + its facing.
                  w1 |= (255 << AO_AT) | ((facing[id] + 1) << FACING_AT) | (shape << SHAPE_AT) if shape > 0
                  list = @lists[f]
                  list << w0
                  list << w1
                end
              end
              f += 1
            end
          end
          below = id
          id = above
          y += 1
        end
        z += 1
      end
      x += 1
    end
    finish
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
    @water_offsets[7] = @water.size / 2
    i = 1
    while i < 7
      @water_offsets[i] = @water.size / 2
      i += 1
    end
  end

  def water_offsets = @water_offsets

  # Spreads torch light through cells that are not opaque: LIGHT_MAX at a torch,
  # one less per step, so walls stop it. Covers the chunk plus a margin.
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
        @light[n] = LIGHT_MAX
        @queue << n
      end
      k += 1
    end
    blocks = @world.blocks
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
          if opaque[(blocks[q >> 3] >> ((q & 7) << 3)) & 127] == 0
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
