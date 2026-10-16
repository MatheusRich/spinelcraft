# Block changes and what follows them: flowing water and lava, falling sand and gravel.
class Game
  def set_block(x, y, z, b)
    @changed = true
    old = @world.get(x, y, z)
    drop_chest(x, y, z) if Block::BASE[b] != Block::CHEST && Block::BASE[old] == Block::CHEST
    drop_furnace(x, y, z) if Block::BASE[old] == Block::FURNACE && Block::BASE[b] != Block::FURNACE
    # A door goes as a whole: removing one half removes the other.
    if Block.door?(old) && !Block.door?(b)
      @world.set(x, y, z, b)
      other = door_partner(x, y, z)
      set_block(x, other, z, Block::AIR) if Block.door?(@world.get(x, other, z))
    end
    # A bed also goes as a whole. Each half faces away from the other.
    if Block.bed?(old) && !Block.bed?(b)
      @world.set(x, y, z, b)
      d = Block::FACING[old] ^ 1
      set_block(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d], Block::AIR) if Block.bed?(@world.get(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d]))
    end
    if Block.emits?(b) || Block.emits?(old) || (Block::OPAQUE[b] == 0 && near_lava?(x, y, z))
      mark_light_area(x, z)
    end
    @world.set(x, y, z, b)
    @chunk_meshes.mark_block(x, z)
    break_unheld_cactus(x, y + 1, z)
    if b == Block::AIR
      above = @world.get(x, y + 1, z)
      set_block(x, y + 1, z, Block::AIR) if Block.plant?(above) && !Block.wall_torch?(above)
      # A wall torch or a ladder falls with the block that holds it.
      d = 0
      while d < 4
        tx = x + Block::DIR_DX[d]
        tz = z + Block::DIR_DZ[d]
        t = @world.get(tx, y, tz)
        set_block(tx, y, tz, Block::AIR) if t == Block.facing_id(Block::TORCH, d) || t == Block.facing_id(Block::LADDER, d)
        d += 1
      end
    end
    settle_column(x, z)
    wake_water(x, y, z)
  end

  # A cactus breaks and drops when the block under it is not sand or a
  # cactus. minecraft.wiki/w/Cactus
  def break_unheld_cactus(x, y, z)
    return unless @world.get(x, y, z) == Block::CACTUS
    below = @world.get(x, y - 1, z)
    return if below == Block::SAND || below == Block::CACTUS
    set_block(x, y, z, Block::AIR)
    drop_from_block(Block::CACTUS, 1, x, y, z)
  end

  # Each second, the game looks at this many of the 81 x 81 columns near the
  # player for a sapling, a crop or a cactus on top. Only a plant under the
  # open sky grows. Each one that it finds grows (a sapling into a tree, a crop to
  # its next stage) with chance GROW_CHANCE. That is a step in about
  # 81 * 81 / (1100 * 0.1) = 60 seconds.
  GROW_SAMPLES = 1100.0
  GROW_REACH = 40
  GROW_CHANCE = 0.1
  # A cactus grows a block after 16 random ticks on its top block, and a
  # block gets a random tick about each 68 seconds (DECAY_SAMPLES), so a
  # cactus grows a block in about 18 minutes. It grows to 3 blocks.
  # minecraft.wiki/w/Cactus
  CACTUS_TICKS = 16.0
  CACTUS_HEIGHT = 3
  CACTUS_CHANCE = 81.0 * 81.0 / GROW_SAMPLES / (68.0 * CACTUS_TICKS)

  def grow_plants(dt)
    n = (dt * GROW_SAMPLES + @rng.rand01).to_i
    span = GROW_REACH * 2 + 1
    while n > 0
      x = @player.x.floor - GROW_REACH + (@rng.rand01 * span).to_i
      z = @player.z.floor - GROW_REACH + (@rng.rand01 * span).to_i
      if @world.loaded?(x, z)
        y = @world.height_at(x, z)
        b = @world.get(x, y, z)
        if (Block.sapling?(b) || Block.growing?(b)) && @rng.rand01 < GROW_CHANCE
          Block.sapling?(b) ? grow_tree(x, y, z, Block.wood(b)) : set_block(x, y, z, b + 1)
        elsif b == Block::PUMPKIN_STEM_RIPE && @rng.rand01 < GROW_CHANCE
          grow_pumpkin(x, y, z)
        elsif b == Block::AIR && @world.get(x, y - 1, z) == Block::CACTUS && @rng.rand01 < CACTUS_CHANCE
          # A cactus blocks the light, so it is the block under height_at.
          grow_cactus(x, y - 1, z)
        end
      end
      n -= 1
    end
  end

  # Bone meal makes a plant grow. A sapling grows into its tree with this
  # chance. In Minecraft, a sapling has 2 stages, and each bone meal moves
  # it one stage with this chance. Here a sapling has 1 stage, as when it
  # grows by itself. minecraft.wiki/w/Bone_Meal
  SAPLING_MEAL_CHANCE = 0.45

  # Uses bone meal on the block at x, y, z. A sapling may grow into a tree,
  # a crop or a pumpkin stem grows, and a grass block with air above it
  # grows plants around it. It returns false for a block that bone meal
  # does not change, so that the bone meal is not spent. Ripe wheat and a
  # ripe stem take none. minecraft.wiki/w/Bone_Meal does not say this for
  # a stem; in the code of Minecraft (StemBlock), a stem of age 7 takes no
  # bone meal.
  def fertilize(x, y, z)
    b = @world.get(x, y, z)
    if Block.sapling?(b)
      grow_tree(x, y, z, Block.wood(b)) if @rng.rand01 < SAPLING_MEAL_CHANCE
    elsif Block.growing?(b)
      first = b >= Block::PUMPKIN_SEEDS ? Block::PUMPKIN_SEEDS : Block::SEEDS
      last = (first == Block::SEEDS ? Block::WHEAT_RIPE : Block::PUMPKIN_STEM_RIPE) - first
      set_block(x, y, z, first + Game.meal_stage(b - first, 2 + (@rng.rand01 * 4.0).to_i, last))
    elsif b == Block::GRASS && @world.get(x, y + 1, z) == Block::AIR
      scatter_plants(x, y + 1, z)
    else
      return false
    end
    true
  end

  # The stage of a crop at stage after bone meal adds ages. Its stages go
  # from 0 to last: 3 for wheat, and 2 for pumpkin seeds, a stem and a ripe
  # stem. Wheat and a stem have 8 ages in Minecraft, 0 to 7, and bone meal
  # adds 2 to 5 of them (minecraft.wiki/w/Bone_Meal, /w/Pumpkin_Seeds).
  # Here the 7 steps of age become the last steps of stage, so ages move
  # the crop ages * last / 7 stages, to the nearest stage. Wheat grows 1
  # stage for 2 or 3 ages and 2 stages for 4 or 5. A stem grows 1 stage.
  def self.meal_stage(stage, ages, last) = (stage + (ages * last * 2 + 7) / 14).clamp(0, last)

  # Bone meal on a grass block: tall grass and flowers grow on the grass
  # blocks around the cell x, y, z above it. As in Minecraft
  # (GrassBlock.performBonemeal, not on the wiki), 128 tries each walk
  # try / 16 random steps from the cell, along grass blocks with no solid
  # block on them, so the plants reach 7 blocks out: the 15 x 15 x 15 area
  # of minecraft.wiki/w/Bone_Meal. A try that ends in air grows tall grass,
  # or a flower 1 time in 8. The flower is a poppy 2 times in 3 and a
  # dandelion 1 time in 3, the flower_default feature of Minecraft (not on
  # the wiki). A plant grows only on a grass block, never on dirt or snow.
  def scatter_plants(x, y, z)
    i = 0
    while i < 128
      px = x
      py = y
      pz = z
      ok = true
      j = 0
      while ok && j < i / 16
        px += (@rng.rand01 * 3.0).to_i - 1
        py += ((@rng.rand01 * 3.0).to_i - 1) * ((@rng.rand01 * 3.0).to_i / 2)
        pz += (@rng.rand01 * 3.0).to_i - 1
        ok = @world.get(px, py - 1, pz) == Block::GRASS && !Block.solid?(@world.get(px, py, pz))
        j += 1
      end
      if ok && @world.get(px, py, pz) == Block::AIR
        plant = Block::TALL_GRASS
        plant = @rng.rand01 < 2.0 / 3.0 ? Block::ROSE : Block::DANDELION if @rng.rand01 < 0.125
        set_block(px, py, pz, plant)
      end
      i += 1
    end
  end

  # A ripe stem grows a pumpkin on a cell next to it, in a random
  # direction, when that cell is air over soil (Block.soil?). A stem with a
  # pumpkin next to it waits until the pumpkin goes. minecraft.wiki/w/Pumpkin_Seeds
  def grow_pumpkin(x, y, z)
    d = 0
    while d < 4
      return if @world.get(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d]) == Block::PUMPKIN
      d += 1
    end
    d = (@rng.rand01 * 4).to_i
    px = x + Block::DIR_DX[d]
    pz = z + Block::DIR_DZ[d]
    ground = @world.get(px, y - 1, pz)
    return unless @world.get(px, y, pz) == Block::AIR && Block.soil?(ground)
    set_block(px, y, pz, Block::PUMPKIN)
  end

  # Puts a cactus on top of the cactus at x, y, z when the cactus is less
  # than CACTUS_HEIGHT tall and air is above it.
  def grow_cactus(x, y, z)
    return unless y + 1 < WY && @world.get(x, y + 1, z) == Block::AIR
    tall = 1
    tall += 1 while tall < CACTUS_HEIGHT && @world.get(x, y - tall, z) == Block::CACTUS
    set_block(x, y + 1, z, Block::CACTUS) if tall < CACTUS_HEIGHT
  end

  # Each second, the game looks at this many of the 81 x 81 columns near
  # the player, down through the leaves, the air and the logs on top. In
  # Minecraft, a block gets a random tick about each 68 seconds (3 in each
  # section of 16 x 16 x 16 each tick, minecraft.wiki/w/Tick), and then
  # leaves with no log near decay (minecraft.wiki/w/Leaves). With 96, a
  # column comes up about each 81 * 81 / 96 = 68 seconds.
  DECAY_SAMPLES = 96.0
  # Leaves stay while a log is at most this many steps away through leaves.
  # minecraft.wiki/w/Leaves
  LEAF_REACH = 6
  LEAF_SPAN = LEAF_REACH * 2 + 1
  LEAF_DX = [1, -1, 0, 0, 0, 0]
  LEAF_DY = [0, 0, 1, -1, 0, 0]
  LEAF_DZ = [0, 0, 0, 0, 1, -1]

  def decay_leaves(dt)
    n = (dt * DECAY_SAMPLES + @rng.rand01).to_i
    span = GROW_REACH * 2 + 1
    while n > 0
      x = @player.x.floor - GROW_REACH + (@rng.rand01 * span).to_i
      z = @player.z.floor - GROW_REACH + (@rng.rand01 * span).to_i
      if @world.loaded?(x, z)
        y = @world.height_at(x, z) - 1
        while y > 0
          b = @world.get(x, y, z)
          if Block.leaves?(b)
            if !Block.placed_leaves?(b) && !held_by_log?(x, y, z)
              set_block(x, y, z, Block::AIR)
              drop_extra(b, x, y, z)
            end
          elsif b != Block::AIR && !Block.log?(b)
            break
          end
          y -= 1
        end
      end
      n -= 1
    end
  end

  # True when a log is at most LEAF_REACH steps from the leaves at x, y, z,
  # with leaves at each step, as in Minecraft.
  def held_by_log?(x, y, z)
    @leaf_stamp += 1
    q = @leaf_queue
    q.clear
    q << x << y << z << 0
    @leaf_seen[(LEAF_REACH * LEAF_SPAN + LEAF_REACH) * LEAF_SPAN + LEAF_REACH] = @leaf_stamp
    head = 0
    while head < q.size
      qx = q[head]
      qy = q[head + 1]
      qz = q[head + 2]
      d = q[head + 3]
      head += 4
      i = 0
      while i < 6
        nx = qx + LEAF_DX[i]
        ny = qy + LEAF_DY[i]
        nz = qz + LEAF_DZ[i]
        b = @world.get(nx, ny, nz)
        return true if Block.log?(b)
        if d + 1 < LEAF_REACH && Block.leaves?(b)
          k = ((nx - x + LEAF_REACH) * LEAF_SPAN + ny - y + LEAF_REACH) * LEAF_SPAN + nz - z + LEAF_REACH
          if @leaf_seen[k] != @leaf_stamp
            @leaf_seen[k] = @leaf_stamp
            q << nx << ny << nz << d + 1
          end
        end
        i += 1
      end
    end
    false
  end

  # Grows a tree of wood (Block::OAK_WOOD and so on) from the sapling at
  # x, y, z, with the shape of the generator's tree (World#plan_tree). The
  # sapling waits when something is in the way of a log.
  def grow_tree(x, y, z, wood)
    plan = @world.plan_tree(x, y, z, wood)
    i = 0
    while i < plan.size
      set_block(plan[i], plan[i + 1], plan[i + 2], plan[i + 3].to_i)
      i += 4
    end
  end

  # A light that changes at column x, z reaches Mesher::LIGHT_MAX blocks, so
  # every chunk in that square remeshes. These remeshes may wait for later frames.
  def mark_light_area(x, z)
    r = Mesher::LIGHT_MAX
    cx = (x.to_i - r) / CHUNK
    while cx <= (x.to_i + r) / CHUNK
      cz = (z.to_i - r) / CHUNK
      while cz <= (z.to_i + r) / CHUNK
        @chunk_meshes.mark_later(cx, cz)
        cz += 1
      end
      cx += 1
    end
    nil
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

  def touches_water?(x, y, z)
    Block.water?(@world.get(x + 1, y, z)) || Block.water?(@world.get(x - 1, y, z)) ||
      Block.water?(@world.get(x, y + 1, z)) || Block.water?(@world.get(x, y, z + 1)) || Block.water?(@world.get(x, y, z - 1))
  end

  def update_water
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
      if Block.lava?(b) && touches_water?(x, y, z)
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
      set_block(x, y, z, want)
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
    y = 1
    while y < WY
      b = @world.get(x, y, z)
      if falls?(b) && lets_fall?(@world.get(x, y - 1, z))
        @world.set(x, y, z, Block::AIR)
        wake_water(x, y, z)
        @falling << FallingBlock.new(b, x, y.to_f, z)
        moved = true
        break_unheld_cactus(x, y + 1, z)
      end
      y += 1
    end
    @chunk_meshes.mark_block(x, z) if moved
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
