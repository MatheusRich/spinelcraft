# Block changes and what follows them: flowing water and lava, falling sand and gravel.
class Game
  def set_block(x, y, z, b)
    @changed = true
    drop_chest(x, y, z) if b != Block::CHEST && @world.get(x, y, z) == Block::CHEST
    old = @world.get(x, y, z)
    if Block.emits?(b) || Block.emits?(old) || (Block::OPAQUE[b] == 0 && near_lava?(x, y, z))
      mark_light_area(x, z)
    end
    @world.set(x, y, z, b)
    mark_dirty(x, z)
    set_block(x, y + 1, z, Block::AIR) if b == Block::AIR && Block::PLANT[@world.get(x, y + 1, z)] == 1
    settle_column(x, z)
    wake_water(x, y, z)
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
      if level > 0 && (level == 8 || Block::SOLID[@world.get(nx, y - 1, nz)] == 1)
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
      if level > 0 && (level == 4 || Block::SOLID[@world.get(nx, y - 1, nz)] == 1)
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
      next unless b == Block::AIR || level > 0 || lava > 0 || Block::PLANT[b] == 1
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

  # Sand and gravel drop onto the first block below that holds them.
  def settle_column(x, z)
    moved = false
    y = 1
    while y < WY
      b = @world.get(x, y, z)
      if falls?(b)
        below = @world.get(x, y - 1, z)
        if below == Block::AIR || Block.water?(below) || Block::PLANT[below] == 1
          ty = y - 1
          while ty > 0
            under = @world.get(x, ty - 1, z)
            break unless under == Block::AIR || Block.water?(under) || Block::PLANT[under] == 1
            ty -= 1
          end
          # The block lands in the place of a plant or a torch: a buried torch's light goes out.
          mark_light_area(x, z) if Block.emits?(@world.get(x, ty, z))
          @world.set(x, y, z, Block::AIR)
          @world.set(x, ty, z, b)
          wake_water(x, y, z)
          wake_water(x, ty, z)
          moved = true
        end
      end
      y += 1
    end
    mark_dirty(x, z) if moved
  end
end
