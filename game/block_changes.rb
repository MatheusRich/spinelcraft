# Block changes and what follows them: the blocks that break and what they
# drop, the changes of flowing water and lava (see Fluids), falling sand
# and gravel, and the plants that grow and the leaves that decay.
class Game
  def set_block(x, y, z, block) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    @changed = true
    old = @world.get(x, y, z)
    drop_chest(x, y, z) if Block::BASE[block] != Block::CHEST && Block::BASE[old] == Block::CHEST
    drop_furnace(x, y, z) if Block::BASE[old] == Block::FURNACE && Block::BASE[block] != Block::FURNACE
    # A door goes as a whole: removing one half removes the other.
    if Block.door?(old) && !Block.door?(block)
      @world.set(x, y, z, block)
      other = @world.door_partner(x, y, z)
      set_block(x, other, z, Block::AIR) if Block.door?(@world.get(x, other, z))
    end
    # A bed also goes as a whole. Each half faces away from the other.
    if Block.bed?(old) && !Block.bed?(block)
      @world.set(x, y, z, block)
      d = Block::FACING[old] ^ 1
      set_block(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d], Block::AIR) if Block.bed?(@world.get(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d]))
    end
    if block != old && (Block.chest_left?(old) || Block.chest_right?(old))
      @world.set(x, y, z, block)
      split_chest(x, y, z, old)
    end
    if Block.emits?(block) || Block.emits?(old) || (Block::OPAQUE[block] == 0 && @world.near_lava?(x, y, z))
      mark_light_area(x, z)
    end
    @world.set(x, y, z, block)
    @chunk_meshes.mark_block(x, z)
    release_unheld(x, y, z)
    release_if_unheld(x, y, z) if Block.falls?(block)
    @fluids.wake(x, y, z)
  end

  # Releases each block next to x, y, z that the world can no longer hold
  # (see release_if_unheld): a plant or a torch on top, sand or gravel on
  # top, a wall torch or a ladder on a side, or a cactus on any side.
  def release_unheld(x, y, z)
    release_if_unheld(x, y + 1, z)
    release_if_unheld(x, y - 1, z)
    dir = 0
    while dir < 4
      release_if_unheld(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir])
      dir += 1
    end
  end

  # When the world can no longer hold the block at x, y, z (see
  # World#can_hold?), sand and gravel fall, and any other block breaks
  # and drops its item, as a torch does in Minecraft
  # (minecraft.wiki/w/Torch). The wiki does not say this for each plant
  # and for a ladder.
  def release_if_unheld(x, y, z)
    block = @world.get(x, y, z)
    return if @world.can_hold?(block, x, y, z)

    if Block.falls?(block)
      start_fall(x, y, z, block)
    else
      break_block(x, y, z)
    end
  end

  # Sand or gravel at x, y, z leaves its cell and falls as a block in the
  # air. update_falling moves it.
  def start_fall(x, y, z, block)
    @falling << FallingBlock.new(block, x.to_i, y.to_f, z.to_i)
    set_block(x, y, z, Block::AIR)
  end

  # Breaks the block at x, y, z with no tool (see drop_broken).
  def break_block(x, y, z)
    block = @world.get(x, y, z)
    set_block(x, y, z, Block::AIR)
    drop_broken(block, x, y, z, Block::AIR)
  end

  # Drops what block drops when tool breaks it at x, y, z. Block::AIR is no
  # tool, as when water washes a plant away. Leaves or grass that shears
  # cut drop themselves (see Block.shears_cut?). Any other block drops its
  # Block::DROPS and its extras (see drop_extra). The pickaxe tier counts
  # only when the player mines, so mine checks it.
  def drop_broken(block, x, y, z, tool)
    if tool == Block::SHEARS && Block.shears_cut?(block)
      drop_from_block(Block::BASE[block], 1, x, y, z)
    else
      drop_from_block(Block::DROPS[block], 1, x, y, z)
      drop_extra(block, x, y, z)
    end
  end

  # What a broken block drops besides Block::DROPS: leaves now and then a
  # sapling of their wood, oak leaves also now and then an apple, tall
  # grass now and then seeds, and ripe wheat 1 to 4 seeds.
  def drop_extra(block, x, y, z)
    if Block.leaves?(block)
      # Leaves drop a sapling 1 time in 20, and oak leaves also an apple 1
      # time in 200. Leaves also drop a stick 1 time in 50, but the game
      # has no sticks. minecraft.wiki/w/Leaves
      drop_from_block(Block::SAPLINGS[Block.wood(block)], 1, x, y, z) if @rng.rand01 < 0.05
      drop_from_block(Block::APPLE, 1, x, y, z) if Block::BASE[block] == Block::OAK_LEAVES && @rng.rand01 < 0.005
    elsif block == Block::TALL_GRASS
      drop_from_block(Block::SEEDS, 1, x, y, z) if @rng.rand01 < 0.125
    elsif block == Block::WHEAT_RIPE
      drop_from_block(Block::SEEDS, ripe_wheat_seeds, x, y, z)
    end
  end

  # Ripe wheat drops 1 seed, and 1 more for each of 3 tries with a chance
  # of 4/7, so about 2 5/7 seeds. minecraft.wiki/w/Wheat_Seeds
  def ripe_wheat_seeds
    seeds = 1
    3.times { seeds += 1 if @rng.rand01 < 4.0 / 7.0 }
    seeds
  end

  # Puts block, water, lava or the air of drained fluid, at x, y, z. Water
  # washes a plant or a torch away, and it drops. Lava burns it, and it
  # drops nothing. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
  def pour(x, y, z, block)
    old = @world.get(x, y, z)
    drop_broken(old, x, y, z, Block::AIR) if Block.plant?(old) && Block.water?(block)
    set_block(x, y, z, block)
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

  # Grass spreads onto dirt near it in the random ticks of the columns near
  # the player, when the sky light above the grass is at least
  # Plants::GRASS_LIGHT (see Plants#grass_tick). At night the sky light
  # is less, so grass does not spread.
  def spread_grass(dt)
    sky = Light.sky(@clock.ticks, raining: @weather.raining?)
    return if sky < Plants::GRASS_LIGHT

    @plants.random_ticks(dt, Plants::DECAY_SAMPLES).times do
      y = @plants.grass_column(@player.x.floor.to_i, @player.z.floor.to_i)
      next if y < 0

      x = @plants.column_x
      z = @plants.column_z
      next if @light.level(x, y + 1, z, sky, false, sky - Plants::GRASS_LIGHT + 1) < Plants::GRASS_LIGHT

      @plants.grass_tick(x, y, z, @changes)
      apply_changes
    end
    nil
  end

  # Grass under an opaque block turns to dirt in the random ticks of the
  # columns near the player (see Plants#covered_grass_column). It needs no
  # light, so it happens at night too.
  def kill_covered_grass(dt)
    @plants.random_ticks(dt, Plants::DECAY_SAMPLES).times do
      @plants.covered_grass_column(@player.x.floor.to_i, @player.z.floor.to_i, @changes)
      apply_changes
    end
    nil
  end

  # Decayed leaves break, and now and then they drop a sapling or an
  # apple. Each change of Plants#decay_column is air.
  def decay_leaves(dt)
    @plants.random_ticks(dt, Plants::DECAY_SAMPLES).times do
      @plants.decay_column(@player.x.floor.to_i, @player.z.floor.to_i, @changes)
      i = 0
      while i < @changes.size
        break_block(@changes[i], @changes[i + 1], @changes[i + 2])
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

  # Puts the changes of the steps of water and lava that start after dt
  # more seconds in the world (see Fluids). The remeshes of flowing water
  # and lava may wait for later frames.
  def update_fluids(dt)
    marked = @chunk_meshes.dirty_count
    flow_water if @fluids.water_step?(dt)
    flow_lava if @fluids.lava_step?(dt)
    @chunk_meshes.postpone_since(marked)
  end

  # Puts the changes of a step of water in the world, one at a time. Water
  # that cools lava hisses once in a step.
  def flow_water
    hiss = false
    while @fluids.next_water(@changes)
      if @changes[3] == Block::COBBLE && !hiss
        play_at(Sfx::FIZZ, @changes[0] + 0.5, @changes[1] + 0.5, @changes[2] + 0.5, 0.6)
        hiss = true
      end
      pour_change
    end
  end

  # Puts the changes of a step of lava in the world, one at a time.
  def flow_lava
    pour_change while @fluids.next_lava(@changes)
  end

  # Pours the one change in @changes (x, y, z and the block), and clears
  # the list.
  def pour_change
    x = @changes[0]
    y = @changes[1]
    z = @changes[2]
    block = @changes[3]
    @changes.clear
    pour(x, y, z, block)
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
        if f.y < 0.0 || !Block.lets_fall?(@world.get(f.x, f.y.floor, f.z))
          @falling.delete_at(i)
          land(f) if f.y >= 0.0
          next
        end
      end
      i += 1
    end
  end

  # The block takes the place of a block that Block.replaceable? names:
  # air, water, lava or grass. In a torch or another plant it breaks and
  # drops as an item, and the plant stays. minecraft.wiki/w/Falling_Block;
  # the wiki does not list the blocks that a falling block replaces.
  def land(f)
    y = f.y.floor + 1
    y += 1 while y < WY - 1 && !Block.lets_fall?(@world.get(f.x, y, f.z))
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
