# The generator of the blocks of a chunk: the ground and the water from
# the noise of Terrain, then the caves, the ores (Ores), the trees
# (Trees), the treasure chests (TreasureMap), the plants and the desert
# wells. It writes into the store of World with World#put_block, and
# keeps its own work arrays.
class ChunkGenerator
  # The coal rolls of one column of coal cells: one for each 2 layers.
  COAL_ROLLS = WY / 2
  # Dirt and sand lie SOIL_DEPTH deep, and sand lies on sandstone
  # (minecraft.wiki/w/Sand). The wiki does not give the depth of the
  # sandstone.
  SOIL_DEPTH = 4
  SANDSTONE_DEPTH = 4
  # Dry grass per 65536 columns of desert sand. minecraft.wiki/w/Short_Dry_Grass
  # says only that it generates often in deserts, so the number is a guess.
  DESERT_DRY_GRASS = 1500

  attr_reader :terrain, :treasure_map

  def initialize(world, seed)
    @world = world
    @col_h = Array.new(CHUNK * CHUNK, 0)
    @col_b = Array.new(CHUNK * CHUNK, 0)
    @coal_rolls = Array.new(16 * COAL_ROLLS, 0)
    @ores = Ores.new
    @terrain = Terrain.new(seed)
    @caves = Caves.new(world, @terrain, @col_h)
    @trees = Trees.new(world)
    @treasure_map = TreasureMap.new(@terrain)
  end

  # Fills the chunk cx, cz of the world with the generated blocks.
  def generate(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    highest = sample_columns(x0, z0)
    fill_ground(x0, z0)
    @caves.carve(x0, z0, highest)
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
        ore = @ores.clump(y, coal_r, r)
        @world.put_block(base + y, ore) if ore != Block::STONE && Ores.fills?(ore, x, y, z)
      end
      y += 1
    end
    nil
  end

  # A chunk has a pumpkin patch 1 time in 32 (minecraft.wiki/w/Pumpkin).
  # The patch fills about a quarter of the grass PATCH_REACH blocks or
  # less from its center. The wiki does not give the size of a patch. The
  # center stays PATCH_REACH blocks from the chunk edges, so the patch
  # does not need the chunks next door.
  PATCH_ODDS = 65536 / 32
  PATCH_REACH = 3
  PATCH_FILL = 65536 / 4

  # Trees (also those that grow next door and reach in), the treasure
  # chest, then plants and cacti.
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
    treasure_chest(cx, cz)
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
        elsif ground == Block::SAND && biome == Biome::DESERT && !Terrain.beach?(top) && @world.block(World.index(x, top + 1, z)) == Block::AIR
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

  # Puts a chest on the treasure site in the chunk cx, cz, if it has one.
  # The chest takes the place of the leaves of a tree next to it. The
  # plants come after the chest, so they do not take its place. The chest
  # faces a random way.
  def treasure_chest(cx, cz)
    site = @treasure_map.site_at(cx * CHUNK, cz * CHUNK)
    x = site.chest_x
    y = site.chest_y
    z = site.chest_z
    return unless site.found? && x >> 4 == cx && z >> 4 == cz

    block = @world.block(World.index(x, y, z))
    return unless block == Block::AIR || Block.leaves?(block)

    @world.put(x, y, z, Block.facing_id(Block::CHEST, Noise.hash3(x, y, z, 41) & 3), cx * CHUNK, cz * CHUNK)
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
