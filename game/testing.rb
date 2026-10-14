# Test switches: SELFTEST, SHOWMOBS, SHOWITEMS, and DEMO.
class Game
  # SHOWMOBS=1 lines up one mob of each kind on a stone floor in front of the player.
  def show_mobs
    @mobs.clear
    bx = @player.x.floor
    bz = @player.z.floor - 6
    y = 80
    dx = -4
    while dx <= 4
      dz = -3
      while dz <= 3
        set_block(bx + dx, y, bz + dz, Block::STONE)
        dz += 1
      end
      dx += 1
    end
    set_block(bx - 3, y + 1, bz + 2, Block::BED)
    set_block(bx - 2, y + 1, bz + 2, Block::BED_HEAD)
    set_block(bx + 3, y + 1, bz + 2, Block::TORCH)
    [Mob::PIG, Mob::SHEEP, Mob::ZOMBIE, Mob::SKELETON, Mob::CREEPER].each_with_index do |kind, i|
      m = Mob.new(kind, bx - 4.0 + i * 2.0, y + 1.0, bz + 0.5, 1)
      m.yaw = 3.14159
      @mobs << m
    end
    @player.x = bx + 0.5
    @player.y = y + 1.5
    @player.z = bz + 6.5
    @player.yaw = 0.0
    @player.pitch = -0.15
    @player.flying = true
    @time_of_day = 0.3
  end

  # SHOWITEMS=1 lays a row of dropped items on a stone floor in front of the
  # player, in survival with a block in the hand. HAND=id holds block id
  # instead (0 for the empty hand).
  def show_items
    bx = @player.x.floor
    bz = @player.z.floor - 4
    y = 80
    dx = -4
    while dx <= 4
      dz = -3
      while dz <= 3
        set_block(bx + dx, y, bz + dz, Block::STONE)
        dz += 1
      end
      dx += 1
    end
    shown = [Block::GRASS, Block::CHEST, Block::DOOR, Block::FURNACE, Block::SAPLING, Block::APPLE,
             Block::BREAD, Block::WHEAT, Block::IRON_SWORD, Block::IRON_AXE, Block::STONE_SHOVEL, Block::ARROW]
    shown.each_with_index do |b, i|
      drop_item(b, i == 11 ? 3 : 1, bx - 3.6 + i * 0.65, y + 1.0, bz + 0.5, 0.0, 0.0, 0.0, 1.0e9)
    end
    set_block(bx - 2, y + 1, bz - 2, Block::DOOR)
    set_block(bx - 2, y + 2, bz - 2, Block::DOOR)
    set_block(bx, y + 1, bz - 2, Block::DOOR_OPEN)
    set_block(bx, y + 2, bz - 2, Block::DOOR_OPEN)
    set_block(bx + 2, y + 1, bz - 2, Block::FURNACE)
    set_block(bx + 4, y + 1, bz - 2, Block::CRAFTING_TABLE)
    set_block(bx + 5, y + 1, bz - 2, Block::SAPLING)
    # Wall torches on the front of the furnace and on the side of the table.
    set_block(bx + 2, y + 1, bz - 1, Block::WALL_TORCH + 3)
    set_block(bx + 3, y + 1, bz - 2, Block::WALL_TORCH)
    set_block(bx + 1, y + 1, bz - 2, Block::LADDER)
    set_block(bx + 1, y + 2, bz - 2, Block::LADDER)
    [Block::SEEDS, Block::WHEAT_1, Block::WHEAT_2, Block::WHEAT_RIPE].each_with_index do |b, i|
      set_block(bx - 4 + i, y + 1, bz - 1, b)
    end
    @survival = true
    hand = (ENV["HAND"] || Block::LOG.to_s).to_i
    @inv.set(0, hand, hand == Block::AIR ? 0 : 5)
    @slot = 0
    @player.x = bx + 0.5
    @player.y = y + 1.0
    @player.z = bz + 3.5
    @player.yaw = 0.0
    @player.pitch = -0.35
    @player.flying = true
    @time_of_day = 0.3
  end

  # DEMO=1 digs and builds in front of the player through the normal actions,
  # so screenshots can check breaking, placing and particles.
  def demo(frame)
    @player.pitch = -1.3
    return unless @player.hit
    if frame % 20 == 0 && frame < 50
      b = @world.get(@player.hx, @player.hy, @player.hz)
      @particles.burst(@player.hx, @player.hy, @player.hz, b)
      play(Sfx::BREAK, 0.7)
      set_block(@player.hx, @player.hy, @player.hz, Block::AIR)
    elsif frame % 20 == 0 && frame >= 60 && frame < 120
      @slot = 7
      place
    end
  end

  def check(name, ok)
    puts "#{ok ? "PASS" : "FAIL"} #{name}"
    @failures += 1 unless ok
  end

  # SELFTEST=1 runs the game rules without input and reports PASS/FAIL lines.
  def self_test
    @failures = 0
    test_spawn
    x = @spawn_x.floor + 2
    z = @spawn_z.floor + 2
    h = @world.height_at(x, z)
    ground = h - 1
    # The tests need a floor at ground with open air above it around x, z.
    # Spawn can be on a slope, under a plant or on sand over a cave, so the
    # tests build that space first and let any loose sand land.
    (x - 3..x + 3).each do |cx|
      (z - 3..z + 3).each do |cz|
        (WY - 1).downto(ground + 1) { |y| set_block(cx, y, cz, Block::AIR) }
        set_block(cx, ground, cz, Block::DIRT)
      end
    end
    land_falling
    test_falling_and_torches(x, z, ground)
    test_survival(x, z, ground)
    test_monsters
    test_fire
    test_rain
    test_save(x, z, ground)
    test_crafting_limits
    test_inventory_layout
    test_seen_recipes
    test_split_and_quick_move
    cx = @spawn_x.floor + 4
    cz = @spawn_z.floor + 4
    test_chests(cx, cz)
    test_mob_drops
    test_items(cx, cz)
    test_light_sources(cx, cz)
    test_dark
    test_door_furnace_sapling
    test_door_rules
    test_ladder
    test_plant_box
    test_bed
    test_buckets
    test_far_items
    bx = @spawn_x.floor
    bz = @spawn_z.floor
    test_bow(bx, bz)
    test_sneak_and_bed(bx, bz)
    test_water
    test_inventory_clicks
    test_swim_out
    test_hand_sway
    test_streaming
    test_terrain_tables
    File.delete(SAVE_PATH) if File.exist?(SAVE_PATH)
    puts @failures == 0 ? "ALL PASS" : "#{@failures} FAILED"
  end

  # The player starts on dry land: above the beach, with no water or
  # leaves underfoot.
  def test_spawn
    x = @spawn_x.floor
    z = @spawn_z.floor
    h = @world.height_at(x, z)
    b = @world.get(x, h - 1, z)
    check("the player spawns on dry land", h > SEA + 2 && Block.solid?(b) && b != Block::LEAVES && !Block.water?(b))
  end

  # The terrain tables are read by position, so each must have one entry
  # for each biome or tree kind, and the spline needs rising points.
  def test_terrain_tables
    biomes = [Biome::GROUND, Biome::TREES, Biome::TREE, Biome::GRASS, Biome::FLOWERS].all? { |t| t.size == Biome::ALL.size }
    kinds = World::TRUNK.size == Biome::TREE_KINDS.size && Biome::TREE.all? { |k| k < Biome::TREE_KINDS.size }
    xs = World::CONTINENT
    rising = (1...xs.size).all? { |i| xs[i] > xs[i - 1] }
    check("each terrain table has one entry for each biome or tree kind", biomes && kinds)
    check("the continent spline has rising points and one height for each", rising && World::BASE.size == xs.size)
  end

  # The held item moves only a little in each frame while the player walks,
  # and when the player stops.
  def test_hand_sway
    p = @player
    p.on_ground = true
    p.flying = false
    p.vz = 0.0
    @bob = 0.0
    @hand_walk = 0.0
    dt = 1.0 / 60.0
    update_hand(dt)
    last_x = @hand_dx
    last_y = @hand_dy
    most = 0.0
    frame = 0
    while frame < 150
      p.vx = frame < 120 ? 4.3 : 0.0
      # As in Game#update.
      @bob += p.vx * dt * 2.6
      update_hand(dt)
      d = (@hand_dx - last_x).abs + (@hand_dy - last_y).abs
      most = d if d > most
      last_x = @hand_dx
      last_y = @hand_dy
      frame += 1
    end
    p.vx = 0.0
    check("the held item sways smoothly while the player walks and stops", most < 0.006)
  end

  # Runs the falling blocks for the given seconds.
  def fall_for(seconds)
    t = 0.0
    while t < seconds
      update_falling(0.02)
      t += 0.02
    end
  end

  # Falling sand, the torch list, and how far torch light goes.
  def test_falling_and_torches(x, z, ground)
    set_block(x, ground + 6, z, Block::SAND)
    set_block(x, ground + 7, z, Block::GRAVEL)
    midair = @world.get(x, ground + 6, z) == Block::AIR && @world.get(x, ground + 1, z) == Block::AIR && @falling.size == 2
    fall_for(2.0)
    landed = @world.get(x, ground + 1, z) == Block::SAND && @world.get(x, ground + 2, z) == Block::GRAVEL && @falling.empty?
    check("sand and gravel fall through the air and land on the ground", midair && landed)
    set_block(x, ground + 2, z, Block::AIR)
    set_block(x, ground + 1, z, Block::AIR)
    torches = @world.chunk_torches[World.slot(x >> 4, z >> 4)]
    lights = torches.size
    set_block(x, ground + 3, z, Block::TORCH)
    check("torch is listed", torches.size == lights + 3)
    set_block(x, ground + 3, z, Block::AIR)
    check("broken torch is unlisted", torches.size == lights)
    set_block(x, ground + 1, z, Block::TORCH)
    set_block(x, ground, z, Block::AIR)
    check("breaking the block under a torch removes it", torches.size == lights && @world.get(x, ground + 1, z) == Block::AIR)
    set_block(x, ground, z, Block::DIRT)
    # A wall torch on the -x side of a stone.
    set_block(x + 1, ground + 1, z, Block::STONE)
    set_block(x, ground + 1, z, Block::WALL_TORCH)
    check("wall torch is listed", torches.size == lights + 3)
    set_block(x, ground, z, Block::AIR)
    check("breaking the block under a wall torch keeps it", @world.get(x, ground + 1, z) == Block::WALL_TORCH)
    set_block(x, ground, z, Block::DIRT)
    set_block(x + 1, ground + 1, z, Block::AIR)
    check("breaking the block that holds a wall torch removes it", torches.size == lights && @world.get(x, ground + 1, z) == Block::AIR)
    # A torch sealed in a stone box lights nothing outside the box.
    dx = -1
    while dx <= 1
      dy = 1
      while dy <= 3
        dz = -1
        while dz <= 1
          set_block(x + dx, ground + dy, z + dz, Block::STONE)
          dz += 1
        end
        dy += 1
      end
      dx += 1
    end
    set_block(x, ground + 2, z, Block::TORCH)
    @mesher.build(x / CHUNK, z / CHUNK)
    inside = @mesher.torch_light(x, ground + 2, z)
    outside = @mesher.torch_light(x + 2, ground + 2, z)
    check("walls stop torch light", inside == Mesher::LIGHT_MAX && outside == 0)
    set_block(x + 1, ground + 2, z, Block::AIR)
    @mesher.build(x / CHUNK, z / CHUNK)
    check("an opening lets torch light out", @mesher.torch_light(x + 2, ground + 2, z) == 12)
    dx = -1
    while dx <= 1
      dy = 1
      while dy <= 3
        dz = -1
        while dz <= 1
          set_block(x + dx, ground + dy, z + dz, Block::AIR)
          dz += 1
        end
        dy += 1
      end
      dx += 1
    end
    set_block(x, ground + 1, z, Block::TORCH)
    flush_dirty
    puts "torch edit remesh: #{@mesh_ms.round(2)} ms"
    set_block(x, ground + 1, z, Block::AIR)
    flush_dirty
    # Sand that falls onto a torch buries it. A torch in the middle of a
    # chunk lights the next chunk too, so that chunk must remesh.
    tx = (x & ~15) + 8
    th = @world.height_at(tx, z)
    # The column can be water, and a torch needs ground.
    set_block(tx, th - 1, z, Block::DIRT)
    set_block(tx, th, z, Block::TORCH)
    flush_dirty while !@later_list.empty?
    set_block(tx, th + 3, z, Block::SAND)
    fall_for(2.0)
    lit = World.slot((tx >> 4) + 1, z >> 4)
    check("sand that buries a torch remeshes the chunks that it lit", @world.get(tx, th, z) == Block::SAND && (@dirty[lit] == true || @later[lit] == true))
    set_block(tx, th, z, Block::AIR)
    flush_dirty while !@later_list.empty?
  end

  # Survival basics: crafting, stacks, health, placing, mining, and food.
  def test_survival(x, z, ground)
    @survival = true
    @inv.clear
    3.times { @inv.add(Block::LOG) }
    @slot = 0
    craft_recipe(recipe_for(Block::PLANKS))
    check("craft log into planks", @inv.block(0) == Block::LOG && @inv.count(0) == 2 && @inv.block(1) == Block::PLANKS && @inv.count(1) == 4)
    70.times { @inv.add(Block::DIRT) }
    check("stacks split at 64", @inv.count(2) == 64 && @inv.block(3) == Block::DIRT && @inv.count(3) == 6)
    @vitals.health = Vitals::MAX_HEALTH
    hurt(5)
    check("hurt lowers health", @vitals.health == 15 && !@vitals.dead?)
    kept = @inv.copy
    @items.clear
    toggle_inventory
    hurt(30)
    check("death at zero health, and it closes the inventory", @vitals.health == 0 && @vitals.dead? && !@inventory_open)
    check("death drops the inventory on the ground", @inv.room_for(Block::DIRT) == INV * Slots::STACK && ground_count(Block::DIRT) == 70 && ground_count(Block::PLANKS) == 4)
    @items.clear
    @inv = kept
    respawn
    check("respawn restores health", @vitals.health == Vitals::MAX_HEALTH && !@vitals.dead?)
    @player.x = x + 0.5
    @player.y = ground + 1.0
    @player.z = z + 0.5
    @player.pitch = -1.55
    @player.raycast(@world)
    check("raycast hits the ground", @player.hit && @player.hy == ground)
    @slot = 1
    before = @inv.count(1)
    @player.y = ground + 3.0
    @player.raycast(@world)
    place
    check("survival place uses one item", @inv.count(1) == before - 1 && @world.get(x, ground + 1, z) == Block::PLANKS)
    set_block(x, ground + 1, z, Block::TALL_GRASS)
    @player.raycast(@world)
    place
    check("a block placed on tall grass takes its cell", @world.get(x, ground + 1, z) == Block::PLANKS && @world.get(x, ground + 2, z) == Block::AIR)
    # Stone drops cobblestone only to a pickaxe. Off the ground, mining is
    # slow, so the player stands while it mines.
    @inv.clear
    @slot = 0
    set_block(x, ground + 1, z, Block::STONE)
    @player.y = ground + 3.0
    @player.on_ground = true
    n = 0
    while n < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @player.raycast(@world)
      mine(0.05)
      n += 1
    end
    check("stone without a pickaxe drops nothing", @world.get(x, ground + 1, z) == Block::AIR && @items.empty?)
    7.times { @inv.add(Block::PLANKS) }
    craft_recipe(recipe_for(Block::WOOD_PICK))
    by_hand = @inv.total(Block::WOOD_PICK)
    craft_recipe(recipe_for(Block::CRAFTING_TABLE))
    table = @inv.total(Block::CRAFTING_TABLE) == 1
    craft_at_table(recipe_for(Block::WOOD_PICK))
    check("a crafting table comes from 4 planks, and a pickaxe needs one nearby", by_hand == 0 && table && @inv.total(Block::WOOD_PICK) > 0)
    @inv.clear
    @inv.add(Block::WOOD_PICK)
    set_block(x, ground + 1, z, Block::STONE)
    mining_frames = 0
    while mining_frames < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @player.raycast(@world)
      mine(0.05)
      mining_frames += 1
    end
    dropped = ground_count(Block::COBBLE) == 1 && @inv.count(1) == 0
    collect_items
    check("a pickaxe mines stone faster, and the cobblestone drops to the ground", mining_frames < n && dropped && @inv.block(1) == Block::COBBLE)
    by_hand = frames_to_mine(x, ground + 1, z, Block::LOG, Block::AIR)
    by_axe = frames_to_mine(x, ground + 1, z, Block::LOG, Block::STONE_AXE)
    by_pick = frames_to_mine(x, ground + 1, z, Block::LOG, Block::STONE_PICK)
    check("an axe chops a log faster than a hand or a pickaxe", by_axe < by_hand && by_pick == by_hand)
    # 1.5 hardness * 1.5 seconds / speed 4 = 0.5625 seconds, as in Minecraft.
    check("a stone pickaxe breaks stone in 12 frames", frames_to_mine(x, ground + 1, z, Block::STONE, Block::STONE_PICK) == 12)
    @items.clear
    @inv.set(5, Block::COOKED_PORKCHOP, 2)
    @slot = 5
    @vitals.hunger = 5
    eat
    check("eating restores hunger", @vitals.hunger == 13 && @inv.count(5) == 1)
    # A minute of standing still costs no hunger. 400 meters of sprint take
    # 40 exhaustion: the 5 points of saturation, then 5 points of hunger.
    @vitals = Vitals.new
    1200.times { @vitals.update_vitals(0.05, false, false) }
    idle = @vitals.hunger == Vitals::MAX_HUNGER
    @vitals.move(400.0, true, false, false)
    @vitals.update_vitals(0.05, false, false)
    check("standing still costs no hunger, and a sprint does", idle && @vitals.hunger == 15)
  end

  # Frames of 0.05 seconds that it takes to break block b at x, y, z (which
  # the player looks at) with tool in hotbar slot 8.
  def frames_to_mine(x, y, z, b, tool)
    @inv.set(8, tool, tool == Block::AIR ? 0 : Block.uses(tool))
    @slot = 8
    set_block(x, y, z, b)
    @mining = false
    @mine_delay = 0.0
    n = 0
    while n < 400 && @world.get(x, y, z) == b
      @player.raycast(@world)
      mine(0.05)
      n += 1
    end
    @inv.set(8, Block::AIR, 0)
    n
  end

  # Monsters on a sky platform at night: a skeleton's arrow, a zombie's hit,
  # and a creeper's blast hurt the player.
  def test_monsters
    px = @spawn_x.floor
    pz = @spawn_z.floor
    i = -2
    while i <= 16
      set_block(px + i, 88, pz, Block::STONE)
      i += 1
    end
    flush_dirty
    @mobs.clear
    @time_of_day = 0.75
    @vitals.health = Vitals::MAX_HEALTH
    @player.x = px + 0.5
    @player.y = 89.0
    @player.z = pz + 0.5
    @mobs << Mob.new(Mob::SKELETON, px + 12.5, 89.0, pz + 0.5, 7)
    frames = 0
    while frames < 400 && @vitals.health == Vitals::MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("skeleton arrow hurts the player", @vitals.health < Vitals::MAX_HEALTH)
    @mobs.clear
    @mobs << Mob.new(Mob::ZOMBIE, px + 1.5, 89.0, pz + 0.5, 9)
    @vitals.health = Vitals::MAX_HEALTH
    frames = 0
    while frames < 400 && @vitals.health == Vitals::MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("zombie hit hurts the player", @vitals.health < Vitals::MAX_HEALTH)
    @mobs.clear
    # Each block that the blast breaks drops by chance, so the blast gets
    # two more rows of stone to break, and the random numbers start from a
    # known seed.
    @rng = Rng.new(5)
    (0..5).each do |dx|
      set_block(px + dx, 88, pz - 1, Block::STONE)
      set_block(px + dx, 88, pz + 1, Block::STONE)
    end
    @mobs << Mob.new(Mob::CREEPER, px + 2.5, 89.0, pz + 0.5, 11)
    # A blast this near kills a player with full health, so the player
    # gets more health for the test.
    @vitals.health = 100
    @items.clear
    frames = 0
    while frames < 300 && @world.get(px + 2, 88, pz) == Block::STONE
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("a creeper explodes, breaks blocks and hurts", @world.get(px + 2, 88, pz) == Block::AIR && @vitals.health < 100 && frames > 60)
    check("some blocks that a blast breaks drop", ground_count(Block::COBBLE) > 0)
    @items.clear
    @mobs.clear
    @time_of_day = 0.3
    @vitals.health = Vitals::MAX_HEALTH
  end

  # On the sky platform from test_monsters: a zombie in the sun burns with
  # flames, and the player burns on after lava until water puts the fire out.
  def test_fire
    px = @spawn_x.floor
    pz = @spawn_z.floor
    @mobs.clear
    @time_of_day = 0.25
    zombie = Mob.new(Mob::ZOMBIE, px + 8.5, 89.0, pz + 0.5, 9)
    @mobs << zombie
    @player.x = px + 0.5
    @player.y = 89.0
    @player.z = pz + 0.5
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie in the sun burns and makes flames", zombie.fire > 0.0 && zombie.hp < Mob::HP[Mob::ZOMBIE] && @particles.count(Particle::FLAME) > 0)
    @mobs.clear
    @survival = true
    @vitals.health = Vitals::MAX_HEALTH
    @world.set(px + 1, 89, pz, Block::LAVA)
    @player.x = px + 1.5
    update_survival(0.1)
    @world.set(px + 1, 89, pz, Block::AIR)
    @vitals.health = Vitals::MAX_HEALTH
    150.times { update_survival(1.0 / 60.0) }
    burned = @vitals.fire > 0.0 && @vitals.health < Vitals::MAX_HEALTH
    @world.set(px + 1, 89, pz, Block::WATER)
    update_survival(1.0 / 60.0)
    @world.set(px + 1, 89, pz, Block::AIR)
    check("the player burns on after lava, and water puts the fire out", burned && @vitals.fire == 0.0)
    @time_of_day = 0.3
    @vitals.health = Vitals::MAX_HEALTH
  end

  # On the sky platform from test_monsters: rain stops the sun from burning a
  # zombie, and the rain in a column stops at the highest block.
  def test_rain
    px = @spawn_x.floor
    pz = @spawn_z.floor
    @mobs.clear
    @time_of_day = 0.25
    @weather.set_now(true)
    zombie = Mob.new(Mob::ZOMBIE, px + 8.5, 89.0, pz + 0.5, 9)
    @mobs << zombie
    @player.x = px + 0.5
    @player.y = 89.0
    @player.z = pz + 0.5
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie does not burn in the rain", zombie.fire == 0.0 && zombie.hp == Mob::HP[Mob::ZOMBIE])
    @mobs.clear
    @weather.build_quads(@world, @player, 1.0)
    open = rain_bottom(px + 3, pz)
    @world.set(px + 3, 95, pz, Block::STONE)
    @weather.build_quads(@world, @player, 1.0)
    roofed = rain_bottom(px + 3, pz)
    @world.set(px + 3, 95, pz, Block::AIR)
    check("the rain in a column stops at the highest block", open < 96.0 && roofed == 96.0)
    @weather.set_now(false)
    @time_of_day = 0.3
  end

  # The bottom of the rain in column x, z: the third vertex of the quad from
  # corner (x, z) to (x + 1, z + 1). A quad has 6 vertices of 11 floats.
  def rain_bottom(x, z)
    v = @weather.mesh.v
    i = 0
    while i < v.size
      return v[i + 23] if v[i] == x.to_f && v[i + 2] == z.to_f && v[i + 11] == x + 1.0 && v[i + 13] == z + 1.0
      i += 66
    end
    -1.0
  end

  # The save keeps blocks, the inventory, health, the items on the ground and
  # the weather, and a dead player respawns on load.
  def test_save(x, z, ground)
    old = @world.get(x, ground + 1, z)
    kept_block = @inv.block(1)
    kept_count = @inv.count(1)
    @items.clear
    drop_item(Block::STONE_SWORD, 17, x + 0.25, ground + 1.0, z + 0.75, 0.0, 0.0, 0.0, 0.0)
    @weather.set(true)
    @weather.timer = 77.5
    @seen.fill(0)
    @seen[Block::DIAMOND] = 1
    @furnace_heat = {}
    @furnace_heat[77] = 5
    save
    @world.set(x, ground + 1, z, Block::GLASS)
    @vitals.health = 3
    @inv.set(1, Block::AIR, 0)
    @items.clear
    @weather.set_now(false)
    @seen.fill(0)
    @furnace_heat = {}
    ok = load
    apply_loaded if ok
    check("save and load round trip", ok && @world.get(x, ground + 1, z) == old && @vitals.health == Vitals::MAX_HEALTH && @inv.block(1) == kept_block && @inv.count(1) == kept_count && kept_count > 0 && @survival)
    check("the save keeps the items on the ground and the weather",
          @items.size == 1 && @items[0].block == Block::STONE_SWORD && @items[0].count == 17 &&
          @items[0].x == x + 0.25 && @items[0].y == ground + 1.0 && @items[0].z == z + 0.75 &&
          @weather.raining? && @weather.rain == 1.0 && @weather.timer == 77.5)
    check("the save keeps the seen items and the heat in furnaces", @seen[Block::DIAMOND] == 1 && furnace_heat(77) == 5)
    @furnace_heat = {}
    @items.clear
    @weather.set_now(false)
    @vitals.health = 0
    save
    ok = load
    apply_loaded if ok
    check("loading a save made while dead respawns", ok && @vitals.health == Vitals::MAX_HEALTH && !@vitals.dead?)
    File.write(SAVE_PATH, "NOT A SAVE\n")
    ok = load
    keep_bad_save
    check("a save that does not load moves aside", !ok && !File.exist?(SAVE_PATH) && File.exist?(BAD_SAVE_PATH))
    File.delete(BAD_SAVE_PATH) if File.exist?(BAD_SAVE_PATH)
  end

  # A right-click takes half a stack or puts down one item. A Shift-click
  # moves a stack between the hotbar and the backpack, or between the
  # inventory and an open chest.
  def test_split_and_quick_move
    @inv.clear
    @held_count = 0
    @held_block = Block::AIR
    @inv.set(5, Block::DIRT, 7)
    split_cell(@inv, 5)
    half = @held_count == 4 && @inv.count(5) == 3
    split_cell(@inv, 6)
    split_cell(@inv, 6)
    split_cell(@inv, 5)
    one = @inv.count(6) == 2 && @inv.count(5) == 4 && @held_count == 1
    return_held
    check("a right-click takes half a stack and puts down one item", half && one && @inv.count(5) == 5)
    @inv.clear
    @inv.set(0, Block::DIRT, 10)
    @inv.set(HOTBAR, Block::DIRT, 60)
    quick_move_slot(0)
    pack = @inv.count(0) == 0 && @inv.count(HOTBAR) == 64 && @inv.block(HOTBAR + 1) == Block::DIRT && @inv.count(HOTBAR + 1) == 6
    @chest_key = 0
    @chest.clear
    quick_move_slot(HOTBAR + 1)
    into_chest = @inv.count(HOTBAR + 1) == 0 && @chest.block(0) == Block::DIRT && @chest.count(0) == 6
    quick_move_chest(0)
    out_of_chest = @chest.count(0) == 0 && @inv.total(Block::DIRT) == 70
    @chest_key = -1
    @chest.clear
    check("a Shift-click moves a stack to the other side", pack && into_chest && out_of_chest)
    @inv.clear
  end

  # The recipe list shows a recipe once the player has had its ingredient.
  def test_seen_recipes
    @seen.fill(0)
    @recipe_new.fill(0)
    @inv.clear
    @inv.add(Block::LOG)
    note_seen
    logs = shown_recipes == [recipe_for(Block::PLANKS)]
    told = @message == "NEW RECIPE: PLANKS" && @recipe_new[recipe_for(Block::PLANKS)] == 1
    toggle_inventory
    toggle_inventory
    check("a new recipe shows a message and a tag until the inventory closes", told && !@recipe_new.include?(1))
    @inv.add(Block::PLANKS)
    note_seen
    @inv.remove(Block::PLANKS, 1)
    note_seen
    planks = shown_recipes.include?(recipe_for(Block::WOOD_PICK)) && !shown_recipes.include?(recipe_for(Block::STONE_PICK))
    check("the recipe list shows only the recipes for seen ingredients", logs && planks)
  end

  # The inventory screen fits the frame and leaves the hotbar and the health
  # bars free, for common frame sizes.
  def test_inventory_layout
    sizes = [1280.0, 720.0, 2560.0, 1440.0, 1920.0, 1080.0, 2880.0, 1800.0, 3840.0, 2160.0]
    fits = true
    i = 0
    while i < sizes.size
      w = sizes[i]
      h = sizes[i + 1]
      s = inventory_scale(w, h)
      first = pack_cell(HOTBAR, w, h, s)
      last = recipe_cell(RECIPE_ROWS * 2 - 1, w, h, s)
      pad = 18.0 * s
      fits = false if first[0] - pad < 0.0 || first[1] - pad - 40.0 * s < 0.0
      fits = false if last[0] + last[2] + pad > w || last[1] + last[3] + pad > h - 82.0 * ui_scale(h)
      i += 2
    end
    check("the inventory screen fits the frame above the hotbar", fits)
  end

  # The index of the recipe that makes b.
  def recipe_for(b) = RECIPES.index { |r| r[2] == b }

  # Crafts recipe k with a crafting table next to the player.
  def craft_at_table(k)
    x = @player.x.floor + 2
    y = @player.y.floor
    z = @player.z.floor
    old = @world.get(x, y, z)
    set_block(x, y, z, Block::CRAFTING_TABLE)
    craft_recipe(k)
    set_block(x, y, z, old)
  end

  # Crafting needs room for the result, and it takes from several stacks.
  def test_crafting_limits
    i = 0
    while i < INV
      @inv.set(i, Block::PLANKS, 64)
      i += 1
    end
    @inv.set(0, Block::LOG, 5)
    @inv.set(1, Block::PLANKS, 62)
    @slot = 0
    craft_recipe(recipe_for(Block::PLANKS))
    check("crafting refuses when the result does not fit", @inv.count(0) == 5 && @inv.count(1) == 62)
    @inv.clear
    @inv.set(3, Block::PLANKS, 2)
    @inv.set(20, Block::PLANKS, 4)
    craft_at_table(recipe_for(Block::BOW))
    check("a recipe takes ingredients from several stacks", @inv.total(Block::PLANKS) == 1 && @inv.total(Block::BOW) == Block.uses(Block::BOW))
    # A tool wears out, and a thrown tool keeps the uses that it has left.
    @inv.clear
    @inv.add(Block::WOOD_PICK)
    @inv.add(Block::WOOD_PICK)
    @slot = 0
    @inv.set(0, Block::WOOD_PICK, 1)
    survival = @survival
    @survival = true
    wear_tool(1)
    broke = @inv.count(0) == 0 && @inv.block(1) == Block::WOOD_PICK
    @inv.set(1, Block::WOOD_PICK, 7)
    @slot = 1
    @items.clear
    throw_selected
    collect_items
    @survival = survival
    check("a tool breaks after its last use, and a thrown tool keeps its uses", broke && @inv.count(0) == 7 && @inv.block(0) == Block::WOOD_PICK)
    # The only free slot is the one that the recipe empties.
    i = 0
    while i < INV
      @inv.set(i, Block::DIRT, 64)
      i += 1
    end
    @inv.set(0, Block::LOG, 1)
    craft_recipe(0)
    check("a recipe click counts the slot that it empties as room", @inv.block(0) == Block::PLANKS && @inv.count(0) == 4)
  end

  # Chest contents survive a save and come back when the chest breaks.
  def test_chests(cx, cz)
    set_block(cx, 90, cz, Block::CHEST)
    @inv.clear
    open_chest(cx, 90, cz)
    @chest.set(5, Block::DIAMOND, 7)
    toggle_inventory
    save
    @chests = {}
    ok = load
    apply_loaded if ok
    stored = @chests[World.key(cx, 90, cz)]
    check("chest contents survive a save", ok && !stored.nil? && stored.block(5) == Block::DIAMOND && stored.count(5) == 7)
    set_block(cx, 90, cz, Block::AIR)
    dropped = ground_count(Block::DIAMOND) == 7 && @inv.total(Block::DIAMOND) == 0
    collect_items
    check("a broken chest drops its contents", dropped && @inv.total(Block::DIAMOND) == 7 && @chests.empty?)
    # An open chest destroyed by a blast never duplicates its contents.
    @inv.clear
    @items.clear
    set_block(cx, 90, cz, Block::CHEST)
    open_chest(cx, 90, cz)
    @chest.set(0, Block::DIAMOND, 7)
    set_block(cx, 90, cz, Block::AIR)
    check("a chest destroyed while open does not duplicate items", @inv.total(Block::DIAMOND) + ground_count(Block::DIAMOND) == 7 && !@inventory_open && @chests.empty?)
    @items.clear
  end

  # Mobs that die without the player's help drop nothing.
  def test_mob_drops
    @inv.clear
    far = Mob.new(Mob::PIG, @spawn_x + 30.0, 90.0, @spawn_z, 5)
    far.hp = 0.0
    far.alive = false
    @mobs.clear
    @mobs << far
    update_mobs(1.0 / 60.0)
    check("a pig that dies on its own drops nothing", @items.empty?)
    killed = Mob.new(Mob::PIG, @spawn_x + 30.0, 90.0, @spawn_z, 5)
    killed.hp = 0.0
    killed.alive = false
    killed.by_player = true
    @mobs << killed
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::PORKCHOP)
    dropped = n >= 1 && n <= 3
    collect_items
    check("a pig that the player kills drops 1 to 3 porkchops", dropped && @inv.total(Block::PORKCHOP) == n)
    @items.clear
    loot(killed, Block::BOW, 1)
    check("a bow that a mob drops is new", @items.size == 1 && @items[0].count == Block.uses(Block::BOW))
    @items.clear
  end

  # Stands the player on the first item until the ground is empty or the
  # frames run out.
  def collect_items
    frames = 0
    while frames < 300 && !@items.empty?
      @player.x = @items[0].x
      @player.y = @items[0].y
      @player.z = @items[0].z
      update_items(1.0 / 60.0)
      frames += 1
    end
  end

  def run_items(seconds)
    (seconds * 60.0).to_i.times { update_items(1.0 / 60.0) }
  end

  # Items fall and wait before pickup, a full inventory leaves them on the
  # ground, items of one kind join, and lava burns them.
  def test_items(cx, cz)
    y = 92
    dx = -1
    while dx <= 3
      dz = -1
      while dz <= 1
        set_block(cx + dx, y, cz + dz, Block::STONE)
        dz += 1
      end
      dx += 1
    end
    @inv.clear
    @items.clear
    @player.x = cx + 0.5
    @player.y = y + 1.0
    @player.z = cz + 0.5
    throw_stack(Block::DIRT, 1)
    run_items(0.5)
    waited = @inv.total(Block::DIRT) == 0 && ground_count(Block::DIRT) == 1
    @player.x = @items[0].x
    @player.z = @items[0].z
    run_items(1.5)
    check("a thrown item waits before the player picks it up", waited && @inv.total(Block::DIRT) == 1 && @items.empty?)
    drop_item(Block::SAND, 1, cx + 2.5, y + 3.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    @player.x = cx + 0.5
    run_items(1.5)
    check("an item falls to the ground and stays out of reach", @items.size == 1 && (@items[0].y - (y + 1.0)).abs < 0.01)
    @items.clear
    i = 0
    while i < INV
      @inv.set(i, Block::STONE, Slots::STACK)
      i += 1
    end
    drop_item(Block::SAND, 1, cx + 0.5, y + 1.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    drop_item(Block::SAND, 1, cx + 0.6, y + 1.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    run_items(0.5)
    check("a full inventory leaves items on the ground, and items of one kind join", @items.size == 1 && @items[0].count == 2 && @inv.total(Block::SAND) == 0)
    @items.clear
    @inv.clear
    set_block(cx + 2, y + 1, cz, Block::LAVA)
    drop_item(Block::SAND, 1, cx + 2.5, y + 1.2, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    run_items(0.2)
    check("lava burns an item", @items.empty?)
    set_block(cx + 2, y + 1, cz, Block::AIR)
    flush_dirty while !@later_list.empty? || !@dirty_list.empty?
  end

  # Wool does not glow, lava gives light, and water turns lava into cobblestone.
  def test_light_sources(cx, cz)
    # Wool is not a light source.
    set_block(cx, 90, cz, Block::WOOL)
    @mesher.build(cx / CHUNK, cz / CHUNK)
    faces = 0
    glow = false
    k = 0
    while k < @mesher.opaque.size
      w0 = @mesher.opaque[k]
      if Mesher.face_x(w0) == (cx & LMASK) && Mesher.face_y(w0) == 90 && Mesher.face_z(w0) == (cz & LMASK)
        faces += 1
        glow = true if Mesher.face_light(@mesher.opaque[k + 1]) == 14
      end
      k += 2
    end
    check("wool does not glow", faces > 0 && !glow)
    set_block(cx, 90, cz, Block::AIR)
    lx = @spawn_x.floor - 6
    lz = @spawn_z.floor - 6
    i = -1
    while i <= 1
      set_block(lx + i, 85, lz, Block::STONE)
      set_block(lx + i, 86, lz, Block::AIR)
      i += 1
    end
    set_block(lx, 86, lz, Block::LAVA)
    @mesher.build(lx / CHUNK, lz / CHUNK)
    check("lava lights its surroundings", @mesher.torch_light(lx, 87, lz) == 13)
    set_block(lx + 1, 86, lz, Block::WATER)
    20.times { update_water }
    check("water turns lava into cobblestone", @world.get(lx, 86, lz) == Block::COBBLE)
    set_block(lx + 1, 86, lz, Block::AIR)
    set_block(lx, 86, lz, Block::AIR)
    20.times { update_water }
  end

  # Builds a stone platform and shoots a pig on it with a full bow draw.
  def test_bow(bx, bz)
    @mobs.clear
    i = -2
    while i <= 12
      set_block(bx + i, 88, bz, Block::STONE)
      i += 1
    end
    @player.x = bx + 0.5
    @player.y = 89.0
    @player.z = bz + 0.5
    @player.yaw = 1.5708
    @player.pitch = -0.12
    @inv.clear
    @inv.add(Block::ARROW)
    pig = Mob.new(Mob::PIG, bx + 8.5, 89.0, bz + 0.5, 3)
    @mobs << pig
    shoot_bow(1.0)
    frames = 0
    while frames < 120 && pig.hp == 10.0
      update_arrows(1.0 / 60.0)
      frames += 1
    end
    check("a full bow draw hits a pig and uses an arrow", pig.hp < 10.0 && @inv.room_for(Block::ARROW) == INV * Slots::STACK)
    # A wooden sword does 4 with a full cooldown, and 20% of that right after
    # an attack.
    @mobs.clear
    survival = @survival
    @survival = true
    @inv.set(0, Block::WOOD_SWORD, Block.uses(Block::WOOD_SWORD))
    @slot = 0
    update_hand(0.0)
    full = Mob.new(Mob::ZOMBIE, bx + 2.5, 89.0, bz + 0.5, 3)
    quick = Mob.new(Mob::ZOMBIE, bx + 2.5, 89.0, bz + 0.5, 4)
    @mobs << full
    @mobs << quick
    @attack_time = 1.0
    @target_mob = 0
    left_button(0.0, true, true)
    @target_mob = 1
    left_button(0.0, true, true)
    check("a hit right after an attack does less damage", full.hp == 16.0 && quick.hp > 19.0 && quick.hp < 19.2)
    @inv.clear
    @mobs.clear
    @survival = survival
  end

  # Sneaking, walking off an edge, and the bed, on the platform from test_bow.
  def test_sneak_and_bed(bx, bz)
    # The platform is one block wide in z: sneaking toward its edge stays on it.
    @player.x = bx + 4.5
    @player.y = 89.0
    @player.z = bz + 0.5
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    @player.yaw = 3.14159
    @player.flying = false
    @player.on_ground = true
    120.times { @player.update(@world, 1.0 / 60.0, 1.0, 0.0, false, true, false) }
    @mobs.clear
    set_block(bx + 6, 89, bz, Block::BED)
    @time_of_day = 0.75
    use_bed(bx + 6, 89, bz)
    check("sleeping in a bed skips the night and sets spawn", daylight > 0.35 && @spawn_x == bx + 6.5)
    set_block(bx + 6, 89, bz, Block::AIR)
    @time_of_day = 0.3
    check("sneaking stops at an edge", @player.y > 88.9 && @player.z < bz + 1.4)
    120.times { @player.update(@world, 1.0 / 60.0, 1.0, 0.0, false, false, false) }
    check("walking without sneaking falls off", @player.y < 88.0)
  end

  # A jump against the shore of a pool 2 deep lifts the player out of the
  # water onto the shore.
  def test_swim_out
    wx = @spawn_x.floor + 20
    wz = @spawn_z.floor + 20
    i = -1
    while i <= 3
      k = -2
      while k <= 2
        set_block(wx + i, 88, wz + k, Block::STONE)
        y = 89
        while y <= 94
          set_block(wx + i, y, wz + k, Block::AIR)
          y += 1
        end
        k += 1
      end
      i += 1
    end
    set_block(wx, 89, wz, Block::WATER)
    set_block(wx, 90, wz, Block::WATER)
    set_block(wx + 1, 89, wz, Block::WATER)
    set_block(wx + 1, 90, wz, Block::WATER)
    set_block(wx + 2, 89, wz, Block::STONE)
    set_block(wx + 2, 90, wz, Block::STONE)
    @flow_queue.clear
    @player.x = wx + 0.5
    @player.y = 89.0
    @player.z = wz + 0.5
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    @player.yaw = 1.5708
    @player.flying = false
    @player.on_ground = true
    # The shore is one block wide, so the player stands on it only for a while.
    out = false
    240.times do
      @player.update(@world, 1.0 / 60.0, 1.0, 0.0, true, false, false)
      out = true if @player.on_ground && @player.y >= 91.0 && @player.x > wx + 2.0
    end
    check("a jump against the shore lifts the player out of the water", out)
  end

  # Monsters spawn only in the dark: under the sky at night, or under a
  # block, and never near a torch.
  def test_dark
    x = @spawn_x.floor + 40
    z = @spawn_z.floor + 40
    h = @world.height_at(x, z)
    open_day = dark?(x, h, z, 1.0)
    open_night = dark?(x, h, z, 0.0)
    set_block(x, h + 3, z, Block::LEAVES)
    under_leaves = dark?(x, h, z, 1.0)
    set_block(x, h + 3, z, Block::STONE)
    covered_day = dark?(x, h, z, 1.0)
    # The torch stands on the roof, 4 blocks above the cell.
    set_block(x, h + 4, z, Block::TORCH)
    near_torch = dark?(x, h, z, 0.0)
    set_block(x, h + 4, z, Block::AIR)
    set_block(x, h + 3, z, Block::AIR)
    check("monsters spawn under the night sky or a roof, and not near a torch", !open_day && open_night && covered_day && !near_torch)
    check("leaves let the daylight through", !under_leaves)
  end

  # A door does not stand on a door, and it does not close on a mob.
  def test_door_rules
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 56
    y = @world.height_at(x, z)
    set_block(x, y - 1, z, Block::STONE)
    set_block(x, y, z, Block::DOOR)
    set_block(x, y + 1, z, Block::DOOR)
    stacked = door_fits?(x, y + 2, z)
    toggle_door(x, y, z)
    @mobs.clear
    @mobs << Mob.new(Mob::ZOMBIE, x + 0.5, y.to_f, z + 0.5, 3)
    toggle_door(x, y, z)
    open = @world.get(x, y, z) == Block::DOOR_OPEN
    @mobs.clear
    set_block(x, y, z, Block::AIR)
    check("a door does not stand on a door or close on a mob", !stacked && open)
  end

  # An item in a chunk that is not loaded waits there.
  def test_far_items
    @items.clear
    drop_item(Block::DIRT, 1, @player.x + 3000.0, 60.0, @player.z, 0.0, 0.0, 0.0, 0.0)
    run_items(6.0)
    check("an item in a chunk that is not loaded waits there", @items.size == 1 && @items[0].y == 60.0 && @items[0].age == 0.0)
    @items.clear
  end

  # A door opens and closes as a whole and goes as a whole. Smelting needs a
  # furnace near the player. A sapling grows into a tree.
  def test_door_furnace_sapling
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 50
    y = @world.height_at(x, z)
    set_block(x, y - 1, z, Block::GRASS)
    set_block(x, y, z, Block::DOOR)
    set_block(x, y + 1, z, Block::DOOR)
    toggle_door(x, y + 1, z)
    opened = @world.get(x, y, z) == Block::DOOR_OPEN && @world.get(x, y + 1, z) == Block::DOOR_OPEN
    toggle_door(x, y, z)
    closed = Block.solid?(@world.get(x, y, z)) && Block.solid?(@world.get(x, y + 1, z))
    set_block(x, y, z, Block::AIR)
    check("a door opens and closes as a whole, and breaks as a whole", opened && closed && @world.get(x, y + 1, z) == Block::AIR)
    @player.x = x + 0.5
    @player.y = y.to_f
    @player.z = z + 3.5
    @inv.clear
    9.times { @inv.add(Block::IRON) }
    @inv.add(Block::COAL)
    2.times { @inv.add(Block::PLANKS) }
    smelt = recipe_for(Block::IRON_INGOT)
    craft_recipe(smelt)
    far = @inv.total(Block::IRON) == 9
    check("smelting needs a furnace nearby", far)
    set_block(x + 2, y, z + 3, Block::FURNACE)
    furnace = World.key(x + 2, y, z + 3)
    # A click smelts one item, and the weakest fuel (a plank) covers it.
    craft_recipe(smelt)
    one = @inv.total(Block::IRON) == 8 && @inv.total(Block::IRON_INGOT) == 1 && @inv.total(Block::PLANKS) == 1 && @inv.total(Block::COAL) == 1 && furnace_heat(furnace) == 0
    # A Shift-click smelts all 8 others, and the coal covers them.
    craft_recipe(smelt, CRAFT_ALL)
    all = @inv.total(Block::IRON) == 0 && @inv.total(Block::IRON_INGOT) == 9 && @inv.total(Block::COAL) == 0
    # Coal for one item leaves 7 smelts of heat in the furnace.
    @inv.add(Block::IRON)
    @inv.add(Block::COAL)
    @inv.remove(Block::PLANKS, 1)
    craft_recipe(smelt)
    kept = @inv.total(Block::COAL) == 0 && furnace_heat(furnace) == 7
    @inv.add(Block::SAND)
    craft_recipe(recipe_for(Block::GLASS))
    used = @inv.total(Block::GLASS) == 1 && furnace_heat(furnace) == 6
    # A broken furnace loses its heat, and with no fuel nothing smelts.
    set_block(x + 2, y, z + 3, Block::AIR)
    set_block(x + 2, y, z + 3, Block::FURNACE)
    @inv.add(Block::SAND)
    craft_recipe(recipe_for(Block::GLASS))
    no_fuel = @inv.total(Block::SAND) == 1 && @inv.total(Block::GLASS) == 1
    set_block(x + 2, y, z + 3, Block::AIR)
    check("a furnace keeps the heat of its fuel, and smelting needs fuel", one && all && kept && used && no_fuel)
    set_block(x, y, z, Block::SAPLING)
    # The crop stands out of reach of the tree's leaves, on top of its column.
    cy = @world.height_at(x + 4, z)
    set_block(x + 4, cy - 1, z, Block::DIRT)
    set_block(x + 4, cy, z, Block::SEEDS)
    grow_plants(1200.0)
    check("a sapling grows into a tree", @world.get(x, y, z) == Block::LOG && @world.get(x, y + 3, z) == Block::LOG)
    check("seeds grow into ripe wheat", @world.get(x + 4, cy, z) == Block::WHEAT_RIPE)
    set_block(x + 4, cy, z, Block::AIR)
  end

  # A bed takes two blocks along the view, needs room for both, and breaks
  # as a whole.
  def test_bed
    x = @spawn_x.floor + 20
    z = @spawn_z.floor - 70
    g = @world.height_at(x, z) + 2
    dx = -3
    while dx <= 3
      dz = -2
      while dz <= 2
        set_block(x + dx, g - 1, z + dz, Block::STONE)
        set_block(x + dx, g, z + dz, Block::AIR)
        set_block(x + dx, g + 1, z + dz, Block::AIR)
        set_block(x + dx, g + 2, z + dz, Block::AIR)
        dz += 1
      end
      dx += 1
    end
    survival = @survival
    @survival = true
    @inv.clear
    @inv.add(Block::BED)
    @inv.add(Block::BED)
    @slot = 0
    @player.x = x - 1.5
    @player.y = g.to_f
    @player.z = z + 0.5
    @player.yaw = Math::PI / 2.0
    @player.pitch = -Math.atan(Player::EYE / 2.0)
    set_block(x + 1, g, z, Block::STONE)
    @player.raycast(@world)
    place
    blocked = @world.get(x, g, z) == Block::AIR && @inv.count(0) == 2
    set_block(x + 1, g, z, Block::AIR)
    @player.raycast(@world)
    place
    two = @world.get(x, g, z) == Block::BED && @world.get(x + 1, g, z) == Block::BED_HEAD && @inv.count(0) == 1
    set_block(x + 1, g, z, Block::AIR)
    gone = @world.get(x, g, z) == Block::AIR
    @survival = survival
    @inv.clear
    check("a bed takes two blocks along the view and breaks as a whole", blocked && two && gone)
  end

  # The view ray hits a plant only in its small box, and goes on past it.
  def test_plant_box
    x = @spawn_x.floor + 30
    z = @spawn_z.floor - 60
    g = @world.height_at(x, z) + 2
    dx = -2
    while dx <= 2
      set_block(x + dx, g, z, Block::STONE)
      set_block(x + dx, g + 1, z, dx == 2 ? Block::STONE : Block::AIR)
      set_block(x + dx, g + 2, z, Block::AIR)
      dx += 1
    end
    set_block(x, g + 1, z, Block::ROSE)
    p = Player.new(x - 1.5, g + 1.5 - Player::EYE, z + 0.1)
    p.yaw = Math::PI / 2.0
    p.raycast(@world)
    past = p.hit && p.hx == x + 2
    p.z = z + 0.5
    p.raycast(@world)
    on = p.hit && p.hx == x
    set_block(x, g + 1, z, Block::AIR)
    check("the view ray hits a flower only in its small box", past && on)
  end

  # An empty bucket takes a water or lava source that the player looks at,
  # and a full bucket puts the source back.
  def test_buckets
    x = @spawn_x.floor + 40
    z = @spawn_z.floor - 50
    y = @world.height_at(x, z) + 3
    dx = -1
    while dx <= 1
      dz = -1
      while dz <= 1
        set_block(x + dx, y - 2, z + dz, Block::STONE)
        set_block(x + dx, y - 1, z + dz, Block::STONE)
        dz += 1
      end
      dx += 1
    end
    @player.x = x + 0.5
    @player.y = y.to_f
    @player.z = z + 0.5
    @player.pitch = -1.55
    @inv.clear
    @slot = 0
    ok = true
    [Block::WATER, Block::LAVA].each do |fluid|
      full = fluid == Block::WATER ? Block::WATER_BUCKET : Block::LAVA_BUCKET
      set_block(x, y - 1, z, fluid)
      @inv.add(Block::BUCKET)
      @player.raycast(@world)
      use_bucket
      took = @inv.block(0) == full && @world.get(x, y - 1, z) == Block::AIR
      @player.raycast(@world)
      use_bucket
      ok = false unless took && @inv.block(0) == Block::BUCKET && @world.get(x, y - 1, z) == fluid
      @inv.remove(Block::BUCKET, 1)
    end
    set_block(x, y - 1, z, Block::STONE)
    check("a bucket takes a water or lava source and puts it back", ok)
  end

  # A ladder lifts the player on jump, holds the player on Shift, and lets
  # the player slide down slowly.
  def test_ladder
    x = @spawn_x.floor + 40
    z = @spawn_z.floor - 40
    y = @world.height_at(x, z)
    i = 0
    while i < 6
      set_block(x, y + i, z, Block::LADDER)
      set_block(x + 1, y + i, z, Block::STONE)
      i += 1
    end
    p = Player.new(x + 0.5, y.to_f, z + 0.5)
    50.times { p.update(@world, 0.02, 0.0, 0.0, true, false, false) }
    up = p.y > y + 2.0
    h = p.y
    50.times { p.update(@world, 0.02, 0.0, 0.0, false, true, false) }
    held = (p.y - h).abs < 0.05
    50.times { p.update(@world, 0.02, 0.0, 0.0, false, false, false) }
    slid = p.y < h - 0.5 && p.y > h - 3.0
    # Forward into the wall climbs to its top and steps onto it.
    p = Player.new(x + 0.5, y.to_f, z + 0.5)
    p.yaw = Math::PI / 2.0
    frames = 0
    while frames < 150 && p.x < x + 1.5
      p.update(@world, 0.02, 1.0, 0.0, false, false, false)
      frames += 1
    end
    top = p.x >= x + 1.5 && (p.y - (y + 6)).abs < 0.05
    i = 0
    while i < 6
      set_block(x, y + i, z, Block::AIR)
      set_block(x + 1, y + i, z, Block::AIR)
      i += 1
    end
    check("a ladder climbs on jump, holds on Shift, and slides down slowly", up && held && slid)
    check("forward on a ladder climbs onto the block at its top", top)
  end

  # Water spreads 7 blocks over a floor and drains without its source.
  def test_water
    wx = @spawn_x.floor
    wz = @spawn_z.floor + 3
    i = -10
    while i <= 10
      set_block(wx + i, 85, wz, Block::STONE)
      set_block(wx + i, 86, wz, Block::AIR)
      i += 1
    end
    @flow_queue.clear
    set_block(wx, 86, wz, Block::WATER)
    40.times { update_water }
    check("water spreads 7 blocks over a floor", Block::WATER_LEVEL[@world.get(wx + 7, 86, wz)] == 1 && @world.get(wx + 8, 86, wz) == Block::AIR && Block::WATER_LEVEL[@world.get(wx - 3, 86, wz)] == 5)
    set_block(wx, 86, wz, Block::AIR)
    40.times { update_water }
    check("water drains when its source is gone", @world.get(wx + 3, 86, wz) == Block::AIR && @world.get(wx - 6, 86, wz) == Block::AIR)
  end

  # Stacks spill into the backpack, and clicks move and merge them.
  def test_inventory_clicks
    @inv.clear
    (9 * Slots::STACK + 3).times { @inv.add(Block::DIRT) }
    check("a full hotbar spills into the backpack", @inv.block(9) == Block::DIRT && @inv.count(9) == 3)
    click_cell(@inv, 9)
    click_cell(@inv, 20)
    check("clicks move a stack", @inv.count(9) == 0 && @inv.block(20) == Block::DIRT && @inv.count(20) == 3 && @held_count == 0)
    click_cell(@inv, 20)
    click_cell(@inv, 0)
    check("clicks merge into a full stack and keep the rest", @inv.count(0) == 64 && @held_count == 3)
    return_held
  end

  # Chunk streaming, far terrain tiles, and a new world.
  def test_streaming
    # A chunk that unloads keeps its edits, and the generator gives the same chunk again.
    ex = @player.x.floor
    ez = @player.z.floor
    eh = @world.height_at(ex, ez)
    set_block(ex, eh + 4, ez, Block::GLASS)
    before = @world.chunk_bytes(ex >> 4, ez >> 4)
    far = @world.chunk_bytes((ex >> 4) + 3, ez >> 4)
    stream_around((ex >> 4) + RING, ez >> 4, -1, SYNC_R)
    gone = !@world.loaded?(ex, ez)
    stream_around(ex >> 4, ez >> 4, -1, SYNC_R)
    check("an edited chunk unloads and comes back the same", gone && @world.get(ex, eh + 4, ez) == Block::GLASS && @world.chunk_bytes(ex >> 4, ez >> 4) == before)
    check("an unloaded chunk generates the same blocks again", @world.chunk_bytes((ex >> 4) + 3, ez >> 4) == far)
    set_block(ex, eh + 4, ez, Block::AIR)
    far = @lods[LEVELS - 1]
    slot = far.build(3, -2)
    check("a far tile has a top face for each cell, sorted by direction", far.faces.size / 2 == far.offsets[7] && far.offsets[3] - far.offsets[2] == Lod::CELLS * Lod::CELLS && slot == Lod.slot(3, -2))
    old_seed = @seed
    new_world
    h = @world.height_at(@player.x.floor, @player.z.floor)
    check("a new world has a new seed and the player stands on it", @seed != old_seed && h > 0 && (@player.y - h).abs < 1.5 && @mobs.size > 0)
  end
end
