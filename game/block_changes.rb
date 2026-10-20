# Block changes and what follows them: flowing water and lava, falling sand
# and gravel, and the plants that grow and the leaves that decay.
class Game
  def set_block(x, y, z, b) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    @changed = true
    old = @world.get(x, y, z)
    drop_chest(x, y, z) if Block::BASE[b] != Block::CHEST && Block::BASE[old] == Block::CHEST
    drop_furnace(x, y, z) if Block::BASE[old] == Block::FURNACE && Block::BASE[b] != Block::FURNACE
    # A door goes as a whole: removing one half removes the other.
    if Block.door?(old) && !Block.door?(b)
      @world.set(x, y, z, b)
      other = @world.door_partner(x, y, z)
      set_block(x, other, z, Block::AIR) if Block.door?(@world.get(x, other, z))
    end
    # A bed also goes as a whole. Each half faces away from the other.
    if Block.bed?(old) && !Block.bed?(b)
      @world.set(x, y, z, b)
      d = Block::FACING[old] ^ 1
      set_block(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d], Block::AIR) if Block.bed?(@world.get(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d]))
    end
    if b != old && (Block.chest_left?(old) || Block.chest_right?(old))
      @world.set(x, y, z, b)
      split_chest(x, y, z, old)
    end
    if Block.emits?(b) || Block.emits?(old) || (Block::OPAQUE[b] == 0 && @world.near_lava?(x, y, z))
      mark_light_area(x, z)
    end
    @world.set(x, y, z, b)
    @chunk_meshes.mark_block(x, z)
    break_unheld(x, y, z)
    settle_column(x, z)
    wake_water(x, y, z)
  end

  # Breaks each block next to x, y, z that the world can no longer hold
  # (see World#can_hold?): a plant or a torch on top, a wall torch or a
  # ladder on a side, or a cactus. Each one drops its item, as a torch
  # does in Minecraft (minecraft.wiki/w/Torch). The wiki does not say this
  # for each plant and for a ladder.
  def break_unheld(x, y, z)
    break_if_unheld(x, y + 1, z)
    dir = 0
    while dir < 4
      break_if_unheld(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir])
      dir += 1
    end
  end

  def break_if_unheld(x, y, z)
    block = @world.get(x, y, z)
    break_block(x, y, z) unless @world.can_hold?(block, x, y, z)
  end

  # Breaks the block at x, y, z with no tool (see drop_broken).
  def break_block(x, y, z)
    b = @world.get(x, y, z)
    set_block(x, y, z, Block::AIR)
    drop_broken(b, x, y, z)
  end

  # Drops what block b drops when it breaks at x, y, z with no tool: its
  # item and its extras (see drop_extra). Unlike mine, it does not check
  # the pickaxe tier, because no block that it breaks needs a pickaxe.
  def drop_broken(b, x, y, z)
    drop_from_block(Block::DROPS[b], 1, x, y, z)
    drop_extra(b, x, y, z)
  end

  # Puts b, water, lava or the air of drained fluid, at x, y, z. Water
  # washes a plant or a torch away, and it drops. Lava burns it, and it
  # drops nothing. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
  def pour(x, y, z, b)
    old = @world.get(x, y, z)
    drop_broken(old, x, y, z) if Block.plant?(old) && Block.water?(b)
    set_block(x, y, z, b)
  end

  # The half old of a large chest at x, y, z is gone, so the other half is
  # a chest of one block again. It keeps its contents.
  def split_chest(x, y, z, old)
    d = Block.chest_partner_dir(old)
    px = x + Block::DIR_DX[d]
    pz = z + Block::DIR_DZ[d]
    other = @world.get(px, y, pz)
    paired = Block.chest_left?(old) ? Block.chest_right?(other) : Block.chest_left?(other)
    set_block(px, y, pz, Block.facing_id(Block::CHEST, Block::FACING[old])) if paired && Block::FACING[other] == Block::FACING[old]
  end

  # The random ticks of growth and of decay near the player, and the
  # changes that each one makes (see Plants).
  def grow_plants(dt)
    @plants.random_ticks(dt, Plants::GROW_SAMPLES).times do
      @plants.grow_column(@player.x.floor.to_i, @player.z.floor.to_i, @changes)
      apply_changes
    end
    nil
  end

  # Decayed leaves drop their extras: now and then a sapling or an apple.
  def decay_leaves(dt)
    @plants.random_ticks(dt, Plants::DECAY_SAMPLES).times do
      @plants.decay_column(@player.x.floor.to_i, @player.z.floor.to_i, @changes)
      i = 0
      while i < @changes.size
        x = @changes[i]
        y = @changes[i + 1]
        z = @changes[i + 2]
        b = @world.get(x, y, z)
        set_block(x, y, z, @changes[i + 3])
        drop_extra(b, x, y, z)
        i += 4
      end
      @changes.clear
    end
    nil
  end

  # Puts the changes of Plants in the world, and clears the list.
  def apply_changes
    i = 0
    while i < @changes.size
      set_block(@changes[i], @changes[i + 1], @changes[i + 2], @changes[i + 3])
      i += 4
    end
    @changes.clear
    nil
  end

  # A light that changes at column x, z reaches Mesher::LIGHT_MAX blocks, so
  # every chunk in that square remeshes. These remeshes may wait for later frames.
  def mark_light_area(x, z)
    r = Mesher::LIGHT_MAX
    ((x.to_i - r) / CHUNK..(x.to_i + r) / CHUNK).each do |cx|
      ((z.to_i - r) / CHUNK..(z.to_i + r) / CHUNK).each { |cz| @chunk_meshes.mark_later(cx, cz) }
    end
    nil
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

  # The level of water (or of lava, when lava is true) that a cell should
  # have: one less than a source under falling fluid, else one less than
  # the best neighbor that spreads sideways (a source, or fluid resting on a
  # solid block). Water spreads 7 blocks and lava 3.
  def flow_target(x, y, z, lava)
    source = lava ? 4 : 8
    return source - 1 if fluid_level(@world.get(x, y + 1, z), lava) > 0
    best = 0
    d = 0
    while d < 4
      nx = x + Block::DIR_DX[d]
      nz = z + Block::DIR_DZ[d]
      level = fluid_level(@world.get(nx, y, nz), lava)
      if level > 0 && (level == source || Block.solid?(@world.get(nx, y - 1, nz)))
        best = level - 1 if level - 1 > best
      end
      d += 1
    end
    best
  end

  # The level of block b as water (8 for a source), or as lava (4 for a
  # source) when lava is true; 0 when it is not that fluid.
  def fluid_level(b, lava) = lava ? Block.lava_level(b) : Block::WATER_LEVEL[b]

  def update_water # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    batch = @flow_queue
    @flow_queue = []
    # The remeshes of flowing water may wait for later frames.
    marked = @chunk_meshes.dirty_count
    hiss = false
    i = 0
    while i < batch.size && i < 6000
      x = batch[i]
      y = batch[i + 1]
      z = batch[i + 2]
      i += 3
      next unless @world.inside?(x, y, z)
      b = @world.get(x, y, z)
      if Block.lava?(b) && @world.touches_water?(x, y, z)
        # Water cools lava into cobblestone.
        set_block(x, y, z, Block::COBBLE)
        play_at(Sfx::FIZZ, x + 0.5, y + 0.5, z + 0.5, 0.6, SOUND_RANGE) unless hiss
        hiss = true
        next
      end
      level = Block::WATER_LEVEL[b]
      lava = Block.lava_level(b)
      next if level == 8 || lava == 4
      next unless b == Block::AIR || level > 0 || lava > 0 || Block.plant?(b)
      target = flow_target(x, y, z, false)
      lava_to = flow_target(x, y, z, true)
      want = if lava_to > 0
        Block::LAVA_FLOW + lava_to - 1
      elsif target > 0
        Block::FLOW + target - 1
      else
        Block::AIR
      end
      next if want == b
      next if want == Block::AIR && level == 0 && lava == 0
      pour(x, y, z, want)
    end
    @flow_queue.concat(batch[i, batch.size - i]) if i < batch.size
    @chunk_meshes.postpone_since(marked)
  end

  def falls?(b) = b == Block::SAND || b == Block::GRAVEL

  # A falling block passes air, water and plants.
  def lets_fall?(b) = b == Block::AIR || Block.water?(b) || Block.plant?(b)

  # Sand and gravel with nothing under them leave their cells and fall as
  # blocks in the air. update_falling moves them.
  def settle_column(x, z)
    moved = false
    (1...WY).each do |y|
      b = @world.get(x, y, z)
      if falls?(b) && lets_fall?(@world.get(x, y - 1, z))
        @world.set(x, y, z, Block::AIR)
        wake_water(x, y, z)
        @falling << FallingBlock.new(b, x, y.to_f, z)
        moved = true
        break_unheld(x, y, z)
      end
    end
    @chunk_meshes.mark_block(x, z) if moved
  end

  # A falling block lands on the first cell that does not let it fall (see
  # land). A block over a chunk that is not loaded waits. A landing can make
  # more blocks fall, so the list grows in the loop.
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

  # The block takes the place of air, water, or the grass that
  # Block.replaceable? names. In a torch or another plant it breaks and
  # drops as an item, and the plant stays. minecraft.wiki/w/Falling_Block;
  # the wiki does not list the blocks that a falling block replaces.
  def land(f)
    y = f.y.floor + 1
    y += 1 while y < WY - 1 && !lets_fall?(@world.get(f.x, y, f.z))
    cell = @world.get(f.x, y, f.z)
    if Block.plant?(cell) && !Block.replaceable?(cell)
      drop_from_block(f.block, 1, f.x, y, f.z)
    else
      set_block(f.x, y, f.z, f.block)
    end
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
