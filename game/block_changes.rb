# Block changes and what follows them: flowing water and lava, falling sand and gravel.
class Game
  def set_block(x, y, z, b)
    @changed = true
    drop_chest(x, y, z) if b != Block::CHEST && @world.get(x, y, z) == Block::CHEST
    old = @world.get(x, y, z)
    @furnace_heat.delete(World.key(x, y, z)) if old == Block::FURNACE && b != Block::FURNACE
    # A door goes as a whole: removing one half removes the other.
    if Block.door?(old) && !Block.door?(b)
      @world.set(x, y, z, b)
      other = door_partner(x, y, z)
      set_block(x, other, z, Block::AIR) if Block.door?(@world.get(x, other, z))
    end
    # A bed also goes as a whole.
    if Block.bed?(old) && !Block.bed?(b)
      @world.set(x, y, z, b)
      d = bed_partner(x, y, z)
      set_block(x + BED_DX[d], y, z + BED_DZ[d], Block::AIR) if d >= 0
    end
    if Block.emits?(b) || Block.emits?(old) || (Block::OPAQUE[b] == 0 && near_lava?(x, y, z))
      mark_light_area(x, z)
    end
    @world.set(x, y, z, b)
    mark_dirty(x, z)
    set_block(x, y + 1, z, Block::AIR) if b == Block::AIR && Block.plant?(@world.get(x, y + 1, z))
    settle_column(x, z)
    wake_water(x, y, z)
  end

  # Each second, the game looks at this many of the 81 x 81 columns near the
  # player for a sapling or a crop on top. Only a plant under the open sky
  # grows. Each one that it finds grows (a sapling into a tree, a crop to
  # its next stage) with chance GROW_CHANCE. That is a step in about
  # 81 * 81 / (1100 * 0.1) = 60 seconds.
  GROW_SAMPLES = 1100.0
  GROW_REACH = 40
  GROW_CHANCE = 0.1

  def grow_plants(dt)
    n = (dt * GROW_SAMPLES + @rng.rand01).to_i
    span = GROW_REACH * 2 + 1
    while n > 0
      x = @player.x.floor - GROW_REACH + (@rng.rand01 * span).to_i
      z = @player.z.floor - GROW_REACH + (@rng.rand01 * span).to_i
      if @world.loaded?(x, z)
        y = @world.height_at(x, z)
        b = @world.get(x, y, z)
        if (b == Block::SAPLING || Block.growing?(b)) && @rng.rand01 < GROW_CHANCE
          b == Block::SAPLING ? grow_tree(x, y, z) : set_block(x, y, z, b + 1)
        end
      end
      n -= 1
    end
  end

  # A tree like the generator's: a trunk of 4 to 6 logs under two wide
  # layers and two small layers of leaves. It needs air above the sapling.
  def grow_tree(x, y, z)
    tall = 4 + (@rng.rand01 * 3.0).to_i
    return if y + tall + 2 >= WY
    i = 1
    while i < tall + 2
      return unless @world.get(x, y + i, z) == Block::AIR
      i += 1
    end
    top = y + tall
    ly = top - 2
    while ly <= top + 1
      radius = ly >= top ? 1 : 2
      dx = -radius
      while dx <= radius
        dz = -radius
        while dz <= radius
          corner = dx.abs == radius && dz.abs == radius
          skip = corner && (ly == top + 1 || @rng.rand01 < 0.5)
          set_block(x + dx, ly, z + dz, Block::LEAVES) if !skip && @world.get(x + dx, ly, z + dz) == Block::AIR
          dz += 1
        end
        dx += 1
      end
      ly += 1
    end
    i = 0
    while i < tall
      set_block(x, y + i, z, Block::LOG)
      i += 1
    end
    set_block(x, y - 1, z, Block::DIRT) if @world.get(x, y - 1, z) == Block::GRASS
  end

  # A light that changes at column x, z reaches Mesher::LIGHT_MAX blocks, so
  # every chunk in that square remeshes. These remeshes may wait for later frames.
  def mark_light_area(x, z)
    deferred = @defer
    @defer = true
    r = Mesher::LIGHT_MAX
    cx = (x - r) / CHUNK
    while cx <= (x + r) / CHUNK
      cz = (z - r) / CHUNK
      while cz <= (z + r) / CHUNK
        mark_chunk(cx, cz)
        cz += 1
      end
      cx += 1
    end
    @defer = deferred
  end

  def near_lava?(x, y, z)
    Block.lava?(@world.get(x + 1, y, z)) || Block.lava?(@world.get(x - 1, y, z)) || Block.lava?(@world.get(x, y + 1, z)) ||
      Block.lava?(@world.get(x, y - 1, z)) || Block.lava?(@world.get(x, y, z + 1)) || Block.lava?(@world.get(x, y, z - 1))
  end

  # Queues a cell and its six neighbors for the water simulation.
  def wake_water(x, y, z)
    @flow_queue << x << y << z
    @flow_queue << x + 1 << y << z
    @flow_queue << x - 1 << y << z
    @flow_queue << x << y + 1 << z
    @flow_queue << x << y - 1 << z
    @flow_queue << x << y << z + 1
    @flow_queue << x << y << z - 1
  end

  # The level a cell should have: 7 under falling water, else one less than the
  # best neighbor that spreads sideways (a source, or water resting on a solid block).
  def flow_target(x, y, z)
    return 7 if Block.water?(@world.get(x, y + 1, z))
    best = 0
    d = 0
    while d < 4
      nx = x + (d == 0 ? 1 : (d == 1 ? -1 : 0))
      nz = z + (d == 2 ? 1 : (d == 3 ? -1 : 0))
      level = Block::WATER_LEVEL[@world.get(nx, y, nz)]
      if level > 0 && (level == 8 || Block.solid?(@world.get(nx, y - 1, nz)))
        best = level - 1 if level - 1 > best
      end
      d += 1
    end
    best
  end

  # Lava's version of flow_target: it spreads 3 blocks.
  def lava_target(x, y, z)
    return 3 if Block.lava?(@world.get(x, y + 1, z))
    best = 0
    d = 0
    while d < 4
      nx = x + (d == 0 ? 1 : (d == 1 ? -1 : 0))
      nz = z + (d == 2 ? 1 : (d == 3 ? -1 : 0))
      level = Block.lava_level(@world.get(nx, y, nz))
      if level > 0 && (level == 4 || Block.solid?(@world.get(nx, y - 1, nz)))
        best = level - 1 if level - 1 > best
      end
      d += 1
    end
    best
  end

  def touches_water?(x, y, z)
    Block.water?(@world.get(x + 1, y, z)) || Block.water?(@world.get(x - 1, y, z)) ||
      Block.water?(@world.get(x, y + 1, z)) || Block.water?(@world.get(x, y, z + 1)) || Block.water?(@world.get(x, y, z - 1))
  end

  def update_water
    batch = @flow_queue
    @flow_queue = []
    @defer = true
    i = 0
    while i < batch.size && i < 6000
      x = batch[i]
      y = batch[i + 1]
      z = batch[i + 2]
      i += 3
      next unless @world.inside?(x, y, z)
      b = @world.get(x, y, z)
      if Block.lava?(b) && touches_water?(x, y, z)
        # Water cools lava into cobblestone.
        set_block(x, y, z, Block::COBBLE)
        next
      end
      level = Block::WATER_LEVEL[b]
      lava = Block.lava_level(b)
      next if level == 8 || lava == 4
      next unless b == Block::AIR || level > 0 || lava > 0 || Block.plant?(b)
      target = flow_target(x, y, z)
      lava_to = lava_target(x, y, z)
      want = if lava_to > 0
        Block::LAVA_FLOW + lava_to - 1
      elsif target > 0
        Block::FLOW + target - 1
      else
        Block::AIR
      end
      next if want == b
      next if want == Block::AIR && level == 0 && lava == 0
      set_block(x, y, z, want)
    end
    @flow_queue.concat(batch[i, batch.size - i]) if i < batch.size
    @defer = false
  end

  def falls?(b) = b == Block::SAND || b == Block::GRAVEL

  # A falling block passes air, water and plants.
  def lets_fall?(b) = b == Block::AIR || Block.water?(b) || Block.plant?(b)

  # Sand and gravel with nothing under them leave their cells and fall as
  # blocks in the air. update_falling moves them.
  def settle_column(x, z)
    moved = false
    y = 1
    while y < WY
      b = @world.get(x, y, z)
      if falls?(b) && lets_fall?(@world.get(x, y - 1, z))
        @world.set(x, y, z, Block::AIR)
        wake_water(x, y, z)
        @falling << FallingBlock.new(b, x, y.to_f, z)
        moved = true
      end
      y += 1
    end
    mark_dirty(x, z) if moved
  end

  # A falling block lands on the first cell that does not let it fall, and
  # set_block puts it there. It takes the place of a plant or a torch, so a
  # buried torch's light goes out. A block over a chunk that is not loaded
  # waits. A landing can make more blocks fall, so the list grows in the loop.
  def update_falling(dt)
    i = 0
    while i < @falling.size
      f = @falling[i]
      if @world.loaded?(f.x, f.z)
        f.fall(dt)
        if f.y < 0.0 || !lets_fall?(@world.get(f.x, f.y.floor, f.z))
          @falling.delete_at(i)
          land(f) if f.y >= 0.0
          next
        end
      end
      i += 1
    end
  end

  def land(f)
    y = f.y.floor + 1
    y += 1 while y < WY - 1 && !lets_fall?(@world.get(f.x, y, f.z))
    set_block(f.x, y, f.z, f.block)
  end

  # Lands the falling blocks at once, so that the save keeps them.
  def land_falling
    steps = 0
    while !@falling.empty? && steps < 500
      update_falling(0.05)
      steps += 1
    end
  end
end
