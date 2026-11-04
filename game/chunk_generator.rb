# Fills a chunk: ground and water, caves, ores, trees, treasure chests,
# plants and desert wells.
class ChunkGenerator
  COAL_ROLLS = WY / 2
  # Sand lies on sandstone (minecraft.wiki/w/Sand). The wiki does not give
  # the depth of the sandstone.
  SOIL_DEPTH = 4
  SANDSTONE_DEPTH = 4
  # minecraft.wiki/w/Short_Dry_Grass says only that dry grass generates
  # often in deserts, so the number is a guess.
  DESERT_DRY_GRASS = 1500

  attr_reader :terrain, :treasure_map

  def initialize(world, seed)
    @world = world
    @col_h = Array.new(CHUNK * CHUNK, 0)
    @col_b = Array.new(CHUNK * CHUNK, 0)
    @col_top = Array.new(CHUNK * CHUNK, 0)
    @coal_rolls = Array.new(16 * COAL_ROLLS, 0)
    @ores = Ores.new
    @terrain = Terrain.new(seed)
    @caves = Caves.new(world, @terrain.cave_shape, @col_h)
    @trees = Trees.new(world)
    @treasure_map = TreasureMap.new(@terrain)
  end

  def generate(cx, cz)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    highest = sample_columns(x0, z0)
    fill_ground(x0, z0)
    @caves.carve(x0, z0, highest)
    place_ores(x0, z0, highest)
    decorate(cx, cz)
  end

  def sample_columns(x0, z0)
    highest = 0
    lx = 0
    while lx < CHUNK
      lz = 0
      while lz < CHUNK
        h = @terrain.surface_height(x0 + lx, z0 + lz)
        @col_h[lx * CHUNK + lz] = h
        biome = @terrain.biome(x0 + lx, z0 + lz, h)
        @col_b[lx * CHUNK + lz] = biome
        @col_top[lx * CHUNK + lz] = @terrain.top_block(x0 + lx, z0 + lz, h, biome)
        highest = h if h > highest
        lz += 1
      end
      lx += 1
    end
    highest
  end

  def fill_ground(x0, z0)
    CHUNK.times do |lx|
      CHUNK.times do |lz|
        x = x0 + lx
        z = z0 + lz
        h = @col_h[lx * CHUNK + lz]
        surface = @col_top[lx * CHUNK + lz]
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

  def self.ground_block(y, top, surface)
    return Block::BEDROCK if y == 0
    return surface if y == top

    soil = y > top - SOIL_DEPTH
    return Block::STONE if soil && (Terrain.bare_rock?(top) || surface == Block::STONE || surface == Block::GRAVEL)
    return Block::SAND if soil && surface == Block::SAND
    return Block::DIRT if soil
    return Block::SANDSTONE if y > top - SOIL_DEPTH - SANDSTONE_DEPTH && surface == Block::SAND

    Block::STONE
  end

  def place_ores(x0, z0, highest)
    roll_coal(x0, z0, highest)
    CHUNK.times do |lx|
      CHUNK.times { |lz| place_column_ores(x0, z0, lx, lz) }
    end
  end

  # The 16 block columns of a coal cell column share its rolls.
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

  # A pumpkin patch 1 time in 32 chunks (minecraft.wiki/w/Pumpkin). The
  # wiki does not give the size of a patch. The center stays PATCH_REACH
  # from the chunk edges, so the patch does not need the chunks next door.
  PATCH_ODDS = 65536 / 32
  PATCH_REACH = 3
  PATCH_FILL = 65536 / 4

  # Trees that grow next door also reach in.
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

  # The plants come after the chest, so they do not take its place.
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
  # Its center stays WELL_REACH from the chunk edges, so the well does not
  # need the chunks next door.
  WELL_ODDS = 65536 / 1000
  WELL_REACH = 2

  # Each column under the well is desert sand, as high as the center or 1
  # higher, so no part of the well hangs over air.
  def well_top(x, z)
    h = @terrain.surface_height(x, z)
    (-WELL_REACH..WELL_REACH).each do |dx|
      (-WELL_REACH..WELL_REACH).each do |dz|
        ch = @terrain.surface_height(x + dx, z + dz)
        return -1 if ch < h || ch > h + 1 || Terrain.beach?(ch - 1)

        biome = @terrain.biome(x + dx, z + dz, ch)
        return -1 if biome != Biome::DESERT || @terrain.top_block(x + dx, z + dz, ch, biome) != Block::SAND
        return -1 if @terrain.cave_shape.opening?(x + dx, ch - 1, z + dz)
      end
    end
    h - 1
  end

  # minecraft.wiki/w/Desert_Well/Structure. The game has no slabs, so
  # sandstone takes their place.
  def well(x, top, z, x0, z0)
    (-2..4).each do |dy|
      (-WELL_REACH..WELL_REACH).each do |dx|
        (-WELL_REACH..WELL_REACH).each { |dz| @world.put(x + dx, top + dy, z + dz, well_block(dx, dy, dz), x0, z0) }
      end
    end
  end

  # Minecraft puts 2 blocks of suspicious sand under the center. The game
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
