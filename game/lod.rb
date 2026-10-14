# Far terrain: a coarse mesh past the full-detail chunks, in levels. Level L
# has cells of 4 << L blocks, and a tile holds CELLS x CELLS cells. Each cell
# has one height and one top block, read from the world generator's noise, so
# far terrain needs no block storage. Edits do not show here.
class Lod
  CELLS = 16
  # Tiles live in a ring like chunks do; the shader wraps Mesher::COLUMNS cells.
  TRING = Mesher::COLUMNS / CELLS
  TMASK = TRING - 1
  # Forest canopy height above the ground.
  CANOPY = 5

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
    @lists = Array.new(6) { Array.new(0, 0) }
    @faces = Array.new(0, 0)
    @offsets = Array.new(8, 0)
    @nx = [1, -1, 0, 0, 0, 0]
    @nz = [0, 0, 0, 0, 1, -1]
  end

  def self.slot(tx, tz) = (tx & TMASK) * TRING + (tz & TMASK)

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
    b = w.top_block(x, z, h, w.temperature(x, z))
    @top[k] = Block::TOP[b]
    @side[k] = Block::SIDE[b]
    @h[k] = h
    if (b == Block::GRASS || b == Block::SNOW_GRASS) && w.tree_roll?(x, z, Noise.hash3(cx, 0, cz, 26) >> 4)
      @h[k] = h + CANOPY
      @top[k] = Tex::LEAVES
      @side[k] = Tex::LEAVES
    end
  end

  # Builds tile (tx, tz): the faces, sorted by direction, and their offsets.
  def build(tx, tz)
    s = Lod.slot(tx, tz)
    @tile_x[s] = tx
    @tile_z[s] = tz
    c0x = tx * CELLS - 1
    c0z = tz * CELLS - 1
    i = 0
    while i < CELLS + 2
      j = 0
      while j < CELLS + 2
        sample(c0x + i, c0z + j, i * (CELLS + 2) + j)
        j += 1
      end
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
        @lists[2] << (@top[k] | (1 << 8) | (@shift << 15))
        f = 0
        while f < 6
          if f != 2 && f != 3
            n = @h[(i + @nx[f]) * (CELLS + 2) + j + @nz[f]]
            if n < h
              tall = h - n
              tall = 127 if tall > 127
              @lists[f] << Mesher.pack(cx, n, cz, f)
              @lists[f] << (@side[k] | (tall << 8) | (@shift << 15))
            end
          end
          f += 1
        end
        j += 1
      end
      i += 1
    end
    @faces.clear
    f = 0
    while f < 6
      @offsets[f] = @faces.size / 2
      @faces.concat(@lists[f])
      f += 1
    end
    @offsets[6] = @faces.size / 2
    @offsets[7] = @faces.size / 2
    @built[s] = 1
    s
  end

  def offsets = @offsets
end
