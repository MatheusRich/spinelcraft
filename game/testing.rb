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
    set_block(bx + 3, y + 1, bz - 2, Block::SAPLING)
    set_block(bx + 4, y + 1, bz - 2, Block::CRAFTING_TABLE)
    set_block(bx + 1, y + 1, bz - 2, Block::LADDER)
    set_block(bx + 1, y + 2, bz - 2, Block::LADDER)
    [Block::SEEDS, Block::WHEAT_1, Block::WHEAT_2, Block::WHEAT_RIPE].each_with_index do |b, i|
      set_block(bx - 4 + i, y + 1, bz - 1, b)
    end
    @survival = true
    @inv_block[0] = (ENV["HAND"] || Block::LOG.to_s).to_i
    @inv_count[0] = @inv_block[0] == Block::AIR ? 0 : 5
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
      burst_particles(@player.hx, @player.hy, @player.hz, b)
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
    x = @spawn_x.floor + 2
    z = @spawn_z.floor + 2
    h = @world.height_at(x, z)
    ground = h - 1
    test_falling_and_torches(x, z, ground)
    test_survival(x, z, ground)
    test_monsters
    test_fire
    test_rain
    test_save(x, z, ground)
    test_crafting_limits
    test_inventory_layout
    test_seen_recipes
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
    test_far_items
    bx = @spawn_x.floor
    bz = @spawn_z.floor
    test_bow(bx, bz)
    test_sneak_and_bed(bx, bz)
    test_water
    test_inventory_clicks
    test_swim_out
    test_streaming
    File.delete(SAVE_PATH) if File.exist?(SAVE_PATH)
    puts @failures == 0 ? "ALL PASS" : "#{@failures} FAILED"
  end

  # Falling sand, the torch list, and how far torch light goes.
  def test_falling_and_torches(x, z, ground)
    set_block(x, ground + 6, z, Block::SAND)
    check("sand falls to the ground", @world.get(x, ground + 1, z) == Block::SAND && @world.get(x, ground + 6, z) == Block::AIR)
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
    set_block(tx, th, z, Block::TORCH)
    flush_dirty while !@later_list.empty?
    set_block(tx, th + 3, z, Block::SAND)
    lit = World.slot((tx >> 4) + 1, z >> 4)
    check("sand that buries a torch remeshes the chunks that it lit", @world.get(tx, th, z) == Block::SAND && (@dirty[lit] == true || @later[lit] == true))
    set_block(tx, th, z, Block::AIR)
    flush_dirty while !@later_list.empty?
  end

  # Survival basics: crafting, stacks, health, placing, mining, and food.
  def test_survival(x, z, ground)
    @survival = true
    @inv_block.fill(0)
    @inv_count.fill(0)
    3.times { give(Block::LOG) }
    @slot = 0
    craft_recipe(recipe_for(Block::PLANKS))
    check("craft log into planks", @inv_block[0] == Block::LOG && @inv_count[0] == 2 && @inv_block[1] == Block::PLANKS && @inv_count[1] == 4)
    70.times { give(Block::DIRT) }
    check("stacks split at 64", @inv_count[2] == 64 && @inv_block[3] == Block::DIRT && @inv_count[3] == 6)
    @health = MAX_HEALTH
    hurt(5)
    check("hurt lowers health", @health == 15 && !@dead)
    kept_blocks = @inv_block.dup
    kept_counts = @inv_count.dup
    clear_items
    toggle_inventory
    hurt(30)
    check("death at zero health, and it closes the inventory", @health == 0 && @dead && !@inventory_open)
    check("death drops the inventory on the ground", room_for(Block::DIRT) == INV * STACK && ground_count(Block::DIRT) == 70 && ground_count(Block::PLANKS) == 4)
    clear_items
    @inv_block = kept_blocks
    @inv_count = kept_counts
    respawn
    check("respawn restores health", @health == MAX_HEALTH && !@dead)
    @player.x = x + 0.5
    @player.y = ground + 1.0
    @player.z = z + 0.5
    @player.pitch = -1.55
    @player.raycast(@world)
    check("raycast hits the ground", @player.hit && @player.hy == ground)
    @slot = 1
    before = @inv_count[1]
    @player.y = ground + 3.0
    @player.raycast(@world)
    place
    check("survival place uses one item", @inv_count[1] == before - 1 && @world.get(x, ground + 1, z) == Block::PLANKS)
    set_block(x, ground + 1, z, Block::TALL_GRASS)
    @player.raycast(@world)
    place
    check("a block placed on tall grass takes its cell", @world.get(x, ground + 1, z) == Block::PLANKS && @world.get(x, ground + 2, z) == Block::AIR)
    # Stone drops cobblestone only to a pickaxe.
    @inv_block.fill(0)
    @inv_count.fill(0)
    @slot = 0
    set_block(x, ground + 1, z, Block::STONE)
    @player.y = ground + 3.0
    n = 0
    while n < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @player.raycast(@world)
      mine(0.05)
      n += 1
    end
    check("stone without a pickaxe drops nothing", @world.get(x, ground + 1, z) == Block::AIR && @it_count.empty?)
    7.times { give(Block::PLANKS) }
    craft_recipe(recipe_for(Block::WOOD_PICK))
    by_hand = count_items(Block::WOOD_PICK)
    craft_recipe(recipe_for(Block::CRAFTING_TABLE))
    table = count_items(Block::CRAFTING_TABLE) == 1
    craft_at_table(recipe_for(Block::WOOD_PICK))
    check("a crafting table comes from 4 planks, and a pickaxe needs one nearby", by_hand == 0 && table && count_items(Block::WOOD_PICK) > 0)
    @inv_block.fill(0)
    @inv_count.fill(0)
    give(Block::WOOD_PICK)
    set_block(x, ground + 1, z, Block::STONE)
    mining_frames = 0
    while mining_frames < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @player.raycast(@world)
      mine(0.05)
      mining_frames += 1
    end
    dropped = ground_count(Block::COBBLE) == 1 && @inv_count[1] == 0
    collect_items
    check("a pickaxe mines stone faster, and the cobblestone drops to the ground", mining_frames < n && dropped && @inv_block[1] == Block::COBBLE)
    by_hand = frames_to_mine(x, ground + 1, z, Block::LOG, Block::AIR)
    by_axe = frames_to_mine(x, ground + 1, z, Block::LOG, Block::STONE_AXE)
    by_pick = frames_to_mine(x, ground + 1, z, Block::LOG, Block::STONE_PICK)
    check("an axe chops a log faster than a hand or a pickaxe", by_axe < by_hand && by_pick == by_hand)
    clear_items
    @inv_block[5] = Block::COOKED_PORKCHOP
    @inv_count[5] = 2
    @slot = 5
    @hunger = 5
    eat
    check("eating restores hunger", @hunger == 15 && @inv_count[5] == 1)
  end

  # Frames of 0.05 seconds that it takes to break block b at x, y, z (which
  # the player looks at) with tool in hotbar slot 8.
  def frames_to_mine(x, y, z, b, tool)
    @inv_block[8] = tool
    @inv_count[8] = tool == Block::AIR ? 0 : Block.uses(tool)
    @slot = 8
    set_block(x, y, z, b)
    @mining = false
    n = 0
    while n < 400 && @world.get(x, y, z) == b
      @player.raycast(@world)
      mine(0.05)
      n += 1
    end
    @inv_block[8] = Block::AIR
    @inv_count[8] = 0
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
    @health = MAX_HEALTH
    @dead = false
    @player.x = px + 0.5
    @player.y = 89.0
    @player.z = pz + 0.5
    @mobs << Mob.new(Mob::SKELETON, px + 12.5, 89.0, pz + 0.5, 7)
    frames = 0
    while frames < 400 && @health == MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("skeleton arrow hurts the player", @health < MAX_HEALTH)
    @mobs.clear
    @mobs << Mob.new(Mob::ZOMBIE, px + 1.5, 89.0, pz + 0.5, 9)
    @health = MAX_HEALTH
    frames = 0
    while frames < 400 && @health == MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("zombie hit hurts the player", @health < MAX_HEALTH)
    @mobs.clear
    @mobs << Mob.new(Mob::CREEPER, px + 2.5, 89.0, pz + 0.5, 11)
    @health = MAX_HEALTH
    clear_items
    frames = 0
    while frames < 300 && @world.get(px + 2, 88, pz) == Block::STONE
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("a creeper explodes, breaks blocks and hurts", @world.get(px + 2, 88, pz) == Block::AIR && @health < MAX_HEALTH && frames > 60)
    check("some blocks that a blast breaks drop", ground_count(Block::COBBLE) > 0)
    clear_items
    @mobs.clear
    @time_of_day = 0.3
    @health = MAX_HEALTH
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
    check("a zombie in the sun burns and makes flames", zombie.fire > 0.0 && zombie.hp < Mob::HP[Mob::ZOMBIE] && @pt_kind.count(FLAME) > 0)
    @mobs.clear
    @survival = true
    @health = MAX_HEALTH
    @dead = false
    @world.set(px + 1, 89, pz, Block::LAVA)
    @player.x = px + 1.5
    update_survival(0.1)
    @world.set(px + 1, 89, pz, Block::AIR)
    @health = MAX_HEALTH
    150.times { update_survival(1.0 / 60.0) }
    burned = @fire_time > 0.0 && @health < MAX_HEALTH
    @world.set(px + 1, 89, pz, Block::WATER)
    update_survival(1.0 / 60.0)
    @world.set(px + 1, 89, pz, Block::AIR)
    check("the player burns on after lava, and water puts the fire out", burned && @fire_time == 0.0)
    @time_of_day = 0.3
    @health = MAX_HEALTH
  end

  # On the sky platform from test_monsters: rain stops the sun from burning a
  # zombie, and the rain in a column stops at the highest block.
  def test_rain
    px = @spawn_x.floor
    pz = @spawn_z.floor
    @mobs.clear
    @time_of_day = 0.25
    @raining = true
    @rain = 1.0
    zombie = Mob.new(Mob::ZOMBIE, px + 8.5, 89.0, pz + 0.5, 9)
    @mobs << zombie
    @player.x = px + 0.5
    @player.y = 89.0
    @player.z = pz + 0.5
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie does not burn in the rain", zombie.fire == 0.0 && zombie.hp == Mob::HP[Mob::ZOMBIE])
    @mobs.clear
    @rain_age = 1.0
    build_rain(0.0)
    open = rain_bottom(px + 3, pz)
    @world.set(px + 3, 95, pz, Block::STONE)
    @rain_age = 1.0
    build_rain(0.0)
    roofed = rain_bottom(px + 3, pz)
    @world.set(px + 3, 95, pz, Block::AIR)
    check("the rain in a column stops at the highest block", open < 96.0 && roofed == 96.0)
    set_raining(false)
    @rain = 0.0
    @time_of_day = 0.3
  end

  # The bottom of the rain in column x, z: the third vertex of the quad from
  # corner (x, z) to (x + 1, z + 1). A quad has 6 vertices of 11 floats.
  def rain_bottom(x, z)
    v = @rain_mesh.v
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
    kept_block = @inv_block[1]
    kept_count = @inv_count[1]
    clear_items
    drop_item(Block::STONE_SWORD, 17, x + 0.25, ground + 1.0, z + 0.75, 0.0, 0.0, 0.0, 0.0)
    set_raining(true)
    @weather_timer = 77.5
    @seen.fill(0)
    @seen[Block::DIAMOND] = 1
    save
    @world.set(x, ground + 1, z, Block::GLASS)
    @health = 3
    @inv_count[1] = 0
    clear_items
    set_raining(false)
    @rain = 0.0
    @seen.fill(0)
    ok = load
    apply_loaded if ok
    check("save and load round trip", ok && @world.get(x, ground + 1, z) == old && @health == MAX_HEALTH && @inv_block[1] == kept_block && @inv_count[1] == kept_count && kept_count > 0 && @survival)
    check("the save keeps the items on the ground and the weather",
          @it_count.size == 1 && @it_block[0] == Block::STONE_SWORD && @it_count[0] == 17 &&
          @it_x[0] == x + 0.25 && @it_y[0] == ground + 1.0 && @it_z[0] == z + 0.75 &&
          @raining && @rain == 1.0 && @weather_timer == 77.5)
    check("the save keeps the seen items", @seen[Block::DIAMOND] == 1)
    clear_items
    set_raining(false)
    @rain = 0.0
    @health = 0
    @dead = true
    save
    ok = load
    apply_loaded if ok
    check("loading a save made while dead respawns", ok && @health == MAX_HEALTH && !@dead)
    File.write(SAVE_PATH, "NOT A SAVE\n")
    ok = load
    keep_bad_save
    check("a save that does not load moves aside", !ok && !File.exist?(SAVE_PATH) && File.exist?(BAD_SAVE_PATH))
    File.delete(BAD_SAVE_PATH) if File.exist?(BAD_SAVE_PATH)
  end

  # The recipe list shows a recipe once the player has had its ingredient.
  def test_seen_recipes
    @seen.fill(0)
    @recipe_new.fill(0)
    @inv_block.fill(0)
    @inv_count.fill(0)
    give(Block::LOG)
    note_seen
    logs = shown_recipes == [recipe_for(Block::PLANKS)]
    told = @message == "NEW RECIPE: PLANKS" && @recipe_new[recipe_for(Block::PLANKS)] == 1
    toggle_inventory
    toggle_inventory
    check("a new recipe shows a message and a tag until the inventory closes", told && !@recipe_new.include?(1))
    give(Block::PLANKS)
    note_seen
    remove_items(Block::PLANKS, 1)
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
      @inv_block[i] = Block::PLANKS
      @inv_count[i] = 64
      i += 1
    end
    @inv_block[0] = Block::LOG
    @inv_count[0] = 5
    @inv_count[1] = 62
    @slot = 0
    craft_recipe(recipe_for(Block::PLANKS))
    check("crafting refuses when the result does not fit", @inv_count[0] == 5 && @inv_count[1] == 62)
    @inv_block.fill(0)
    @inv_count.fill(0)
    @inv_block[3] = Block::PLANKS
    @inv_count[3] = 2
    @inv_block[20] = Block::PLANKS
    @inv_count[20] = 4
    craft_at_table(recipe_for(Block::BOW))
    check("a recipe takes ingredients from several stacks", count_items(Block::PLANKS) == 1 && count_items(Block::BOW) == Block.uses(Block::BOW))
    # A tool wears out, and a thrown tool keeps the uses that it has left.
    @inv_block.fill(0)
    @inv_count.fill(0)
    give(Block::WOOD_PICK)
    give(Block::WOOD_PICK)
    @slot = 0
    @inv_count[0] = 1
    survival = @survival
    @survival = true
    wear_tool
    broke = @inv_count[0] == 0 && @inv_block[1] == Block::WOOD_PICK
    @inv_count[1] = 7
    @slot = 1
    clear_items
    throw_selected
    collect_items
    @survival = survival
    check("a tool breaks after its last use, and a thrown tool keeps its uses", broke && @inv_count[0] == 7 && @inv_block[0] == Block::WOOD_PICK)
    # The only free slot is the one that the recipe empties.
    i = 0
    while i < INV
      @inv_block[i] = Block::DIRT
      @inv_count[i] = 64
      i += 1
    end
    @inv_block[0] = Block::LOG
    @inv_count[0] = 1
    craft_recipe(0)
    check("a recipe click counts the slot that it empties as room", @inv_block[0] == Block::PLANKS && @inv_count[0] == 4)
  end

  # Chest contents survive a save and come back when the chest breaks.
  def test_chests(cx, cz)
    set_block(cx, 90, cz, Block::CHEST)
    @inv_block.fill(0)
    @inv_count.fill(0)
    open_chest(cx, 90, cz)
    @chest_block[5] = Block::DIAMOND
    @chest_count[5] = 7
    toggle_inventory
    save
    @chests = {}
    ok = load
    apply_loaded if ok
    stored = @chests[World.key(cx, 90, cz)]
    check("chest contents survive a save", ok && !stored.nil? && stored[5] == Block::DIAMOND && stored[CHEST_SLOTS + 5] == 7)
    set_block(cx, 90, cz, Block::AIR)
    dropped = ground_count(Block::DIAMOND) == 7 && count_items(Block::DIAMOND) == 0
    collect_items
    check("a broken chest drops its contents", dropped && count_items(Block::DIAMOND) == 7 && @chests.empty?)
    # An open chest destroyed by a blast never duplicates its contents.
    @inv_block.fill(0)
    @inv_count.fill(0)
    clear_items
    set_block(cx, 90, cz, Block::CHEST)
    open_chest(cx, 90, cz)
    @chest_block[0] = Block::DIAMOND
    @chest_count[0] = 7
    set_block(cx, 90, cz, Block::AIR)
    check("a chest destroyed while open does not duplicate items", count_items(Block::DIAMOND) + ground_count(Block::DIAMOND) == 7 && !@inventory_open && @chests.empty?)
    clear_items
  end

  # Mobs that die without the player's help drop nothing.
  def test_mob_drops
    @inv_block.fill(0)
    @inv_count.fill(0)
    far = Mob.new(Mob::PIG, @spawn_x + 30.0, 90.0, @spawn_z, 5)
    far.hp = 0
    far.alive = false
    @mobs.clear
    @mobs << far
    update_mobs(1.0 / 60.0)
    check("a pig that dies on its own drops nothing", @it_count.empty?)
    killed = Mob.new(Mob::PIG, @spawn_x + 30.0, 90.0, @spawn_z, 5)
    killed.hp = 0
    killed.alive = false
    killed.by_player = true
    @mobs << killed
    update_mobs(1.0 / 60.0)
    dropped = ground_count(Block::PORKCHOP) == 1
    collect_items
    check("a pig that the player kills drops a porkchop", dropped && count_items(Block::PORKCHOP) == 1)
    clear_items
    loot(killed, Block::BOW, 1)
    check("a bow that a mob drops is new", @it_count.size == 1 && @it_count[0] == Block.uses(Block::BOW))
    clear_items
  end

  # Stands the player on the first item until the ground is empty or the
  # frames run out.
  def collect_items
    frames = 0
    while frames < 300 && !@it_count.empty?
      @player.x = @it_x[0]
      @player.y = @it_y[0]
      @player.z = @it_z[0]
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
    @inv_block.fill(0)
    @inv_count.fill(0)
    clear_items
    @player.x = cx + 0.5
    @player.y = y + 1.0
    @player.z = cz + 0.5
    throw_stack(Block::DIRT, 1)
    run_items(0.5)
    waited = count_items(Block::DIRT) == 0 && ground_count(Block::DIRT) == 1
    @player.x = @it_x[0]
    @player.z = @it_z[0]
    run_items(1.5)
    check("a thrown item waits before the player picks it up", waited && count_items(Block::DIRT) == 1 && @it_count.empty?)
    drop_item(Block::SAND, 1, cx + 2.5, y + 3.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    @player.x = cx + 0.5
    run_items(1.5)
    check("an item falls to the ground and stays out of reach", @it_count.size == 1 && (@it_y[0] - (y + 1.0)).abs < 0.01)
    clear_items
    i = 0
    while i < INV
      @inv_block[i] = Block::STONE
      @inv_count[i] = STACK
      i += 1
    end
    drop_item(Block::SAND, 1, cx + 0.5, y + 1.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    drop_item(Block::SAND, 1, cx + 0.6, y + 1.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    run_items(0.5)
    check("a full inventory leaves items on the ground, and items of one kind join", @it_count.size == 1 && @it_count[0] == 2 && count_items(Block::SAND) == 0)
    clear_items
    @inv_block.fill(0)
    @inv_count.fill(0)
    set_block(cx + 2, y + 1, cz, Block::LAVA)
    drop_item(Block::SAND, 1, cx + 2.5, y + 1.2, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    run_items(0.2)
    check("lava burns an item", @it_count.empty?)
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
    @inv_block.fill(0)
    @inv_count.fill(0)
    give(Block::ARROW)
    pig = Mob.new(Mob::PIG, bx + 8.5, 89.0, bz + 0.5, 3)
    @mobs << pig
    shoot_bow(1.0)
    frames = 0
    while frames < 120 && pig.hp == 10
      update_arrows(1.0 / 60.0)
      frames += 1
    end
    check("a full bow draw hits a pig and uses an arrow", pig.hp < 10 && room_for(Block::ARROW) == INV * STACK)
    @mobs.clear
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
    clear_items
    drop_item(Block::DIRT, 1, @player.x + 3000.0, 60.0, @player.z, 0.0, 0.0, 0.0, 0.0)
    run_items(6.0)
    check("an item in a chunk that is not loaded waits there", @it_count.size == 1 && @it_y[0] == 60.0 && @it_age[0] == 0.0)
    clear_items
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
    @inv_block.fill(0)
    @inv_count.fill(0)
    9.times { give(Block::IRON) }
    give(Block::COAL)
    2.times { give(Block::PLANKS) }
    smelt = recipe_for(Block::IRON_INGOT)
    craft_recipe(smelt)
    far = count_items(Block::IRON) == 9
    check("smelting needs a furnace nearby", far)
    set_block(x + 2, y, z + 3, Block::FURNACE)
    craft_recipe(smelt)
    # No fuel covers 9 smelts, so the coal burns for 8.
    coal = count_items(Block::IRON) == 1 && count_items(Block::IRON_INGOT) == 8 && count_items(Block::COAL) == 0 && count_items(Block::PLANKS) == 2
    craft_recipe(smelt)
    plank = count_items(Block::IRON) == 0 && count_items(Block::IRON_INGOT) == 9 && count_items(Block::PLANKS) == 1
    give(Block::SAND)
    remove_items(Block::PLANKS, 1)
    craft_recipe(recipe_for(Block::GLASS))
    no_fuel = count_items(Block::SAND) == 1 && count_items(Block::GLASS) == 0
    set_block(x + 2, y, z + 3, Block::AIR)
    check("a smelt burns the smallest fuel that covers it, and needs fuel", coal && plank && no_fuel)
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
    @inv_block.fill(0)
    @inv_count.fill(0)
    (9 * STACK + 3).times { give(Block::DIRT) }
    check("a full hotbar spills into the backpack", @inv_block[9] == Block::DIRT && @inv_count[9] == 3)
    click_slot(9)
    click_slot(20)
    check("clicks move a stack", @inv_count[9] == 0 && @inv_block[20] == Block::DIRT && @inv_count[20] == 3 && @held_count == 0)
    click_slot(20)
    click_slot(0)
    check("clicks merge into a full stack and keep the rest", @inv_count[0] == 64 && @held_count == 3)
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
