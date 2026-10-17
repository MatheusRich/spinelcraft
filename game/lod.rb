# Far terrain: a coarse mesh past the full-detail chunks, in levels. Level L
# has cells of 4 << L blocks, and a tile holds CELLS x CELLS cells. Each cell
# has one height and one top block, read from the world generator's noise, so
# far terrain needs no block storage. Edits do not show here.
class Lod
  CELLS = 16
  # Tiles live in a ring like chunks do; the shader wraps Mesher::COLUMNS cells.
  TRING = Mesher::COLUMNS / CELLS
  TMASK = TRING - 1
  # A face record of far terrain has the first word of a chunk face record
  # (Mesher.pack). Its second word holds the texture, the height of the
  # face in blocks, the cell size as a shift, the tint of the texture
  # (Tex.tint) and the biome. The fields follow the layout of
  # Mesher::X_AT and the others.
  TALL_AT = Mesher::TEX_AT + Mesher::TEX_BITS
  TALL_BITS = 8
  CELL_AT = TALL_AT + TALL_BITS
  CELL_BITS = 3
  TINT_AT = CELL_AT + CELL_BITS
  TINT_BITS = 2
  BIOME_AT = TINT_AT + TINT_BITS
  BIOME_BITS = 4
  TALL_MAX = (1 << TALL_BITS) - 1

  attr_reader :tile_x, :tile_z, :built, :faces, :tile, :tile_shift

  def initialize(world, level)
    @world = world
    @shift = 2 + level
    @cell = 1 << @shift
    @tile = @cell * CELLS
    @tile_shift = @shift + 4
    @tile_x = Array.new(TRING * TRING, World::NONE)
    @tile_z = Array.new(TRING * TRING, World::NONE)
    @built = Array.new(TRING * TRING, 0)
    # Heights and top textures of the tile's cells plus a border of one cell.
    @h = Array.new((CELLS + 2) * (CELLS + 2), 0)
    @top = Array.new((CELLS + 2) * (CELLS + 2), 0)
    @side = Array.new((CELLS + 2) * (CELLS + 2), 0)
    @biome = Array.new((CELLS + 2) * (CELLS + 2), 0)
    @lists = Array.new(6) { Array.new(0, 0) }
    @faces = Array.new(0, 0)
    @offsets = Array.new(8, 0)
    @nx = [1, -1, 0, 0, 0, 0]
    @nz = [0, 0, 0, 0, 1, -1]
  end

  def self.slot(tx, tz) = (tx & TMASK) * TRING + (tz & TMASK)

  # The tint and the biome fields of a face record. The shader takes the
  # ratio of that biome from the uniforms (Tint#write_uniforms).
  def self.tint(tex, biome) = (Tex.tint(tex) << TINT_AT) | (biome << BIOME_AT)

  # The fields of the second word as #defines for the shaders, as
  # Mesher.shader_defines gives them.
  def self.shader_defines
    Mesher.define_field("TALL", TALL_AT, TALL_BITS) + Mesher.define_field("CELL", CELL_AT, CELL_BITS) +
      Mesher.define_field("LOD_TINT", TINT_AT, TINT_BITS) + Mesher.define_field("BIOME", BIOME_AT, BIOME_BITS)
  end

  def ready?(tx, tz)
    s = Lod.slot(tx, tz)
    @built[s] == 1 && @tile_x[s] == tx && @tile_z[s] == tz
  end

  # Samples cell (cx, cz) (in cell units) into grid entry k.
  def sample(cx, cz, k)
    w = @world
    x = (cx << @shift) + @cell / 2
    z = (cz << @shift) + @cell / 2
    h = w.surface_height(x, z)
    if h - 1 < SEA
      @h[k] = SEA + 1
      @top[k] = Tex::WATER
      @side[k] = Tex::WATER
      return
    end
    biome = w.biome(x, z, h)
    @biome[k] = biome
    b = w.top_block(x, z, h, biome)
    @top[k] = Block::TOP[b]
    @side[k] = Block::SIDE[b]
    @h[k] = h
    if (b == Block::GRASS || b == Block::SNOW_GRASS) && Noise.hash3(cx, 0, cz, 26) >> 4 < Biome::TREES[biome]
      # About the height of the biome's trees: the trunk, plus the leaves above it.
      @h[k] = h + World::TRUNK[Biome::TREE[biome]] + 2
      leaves = Block::TOP[Block::LEAVES[World::WOOD[Biome::TREE[biome]]]]
      @top[k] = leaves
      @side[k] = leaves
    end
  end

  # Builds tile (tx, tz): the faces, sorted by direction, and their offsets.
  def build(tx, tz) # rubocop:todo Metrics/MethodLength
    s = Lod.slot(tx, tz)
    @tile_x[s] = tx
    @tile_z[s] = tz
    c0x = tx * CELLS - 1
    c0z = tz * CELLS - 1
    i = 0
    while i < CELLS + 2
      (CELLS + 2).times { |j| sample(c0x + i, c0z + j, i * (CELLS + 2) + j) }
      i += 1
    end
    @lists.each { |l| l.clear }
    i = 1
    while i <= CELLS
      j = 1
      while j <= CELLS
        k = i * (CELLS + 2) + j
        h = @h[k]
        cx = (c0x + i) & Mesher::COLUMN_MASK
        cz = (c0z + j) & Mesher::COLUMN_MASK
        # The top face: the cell's top block is at y = h - 1.
        @lists[2] << Mesher.pack(cx, h - 1, cz, 2)
        @lists[2] << (@top[k] | (1 << TALL_AT) | (@shift << CELL_AT) | Lod.tint(@top[k], @biome[k]))
        6.times do |f|
          if f != 2 && f != 3
            n = @h[(i + @nx[f]) * (CELLS + 2) + j + @nz[f]]
            if n < h
              tall = h - n
              tall = TALL_MAX if tall > TALL_MAX
              @lists[f] << Mesher.pack(cx, n, cz, f)
              @lists[f] << (@side[k] | (tall << TALL_AT) | (@shift << CELL_AT) | Lod.tint(@side[k], @biome[k]))
            end
          end
        end
        j += 1
      end
      i += 1
    end
    @faces.clear
    6.times do |f|
      @offsets[f] = @faces.size / 2
      @faces.concat(@lists[f])
    end
    @offsets[6] = @faces.size / 2
    @offsets[7] = @faces.size / 2
    @built[s] = 1
    s
  end

  def offsets = @offsets
end
