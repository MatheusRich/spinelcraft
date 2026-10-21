# The generator of the blocks of a chunk: the ground and the water from
# the noise of Terrain, then the caves, the ores, the trees (Trees), the
# plants and the desert wells. It writes into the store of World with
# World#put_block, and keeps its own work arrays.
class ChunkGenerator
  # Cave noise grid of one chunk: a point every 4 blocks.
  GX = CHUNK / 4 + 1
  GY = WY / 4 + 1
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
  # Dirt and sand lie SOIL_DEPTH deep, and sand lies on sandstone
  # (minecraft.wiki/w/Sand). The wiki does not give the depth of the
  # sandstone.
  SOIL_DEPTH = 4
  SANDSTONE_DEPTH = 4
  # Dry grass per 65536 columns of desert sand. minecraft.wiki/w/Short_Dry_Grass
  # says only that it generates often in deserts, so the number is a guess.
  DESERT_DRY_GRASS = 1500

  attr_reader :terrain

  def initialize(world, seed)
    @world = world
    @col_h = Array.new(CHUNK * CHUNK, 0)
    @col_b = Array.new(CHUNK * CHUNK, 0)
    @cave_a = Array.new(GX * GY * GX, 0.0)
    @cave_b = Array.new(GX * GY * GX, 0.0)
    # 1 for each cell of the cave grid that can hold a cave (see cave_cell).
    @cave_cell = Array.new(GX * GY * GX, 0)
    # The edges along x of a cave grid cell, of the two fields (Terrain.x_edges).
    @edges_a = Array.new(4, 0.0)
    @edges_c = Array.new(4, 0.0)
    # The grid layer of the edges in @edges_a and @edges_c (see tunnel?).
    @a_layer = -1
    @c_layer = -1
    @coal_odds = Array.new(WY, 0)
    @iron_odds = Array.new(WY, 0)
    @diamond_odds = Array.new(WY, 0)
    @spinel_odds = Array.new(WY, 0)
    @coal_rolls = Array.new(16 * COAL_ROLLS, 0)
    y = 0
    while y < WY
      @coal_odds[y] = ChunkGenerator.ore_odds(ChunkGenerator.ore_at(Block::COAL_ORE, y), COAL_CELL, VEIN_17)
      @iron_odds[y] = ChunkGenerator.ore_odds(ChunkGenerator.ore_at(Block::IRON, y), ORE_CELL, VEIN_9)
      @diamond_odds[y] = ChunkGenerator.ore_odds(ChunkGenerator.ore_at(Block::DIAMOND, y), ORE_CELL, DIAMOND_VEIN)
      @spinel_odds[y] = ChunkGenerator.ore_odds(ChunkGenerator.ore_at(Block::SPINEL_ORE, y), ORE_CELL, VEIN_9)
      y += 1
    end
    @terrain = Terrain.new(seed)
    @trees = Trees.new(world)
  end

  # The y in Minecraft of layer y. Below the sea, layer y also stands for
  # the layer above that y in Minecraft.
  def self.mc_y(y)
    return y - SEA + MC_SEA if y >= SEA
    MC_BOTTOM + (y - 1) * 2
  end

  # The blocks of an ore in each chunk at layer y, in solid stone.
  def self.ore_at(ore, y)
    m = ChunkGenerator.mc_y(y)
    return ChunkGenerator.mc_ore(ore, m) if y >= SEA
    ChunkGenerator.mc_ore(ore, m) + ChunkGenerator.mc_ore(ore, m + 1)
  end

  # The blocks of an ore in each chunk of Minecraft at its layer m, in
  # solid stone: the veins that start at m, times the blocks of a vein.
  def self.mc_ore(ore, m)
    # 20 veins of size 17 in a triangle from y 0 to 192, and 30 spread
    # evenly from y 136 to 320. minecraft.wiki/w/Coal_Ore
    return VEIN_17 * (20 * ChunkGenerator.peaked(m, 0, 192) + 30 * ChunkGenerator.even(m, 136, 320)) if ore == Block::COAL_ORE
    # 90 veins of size 9 in a triangle from y 80 to 384, 10 in a triangle
    # from y -24 to 56, and 10 of size 4 spread evenly from y -64 to 72.
    # minecraft.wiki/w/Iron_Ore
    return VEIN_9 * (90 * ChunkGenerator.peaked(m, 80, 384) + 10 * ChunkGenerator.peaked(m, -24, 56)) + VEIN_4 * 10 * ChunkGenerator.even(m, -64, 72) if ore == Block::IRON
    # Spinel copies gold ore: 4 veins of size 9 from y -64 to 32, most of
    # them near y -16, and half a vein of size 9 spread evenly from y -64
    # to -48. minecraft.wiki/w/Gold_Ore gives the veins as 0 to 13 blocks,
    # the largest of size 9. The wiki also says that half of these blocks
    # do not generate where they touch air. The game skips that rule. It
    # also skips the extra gold of the badlands, a biome that it does not
    # have.
    return VEIN_9 * (4 * ChunkGenerator.peaked(m, -64, 32) + 0.5 * ChunkGenerator.even(m, -64, -48)) if ore == Block::SPINEL_ORE
    # 7 veins of size 4, 4 of size 8 and 1/9 of size 12 in a triangle
    # that ends at y 16, and 2 of size 8 spread evenly from y -64 to -4.
    # minecraft.wiki/w/Diamond_Ore gives the range of the triangle as
    # -64 to 16 and says that the ore is more common lower down. The
    # wiki does not give the bottom of the triangle, -144 in the data of
    # the game, 80 layers below the bottom of the world.
    (7 * VEIN_4 + 4 * VEIN_8 + VEIN_12 / 9) * ChunkGenerator.peaked(m, -144, 16) + 2 * VEIN_8 * ChunkGenerator.even(m, -64, -4)
  end

  # The share of the veins that start at layer m, for veins in a triangle
  # from y low to high.
  def self.peaked(m, low, high)
    ChunkGenerator.triangle(m, low.to_f, (low + high) / 2.0, high.to_f) * 2.0 / (high - low)
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

  # Fills the chunk cx, cz of the world with the generated blocks.
  def generate(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    highest = sample_columns(x0, z0)
    fill_ground(x0, z0)
    carve_caves(x0, z0, highest)
    place_ores(x0, z0, highest)
    decorate(cx, cz)
  end

  # The height and the biome of each column of the chunk at x0, z0, into
  # @col_h and @col_b. Gives the highest height.
  def sample_columns(x0, z0)
    highest = 0
    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        h = @terrain.surface_height(x0 + lx, z0 + lz)
        @col_h[lx * CHUNK + lz] = h
        @col_b[lx * CHUNK + lz] = @terrain.biome(x0 + lx, z0 + lz, h)
        highest = h if h > highest
        lz += 1
      end
      lx += 1
    end
    highest
  end

  # Bedrock, stone, the soil and the top block of each column, then water
  # up to the sea and air above.
  def fill_ground(x0, z0)
    CHUNK.times do |lx|
      CHUNK.times do |lz|
        x = x0 + lx
        z = z0 + lz
        h = @col_h[lx * CHUNK + lz]
        surface = @terrain.top_block(x, z, h, @col_b[lx * CHUNK + lz])
        base = World.index(x, 0, z)
        y = 0
        while y < h
          @world.put_block(base + y, ChunkGenerator.ground_block(y, h - 1, surface))
          y += 1
        end
        while y <= SEA
          @world.put_block(base + y, Block::WATER)
          y += 1
        end
        @world.clear_above(base, y)
      end
    end
  end

  # The block at layer y of a column whose top block is surface at layer
  # top, before the caves and the ores.
  def self.ground_block(y, top, surface)
    return Block::BEDROCK if y == 0
    return surface if y == top
    soil = y > top - SOIL_DEPTH
    return Block::STONE if soil && Terrain.bare_rock?(top)
    return Block::SAND if soil && surface == Block::SAND
    return Block::DIRT if soil
    return Block::SANDSTONE if y > top - SOIL_DEPTH - SANDSTONE_DEPTH && surface == Block::SAND
    Block::STONE
  end

  # Air in the tunnels, and lava at LAVA_LEVEL and below.
  def carve_caves(x0, z0, highest)
    fill_cave_grid(x0, z0, highest)
    CHUNK.times do |lx|
      CHUNK.times { |lz| carve_column(x0, z0, lx, lz) }
    end
  end

  # Coarse 3D noise for caves, sampled every 4 blocks and interpolated.
  # Caves stay below the top block of a column, so the grid stops at the
  # layer above the highest top block.
  def fill_cave_grid(x0, z0, highest)
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
          @cave_a[n] = @terrain.cave_a(gx0 + i, j, gz0 + k)
          @cave_b[n] = @terrain.cave_b(gx0 + i, j, gz0 + k)
          k += 1
        end
        j += 1
      end
      i += 1
    end
    mark_cave_cells(gy)
  end

  # Marks the cells of the lowest gy layers of the cave grid that can
  # hold a cave (see cave_cell).
  def mark_cave_cells(gy)
    (GX - 1).times do |i|
      (gy - 1).times do |j|
        (GX - 1).times do |k|
          n = (i * GY + j) * GX + k
          @cave_cell[n] = cave_cell(n)
        end
      end
    end
  end

  # Carves the tunnels of column lx, lz of the chunk at x0, z0. In an
  # entrance patch they keep their full width up to the top block. A beach
  # keeps the 3 blocks under its top block.
  def carve_column(x0, z0, lx, lz)
    x = x0 + lx
    z = z0 + lz
    top = @col_h[lx * CHUNK + lz] - 1
    entrance = @terrain.entrance?(x, z)
    base = World.index(x, 0, z)
    # The column's place in the cave grid.
    fx = lx / 4.0
    fz = lz / 4.0
    ix = fx.to_i
    iz = fz.to_i
    @a_layer = -1
    @c_layer = -1
    last = Terrain.beach?(top) ? top - 3 : top
    y = 2
    while y <= last
      n = (ix * GY + (y >> 2)) * GX + iz
      if @cave_cell[n] == 1
        width = entrance ? Terrain::CAVE_WIDTH : Terrain.cave_width(top - y)
        @world.put_block(base + y, y <= LAVA_LEVEL ? Block::LAVA : Block::AIR) if tunnel?(n, y, fx - ix, fz - iz, width)
      end
      y += 1
    end
    nil
  end

  # True when layer y of a column is in a tunnel of width. n is the cave
  # grid point under the block, and tx, tz are the place of the column
  # inside the grid cell. The 4 layers of a grid cell share its edges along
  # x (x_edges), so a column reads them once a layer, into @edges_a and
  # @edges_c.
  def tunnel?(n, y, tx, tz, width)
    fy = y / 4.0
    iy = fy.to_i
    if iy != @a_layer
      @a_layer = iy
      Terrain.x_edges(@cave_a, n, GY, GX, tx, @edges_a)
    end
    a = Terrain.yz_lerp(@edges_a, fy - iy, tz)
    return false unless Terrain.cave_possible?(a, width)
    if iy != @c_layer
      @c_layer = iy
      Terrain.x_edges(@cave_b, n, GY, GX, tx, @edges_c)
    end
    Terrain.cave?(a, Terrain.yz_lerp(@edges_c, fy - iy, tz), width)
  end

  # Coal, iron, diamond and spinel in the stone that the caves left.
  def place_ores(x0, z0, highest)
    roll_coal(x0, z0, highest)
    CHUNK.times do |lx|
      CHUNK.times { |lz| place_column_ores(x0, z0, lx, lz) }
    end
  end

  # The rolls of the 4 x 4 columns of coal cells in the chunk at x0, z0,
  # one for each 2 layers up to highest. The 16 block columns of a cell
  # column read them.
  def roll_coal(x0, z0, highest)
    i = 0
    while i < 16
      j = 0
      while j <= highest >> 1
        @coal_rolls[i * COAL_ROLLS + j] = Noise.hash3((x0 >> 2) + (i >> 2), j, (z0 >> 2) + (i & 3), 13)
        j += 1
      end
      i += 1
    end
    nil
  end

  # Puts the ores in the stone of column lx, lz of the chunk at x0, z0.
  # Two layers share the rolls of their cells.
  def place_column_ores(x0, z0, lx, lz)
    x = x0 + lx
    z = z0 + lz
    base = World.index(x, 0, z)
    coal_cells = ((lx >> 2) * 4 + (lz >> 2)) * COAL_ROLLS
    h = @col_h[lx * CHUNK + lz]
    roll_y = -1
    coal_r = 0
    r = 0
    y = 1
    while y < h
      if @world.block(base + y) == Block::STONE
        if (y >> 1) != roll_y
          roll_y = y >> 1
          coal_r = @coal_rolls[coal_cells + roll_y]
          r = Noise.hash3(x >> 1, roll_y, z >> 1, 11)
        end
        ore = clump_ore(y, coal_r, r)
        @world.put_block(base + y, ore) if ore != Block::STONE && ChunkGenerator.ore_fills?(ore, x, y, z)
      end
      y += 1
    end
    nil
  end

  # The ore of the clump at layer y, or stone: coal_r is the roll of the
  # coal cell, and r the roll of the iron, diamond or spinel cell. Spinel
  # takes the top of the roll. Its range then starts at the same roll in
  # both layers of a cell, even where the odds of iron and diamond change
  # from layer to layer.
  def clump_ore(y, coal_r, r)
    return Block::COAL_ORE if coal_r < @coal_odds[y]
    iron = @iron_odds[y]
    return Block::IRON if r < iron
    return Block::DIAMOND if r < iron + @diamond_odds[y]
    return Block::SPINEL_ORE if r >= 65536 - @spinel_odds[y]
    Block::STONE
  end

  # True when block x, y, z of a clump of ore is ore. A roll for each block
  # leaves gaps in the clump.
  def self.ore_fills?(ore, x, y, z)
    return Noise.hash3(x, y, z, 12) < COAL_FILL if ore == Block::COAL_ORE
    return Noise.hash3(x, y, z, 14) < IRON_FILL if ore == Block::IRON
    return Noise.hash3(x, y, z, 16) < DIAMOND_FILL if ore == Block::DIAMOND
    Noise.hash3(x, y, z, 18) < SPINEL_FILL
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
    Terrain.cave_possible?(low, Terrain::CAVE_WIDTH) || Terrain.cave_possible?(high, Terrain::CAVE_WIDTH) || (low < 0.0 && high > 0.0) ? 1 : 0
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
    x = x0 - Trees::TREE_REACH
    while x < x0 + CHUNK + Trees::TREE_REACH
      z = z0 - Trees::TREE_REACH
      while z < z0 + CHUNK + Trees::TREE_REACH
        top = @terrain.tree_top(x, z)
        @trees.tree(x, top + 1, z, x0, z0, @terrain.biome(x, z, top + 1)) if top >= 0
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
        ground = @world.block(World.index(x, top, z))
        if ground == Block::GRASS && @world.block(World.index(x, top + 1, z)) == Block::AIR
          p = Noise.hash3(x, 2, z, 25)
          meadow = @terrain.meadow(x, z)
          if patch && (x - patch_x).abs <= PATCH_REACH && (z - patch_z).abs <= PATCH_REACH && Noise.hash3(x, 3, z, 40) < PATCH_FILL
            @world.put(x, top + 1, z, Block::PUMPKIN, x0, z0)
          elsif p < Biome::GRASS[biome] + (meadow * 12000.0).to_i
            @world.put(x, top + 1, z, Block::TALL_GRASS, x0, z0)
          elsif p >= 65536 - Biome::FLOWERS[biome] && meadow > -0.05
            @world.put(x, top + 1, z, (x + z) % 3 == 0 ? Block::ROSE : Block::DANDELION, x0, z0)
          end
        elsif ground == Block::SAND && biome == Biome::DESERT && !Terrain.beach?(top)
          r = Noise.hash3(x, 0, z, 21)
          if r < 350
            tall = 1 + Noise.hash3(x, 1, z, 22) % 3
            tall.times { |i| @world.put(x, top + 1 + i, z, Block::CACTUS, x0, z0) }
          elsif r < 350 + DESERT_DRY_GRASS
            @world.put(x, top + 1, z, Block::DRY_GRASS, x0, z0)
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
    h = @terrain.surface_height(x, z)
    (-WELL_REACH..WELL_REACH).each do |dx|
      (-WELL_REACH..WELL_REACH).each do |dz|
        ch = @terrain.surface_height(x + dx, z + dz)
        return -1 if ch < h || ch > h + 1 || Terrain.beach?(ch - 1)
        biome = @terrain.biome(x + dx, z + dz, ch)
        return -1 if biome != Biome::DESERT || @terrain.top_block(x + dx, z + dz, ch, biome) != Block::SAND
        return -1 if @terrain.entrance?(x + dx, z + dz) && @terrain.carved?(x + dx, ch - 1, z + dz)
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
        (-WELL_REACH..WELL_REACH).each { |dz| @world.put(x + dx, top + dy, z + dz, well_block(dx, dy, dz), x0, z0) }
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

end
