# The rules of the plants that grow, by themselves or with bone meal, and
# of the leaves that decay. Plants does not change the world. Each method
# adds its changes to a list, four Integers for each block (x, y, z and
# the new block), as World#plan_tree does. Game puts them in the world
# with Game#set_block, which also updates the meshes, the light and the
# water.
class Plants
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
  # Bone meal makes a plant grow. A sapling grows into its tree with this
  # chance. In Minecraft, a sapling has 2 stages, and each bone meal moves
  # it one stage with this chance. Here a sapling has 1 stage, as when it
  # grows by itself. minecraft.wiki/w/Bone_Meal
  SAPLING_MEAL_CHANCE = 0.45
  # Each second, the game looks at this many of the 81 x 81 columns near
  # the player, down through the leaves, the air and the logs on top. In
  # Minecraft, a block gets a random tick about each 68 seconds (3 in each
  # section of 16 x 16 x 16 each tick, minecraft.wiki/w/Tick), and then
  # leaves with no log near decay (minecraft.wiki/w/Leaves). With 96, a
  # column comes up about each 81 * 81 / 96 = 68 seconds.
  DECAY_SAMPLES = 96.0
  # Grass spreads only when the light above it is at least this. Here only
  # the sky light counts, not the light of a torch. minecraft.wiki/w/Grass_Block
  GRASS_LIGHT = 9
  # Each random tick of a grass block tries this many cells near it.
  # minecraft.wiki/w/Grass_Block
  GRASS_TRIES = 4
  # Leaves stay while a log is at most this many steps away through leaves.
  # minecraft.wiki/w/Leaves
  LEAF_REACH = 6
  LEAF_SPAN = LEAF_REACH * 2 + 1
  LEAF_DX = [1, -1, 0, 0, 0, 0]
  LEAF_DY = [0, 0, 1, -1, 0, 0]
  LEAF_DZ = [0, 0, 0, 0, 1, -1]

  # The stage of a crop at stage after bone meal adds ages. Its stages go
  # from 0 to last: 3 for wheat, and 2 for pumpkin seeds, a stem and a ripe
  # stem. Wheat and a stem have 8 ages in Minecraft, 0 to 7, and bone meal
  # adds 2 to 5 of them (minecraft.wiki/w/Bone_Meal, /w/Pumpkin_Seeds).
  # Here the 7 steps of age become the last steps of stage, so ages move
  # the crop ages * last / 7 stages, to the nearest stage. Wheat grows 1
  # stage for 2 or 3 ages and 2 stages for 4 or 5. A stem grows 1 stage.
  def self.meal_stage(stage, ages, last) = (stage + (ages * last * 2 + 7) / 14).clamp(0, last)

  # The column of the last random tick.
  attr_reader :column_x, :column_z

  def initialize(world, seed)
    @world = world
    @rng = Rng.new(seed)
    # The search of held_by_log?: cells to visit, and the cells seen in the
    # last search (LEAF_REACH around the leaves), by stamp.
    @leaf_queue = Array.new(0, 0)
    @leaf_seen = Array.new(LEAF_SPAN * LEAF_SPAN * LEAF_SPAN, 0)
    @leaf_stamp = 0
    @column_x = 0
    @column_z = 0
    nil
  end

  # The random ticks in dt seconds, at samples ticks for each second. The
  # part of a tick is the chance of one more.
  def random_ticks(dt, samples) = (dt * samples + @rng.rand01).to_i

  # One random tick of growth on a column within GROW_REACH of px, pz: the
  # sapling, the crop, the ripe stem or the cactus on top grows.
  def grow_column(px, pz, changes)
    pick_column(px, pz)
    x = @column_x
    z = @column_z
    return nil unless @world.loaded?(x, z)
    y = @world.height_at(x, z)
    b = @world.get(x, y, z)
    if (Block.sapling?(b) || Block.growing?(b)) && @rng.rand01 < GROW_CHANCE
      if Block.sapling?(b)
        grow_tree(x, y, z, Block.wood(b), changes)
      else
        changes << x << y << z << b + 1
      end
    elsif b == Block::PUMPKIN_STEM_RIPE && @rng.rand01 < GROW_CHANCE
      grow_pumpkin(x, y, z, changes)
    elsif b == Block::AIR && @world.get(x, y - 1, z) == Block::CACTUS && @rng.rand01 < CACTUS_CHANCE
      # A cactus blocks the light, so it is the block under height_at.
      grow_cactus(x, y - 1, z, changes)
    end
    nil
  end

  # One random tick of decay on a column within GROW_REACH of px, pz: down
  # through the leaves, the air and the logs on top, the leaves with no log
  # near become air. Leaves that the player placed stay.
  def decay_column(px, pz, changes)
    pick_column(px, pz)
    x = @column_x
    z = @column_z
    return nil unless @world.loaded?(x, z)
    y = @world.height_at(x, z) - 1
    while y > 0
      b = @world.get(x, y, z)
      if Block.leaves?(b)
        changes << x << y << z << Block::AIR if !Block.placed_leaves?(b) && !held_by_log?(x, y, z)
      elsif b != Block::AIR && !Block.log?(b)
        break
      end
      y -= 1
    end
    nil
  end

  # The y of the grass block on top of a column within GROW_REACH of px, pz,
  # under the air, the leaves and the plants, or -1 when that block is not
  # grass. The column is column_x, column_z.
  def grass_column(px, pz)
    pick_column(px, pz)
    y = @world.height_at(@column_x, @column_z)
    y -= 1 while y > 0 && Block::OPAQUE[@world.get(@column_x, y, @column_z)] == 0
    return y if @world.get(@column_x, y, @column_z) == Block::GRASS

    -1
  end

  # A random tick of the grass at x, y, z: GRASS_TRIES random cells of the
  # 3 x 5 x 3 cells around it, from 3 below it to 1 above it, turn from
  # dirt to grass. The block above such a cell must let light through, and
  # it must not be water or lava. Lava is opaque, so the light rule keeps it
  # out. minecraft.wiki/w/Grass_Block
  def grass_tick(x, y, z, changes)
    GRASS_TRIES.times do
      tx = x - 1 + (@rng.rand01 * 3.0).to_i
      ty = y - 3 + (@rng.rand01 * 5.0).to_i
      tz = z - 1 + (@rng.rand01 * 3.0).to_i
      above = @world.get(tx, ty + 1, tz)
      next if @world.get(tx, ty, tz) != Block::DIRT || Block::OPAQUE[above] != 0 || Block.water?(above)

      changes << tx << ty << tz << Block::GRASS
    end
    nil
  end

  # Picks a column within GROW_REACH of px, pz for a random tick.
  def pick_column(px, pz)
    span = GROW_REACH * 2 + 1
    @column_x = px - GROW_REACH + (@rng.rand01 * span).to_i
    @column_z = pz - GROW_REACH + (@rng.rand01 * span).to_i
    nil
  end

  # Bone meal on the block at x, y, z. A sapling may grow into a tree, a
  # crop or a pumpkin stem grows, and a grass block with air above it grows
  # plants around it. It returns false for a block that bone meal does not
  # change, so that the bone meal is not spent. Ripe wheat and a ripe stem
  # take none. minecraft.wiki/w/Bone_Meal does not say this for a stem; in
  # the code of Minecraft (StemBlock), a stem of age 7 takes no bone meal.
  def fertilize(x, y, z, changes)
    b = @world.get(x, y, z)
    if Block.sapling?(b)
      grow_tree(x, y, z, Block.wood(b), changes) if @rng.rand01 < SAPLING_MEAL_CHANCE
    elsif Block.growing?(b)
      first = b >= Block::PUMPKIN_SEEDS ? Block::PUMPKIN_SEEDS : Block::SEEDS
      last = (first == Block::SEEDS ? Block::WHEAT_RIPE : Block::PUMPKIN_STEM_RIPE) - first
      changes << x << y << z << first + Plants.meal_stage(b - first, 2 + (@rng.rand01 * 4.0).to_i, last)
    elsif b == Block::GRASS && @world.get(x, y + 1, z) == Block::AIR
      scatter_plants(x, y + 1, z, changes)
    else
      return false
    end
    true
  end

  # Bone meal on a grass block: tall grass and flowers grow on the grass
  # blocks around the cell x, y, z above it. As in Minecraft
  # (GrassBlock.performBonemeal, not on the wiki), 128 tries each walk
  # try / 16 random steps from the cell, along grass blocks with no solid
  # block on them, so the plants reach 7 blocks out: the 15 x 15 x 15 area
  # of minecraft.wiki/w/Bone_Meal. A try that ends in air grows tall grass,
  # or a flower 1 time in 8. The flower is a poppy 2 times in 3 and a
  # dandelion 1 time in 3, the flower_default feature of Minecraft (not on
  # the wiki). A plant grows only on a grass block, never on dirt or snow.
  # A cell gets one plant: the first try that ends in it.
  def scatter_plants(x, y, z, changes)
    128.times do |i|
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
      if ok && @world.get(px, py, pz) == Block::AIR && !listed?(changes, px, py, pz)
        plant = Block::TALL_GRASS
        plant = @rng.rand01 < 2.0 / 3.0 ? Block::ROSE : Block::DANDELION if @rng.rand01 < 0.125
        changes << px << py << pz << plant
      end
    end
    nil
  end

  # True when the changes have one for the block at x, y, z.
  def listed?(changes, x, y, z)
    i = 0
    while i < changes.size
      return true if changes[i] == x && changes[i + 1] == y && changes[i + 2] == z
      i += 4
    end
    false
  end

  # A ripe stem grows a pumpkin on a cell next to it, in a random
  # direction, when that cell is air over soil (Block.soil?). A stem with a
  # pumpkin next to it waits until the pumpkin goes. minecraft.wiki/w/Pumpkin_Seeds
  def grow_pumpkin(x, y, z, changes)
    d = 0
    while d < 4
      return nil if @world.get(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d]) == Block::PUMPKIN
      d += 1
    end
    d = (@rng.rand01 * 4).to_i
    px = x + Block::DIR_DX[d]
    pz = z + Block::DIR_DZ[d]
    ground = @world.get(px, y - 1, pz)
    return nil unless @world.get(px, y, pz) == Block::AIR && Block.soil?(ground)
    changes << px << y << pz << Block::PUMPKIN
    nil
  end

  # Puts a cactus on top of the cactus at x, y, z when the cactus is less
  # than CACTUS_HEIGHT tall and air is above it.
  def grow_cactus(x, y, z, changes)
    return nil unless y + 1 < WY && @world.get(x, y + 1, z) == Block::AIR
    tall = 1
    tall += 1 while tall < CACTUS_HEIGHT && @world.get(x, y - tall, z) == Block::CACTUS
    changes << x << y + 1 << z << Block::CACTUS if tall < CACTUS_HEIGHT
    nil
  end

  # A tree of wood (Block::OAK_WOOD and so on) from the sapling at x, y, z,
  # with the shape of the generator's tree (World#plan_tree). The sapling
  # waits when something is in the way of a log.
  def grow_tree(x, y, z, wood, changes)
    changes.concat(@world.plan_tree(x, y, z, wood))
    nil
  end

  # True when a log is at most LEAF_REACH steps from the leaves at x, y, z,
  # with leaves at each step, as in Minecraft.
  def held_by_log?(x, y, z) # rubocop:todo Metrics/MethodLength
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
end
