# Test switches: SELFTEST, SHOWMOBS, SHOWITEMS, SHOWBOATS and STRIKE.
class Game
  # A height above the land and the trees, where the tests and the
  # screenshot scenes build in open air.
  SKY_Y = WY - 6
  # STRIKE=1 strikes this far in front of the player, and this far to the side.
  STRIKE_AHEAD = 40.0
  STRIKE_ASIDE = 8.0

  # STRIKE=1: lightning strikes in front of the player, a little to the side.
  def strike_ahead
    x = @player.x + Math.sin(@player.yaw) * STRIKE_AHEAD + Math.cos(@player.yaw) * STRIKE_ASIDE
    z = @player.z - Math.cos(@player.yaw) * STRIKE_AHEAD + Math.sin(@player.yaw) * STRIKE_ASIDE
    lightning_hit_player if @storm.strike(x.floor, z.floor, @player, @particles)
  end

  # SHOWMOBS=1 lines up one mob of each kind on a stone floor in front of the player.
  def show_mobs
    @mobs.clear
    bx = @player.x.floor
    bz = @player.z.floor - 6
    y = SKY_Y - 10
    fill_box(bx - 4, y, bz - 3, bx + 4, y, bz + 3, Block::STONE)
    set_block(bx - 3, y + 1, bz + 2, Block.bed_id(1, false))
    set_block(bx - 2, y + 1, bz + 2, Block.bed_id(0, true))
    set_block(bx + 3, y + 1, bz + 2, Block::TORCH)
    [Mob::PIG, Mob::SHEEP, Mob::COW, Mob::ZOMBIE, Mob::SKELETON, Mob::CREEPER].each_with_index do |kind, i|
      x = bx - 4.0 + i * 1.6
      m = Mob::PASSIVE[kind] == 1 ? Animal.new(kind, x, y + 1.0, bz + 0.5, 1) : Monster.new(kind, x, y + 1.0, bz + 0.5, 1)
      m.yaw = 3.14159
      m.head = kind == Mob::ZOMBIE ? Block::CARVED_PUMPKIN : Block::JACK_O_LANTERN if @halloween && (kind == Mob::ZOMBIE || kind == Mob::SKELETON)
      @mobs << m
    end
    @mobs << Animal.new(Mob::CHICKEN, bx - 0.5, y + 1.0, bz + 2.5, 1)
    chick = Animal.new(Mob::CHICKEN, bx + 1.5, y + 1.0, bz + 2.5, 2)
    chick.make_baby
    @mobs << chick
    @player.x = bx + 0.5
    @player.y = y + 1.5
    @player.z = bz + 6.5
    @player.yaw = 0.0
    @player.pitch = -0.15
    @player.flying = true
    @clock.time_of_day = 0.3
  end

  # SHOWBOATS=1 puts a boat of each wood on a pool of water, with the
  # player in the nearest one.
  def show_boats
    bx = @player.x.floor.to_i
    bz = @player.z.floor.to_i
    y = SKY_Y - 10
    (bx - 7..bx + 7).each do |cx|
      (bz - 16..bz + 3).each do |cz|
        set_block(cx, y, cz, Block::STONE)
        rim = cx == bx - 7 || cx == bx + 7 || cz == bz - 16 || cz == bz + 3
        @world.set(cx, y + 1, cz, rim ? Block::STONE : Block::WATER)
        @chunk_meshes.mark_block(cx, cz)
      end
    end
    @boats.clear
    top = y + 1 + 8.0 / 9.0 - Boat::DRAFT
    @boats << Boat.new(Block::OAK_BOAT, bx + 0.5, top, bz + 0.5, 0.0)
    @boats << Boat.new(Block::SPRUCE_BOAT, bx - 1.5, top, bz - 5.5, 0.8)
    @boats << Boat.new(Block::BIRCH_BOAT, bx + 3.0, top, bz - 9.5, -1.9)
    @player.flying = false
    @player.yaw = 0.0
    @player.pitch = -0.3
    board_boat(0)
    @clock.time_of_day = 0.3
  end

  # SHOWITEMS=1 lays a row of dropped items on a stone floor in front of the
  # player, in survival with a block in the hand. HAND=id holds block id
  # instead (0 for the empty hand).
  def show_items
    bx = @player.x.floor
    bz = @player.z.floor - 4
    y = SKY_Y - 10
    fill_box(bx - 4, y, bz - 3, bx + 4, y, bz + 3, Block::STONE)
    shown = [Block::GRASS, Block::CHEST, Block::DOOR, Block::FURNACE, Block::OAK_SAPLING, Block::APPLE,
             Block::BREAD, Block::WHEAT, Block::IRON_SWORD, Block::IRON_AXE, Block::STONE_SHOVEL, Block::ARROW]
    shown.each_with_index do |block, i|
      drop_item(block, i == 11 ? 3 : 1, bx - 3.6 + i * 0.65, y + 1.0, bz + 0.5, 0.0, 0.0, 0.0, 1.0e9)
    end
    # A closed door and an open door that face the player.
    set_block(bx - 2, y + 1, bz - 2, Block.door_id(2, false, false))
    set_block(bx - 2, y + 2, bz - 2, Block.door_id(2, true, false))
    set_block(bx, y + 1, bz - 2, Block.door_id(2, false, true))
    set_block(bx, y + 2, bz - 2, Block.door_id(2, true, true))
    # A chest and a lit furnace face the player.
    set_block(bx - 4, y + 1, bz - 2, Block.facing_id(Block::CHEST, 2))
    set_block(bx + 2, y + 1, bz - 2, Block.furnace_id(2, true))
    set_block(bx + 4, y + 1, bz - 2, Block::CRAFTING_TABLE)
    # A wall torch on the side of the table, and a ladder on a wall.
    set_block(bx + 3, y + 1, bz - 2, Block.facing_id(Block::TORCH, 1))
    set_block(bx + 1, y + 1, bz - 3, Block::STONE)
    set_block(bx + 1, y + 2, bz - 3, Block::STONE)
    set_block(bx + 1, y + 1, bz - 2, Block.facing_id(Block::LADDER, 2))
    set_block(bx + 1, y + 2, bz - 2, Block.facing_id(Block::LADDER, 2))
    # A bed in front of the table, with its head to the right.
    set_block(bx + 3, y + 1, bz - 1, Block.bed_id(1, false))
    set_block(bx + 4, y + 1, bz - 1, Block.bed_id(0, true))
    [Block::SEEDS, Block::WHEAT_1, Block::WHEAT_2, Block::WHEAT_RIPE].each_with_index do |block, i|
      set_block(bx - 4 + i, y + 1, bz - 1, block)
    end
    @survival = true
    hand = (ENV["HAND"] || Block::OAK_LOG.to_s).to_i
    @inv.set(0, hand, hand == Block::AIR ? 0 : 5)
    @slot = 0
    @player.x = bx + 0.5
    @player.y = y + 1.0
    @player.z = bz + 3.5
    @player.yaw = 0.0
    @player.pitch = -0.35
    @player.flying = true
    @clock.time_of_day = 0.3
  end

  def check(name, ok)
    puts "#{ok ? "PASS" : "FAIL"} #{name}"
    @checks += 1
    @failures += 1 unless ok
  end

  # True when the newest line of the chat is red.
  def last_chat_error? = @chat.error?(@chat.lines.size - 1)

  # SELFTEST=1 runs the game rules without input and reports PASS/FAIL lines.
  # It returns true when all rules pass.
  def self_test
    @checks = 0
    @failures = 0
    test_spawn
    test_sandstone
    test_ores
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
    test_held_blocks_drop(x, z, ground)
    test_survival(x, z, ground)
    test_monsters
    test_fire
    test_rain
    test_thunder
    test_weather_fade
    test_cactus
    test_save(x, z, ground)
    test_crafting_limits
    test_inventory_layout
    test_menu_layout
    test_seen_recipes
    test_recipe_scroll
    test_creative_layout
    cx = @spawn_x.floor + 4
    cz = @spawn_z.floor + 4
    test_split_and_quick_move(cx, cz)
    test_chests(cx, cz)
    test_mob_drops
    test_mob_death
    test_mob_panic
    test_leaf_decay
    test_grass_spread
    test_covered_grass
    test_drop_rates
    test_items(cx, cz)
    test_light_sources(cx, cz)
    test_tint(cx, cz)
    test_door_furnace_sapling
    test_door_rules
    test_door_board
    test_door_swing
    test_ladder
    test_ladder_wall
    test_low_blocks
    test_plant_box
    test_bed
    test_place_cells
    test_large_chest
    test_buckets
    test_pumpkins
    test_bone_meal
    test_seed_soil
    test_shear_sheep
    test_mob_hides_block
    test_resume_click
    test_lambs
    test_graze_rate
    test_breeding
    test_right_click_boat
    test_push
    test_far_items
    test_treasure
    bx = @spawn_x.floor
    bz = @spawn_z.floor
    test_bow(bx, bz)
    test_sneak_and_bed(bx, bz)
    test_bow_on_stations
    test_water
    test_inventory_clicks
    test_swim_out
    test_swing_at_air
    test_bow_draw_image
    test_pause
    test_screens
    test_screen_input
    test_menu
    test_fullscreen_follows_window
    test_commands
    test_tab_completion
    test_fly_keys
    test_boats
    test_sounds
    test_culling
    test_streaming
    test_title
    test_demo_reel
    File.delete(@save_path) if File.exist?(@save_path)
    puts @failures == 0 ? "ALL #{@checks} PASS" : "#{@failures} OF #{@checks} FAILED"
    @failures == 0
  end

  # The player starts on dry land: above the beach, with no water or
  # leaves underfoot.
  def test_spawn
    x = @spawn_x.floor
    z = @spawn_z.floor
    h = @world.height_at(x, z)
    block = @world.get(x, h - 1, z)
    check("the player spawns on dry land", h > SEA + 2 && Block.solid?(block) && !Block.leaves?(block) && !Block.water?(block))
  end

  # Each sand column near spawn has SOIL_DEPTH of sand on SANDSTONE_DEPTH
  # of sandstone, where no cave cuts it. 4 sand make a sandstone.
  def test_sandstone
    sand = 0
    held = 0
    depth = ChunkGenerator::SOIL_DEPTH + ChunkGenerator::SANDSTONE_DEPTH
    (@spawn_x.floor - 128...@spawn_x.floor + 128).each do |x|
      (@spawn_z.floor - 128...@spawn_z.floor + 128).each do |z|
        top = @world.height_at(x, z) - 1
        if @world.loaded?(x, z) && @world.get(x, top, z) == Block::SAND && (1...depth).none? { |d| @world.get(x, top - d, z) == Block::AIR }
          sand += 1
          held += 1 if (0...depth).all? { |d| @world.get(x, top - d, z) == (d < ChunkGenerator::SOIL_DEPTH ? Block::SAND : Block::SANDSTONE) }
        end
      end
    end
    check("sand lies on sandstone", sand > 0 && held == sand)
    @inv.clear
    5.times { @inv.add(Block::SAND) }
    craft_recipe(recipe_for(Block::SANDSTONE))
    check("4 sand make a sandstone", @inv.total(Block::SAND) == 1 && @inv.total(Block::SANDSTONE) == 1)
    @inv.clear
  end

  # Near spawn, each ore holds its share of the stone at each layer
  # (Ores.ore_at), and no ore lies at a layer where that share is 0.
  def test_ores
    ores = [Block::COAL_ORE, Block::IRON, Block::DIAMOND, Block::SPINEL_ORE]
    stone = Array.new(WY, 0)
    found = Array.new(ores.size * WY, 0)
    x = @spawn_x.floor - 128
    while x < @spawn_x.floor + 128
      z = @spawn_z.floor - 128
      while z < @spawn_z.floor + 128
        if @world.loaded?(x, z)
          y = 1
          while y < WY
            block = @world.get(x, y, z)
            k = ores.index(block) || -1
            stone[y] += 1 if block == Block::STONE || k >= 0
            found[k * WY + y] += 1 if k >= 0
            y += 1
          end
        end
        z += 1
      end
      x += 1
    end
    near = true
    outside = 0
    ores.each_with_index do |ore, k|
      want = 0.0
      got = 0
      (1...WY).each do |y|
        share = Ores.ore_at(ore, y)
        want += stone[y] * share / 256
        got += found[k * WY + y]
        outside += found[k * WY + y] if share == 0.0
      end
      near = false unless got > want * 0.75 && got < want * 1.25
    end
    check("each ore fills its share of the stone at each layer", near)
    check("no ore lies outside the layers of its Minecraft range", outside == 0)
  end

  # The commands change the time, the inventory and the place of the
  # player, and a bad command prints a red line.
  def test_commands
    survival = @survival
    day = @clock.day
    @chat = Chat.new
    run_chat("/time set midnight")
    midnight = @clock.ticks == 18000
    run_chat("/time add 6000")
    added = @clock.ticks == 0 && @clock.day == day + 1
    check("/time set and /time add move the clock, and a new day starts at 6:00", midnight && added)
    run_chat("/time set 0")
    run_chat("/time add 2147483647")
    check("/time add of many days counts them at once",
          @clock.day == day + 1 + 2147483647 / Clock::DAY_TICKS && @clock.ticks == 2147483647 % Clock::DAY_TICKS)
    @clock.time_of_day = 0.3
    @clock.day = day
    set_mode(true)
    kept = @inv.copy
    @inv.clear
    run_chat("/give diamond_pickaxe")
    run_chat("/give @s torch 70")
    check("/give puts items in the inventory, with a count",
          @inv.block(0) == Block::DIAMOND_PICK && @inv.count(0) == Block.uses(Block::DIAMOND_PICK) &&
          @inv.total(Block::TORCH) == 70 && !last_chat_error?)
    run_chat("/give dirtt")
    bad_item = last_chat_error?
    run_chat("/give dirt 0")
    bad_count = last_chat_error?
    run_chat("/fly")
    unknown = last_chat_error? && @chat.lines.last == "UNKNOWN COMMAND: FLY"
    check("a bad item, count or command prints an error line", bad_item && bad_count && unknown)
    @inv = kept
    run_chat("/gamemode creative")
    creative = !@survival
    run_chat("/gamemode s")
    check("/gamemode switches survival and creative", creative && @survival)
    set_mode(survival)
    x = @player.x
    y = @player.y
    z = @player.z
    run_chat("/tp ~ ~2 ~-3")
    relative = @player.x == x && @player.y == y + 2.0 && @player.z == z - 3.0
    tx = @spawn_x.floor + 1
    tz = @spawn_z.floor - 1
    run_chat("/tp #{tx} 150 #{tz}")
    whole = @player.x == tx + 0.5 && @player.y == 150.0 && @player.z == tz + 0.5
    check("/tp moves the player, with ~ for a place relative to the player", relative && whole)
    site = @treasure.nearest(@player.x.to_f, @player.z.to_f)
    run_chat("/locate treasure")
    found = @chat.lines.last.start_with?("THE NEAREST TREASURE IS AT [#{site.chest_x}, #{site.chest_y}, #{site.chest_z}] (")
    run_chat("/locate village")
    check("/locate treasure gives the place of the nearest treasure chest", site.found? && found && last_chat_error?)
    mobs = @mobs.size
    run_chat("/summon creeper ~ ~ ~5")
    m = @mobs.last
    check("/summon puts a mob of the kind at the place",
          @mobs.size == mobs + 1 && m.kind == Mob::CREEPER && m.x == @player.x && m.z == @player.z + 5.0 && m.hp == Mob::HP[Mob::CREEPER])
    @mobs.pop
    run_chat("/tp 99999999 100 -99999999")
    check("/tp stops at the farthest x and z that the world holds",
          @player.x == TP_LIMIT && @player.z == -TP_LIMIT && @player.y == 100.0)
    run_chat("/tp ~3000 ~ ~3000")
    run_chat("/spawn")
    h = @world.height_at(@spawn_x.floor, @spawn_z.floor)
    check("/spawn goes to the ground at the spawn point, also from far away",
          @player.x == @spawn_x && @player.z == @spawn_z && @player.y == h + 0.01 &&
          Block.solid?(@world.get(@spawn_x.floor, h - 1, @spawn_z.floor)))
    @player.x = x
    @player.y = y
    @player.z = z
    run_chat("/time set noon")
    open_chat("")
    @chat.recall(-1)
    back = @chat.text == "/time set noon"
    @chat.recall(-1)
    further = @chat.text == "/spawn"
    @chat.recall(1)
    @chat.recall(1)
    check("Up and Down walk through the lines typed before", back && further && @chat.text == "")
    close_chat
    @clock.time_of_day = 0.3
  end

  # Tab completes a command, then the names that the command takes.
  # The scancode of G, a key that no longer does anything.
  KEY_G = 10

  # The demo reel (DEMO=1, tools/demo.sh) plays to its end, as in a
  # recording: the miner breaks the ores, a calf comes, the sheep loses its
  # wool, the house goes up, and the player lives through the night. It
  # plays in a new world of seed 1337, as a recording does, and not among
  # the blocks of the other checks.
  def test_demo_reel
    new_world(1337)
    dt = 1.0 / RECORD_FPS
    calf = false
    wool = false
    died = false
    mined = false
    until @quit
      demo(dt)
      update_game(dt)
      Gfx.in_test_frame
      mined = true if @demo_scene == 1 && mine_target < 0
      calf = true if @mobs.any? { |mob| mob.kind == Mob::COW && mob.baby? }
      wool = true if @mobs.any? { |mob| mob.kind == Mob::SHEEP && !mob.baby? && !mob.shearable? }
      died = true if @player.vitals.dead?
    end
    @quit = false
    check("the demo reel: the miner breaks each block of the mine", mined)
    check("the demo reel: a calf comes", calf)
    check("the demo reel: the sheep loses its wool", wool)
    check("the demo reel: the whole house goes up", @demo_built * 4 == @demo_build.size)
    check("the demo reel: the player lives through the night", !died)
  end

  # Runs one frame of dt seconds with key down or up, through the key
  # state that in_poll fills.
  def key_frame(key, down, dt)
    Gfx.in_test_key(key, down ? 1 : 0)
    update_game(dt)
    Gfx.in_test_frame
  end

  # The ripe stem at x, y, z tries once to grow a pumpkin.
  def grow_pumpkin_now(x, y, z)
    @plants.grow_pumpkin(x, y, z, @changes)
    apply_changes
  end

  # Sets each block from x0, y0, z0 to x1, y1, z1 to block, in the order x, y, z.
  def fill_box(x0, y0, z0, x1, y1, z1, block)
    (x0..x1).each { |x| (y0..y1).each { |y| (z0..z1).each { |z| set_block(x, y, z, block) } } }
  end

  # The number of cells from x0, y0, z0 to x1, y1, z1 that hold block.
  def count_box(x0, y0, z0, x1, y1, z1, block)
    count = 0
    (x0..x1).each { |x| (y0..y1).each { |y| (z0..z1).each { |z| count += 1 if @world.get(x, y, z) == block } } }
    count
  end

  # Saves the place, the view and the flight of the player. restore_pose
  # puts them back at the end of a test.
  def keep_pose
    @kept_x = @player.x
    @kept_y = @player.y
    @kept_z = @player.z
    @kept_yaw = @player.yaw
    @kept_pitch = @player.pitch
    @kept_flying = @player.flying
  end

  def restore_pose
    @player.x = @kept_x
    @player.y = @kept_y
    @player.z = @kept_z
    @player.yaw = @kept_yaw
    @player.pitch = @kept_pitch
    # == true: a Bool, so Spinel keeps Player#flying typed.
    @player.flying = @kept_flying == true
  end

  # Puts the player at rest on the block x, y - 1, z, not flying.
  def stand_at(x, y, z)
    @player.move_to(x + 0.5, y.to_f, z + 0.5)
    @player.flying = false
    @last_jump = -1.0
  end

  # Two quick presses of Space start and stop flying in creative, through
  # the real input path. A slow double press and a double press in
  # survival do not, a landing stops the flight, and R and G no longer
  # change the rain or the game mode.
  def test_fly_keys
    survival = @survival
    x = @spawn_x.floor
    z = @spawn_z.floor
    y = SKY_Y - 10
    fill_box(x - 2, y, z - 2, x + 2, y, z + 2, Block::STONE)
    set_mode(false)
    stand_at(x, y + 1, z)
    key_frame(Key::SPACE, true, 0.05)
    jumped = @player.y > y + 1.0 && !@player.flying
    key_frame(Key::SPACE, false, 0.05)
    key_frame(Key::SPACE, true, 0.05)
    on = @player.flying
    high = @player.y
    8.times { key_frame(Key::SPACE, true, 0.05) }
    rose = @player.y > high + 0.3 && @player.flying
    key_frame(Key::SPACE, false, 0.05)
    key_frame(Key::SPACE, true, 0.05)
    key_frame(Key::SPACE, false, 0.05)
    key_frame(Key::SPACE, true, 0.05)
    off = !@player.flying
    key_frame(Key::SPACE, false, 0.05)
    check("one Space jumps, two quick presses start and stop flying in creative, and Space held while flying rises",
          jumped && on && rose && off)
    stand_at(x, y + 1, z)
    key_frame(Key::SPACE, true, 0.05)
    key_frame(Key::SPACE, false, 0.5)
    key_frame(Key::SPACE, true, 0.05)
    slow = !@player.flying
    key_frame(Key::SPACE, false, 0.05)
    set_mode(true)
    stand_at(x, y + 1, z)
    key_frame(Key::SPACE, true, 0.05)
    key_frame(Key::SPACE, false, 0.05)
    key_frame(Key::SPACE, true, 0.05)
    in_survival = !@player.flying
    key_frame(Key::SPACE, false, 0.05)
    check("a slow double press, or one in survival, does not start flying", slow && in_survival)
    set_mode(false)
    stand_at(x, y + 2, z)
    @player.flying = true
    key_frame(Key::SPACE, false, 0.1)
    aloft = @player.flying
    20.times { key_frame(Key::LSHIFT, true, 0.05) }
    key_frame(Key::LSHIFT, false, 0.05)
    check("a flying player who comes down onto a block stops flying", aloft && !@player.flying && @player.on_ground)
    rain = @weather.raining?
    Gfx.in_test_key(Key::R, 1)
    Gfx.in_test_key(KEY_G, 1)
    handle_keys
    Gfx.in_test_frame
    Gfx.in_test_key(Key::R, 0)
    Gfx.in_test_key(KEY_G, 0)
    Gfx.in_test_frame
    check("R and G no longer change the rain or the game mode", @weather.raining? == rain && !@survival)
    set_mode(survival)
  end

  def test_tab_completion
    commands = Command.complete("/t")
    check("Tab completes the command names",
          Command.complete("/gi") == ["give"] && commands == ["teleport", "time", "tp"] && Command.complete("hello").empty?)
    items = Command.complete("/give ")
    check("Tab completes item names in /give and mob names in /summon, also after @s",
          Command.complete("/give @s diamond_p") == ["diamond_pickaxe"] && Command.complete("/summon c") == ["creeper", "cow", "chicken"] &&
          Command.complete("/give pum") == ["pumpkin", "pumpkin_seeds", "pumpkin_pie"] && Command.complete("/give jack") == ["jack_o_lantern"] &&
          items.size == CREATIVE_ITEMS.size && items.count("water") == 1 && items.count("wheat") == 1 &&
          !items.include?("wheat_crops"))
    check("Tab completes the words of /time, /weather and /gamemode",
          Command.complete("/time set n") == ["noon", "night"] && Command.complete("/time q") == ["query"] &&
          Command.complete("/weather r") == ["rain"] && Command.complete("/gamemode c") == ["creative"] &&
          Command.complete("/kill x").empty?)
  end

  # The title and the pause screen stop the world, but the inventory and
  # the death screen do not.
  def test_pause
    time = @clock.time_of_day
    show_screen(Screen::PAUSED)
    update_game(0.05)
    stopped = @clock.time_of_day == time
    show_screen(Screen::INVENTORY)
    update_game(0.05)
    inventory = @clock.time_of_day != time
    show_screen(Screen::DEAD)
    time = @clock.time_of_day
    update_game(0.05)
    dead = @clock.time_of_day != time
    show_screen(Screen::TITLE)
    time = @clock.time_of_day
    update_game(0.05)
    title = @clock.time_of_day == time
    show_screen(Screen::PLAYING)
    check("the title and the pause screen stop the world, but not the inventory or the death screen", stopped && title && inventory && dead)
  end

  # The inventory, the chat and a death open their screens, and closing the
  # inventory or the chat goes back to playing.
  def test_screens
    toggle_inventory
    opened = current_screen.inventory?
    toggle_inventory
    open_chat("")
    typing = current_screen.typing?
    close_chat
    check("the inventory and the chat open their screens and give the game back", opened && typing && current_screen.playing?)
    survival = @survival
    @survival = true
    @inv.clear
    toggle_inventory
    open_chat("")
    @player.vitals.hurt(1000)
    felt_hurt(Sfx::HURT)
    dead = current_screen.death_screen?
    respawn
    resume
    check("a death opens the death screen, and a respawn plays again", dead && current_screen.playing? && !@player.vitals.dead?)
    @survival = survival
    Gfx.in_capture(0)
  end

  # Esc pauses the game, and R on the death screen respawns the player.
  def test_screen_input
    Gfx.in_test_frame
    Gfx.in_test_key(Key::ESCAPE, 1)
    handle_input(0.05)
    Gfx.in_test_key(Key::ESCAPE, 0)
    Gfx.in_test_frame
    paused = current_screen.pause_menu?
    show_screen(Screen::DEAD)
    Gfx.in_test_key(Key::R, 1)
    handle_input(0.05)
    Gfx.in_test_key(Key::R, 0)
    Gfx.in_test_frame
    check("Esc opens the pause menu, and R on the death screen respawns the player", paused && current_screen.playing?)
    Gfx.in_capture(0)
  end

  # A click on BACK TO GAME takes the mouse while the button is still down.
  # The held button does nothing until the player lets it go, so the click
  # does not also break the block in view. The next click does.
  def test_resume_click
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 120
    y = SKY_Y - 20
    fill_box(bx - 2, y + 1, bz - 2, bx + 2, y + 4, bz + 2, Block::AIR)
    fill_box(bx - 2, y, bz - 2, bx + 2, y, bz + 2, Block::STONE)
    survival = @survival
    keep_pose
    @survival = false
    @mobs.clear
    @target_mob = -1
    @target_boat = -1
    @player.x = bx + 0.5
    @player.y = y + 1.0
    @player.z = bz + 0.5
    @player.flying = true
    @player.pitch = -1.55
    @target_block.trace(@world, @player)
    show_screen(Screen::PAUSED)
    Gfx.in_test_button(1, 1)
    click_menu(M_RESUME)
    Gfx.in_test_frame
    5.times do
      handle_input(0.05)
      Gfx.in_test_frame
    end
    kept = @world.get(bx, y, bz) == Block::STONE
    Gfx.in_test_button(1, 0)
    handle_input(0.05)
    Gfx.in_test_frame
    Gfx.in_test_button(1, 1)
    handle_input(0.05)
    Gfx.in_test_button(1, 0)
    Gfx.in_test_frame
    Gfx.in_capture(0)
    check("the click on BACK TO GAME breaks no block, and the next click does", kept && @world.get(bx, y, bz) == Block::AIR)
    @survival = survival
    restore_pose
  end

  # Save and quit to title saves the world and opens the title screen. The
  # world waits behind it, and the view turns. PLAY starts the game in the
  # same world, and NEW WORLD asks for a second click that comes at least
  # CONFIRM_WAIT after the first. A click on PLAY or NEW WORLD takes the
  # mouse, as a click on Back to game does, so the check gives it back.
  def test_title
    File.delete(@save_path) if File.exist?(@save_path)
    show_screen(Screen::PAUSED)
    click_menu(M_QUIT)
    check("save and quit to title saves the world and opens the title screen", File.exist?(@save_path) && current_screen.title? && !@quit)
    time = @clock.time_of_day
    yaw = @player.yaw
    update_game(0.5)
    check("the world waits behind the title screen, and the view turns",
          @clock.time_of_day == time && @player.yaw == yaw + TITLE_TURN * 0.5)
    click_title(T_QUIT)
    quit = @quit
    @quit = false
    check("QUIT on the title screen quits the game", quit)
    seed = @seed
    click_title(T_NEW_WORLD)
    asks = current_screen.title? && title_label(T_NEW_WORLD) == "LOSE THIS WORLD? CLICK AGAIN"
    click_title(T_PLAY)
    Gfx.in_capture(0)
    check("PLAY on the title screen starts the game in the same world, and ends the question of NEW WORLD",
          asks && current_screen.playing? && @seed == seed && title_label(T_NEW_WORLD) == "NEW WORLD")
    show_screen(Screen::PAUSED)
    open_title
    click_title(T_NEW_WORLD)
    update_game(0.2)
    click_title(T_NEW_WORLD)
    check("a double-click on NEW WORLD keeps the world and asks again",
          current_screen.title? && @seed == seed && title_label(T_NEW_WORLD) == "LOSE THIS WORLD? CLICK AGAIN")
    update_game(CONFIRM_WAIT)
    click_title(T_NEW_WORLD)
    Gfx.in_capture(0)
    check("a second click on NEW WORLD on the title screen starts a new world", current_screen.playing? && @seed != seed)
  end

  # The window can leave or enter fullscreen without the menu or F11, as
  # through the green button of macOS. The FULLSCREEN option follows it.
  def test_fullscreen_follows_window
    fullscreen = @options.fullscreen
    @options.fullscreen = true
    Gfx.in_test_fullscreen(0)
    handle_input(0.05)
    left = !@options.fullscreen && menu_label(M_FULLSCREEN) == "FULLSCREEN: OFF"
    Gfx.in_test_fullscreen(1)
    handle_input(0.05)
    entered = @options.fullscreen && menu_label(M_FULLSCREEN) == "FULLSCREEN: ON"
    Gfx.in_test_fullscreen(-1)
    @options.fullscreen = fullscreen
    check("the FULLSCREEN option follows the window when it leaves or enters fullscreen", left && entered)
  end

  # The sliders of the pause menu set the options.
  def test_menu
    options = @options
    path = file_prefix + OPTIONS_PATH
    @options = Options.new(path)
    set_slider(M_VIEW, 0.5)
    check("the render distance slider sets the render distance", @options.view == 2600.0 && menu_label(M_VIEW) == "RENDER DISTANCE: 2600 BLOCKS")
    set_slider(M_BRIGHTNESS, 1.0)
    set_slider(M_VOLUME, 0.25)
    set_slider(M_MUSIC, 0.0)
    check("the brightness and volume sliders set the options", @options.brightness == 1.0 && slider_value(M_VOLUME) == 0.25 && menu_label(M_VOLUME) == "VOLUME: 25%")
    check("the music slider sets the music volume", slider_value(M_MUSIC) == 0.0 && menu_label(M_MUSIC) == "MUSIC: OFF")
    set_slider(M_FOV, 0.5)
    normal = menu_label(M_FOV)
    set_slider(M_FOV, 1.0)
    quake = menu_label(M_FOV)
    set_slider(M_FOV, 0.0)
    check("the field of view slider goes from 30 to 110 degrees, with 70 as normal",
          @options.fov_degrees == Options::FOV_MIN && menu_label(M_FOV) == "FIELD OF VIEW: 30" && normal == "FIELD OF VIEW: NORMAL" && quake == "FIELD OF VIEW: QUAKE PRO")
    check("the view takes the new field of view at once", @fov == Options::FOV_MIN * Math::PI / 360.0)
    # The compiled game writes the numbers, so this check runs here and
    # not only in Minitest.
    @options.fov_degrees = 90.0
    @options.view = 1200.0
    @options.debug = false
    @options.write_file
    read = Options.new(path)
    read.read_file
    File.delete(path)
    check("the options load from the file that write_file writes",
          read.brightness == 1.0 && read.volume == 0.25 && read.music == 0.0 && read.view == 1200.0 && read.fov_degrees == 90.0 && !read.debug && !read.fullscreen)
    @options = options
    @fov = @options.half_fov
  end

  # Every sound file loads, footsteps follow the block underfoot, and a
  # creeper hisses once when it lights its fuse.
  # A boat goes only on water, floats there, goes up to 8 m/s on water and
  # 2 m/s on land, carries the player, lets the player out on land, and
  # breaks into its item. minecraft.wiki/w/Boat
  def test_boats
    x = @spawn_x.floor + 60
    z = @spawn_z.floor - 60
    y = SKY_Y - 20
    # A stone floor 3 wide and 40 long along -z, with walls around it, and
    # a bank of stone on its +x side.
    (x - 2..x + 3).each do |cx|
      (z - 41..z + 1).each do |cz|
        @world.set(cx, y, cz, Block::STONE)
        wall = cx == x - 2 || cz == z - 41 || cz == z + 1
        @world.set(cx, y + 1, cz, wall || cx >= x + 2 ? Block::STONE : Block::AIR)
      end
    end
    @boats.clear
    @riding = -1
    survival = @survival
    boat = Boat.new(Block::OAK_BOAT, x + 0.5, y + 1.0, z - 20.5, 0.0)
    150.times { boat.move_boat(@world, 0.02, 1.0, 0.0) }
    land = boat.speed
    # The player cannot put a boat on land.
    @survival = true
    @inv.clear
    @slot = 0
    @inv.add(Block::OAK_BOAT)
    @player.flying = false
    @player.x = x + 0.5
    @player.y = y + 2.5
    @player.z = z - 2.5
    @player.yaw = 0.0
    @player.pitch = -1.55
    place_boat
    on_land = @boats.size
    (x - 1..x + 1).each { |cx| (z - 40..z).each { |cz| @world.set(cx, y + 1, cz, Block::WATER) } }
    place_boat
    placed = @boats.size == 1 && @inv.empty?(0)
    check("a boat goes on water, not on land", on_land == 0 && placed)
    boat = @boats[0]
    100.times { boat.move_boat(@world, 0.02, 0.0, 0.0) }
    float = y + 1 + 8.0 / 9.0 - Boat::DRAFT
    check("a boat floats with its bottom just under the water", boat.afloat && (boat.y - float).abs < 0.01)
    board_boat(0)
    seated = riding? && (@player.y - (boat.y + Boat::SEAT)).abs < 0.001
    start_z = @player.z
    @player.controls.hold(1.0, 0.0, jump: false, sneak: false, sprint: false)
    150.times { update_boats(0.02) }
    water = boat.speed
    carried = (@player.z - boat.z).abs < 0.001 && @player.z < start_z - 15.0
    check("a boat goes up to 8 m/s on water and 2 m/s on land",
          water > 7.9 && water < 8.0001 && land > 1.95 && land < 2.0001)
    check("the rider sits in the boat and goes with it", seated && carried)
    # A turn key turns the boat and the player's view at up to 200 degrees/s.
    @player.controls.hold(0.0, 1.0, jump: false, sneak: false, sprint: false)
    150.times { update_boats(0.02) }
    yaw = @player.yaw
    boat_yaw = boat.yaw
    @player.controls.hold(0.0, 1.0, jump: false, sneak: false, sprint: false)
    update_boats(0.1)
    turn = (boat.yaw - boat_yaw) * 180.0 / Math::PI
    check("a boat turns at up to 200 degrees/s, and the view turns with it",
          turn > 19.5 && turn < 20.001 && (@player.yaw - yaw - (boat.yaw - boat_yaw)).abs < 0.0001)
    # Facing the bank on +x, the player gets out onto it.
    @player.yaw = Math::PI / 2.0
    leave_boat
    check("Shift lets the player out of the boat onto land", !riding? && @player.y == y + 2.0)
    # In survival 5 hits of a hand break a boat into its item; in creative
    # one hit breaks it and drops nothing.
    @items.clear
    @player.melee_attack.restart
    @player.melee_attack.advance(10.0)
    4.times do
      hit_boat(0)
      @player.melee_attack.restart
      @player.melee_attack.advance(10.0)
    end
    held = @boats.size == 1
    hit_boat(0)
    dropped = @boats.empty? && @items.size == 1 && @items[0].block == Block::OAK_BOAT
    @survival = false
    @boats << Boat.new(Block::BIRCH_BOAT, x + 0.5, y + 1.5, z - 20.5, 0.0)
    hit_boat(0)
    check("a boat breaks after 5 hits in survival and drops itself, and after one in creative",
          held && dropped && @boats.empty? && @items.size == 1)
    @inv.clear
    @inv.add(Block::OAK_BOAT)
    @inv.add(Block::OAK_BOAT)
    check("each boat takes a slot of its own", @inv.count(0) == 1 && @inv.count(1) == 1 && @inv.room_for(Block::OAK_BOAT) == INV - 2)
    @inv.clear
    @items.clear
    @survival = survival
    (x - 2..x + 3).each do |cx|
      (z - 41..z + 1).each do |cz|
        @world.set(cx, y, cz, Block::AIR)
        @world.set(cx, y + 1, cz, Block::AIR)
      end
    end
  end

  def test_sounds
    check("every sound file loads", Sfx.load_files == Sfx::FILES.size && Gfx.au_seconds(Sfx::RAIN) > 5.0)
    # The lid of a chest hits at once, not after a creak.
    check("the closing sound of a chest hits within 0.1 s", Gfx.au_peak_seconds(Sfx::CHEST_CLOSE) < 0.1)
    check("blocks sound like their material",
          MATERIAL_STEP[material(Block::GRASS)] == Sfx::STEP_GRASS && MATERIAL_STEP[material(Block::STONE)] == Sfx::STEP_HARD &&
          MATERIAL_STEP[material(Block::OAK_PLANKS)] == Sfx::STEP_WOOD && MATERIAL_STEP[material(Block::SAND)] == Sfx::STEP_SAND &&
          MATERIAL_BREAK[material(Block::GLASS)] == Sfx::BREAK_GLASS && MATERIAL_DIG[material(Block::OAK_LEAVES)] == Sfx::DIG_LEAVES &&
          MATERIAL_DIG[material(Block::ROSE)] == Sfx::DIG_LEAVES && material(Block::TORCH) == M_WOOD &&
          MATERIAL_STEP[material(Block::WOOL)] == Sfx::CLOTH && MATERIAL_STEP[material(Block::SNOW)] == Sfx::SNOW)
    test_block_sounds
    test_furnace_crackle
    test_lava_swim
    test_eat_slowdown
    test_jump
    test_swim_speed
    test_cave_sound
    test_music
  end

  # Every track opens. test/music_test.rb checks how Music picks the tracks.
  def test_music
    opened = 0
    Music::FILES.size.times { |id| opened += 1 if Music.start(id) }
    Gfx.au_music_stop
    check("every music track opens", opened == Music::FILES.size && !Gfx.au_music_playing)
  end

  # A jump lifts the feet 1.2522 blocks, and sprint-jumps move faster than
  # a sprint, at 7.127 m/s on average.
  def test_jump
    keep_pose
    x = @player.x.floor
    z = @player.z.floor
    y = WY - 4
    (0..40).each { |d| set_block(x, y, z - d, Block::STONE) }
    @player.flying = false
    @player.yaw = 0.0
    @player.move_to(x + 0.5, y + 1.0, z + 0.5)
    top = 0.0
    50.times do
      @player.controls.hold(0.0, 0.0, jump: true, sneak: false, sprint: false)
      @player.update(@world, 0.02)
      top = @player.y if @player.y > top
    end
    height = top - (y + 1.0)
    @player.z = z + 0.5
    @player.controls.hold(1.0, 0.0, jump: false, sneak: false, sprint: true)
    25.times { @player.update(@world, 0.02) }
    z0 = @player.z
    @player.controls.hold(1.0, 0.0, jump: true, sneak: false, sprint: true)
    150.times { @player.update(@world, 0.02) }
    speed = (z0 - @player.z) / 3.0
    (0..40).each { |d| set_block(x, y, z - d, Block::AIR) }
    restore_pose
    check("a jump lifts the feet 1.25 blocks, and sprint-jumps move at 7.1 m/s",
          (height - 1.2522).abs < 0.01 && (speed - 7.127).abs < 0.15)
  end

  # The player swims at 2.2 m/s at the surface, 1.97 m/s under water, and
  # 3.918 m/s in a sprint. In lava the player swims at 0.4 times the speed
  # in water, and a sprint does not make it faster. A held jump does not
  # make the player faster in water or in lava.
  def test_swim_speed
    keep_pose
    x = @player.x.floor
    z = @player.z.floor
    y = WY - 4
    (0..20).each do |d|
      set_block(x, y, z - d, Block::STONE)
      set_block(x, y + 1, z - d, Block::WATER)
    end
    @player.flying = false
    @player.yaw = 0.0
    speeds = [[false, false, false, false], [true, false, false, false], [false, true, false, false], [true, false, true, false],
              [false, false, false, true], [false, false, true, true]].map do |sprint, under, lava, jump|
      (0..20).each do |d|
        set_block(x, y + 1, z - d, lava ? Block::LAVA : Block::WATER)
        set_block(x, y + 2, z - d, under ? Block::WATER : Block::AIR)
      end
      @player.move_to(x + 0.5, y + 1.0, z + 0.5)
      # Spinel cannot type the Booleans of the table, and an untyped key
      # would make the controls untyped in the game too.
      @player.controls.hold(1.0, 0.0, jump: jump == true, sneak: false, sprint: sprint == true)
      25.times { @player.update(@world, 0.02) }
      z0 = @player.z
      100.times { @player.update(@world, 0.02) }
      (z0 - @player.z) / 2.0
    end
    (0..20).each do |d|
      set_block(x, y, z - d, Block::AIR)
      set_block(x, y + 1, z - d, Block::AIR)
      set_block(x, y + 2, z - d, Block::AIR)
    end
    @fluids.clear
    restore_pose
    check("the player swims at 2.2 m/s, 1.97 m/s under water, and 3.918 m/s in a sprint",
          (speeds[0] - 2.2).abs < 0.05 && (speeds[1] - 3.918).abs < 0.05 && (speeds[2] - 1.97).abs < 0.05)
    check("the player swims in lava at 0.88 m/s, also in a sprint", (speeds[3] - 0.88).abs < 0.03)
    check("a held jump does not make a swim faster", (speeds[4] - 2.2).abs < 0.05 && (speeds[5] - 0.88).abs < 0.03)
  end

  # A player who eats or draws the bow walks at sneaking speed.
  def test_eat_slowdown
    keep_pose
    x = @player.x.floor
    z = @player.z.floor
    y = WY - 4
    (0..30).each { |d| set_block(x, y, z - d, Block::STONE) }
    @player.flying = false
    @player.yaw = 0.0
    speeds = [false, true].map do |slowed|
      @player.move_to(x + 0.5, y + 1.0, z + 0.5)
      @player.slowed = slowed
      @player.controls.hold(1.0, 0.0, jump: false, sneak: false, sprint: true)
      40.times { @player.update(@world, 0.02) }
      @player.speed
    end
    (0..30).each { |d| set_block(x, y, z - d, Block::AIR) }
    @player.slowed = false
    restore_pose
    @draw_time = 0.5
    bow = using_item?
    @draw_time = -1.0
    check("a player who eats or draws the bow walks at sneaking speed, not a sprint",
          speeds[0] > 5.0 && speeds[1] < 1.5 && bow && !using_item?)
  end

  # The player swims in lava as in water, but only water counts for the
  # splash and the swim sound.
  def test_lava_swim
    keep_pose
    x = @player.x.floor
    z = @player.z.floor
    y = WY - 4
    # A pool of one cell in a box of stone, so the liquid does not flow.
    fill_box(x - 1, y - 1, z - 1, x + 1, y, z + 1, Block::STONE)
    @player.flying = false
    # In creative, lava does not hurt, so the hurt sound does not hide the
    # splash.
    survival = @survival
    @survival = false
    set_block(x, y, z, Block::LAVA)
    lava = splashes_into?(x, y, z)
    set_block(x, y, z, Block::WATER)
    water = splashes_into?(x, y, z)
    @survival = survival
    fill_box(x - 1, y - 1, z - 1, x + 1, y, z + 1, Block::AIR)
    restore_pose
    check("the player splashes into water, but not into lava", !lava && water)
  end

  # Drops the player into the pool at x, y, z for one frame, and returns
  # true when the player hears a splash.
  def splashes_into?(x, y, z)
    @player.move_to(x + 0.5, y.to_f, z + 0.5)
    @was_swimming = false
    @sfx.clear
    update_game(1.0 / 60.0)
    @sfx.ids.include?(Sfx::SPLASH)
  end

  # Lava under air, flowing water and a lit furnace make sounds, but
  # covered lava and still water do not.
  def test_block_sounds
    x = @player.x.floor
    z = @player.z.floor
    y = WY - 4
    set_block(x, y, z, Block::LAVA)
    open_lava = block_sound(x, y, z)
    set_block(x, y + 1, z, Block::STONE)
    covered_lava = block_sound(x, y, z)
    set_block(x, y, z, Block::FLOW)
    flowing = block_sound(x, y, z)
    set_block(x, y, z, Block::WATER)
    still = block_sound(x, y, z)
    set_block(x, y, z, Block.furnace_id(0, true))
    furnace = block_sound(x, y, z)
    set_block(x, y, z, Block::AIR)
    set_block(x, y + 1, z, Block::AIR)
    check("lava, flowing water and a lit furnace make sounds",
          AMBIENT[open_lava] == Sfx::LAVA && covered_lava < 0 && AMBIENT[flowing] == Sfx::FLOWING &&
          still < 0 && AMBIENT[furnace] == Sfx::CRACKLE)
  end

  # A lit furnace next to the player crackles about once in 3 seconds, as
  # in Minecraft, not once in 25 seconds. The check counts the crackles in
  # 2 minutes, with no wait for the end of the clip.
  def test_furnace_crackle
    x = @spawn_x.floor + 30
    z = @spawn_z.floor + 80
    y = @world.height_at(x, z) + 6
    set_block(x + 1, y, z, Block.furnace_id(0, true))
    player = [@player.x, @player.y, @player.z]
    @player.move_to(x + 0.5, y.to_f, z + 0.5)
    crackles = 0
    7200.times do
      @ambient_wait[2] = 0.0
      update_block_sounds(1.0 / 60.0)
      crackles += 1 if @ambient_wait[2] > 0.0
    end
    @ambient_wait[2] = 0.0
    set_block(x + 1, y, z, Block::AIR)
    @player.move_to(player[0], player[1], player[2])
    check("a lit furnace next to the player crackles every few seconds", crackles > 15)
  end

  # In a dark pocket deep in the rock, the fear grows and a cave sound
  # plays when it is full.
  def test_cave_sound
    cx = @spawn_x.floor - 6
    cz = @spawn_z.floor - 6
    (cx - 1..cx + 1).each do |x|
      (cz - 1..cz + 1).each do |z|
        (4..8).each { |y| @world.set(x, y, z, Block::STONE) }
      end
    end
    @world.set(cx, 5, cz, Block::AIR)
    @world.set(cx, 6, cz, Block::AIR)
    keep_pose
    @player.x = cx + 0.5
    @player.y = 5.0
    @player.z = cz + 0.5
    @cave_fear = 0.0
    @cave_timer = 0.0
    @sfx.clear
    update_cave_sound(0.0)
    grew = @cave_fear == 3.0
    quiet = @sfx.ids.none? { |id| id >= Sfx::CAVE && id < Sfx::CAVE + Sfx::CAVES }
    @cave_fear = 299.0
    @cave_timer = 0.0
    @sfx.clear
    update_cave_sound(0.0)
    cave = @sfx.ids.size == 1 && @sfx.ids[0] >= Sfx::CAVE && @sfx.ids[0] < Sfx::CAVE + Sfx::CAVES
    check("the dark builds fear, and full fear plays a cave sound", grew && quiet && cave && @cave_fear == 0.0)
    restore_pose
  end

  # A left click with nothing in reach swings the held sword, and the next
  # hit has a low charge.
  def test_swing_at_air
    survival = @survival
    shown = @screen
    @survival = true
    show_screen(Screen::PLAYING)
    @inv.set(0, Block::WOOD_SWORD, Block.uses(Block::WOOD_SWORD))
    @slot = 0
    update_hand(0.0)
    @held_item.ease(1.0, 0.0, 0.0)
    @player.pitch = 1.5
    @target_block.trace(@world, @player)
    @target_mob = -1
    @target_boat = -1
    @swing = 0.0
    @player.melee_attack.restart
    @player.melee_attack.advance(1.0)
    rest = hand_corner
    left_button(1.0 / 60.0, true, true)
    # Halfway through the swing, as Game#update counts it down.
    @swing -= SWING / 2.0
    moved = (hand_corner - rest).abs > 0.05
    check("a click at the air swings the held sword and starts the cooldown again", !@target_block.hit? && moved && @player.melee_attack.charge(current_block.to_i) < 0.2)
    @swing = 0.0
    @dyn.clear
    @inv.clear
    @screen = shown
    @player.pitch = 0.0
    @survival = survival
  end

  # The bow in the hand shows the arrow and a pulled string while the
  # player draws it.
  def test_bow_draw_image
    hand = @held_item.block
    draw = @draw_time
    shown = @screen
    show_screen(Screen::PLAYING)
    @held_item.change(Block::BOW)
    layers = [-1.0, 0.0, 0.7, 0.95].map do |time|
      @draw_time = time
      hand_corner
      @dyn.v[5].to_i
    end
    check("the held bow shows a pulled string and an arrow as the draw grows",
          layers[0] == Tex::BOW && layers[1] == Tex::BOW_PULLING && layers[2] == Tex::BOW_PULLING + 1 && layers[3] == Tex::BOW_PULLING + 2)
    @dyn.clear
    @screen = shown
    @draw_time = draw
    @held_item.change(hand)
  end

  # The sum of the coordinates of the first vertex of the held model.
  def hand_corner
    @dyn.clear
    draw_hand(@player.x, @player.eye_y, @player.z)
    @dyn.v[0] + @dyn.v[1] + @dyn.v[2]
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
    # The generator can leave sand over a cave. It stays until a block
    # next to it changes, as in Minecraft.
    @world.set(x, ground + 6, z, Block::SAND)
    set_block(x, ground + 2, z, Block::STONE)
    stayed = @world.get(x, ground + 6, z) == Block::SAND && @falling.empty?
    set_block(x + 1, ground + 6, z, Block::STONE)
    fell = @world.get(x, ground + 6, z) == Block::AIR && @falling.size == 1
    fall_for(2.0)
    landed = @world.get(x, ground + 3, z) == Block::SAND
    check("sand over a cave falls when a block next to it changes, and not before", stayed && fell && landed)
    set_block(x + 1, ground + 6, z, Block::AIR)
    set_block(x, ground + 3, z, Block::AIR)
    set_block(x, ground + 2, z, Block::AIR)
    # Gravel falls through lava and takes its place at the bottom.
    set_block(x, ground + 1, z, Block::LAVA)
    set_block(x, ground + 2, z, Block::LAVA)
    set_block(x, ground + 6, z, Block::GRAVEL)
    fall_for(2.0)
    filled = @world.get(x, ground + 1, z) == Block::GRAVEL && Block.lava?(@world.get(x, ground + 2, z)) && @falling.empty?
    check("gravel falls through lava and takes its place at the bottom", filled)
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
    wall_torch = Block.facing_id(Block::TORCH, 1)
    set_block(x, ground + 1, z, wall_torch)
    check("wall torch is listed", torches.size == lights + 3)
    set_block(x, ground, z, Block::AIR)
    check("breaking the block under a wall torch keeps it", @world.get(x, ground + 1, z) == wall_torch)
    set_block(x, ground, z, Block::DIRT)
    set_block(x + 1, ground + 1, z, Block::AIR)
    check("breaking the block that holds a wall torch removes it", torches.size == lights && @world.get(x, ground + 1, z) == Block::AIR)
    @items.clear
    # A torch sealed in a stone box lights nothing outside the box.
    fill_box(x - 1, ground + 1, z - 1, x + 1, ground + 3, z + 1, Block::STONE)
    set_block(x, ground + 2, z, Block::TORCH)
    mesher = Mesher.new(@world)
    mesher.build(x / CHUNK, z / CHUNK)
    inside = mesher.torch_light(x, ground + 2, z)
    outside = mesher.torch_light(x + 2, ground + 2, z)
    check("walls stop torch light", inside == Mesher::TORCH_LIGHT && outside == 0)
    set_block(x + 1, ground + 2, z, Block::AIR)
    mesher.build(x / CHUNK, z / CHUNK)
    check("an opening lets torch light out", mesher.torch_light(x + 2, ground + 2, z) == 12)
    fill_box(x - 1, ground + 1, z - 1, x + 1, ground + 3, z + 1, Block::AIR)
    set_block(x, ground + 1, z, Block::TORCH)
    @chunk_meshes.flush
    puts "torch edit remesh: #{@chunk_meshes.mesh_ms.round(2)} ms"
    set_block(x, ground + 1, z, Block::AIR)
    @chunk_meshes.flush
    # A torch in the middle of a chunk lights the next chunk too, so
    # that chunk must remesh when the torch goes.
    tx = (x & ~15) + 8
    th = @world.height_at(tx, z)
    # The column can be water, and a torch needs ground.
    set_block(tx, th - 1, z, Block::DIRT)
    set_block(tx, th, z, Block::TORCH)
    @chunk_meshes.flush_all
    set_block(tx, th, z, Block::AIR)
    check("breaking a torch remeshes the chunks that it lit", @chunk_meshes.queued?((tx >> 4) + 1, z >> 4))
    @chunk_meshes.flush_all
  end

  # Each block that stands on a block or hangs on its side drops its item
  # when that block goes.
  def test_held_blocks_drop(x, z, ground)
    lost = []
    Block::COUNT.times do |block|
      next unless Block.plant?(block) && !Block.wall_torch?(block)

      @items.clear
      set_block(x, ground, z, Block::DIRT)
      set_block(x, ground + 1, z, block)
      set_block(x, ground, z, Block::AIR)
      dropped = Block::DROPS[block] == Block::AIR || ground_count(Block::DROPS[block]) == 1
      lost << Block::NAMES[block] unless @world.get(x, ground + 1, z) == Block::AIR && dropped
    end
    set_block(x, ground, z, Block::DIRT)
    [Block::TORCH, Block::LADDER].each do |base|
      4.times do |d|
        hung = Block.facing_id(base, d)
        @items.clear
        set_block(x - Block::DIR_DX[d], ground + 1, z - Block::DIR_DZ[d], Block::STONE)
        set_block(x, ground + 1, z, hung)
        set_block(x - Block::DIR_DX[d], ground + 1, z - Block::DIR_DZ[d], Block::AIR)
        lost << "#{Block::NAMES[hung]} #{d}" unless @world.get(x, ground + 1, z) == Block::AIR && ground_count(Block::DROPS[hung]) == 1
      end
    end
    @items.clear
    puts "lost: #{lost.join(", ")}" unless lost.empty?
    check("each plant, torch and ladder drops its item when the block that holds it goes", lost.empty?)
    set_block(x, ground + 1, z, Block::STONE)
    set_block(x, ground + 2, z, Block::SAND)
    set_block(x, ground + 3, z, Block::TORCH)
    set_block(x - 1, ground + 2, z, Block.facing_id(Block::TORCH, 1))
    set_block(x, ground + 1, z, Block::AIR)
    fall_for(2.0)
    check("sand that falls drops the torches that it held",
          @world.get(x, ground + 3, z) == Block::AIR && @world.get(x - 1, ground + 2, z) == Block::AIR && ground_count(Block::TORCH) == 2)
    fill_box(x - 1, ground + 1, z, x + 1, ground + 4, z, Block::AIR)
    set_block(x - 1, ground + 1, z, Block::OAK_SAPLING)
    set_block(x, ground + 1, z, Block::TORCH)
    set_block(x + 1, ground + 1, z, Block::TALL_GRASS)
    @items.clear
    (x - 1..x + 1).each { |sx| set_block(sx, ground + 4, z, Block::SAND) }
    fall_for(2.0)
    check("sand breaks into an item on a torch or a sapling, and takes the place of tall grass",
          @world.get(x - 1, ground + 1, z) == Block::OAK_SAPLING && @world.get(x, ground + 1, z) == Block::TORCH &&
          @world.get(x + 1, ground + 1, z) == Block::SAND && ground_count(Block::SAND) == 2)
    fill_box(x - 1, ground + 1, z, x + 1, ground + 4, z, Block::AIR)
    @items.clear
    fill_box(x - 1, ground, z, x + 1, ground, z, Block::DIRT)
    set_block(x - 1, ground + 1, z, Block::OAK_SAPLING)
    set_block(x, ground + 1, z, Block::TORCH)
    set_block(x + 1, ground + 1, z, Block::ROSE)
    (x - 1..x + 1).each { |sx| set_block(sx, ground + 2, z, Block::SAND) }
    rested = (x - 1..x + 1).all? { |sx| @world.get(sx, ground + 2, z) == Block::SAND } && @falling.empty?
    check("sand on a torch, a sapling or a flower stays", rested)
    # The sand goes first, so that it does not fall.
    fill_box(x - 1, ground + 2, z, x + 1, ground + 2, z, Block::AIR)
    fill_box(x - 1, ground + 1, z, x + 1, ground + 1, z, Block::AIR)
    @items.clear
  end

  # Survival basics: crafting, stacks, health, placing, mining, and food.
  def test_survival(x, z, ground)
    @survival = true
    @inv.clear
    3.times { @inv.add(Block::OAK_LOG) }
    @slot = 0
    craft_recipe(recipe_for(Block::OAK_PLANKS))
    check("craft log into planks", @inv.block(0) == Block::OAK_LOG && @inv.count(0) == 2 && @inv.block(1) == Block::OAK_PLANKS && @inv.count(1) == 4)
    70.times { @inv.add(Block::DIRT) }
    check("stacks split at 64", @inv.count(2) == 64 && @inv.block(3) == Block::DIRT && @inv.count(3) == 6)
    @player.vitals.health = Vitals::MAX_HEALTH
    hurt(5, Sfx::HURT)
    check("hurt lowers health", @player.vitals.health == 15.0 && !@player.vitals.dead?)
    kept = @inv.copy
    @items.clear
    toggle_inventory
    hurt(30, Sfx::HURT)
    check("death at zero health, and it closes the inventory", @player.vitals.health == 0.0 && @player.vitals.dead? && !current_screen.inventory?)
    check("death drops the inventory on the ground", @inv.room_for(Block::DIRT) == INV * Slots::STACK && ground_count(Block::DIRT) == 70 && ground_count(Block::OAK_PLANKS) == 4)
    @items.clear
    @inv = kept
    respawn
    check("respawn restores health", @player.vitals.health == Vitals::MAX_HEALTH && !@player.vitals.dead?)
    kept = @inv.copy
    @inv.clear
    open_chat("")
    hurt(30, Sfx::HURT)
    Gfx.in_test_frame
    Gfx.in_test_key(Key::R, 1)
    handle_input(0.05)
    Gfx.in_test_key(Key::R, 0)
    Gfx.in_test_frame
    check("a death while the player types opens the death screen, and R respawns", !@player.vitals.dead? && current_screen.playing?)
    Gfx.in_capture(0)
    @items.clear
    @inv = kept
    respawn
    @player.x = x + 0.5
    @player.y = ground + 1.0
    @player.z = z + 0.5
    @player.pitch = -1.55
    @target_block.trace(@world, @player)
    check("raycast hits the ground", @target_block.hit? && @target_block.y == ground)
    @slot = 1
    before = @inv.count(1)
    @player.y = ground + 3.0
    @target_block.trace(@world, @player)
    place
    check("survival place uses one item", @inv.count(1) == before - 1 && @world.get(x, ground + 1, z) == Block::OAK_PLANKS)
    set_block(x, ground + 1, z, Block::TALL_GRASS)
    @target_block.trace(@world, @player)
    place
    check("a block placed on tall grass takes its cell", @world.get(x, ground + 1, z) == Block::OAK_PLANKS && @world.get(x, ground + 2, z) == Block::AIR)
    set_block(x, ground + 1, z, Block::LAVA)
    @target_block.trace(@world, @player)
    place
    check("a block placed in lava takes its cell", @world.get(x, ground + 1, z) == Block::OAK_PLANKS)
    set_block(x, ground + 1, z, Block::AIR)
    @target_block.trace(@world, @player)
    @mobs << Animal.new(Mob::PIG, x + 0.5, ground + 1.0, z + 0.5, 4)
    place
    blocked = @world.get(x, ground + 1, z) == Block::AIR
    @mobs.pop
    place
    check("a block does not go into the cell of a mob", blocked && @world.get(x, ground + 1, z) == Block::OAK_PLANKS)
    # Stone drops cobblestone only to a pickaxe. Off the ground, mining is
    # slow, so the player stands while it mines.
    @inv.clear
    @slot = 0
    set_block(x, ground + 1, z, Block::STONE)
    @player.y = ground + 3.0
    @player.on_ground = true
    n = 0
    while n < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @target_block.trace(@world, @player)
      mine(0.05)
      n += 1
    end
    check("stone without a pickaxe drops nothing", @world.get(x, ground + 1, z) == Block::AIR && @items.empty?)
    7.times { @inv.add(Block::OAK_PLANKS) }
    craft_recipe(recipe_for(Block::WOOD_PICK))
    by_hand = @inv.total(Block::WOOD_PICK)
    craft_recipe(recipe_for(Block::CRAFTING_TABLE))
    table = @inv.total(Block::CRAFTING_TABLE) == 1
    craft_at_table(recipe_for(Block::WOOD_PICK))
    check("a crafting table comes from 4 planks, and a pickaxe needs one", by_hand == 0 && table && @inv.total(Block::WOOD_PICK) > 0)
    @inv.clear
    @inv.add(Block::WOOD_PICK)
    set_block(x, ground + 1, z, Block::STONE)
    mining_frames = 0
    while mining_frames < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @target_block.trace(@world, @player)
      mine(0.05)
      mining_frames += 1
    end
    dropped = ground_count(Block::COBBLE) == 1 && @inv.count(1) == 0
    collect_items
    check("a pickaxe mines stone faster, and the cobblestone drops to the ground", mining_frames < n && dropped && @inv.block(1) == Block::COBBLE)
    by_hand = frames_to_mine(x, ground + 1, z, Block::OAK_LOG, Block::AIR)
    by_axe = frames_to_mine(x, ground + 1, z, Block::OAK_LOG, Block::STONE_AXE)
    by_pick = frames_to_mine(x, ground + 1, z, Block::OAK_LOG, Block::STONE_PICK)
    check("an axe chops a log faster than a hand or a pickaxe", by_axe < by_hand && by_pick == by_hand)
    @items.clear
    wool_hand = frames_to_mine(x, ground + 1, z, Block::WOOL, Block::AIR)
    wool_shears = frames_to_mine(x, ground + 1, z, Block::WOOL, Block::SHEARS)
    leaves_hand = frames_to_mine(x, ground + 1, z, Block::OAK_LEAVES, Block::AIR)
    dirt_hand = frames_to_mine(x, ground + 1, z, Block::DIRT, Block::AIR)
    dirt_shears = frames_to_mine(x, ground + 1, z, Block::DIRT, Block::SHEARS)
    @items.clear
    # Each leaf block takes 1 use of the shears and drops itself, never a
    # sapling or an apple.
    uses = Block.uses(Block::SHEARS)
    @inv.set(8, Block::SHEARS, uses)
    @slot = 8
    leaves_shears = 0
    20.times do
      set_block(x, ground + 1, z, Block::OAK_LEAVES)
      @mining = false
      @mine_delay = 0.0
      n = 0
      while n < 20 && @world.get(x, ground + 1, z) == Block::OAK_LEAVES
        @target_block.trace(@world, @player)
        mine(0.05)
        n += 1
      end
      leaves_shears = n
    end
    worn = @inv.count(8) == uses - 20
    @particles.update(@world, 60.0)
    @inv.set(8, Block::AIR, 0)
    leaves = ground_count(Block::OAK_LEAVES) == 20 && @items.all? { |item| item.block == Block::OAK_LEAVES }
    @items.clear
    # Shears cut leaves that the player placed, tall grass and dry grass,
    # and dig dirt as a hand does. Dry grass by hand drops nothing.
    frames_to_mine(x, ground + 1, z, Block::PLACED_BIRCH_LEAVES, Block::SHEARS)
    frames_to_mine(x, ground + 1, z, Block::TALL_GRASS, Block::SHEARS)
    frames_to_mine(x, ground + 1, z, Block::DRY_GRASS, Block::SHEARS)
    frames_to_mine(x, ground + 1, z, Block::DRY_GRASS, Block::AIR)
    frames_to_mine(x, ground + 1, z, Block::DIRT, Block::SHEARS)
    drops = leaves && ground_count(Block::BIRCH_LEAVES) == 1 && ground_count(Block::TALL_GRASS) == 1 &&
            ground_count(Block::DRY_GRASS) == 1 && ground_count(Block::DIRT) == 1 && @items.size == 4
    @items.clear
    check("shears cut wool 5 times and leaves 15 times as fast, and other blocks as fast as a hand",
          wool_shears < wool_hand / 4 && leaves_shears == 1 && leaves_hand > 4 && dirt_shears == dirt_hand)
    check("leaves, tall grass and dry grass that shears cut drop themselves and nothing else, and each cut takes 1 use", drops && worn)
    # 1.5 hardness * 1.5 seconds / speed 4 = 0.5625 seconds, as in Minecraft.
    check("a stone pickaxe breaks stone in 12 frames", frames_to_mine(x, ground + 1, z, Block::STONE, Block::STONE_PICK) == 12)
    @items.clear
    frames_to_mine(x, ground + 1, z, Block::SPINEL_ORE, Block::STONE_PICK)
    by_stone = @items.size
    frames_to_mine(x, ground + 1, z, Block::SPINEL_ORE, Block::IRON_PICK)
    check("spinel ore drops a spinel gem, and only to an iron pickaxe or better", by_stone == 0 && @items.size == 1 && ground_count(Block::SPINEL) == 1)
    @items.clear
    fast = frames_to_mine(x, ground + 1, z, Block::STONE, Block::SPINEL_MATTOCK) < frames_to_mine(x, ground + 1, z, Block::STONE, Block::DIAMOND_PICK) &&
           frames_to_mine(x, ground + 1, z, Block::OAK_LOG, Block::SPINEL_MATTOCK) < frames_to_mine(x, ground + 1, z, Block::OAK_LOG, Block::DIAMOND_AXE) &&
           frames_to_mine(x, ground + 1, z, Block::DIRT, Block::SPINEL_MATTOCK) < frames_to_mine(x, ground + 1, z, Block::DIRT, Block::IRON_SHOVEL)
    @items.clear
    frames_to_mine(x, ground + 1, z, Block::DIAMOND, Block::SPINEL_MATTOCK)
    check("a spinel mattock digs stone, logs and dirt fast, and it mines diamond ore", fast && ground_count(Block::DIAMOND) == 1)
    @items.clear
    @inv.set(5, Block::COOKED_PORKCHOP, 2)
    @slot = 5
    @player.vitals.hunger = 5
    # Eating takes 1.6 seconds of holding the button, and a release starts
    # it over.
    20.times { right_button(0.05, true) }
    right_button(0.05, false)
    31.times { right_button(0.05, true) }
    early = @player.vitals.hunger == 5 && @inv.count(5) == 2
    2.times { right_button(0.05, true) }
    check("holding the button for 1.6 seconds eats the food", early && @player.vitals.hunger == 13 && @inv.count(5) == 1)
    # Rotten flesh gives 4 hunger and 0.8 saturation. The Hunger effect
    # adds 3 exhaustion in its 30 seconds, and then no more.
    @player.revive
    @player.vitals.hunger = 10
    @player.vitals.saturation = 0.0
    @inv.set(5, Block::ROTTEN_FLESH, 1)
    @slot = 5
    eat
    fed = @player.vitals.hunger == 14 && @player.vitals.saturation == 0.8
    @player.vitals.give_hunger_effect
    601.times { @player.vitals.update_vitals(0.05, false, false, false) }
    drained = !@player.vitals.hunger_effect? && (@player.vitals.exhaustion - 3.0).abs < 0.01
    20.times { @player.vitals.update_vitals(0.05, false, false, false) }
    check("rotten flesh feeds, and its Hunger effect adds exhaustion for 30 seconds", fed && drained && (@player.vitals.exhaustion - 3.0).abs < 0.01)
    before = @particles.count(Particle::EFFECT)
    @player.vitals.give_hunger_effect
    update_survival(0.5)
    check("the Hunger effect makes green specks around the player", @particles.count(Particle::EFFECT) > before)
    @player.revive
  end

  # Frames of 0.05 seconds that it takes to break block at x, y, z (which
  # the player looks at) with tool in hotbar slot 8.
  def frames_to_mine(x, y, z, block, tool)
    @inv.set(8, tool, tool == Block::AIR ? 0 : Block.uses(tool))
    @slot = 8
    set_block(x, y, z, block)
    @mining = false
    @mine_delay = 0.0
    n = 0
    while n < 400 && @world.get(x, y, z) == block
      @target_block.trace(@world, @player)
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
    (-2..16).each { |i| set_block(px + i, SKY_Y - 2, pz, Block::STONE) }
    @chunk_meshes.flush
    @mobs.clear
    @clock.time_of_day = 0.75
    @player.vitals.health = Vitals::MAX_HEALTH
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    @mobs << Monster.new(Mob::SKELETON, px + 12.5, SKY_Y - 1.0, pz + 0.5, 7)
    frames = 0
    while frames < 400 && @player.vitals.health == Vitals::MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("skeleton arrow hurts the player", @player.vitals.health < Vitals::MAX_HEALTH)
    @mobs.clear
    @mobs << Monster.new(Mob::ZOMBIE, px + 1.5, SKY_Y - 1.0, pz + 0.5, 9)
    @player.vitals.health = Vitals::MAX_HEALTH
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    frames = 0
    while frames < 400 && @player.vitals.health == Vitals::MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("zombie hit hurts the player", @player.vitals.health < Vitals::MAX_HEALTH)
    check("a zombie hit throws the player away from the zombie and up", @player.vx < 0.0 && @player.vy > 0.0)
    @mobs.clear
    # Each block that the blast breaks drops by chance, so the blast gets
    # two more rows of stone to break, and the random numbers start from a
    # known seed.
    @rng = Rng.new(5)
    (0..5).each do |dx|
      set_block(px + dx, SKY_Y - 2, pz - 1, Block::STONE)
      set_block(px + dx, SKY_Y - 2, pz + 1, Block::STONE)
    end
    @mobs << Monster.new(Mob::CREEPER, px + 2.5, SKY_Y - 1.0, pz + 0.5, 11)
    # A blast this near kills a player with full health, so the player
    # gets more health for the test.
    @player.vitals.health = 100.0
    @items.clear
    frames = 0
    while frames < 300 && @world.get(px + 2, SKY_Y - 2, pz) == Block::STONE
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("a creeper explodes, breaks blocks and hurts", @world.get(px + 2, SKY_Y - 2, pz) == Block::AIR && @player.vitals.health < 100.0 && frames > 60)
    check("a creeper explosion makes a cloud", @particles.count(Particle::BLAST) > 0)
    check("some blocks that a blast breaks drop", ground_count(Block::COBBLE) > 0)
    # A block that a blast breaks drops its extras too, so ripe wheat drops
    # seeds. Each of the 20 blasts drops with chance BLAST_DROP.
    @rng = Rng.new(5)
    @items.clear
    20.times do
      @world.set(px + 20, SKY_Y + 2, pz + 20, Block::WHEAT_RIPE)
      explode(px + 20.5, SKY_Y + 2.5, pz + 20.5)
    end
    check("ripe wheat that a blast breaks drops wheat and seeds", ground_count(Block::WHEAT) > 0 && ground_count(Block::SEEDS) > 0)
    # Nothing updated the particles of the 20 blasts. Without this step
    # they fill Particles::MAX, and the next checks cannot add theirs.
    @particles.update(@world, 5.0)
    @items.clear
    @mobs.clear
    @clock.time_of_day = 0.3
    @player.vitals.health = Vitals::MAX_HEALTH
  end

  # On the sky platform from test_monsters: a zombie in the sun burns with
  # flames, and the player burns on after lava until water puts the fire out.
  def test_fire
    px = @spawn_x.floor
    pz = @spawn_z.floor
    @mobs.clear
    @clock.time_of_day = 0.25
    zombie = Monster.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
    @mobs << zombie
    capped = Monster.new(Mob::ZOMBIE, px + 11.5, SKY_Y - 1.0, pz + 0.5, 10)
    capped.head = Block::CARVED_PUMPKIN
    @mobs << capped
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie in the sun burns and makes flames", zombie.fire > 0.0 && zombie.hp < Mob::HP[Mob::ZOMBIE] && @particles.count(Particle::FLAME) > 0)
    check("a zombie with a carved pumpkin on its head does not burn in the sun", capped.fire == 0.0 && capped.hp == Mob::HP[Mob::ZOMBIE])
    @mobs.clear
    @clock.set_ticks(23500)
    zombie = Monster.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
    @mobs << zombie
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie burns in the sun at dawn", zombie.fire > 0.0)
    @mobs.clear
    @survival = true
    @player.vitals.health = Vitals::MAX_HEALTH
    @world.set(px + 1, SKY_Y - 1, pz, Block::LAVA)
    @player.x = px + 1.5
    update_survival(0.1)
    @world.set(px + 1, SKY_Y - 1, pz, Block::AIR)
    @player.vitals.health = Vitals::MAX_HEALTH
    150.times { update_survival(1.0 / 60.0) }
    burned = @player.vitals.fire > 0.0 && @player.vitals.health < Vitals::MAX_HEALTH
    @world.set(px + 1, SKY_Y - 1, pz, Block::WATER)
    update_survival(1.0 / 60.0)
    @world.set(px + 1, SKY_Y - 1, pz, Block::AIR)
    check("the player burns on after lava, and water puts the fire out", burned && @player.vitals.fire == 0.0)
    @clock.time_of_day = 0.3
    @player.vitals.health = Vitals::MAX_HEALTH
  end

  # On the sky platform from test_monsters: rain stops the sun from burning a
  # zombie, and the rain in a column stops at the highest block.
  def test_rain
    px = @spawn_x.floor
    pz = @spawn_z.floor
    @mobs.clear
    @clock.time_of_day = 0.25
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    @weather.start_rain
    zombie = Monster.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
    @mobs << zombie
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie burns in the sun until the rain is strong enough to wet it", zombie.fire > 0.0)
    @mobs.clear
    @weather.start_rain
    @weather.settle
    zombie = Monster.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
    @mobs << zombie
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie does not burn in the rain", zombie.fire == 0.0 && zombie.hp == Mob::HP[Mob::ZOMBIE])
    @mobs.clear
    @weather.build_quads(@world, @player, 1.0)
    open = rain_bottom(px + 3, pz)
    @world.set(px + 3, SKY_Y + 5, pz, Block::STONE)
    @weather.build_quads(@world, @player, 1.0)
    roofed = rain_bottom(px + 3, pz)
    @world.set(px + 3, SKY_Y + 5, pz, Block::AIR)
    check("the rain in a column stops at the highest block", open < SKY_Y + 6.0 && roofed == SKY_Y + 6.0)
    @weather.stop_rain
    @weather.settle
    @clock.time_of_day = 0.3
  end

  # On the sky platform from test_monsters: the thunder flag keeps the times
  # of the wiki, a thunderstorm is rain while the flag is on, monsters spawn
  # in it by day, and a strike draws itself to a mob near it, hurts and
  # burns what it hits, and its thunder comes later.
  def test_thunder
    px = @spawn_x.floor
    pz = @spawn_z.floor
    survival = @survival
    @weather.stop_rain
    @weather.settle
    @weather.start_thunder
    on = @weather.thunder_timer
    @weather.stop_thunder
    off = @weather.thunder_timer
    check("the thunder flag stays on for 3 to 13 minutes, and off for 10 to 150 minutes",
          on >= 180.0 && on <= 780.0 && off >= 600.0 && off <= 9000.0)
    @weather.start_thunder
    @weather.settle
    dry = !@weather.storm? && @weather.thunder == 0.0
    @weather.start_rain
    600.times { @weather.update_weather(1.0 / 60.0) }
    check("a thunderstorm is rain while the thunder flag is on", dry && @weather.storm? && @weather.striking?)
    @clock.time_of_day = 0.25
    stormy = @sky.spawn_light
    @weather.stop_thunder
    @weather.settle
    check("monsters spawn by day in a thunderstorm", stormy == 5 && @sky.spawn_light > NaturalSpawner::SPAWN_LIGHT)
    @mobs.clear
    zombie = Monster.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
    @mobs << zombie
    @survival = true
    @player.vitals.health = Vitals::MAX_HEALTH
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    @storm.strike(px + 9, pz + 1, @player, @particles)
    lightning = @storm.lightning
    check("lightning strikes a mob near it, for 5 damage, and sets it on fire",
          lightning.x == px + 8 && lightning.z == pz && zombie.hp == Mob::HP[Mob::ZOMBIE] - Storm::STRIKE_DAMAGE &&
          zombie.fire == Storm::STRIKE_FIRE && @player.vitals.health == Vitals::MAX_HEALTH)
    dx = px + 8.5 - @player.x
    dy = SKY_Y - 1.0 - @player.eye_y
    delay = Math.sqrt(dx * dx + dy * dy) / Lightning::SOUND_SPEED
    early = lightning.thunder_arrived?(delay - 0.001)
    check("the thunder takes the distance over the speed of sound to arrive",
          !early && lightning.thunder_arrived?(0.002) && lightning.heard_x == px + 8.5)
    @mobs.clear
    lightning_hit_player if @storm.strike(px, pz, @player, @particles)
    check("lightning strikes the player for 5 damage and sets the player on fire",
          @player.vitals.health == Vitals::MAX_HEALTH - Storm::STRIKE_DAMAGE && @player.vitals.fire == Storm::STRIKE_FIRE)
    lightning.thunder_arrived?(1.0)
    @player.vitals.douse
    @player.vitals.health = Vitals::MAX_HEALTH
    @world.set(px, SKY_Y + 2, pz, Block::GLASS)
    lightning_hit_player if @storm.strike(px + 1, pz, @player, @particles)
    @world.set(px, SKY_Y + 2, pz, Block::AIR)
    check("lightning does not strike the player under a glass roof",
          @player.vitals.health == Vitals::MAX_HEALTH && !@player.vitals.burning?)
    @survival = survival
    @weather.stop_rain
    @weather.settle
    @clock.time_of_day = 0.3
  end

  # On the sky platform from test_monsters: a cactus hurts the player who
  # leans on it or stands on it, 1 each half second, and it hurts a mob.
  # It grows up to 3 blocks.
  def test_cactus
    px = @spawn_x.floor
    pz = @spawn_z.floor
    @mobs.clear
    @survival = true
    # With hunger under 18 and no saturation, the player does not heal.
    @player.revive
    @player.vitals.hunger = 17
    @player.vitals.saturation = 0.0
    set_block(px + 1, SKY_Y - 1, pz, Block::CACTUS)
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    update_survival(1.0 / 60.0)
    apart = @player.vitals.health == Vitals::MAX_HEALTH
    # The player stops 1/16 into the cell of the cactus.
    @player.x = px + 0.76
    update_survival(1.0 / 60.0)
    first = @player.vitals.health == Vitals::MAX_HEALTH - 1.0
    20.times { update_survival(1.0 / 60.0) }
    immune = @player.vitals.health == Vitals::MAX_HEALTH - 1.0
    15.times { update_survival(1.0 / 60.0) }
    second = @player.vitals.health == Vitals::MAX_HEALTH - 2.0
    check("a cactus hurts the player who leans on it, 1 each half second", apart && first && immune && second)
    @player.x = px + 1.5
    @player.y = SKY_Y.to_f
    40.times { update_survival(1.0 / 60.0) }
    check("a cactus hurts the player who stands on it", @player.vitals.health < Vitals::MAX_HEALTH - 2.0)
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    pig = Animal.new(Mob::PIG, px + 1.95 + Mob::HALF[Mob::PIG], SKY_Y - 1.0, pz + 0.5, 3)
    @mobs << pig
    update_mobs(1.0 / 60.0)
    check("a cactus hurts a mob", pig.hp == Mob::HP[Mob::PIG] - 1.0)
    @mobs.clear
    set_block(px + 1, SKY_Y - 1, pz, Block::AIR)
    # A cactus that grows stands on sand.
    set_block(px + 3, SKY_Y - 3, pz, Block::STONE)
    set_block(px + 3, SKY_Y - 2, pz, Block::SAND)
    set_block(px + 3, SKY_Y - 1, pz, Block::CACTUS)
    grow_plants(8000.0)
    grew = @world.get(px + 3, SKY_Y, pz) == Block::CACTUS
    4.times do
      @plants.grow_cactus(px + 3, @world.height_at(px + 3, pz) - 1, pz, @changes)
      apply_changes
    end
    three = @world.get(px + 3, SKY_Y + 1, pz) == Block::CACTUS && @world.get(px + 3, SKY_Y + 2, pz) == Block::AIR
    check("a cactus grows, up to 3 blocks", grew && three)
    set_block(px + 3, SKY_Y + 1, pz, Block::AIR)
    set_block(px + 3, SKY_Y, pz, Block::AIR)
    set_block(px + 3, SKY_Y - 1, pz, Block::AIR)
    set_block(px + 3, SKY_Y - 2, pz, Block::AIR)
    set_block(px + 3, SKY_Y - 3, pz, Block::AIR)
    @player.revive
    # The player places a cactus on sand and on a cactus, but not on stone.
    survival = @survival
    @survival = false
    held = @hotbar[0]
    @slot = 0
    @hotbar[0] = Block::CACTUS
    pitch = @player.pitch
    flying = @player.flying
    @player.pitch = -1.55
    @player.flying = true
    @player.x = px + 5.5
    @player.y = SKY_Y + 1.0
    @player.z = pz + 0.5
    set_block(px + 5, SKY_Y - 2, pz, Block::STONE)
    @target_block.trace(@world, @player)
    place
    stone = @world.get(px + 5, SKY_Y - 1, pz) == Block::AIR
    # Sand falls, so stone holds it up.
    set_block(px + 5, SKY_Y - 3, pz, Block::STONE)
    set_block(px + 5, SKY_Y - 2, pz, Block::SAND)
    @target_block.trace(@world, @player)
    place
    sand = @world.get(px + 5, SKY_Y - 1, pz) == Block::CACTUS
    @target_block.trace(@world, @player)
    place
    stacked = @world.get(px + 5, SKY_Y, pz) == Block::CACTUS
    check("a cactus stands only on sand or on a cactus", stone && sand && stacked)
    # Without the sand, both blocks of the cactus break and drop.
    @items.clear
    set_block(px + 5, SKY_Y - 2, pz, Block::AIR)
    removed = @world.get(px + 5, SKY_Y - 1, pz) == Block::AIR && @world.get(px + 5, SKY_Y, pz) == Block::AIR
    dropped = @items.count { |i| i.block == Block::CACTUS } == 2
    # When the sand falls, the cactus on it breaks too.
    @items.clear
    set_block(px + 5, SKY_Y - 4, pz, Block::STONE)
    set_block(px + 5, SKY_Y - 3, pz, Block::SAND)
    set_block(px + 5, SKY_Y - 2, pz, Block::SAND)
    set_block(px + 5, SKY_Y - 1, pz, Block::CACTUS)
    set_block(px + 5, SKY_Y - 4, pz, Block::AIR)
    fell = @world.get(px + 5, SKY_Y - 1, pz) == Block::AIR && @items.count { |i| i.block == Block::CACTUS } == 1
    check("a cactus breaks and drops when the block under it goes", removed && dropped && fell)
    @items.clear
    @falling.clear
    # A solid block or lava beside a cactus breaks it, and so does water or
    # lava above it. A cactus does not go beside a solid block. The cactus
    # beside it stands on sand too, so it stays.
    [px + 4, px + 5].each do |sx|
      set_block(sx, SKY_Y - 3, pz, Block::STONE)
      set_block(sx, SKY_Y - 2, pz, Block::SAND)
    end
    # Spinel does not type the rows of a nested Array, so each list here
    # holds Integers only.
    beside = [Block::STONE, Block::CACTUS, Block::LAVA, Block::GLASS]
    broken = (0...4).map do |dir|
      side_x = px + 5 + Block::DIR_DX[dir]
      side_z = pz + Block::DIR_DZ[dir]
      @items.clear
      set_block(px + 5, SKY_Y - 1, pz, Block::CACTUS)
      set_block(side_x, SKY_Y - 1, side_z, beside[dir])
      gone = @world.get(px + 5, SKY_Y - 1, pz) == Block::AIR && ground_count(Block::CACTUS) == 1
      set_block(side_x, SKY_Y - 1, side_z, Block::AIR)
      gone
    end
    [Block::WATER, Block::LAVA].each do |above|
      @items.clear
      set_block(px + 5, SKY_Y - 1, pz, Block::CACTUS)
      set_block(px + 5, SKY_Y, pz, above)
      broken << (@world.get(px + 5, SKY_Y - 1, pz) == Block::AIR && ground_count(Block::CACTUS) == 1)
      set_block(px + 5, SKY_Y, pz, Block::AIR)
    end
    @items.clear
    set_block(px + 6, SKY_Y - 1, pz, Block::STONE)
    @target_block.trace(@world, @player)
    place
    refused = @world.get(px + 5, SKY_Y - 1, pz) == Block::AIR
    set_block(px + 6, SKY_Y - 1, pz, Block::AIR)
    set_block(px + 4, SKY_Y - 2, pz, Block::AIR)
    set_block(px + 4, SKY_Y - 3, pz, Block::AIR)
    check("a solid block or lava beside a cactus, or water or lava above it, breaks it, and a cactus does not go beside a " \
          "solid block", broken.all? && refused)
    # Dry grass goes on sand, but not on stone, and a placed block takes
    # its cell.
    @hotbar[0] = Block::DRY_GRASS
    set_block(px + 5, SKY_Y - 2, pz, Block::STONE)
    @target_block.trace(@world, @player)
    place
    stone = @world.get(px + 5, SKY_Y - 1, pz) == Block::AIR
    set_block(px + 5, SKY_Y - 3, pz, Block::STONE)
    set_block(px + 5, SKY_Y - 2, pz, Block::SAND)
    @target_block.trace(@world, @player)
    place
    sand = @world.get(px + 5, SKY_Y - 1, pz) == Block::DRY_GRASS
    @hotbar[0] = Block::COBBLE
    @target_block.trace(@world, @player)
    place
    replaced = @world.get(px + 5, SKY_Y - 1, pz) == Block::COBBLE
    check("dry grass goes on sand, and a placed block takes its cell", stone && sand && replaced)
    set_block(px + 5, SKY_Y - 1, pz, Block::AIR)
    set_block(px + 5, SKY_Y - 2, pz, Block::AIR)
    set_block(px + 5, SKY_Y - 3, pz, Block::AIR)
    @hotbar[0] = held
    @survival = survival
    @player.pitch = pitch
    @player.flying = flying
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
  end

  # /weather clear and /weather rain change the strength of the rain over
  # 100 ticks, as in Java Edition. The rain sound follows the strength of
  # the rain on each tick, with no wait of its own.
  def test_weather_fade
    keep_pose
    @player.move_to(@spawn_x.floor + 0.5, SKY_Y - 1.0, @spawn_z.floor + 0.5)
    @player.flying = true
    @weather.start_rain
    @weather.settle
    run_chat("/weather clear")
    follows = true
    99.times do
      @weather.update_weather(0.05)
      follows = false if @weather.sound(@world, @player) != 0.3 * @weather.rain || @weather.rain <= 0.0
    end
    @weather.update_weather(0.05)
    clear = @weather.rain == 0.0 && @weather.sound(@world, @player) == 0.0
    run_chat("/weather rain")
    99.times do
      @weather.update_weather(0.05)
      follows = false if @weather.sound(@world, @player) != 0.3 * @weather.rain || @weather.rain <= 0.0 || @weather.rain >= 1.0
    end
    @weather.update_weather(0.05)
    rain = @weather.rain == 1.0 && @weather.sound(@world, @player) == 0.3
    check("/weather clear and /weather rain change the rain in 100 ticks, and the rain sound follows the rain on each tick",
          follows && clear && rain)
    @weather.stop_rain
    @weather.settle
    restore_pose
  end

  # The bottom of the rain in column x, z: the third vertex of the quad from
  # corner (x, z) to (x + 1, z + 1). A quad has 6 vertices of 11 floats.
  def rain_bottom(x, z)
    v = @weather.mesh.v
    (0...v.size).step(66) do |i|
      return v[i + 23] if v[i] == x.to_f && v[i + 2] == z.to_f && v[i + 11] == x + 1.0 && v[i + 13] == z + 1.0
    end
    -1.0
  end

  # The save keeps blocks, the inventory, health, the day, the time alive,
  # the items on the ground and the weather, and a dead player respawns on
  # load.
  def test_save(x, z, ground)
    old = @world.get(x, ground + 1, z)
    kept_block = @inv.block(1)
    kept_count = @inv.count(1)
    @items.clear
    drop_item(Block::STONE_SWORD, 17, x + 0.25, ground + 1.0, z + 0.75, 0.0, 0.0, 0.0, 0.0)
    @weather.start_rain
    @weather.timer = 77.5
    @weather.start_thunder
    @weather.thunder_timer = 55.5
    @recipe_book = RecipeBook.new
    @recipe_book.learn(Block::DIAMOND)
    @furnaces.clear
    hot = @furnaces.furnace_at(3, 70, 4)
    hot.burn = 500
    hot.burn_total = 1600
    hot.progress = 37
    hot.slots.set(Furnace::INPUT, Block::SAND, 2)
    hot.slots.set(Furnace::FUEL, Block::OAK_LOG, 3)
    @furnaces.furnace_at(5, 70, 4)
    @clock.day = 37
    @alive_time = 1500.0
    @boats.clear
    @boats << Boat.new(Block::SPRUCE_BOAT, x + 0.5, ground + 1.25, z + 0.5, 1.5)
    @riding = 0
    save
    @boats.clear
    @riding = -1
    @world.set(x, ground + 1, z, Block::GLASS)
    @player.vitals.health = 3.0
    @inv.set(1, Block::AIR, 0)
    @items.clear
    @weather.clear
    @weather.settle
    @recipe_book = RecipeBook.new
    @furnaces.clear
    @clock.day = 0
    @alive_time = 0.0
    ok = load
    apply_loaded if ok
    check("the save keeps the day and the time alive", ok && @clock.day == 37 && @alive_time == 1500.0)
    check("save and load round trip", ok && @world.get(x, ground + 1, z) == old && @player.vitals.health == Vitals::MAX_HEALTH && @inv.block(1) == kept_block && @inv.count(1) == kept_count && kept_count > 0 && @survival)
    check("the save keeps the items on the ground and the weather",
          @items.size == 1 && @items[0].block == Block::STONE_SWORD && @items[0].count == 17 &&
          @items[0].x == x + 0.25 && @items[0].y == ground + 1.0 && @items[0].z == z + 0.75 &&
          @weather.raining? && @weather.rain == 1.0 && @weather.timer == 77.5 &&
          @weather.storm? && @weather.thunder == 1.0 && @weather.thunder_timer == 55.5)
    boat = @boats[0]
    check("the save keeps the boats and the boat that the player rides",
          @boats.size == 1 && boat.item == Block::SPRUCE_BOAT && boat.x == x + 0.5 && boat.y == ground + 1.25 && boat.z == z + 0.5 && boat.yaw == 1.5 && @riding == 0)
    @boats.clear
    @riding = -1
    furnaces = @furnaces.size
    loaded = @furnaces.furnace_at(3, 70, 4)
    check("the save keeps the seen items, and the slots and the fire of furnaces",
          @recipe_book.seen?(Block::DIAMOND) && furnaces == 1 && loaded.burn == 500 && loaded.burn_total == 1600 && loaded.progress == 37 &&
          loaded.slots.block(Furnace::INPUT) == Block::SAND && loaded.slots.count(Furnace::INPUT) == 2 && loaded.slots.block(Furnace::FUEL) == Block::OAK_LOG && loaded.slots.count(Furnace::FUEL) == 3)
    @furnaces.clear
    @items.clear
    @weather.clear
    @weather.settle
    # The sky shows the moon of the loaded day: day 37 has the phase
    # 37 % 8 = 5.
    time = @clock.time_of_day
    @clock.time_of_day = 0.75
    @camera.update_camera(0.0, 64.0, 0.0, 0.0, 1.3, 16.0 / 9.0, 300.0, 0.6)
    @sky.build_sky(1280.0, 720.0, 1.0)
    layers = @sky.mesh.v
    moon = false
    i = 4
    while i < layers.size
      moon = true if layers[i].to_i == Tex::MOON + 5
      i += 54
    end
    check("the sky shows the moon of the day of the loaded save", moon)
    @clock.time_of_day = time
    @player.vitals.health = 0.0
    save
    ok = load
    apply_loaded if ok
    check("loading a save made while dead respawns", ok && @player.vitals.health == Vitals::MAX_HEALTH && !@player.vitals.dead? && @alive_time == 0.0)
    File.write(@save_path, "NOT A SAVE\n")
    ok = load
    keep_bad_save
    check("a save that does not load moves aside", !ok && !File.exist?(@save_path) && File.exist?(@bad_save_path))
    check("a save that does not load gives the reason", @load_error == "its first line has 3 fields, and a save has more than #{F_CHESTS}")
    File.write(@save_path, "0 #{Array.new(F_CHESTS, "0").join(" ")}\n")
    ok = load
    check("a save in an old format gives its format", !ok && @load_error == "its format is 0, not #{SAVE_VERSION}")
    File.delete(@save_path)
    File.delete(@bad_save_path) if File.exist?(@bad_save_path)
  end

  # A right-click takes half a stack or puts down one item. A Shift-click
  # moves a stack between the hotbar and the backpack, or between the
  # inventory and an open chest.
  def test_split_and_quick_move(cx, cz)
    @inv.clear
    @held.clear
    @inv.set(5, Block::DIRT, 7)
    @inv.click_half(5, @held)
    half = @held.count(0) == 4 && @inv.count(5) == 3
    @inv.click_half(6, @held)
    @inv.click_half(6, @held)
    @inv.click_half(5, @held)
    one = @inv.count(6) == 2 && @inv.count(5) == 4 && @held.count(0) == 1
    return_held
    check("a right-click takes half a stack and puts down one item", half && one && @inv.count(5) == 5)
    @inv.clear
    @inv.set(0, Block::DIRT, 10)
    @inv.set(HOTBAR, Block::DIRT, 60)
    quick_move_slot(0)
    pack = @inv.count(0) == 0 && @inv.count(HOTBAR) == 64 && @inv.block(HOTBAR + 1) == Block::DIRT && @inv.count(HOTBAR + 1) == 6
    set_block(cx, SKY_Y, cz, Block::CHEST)
    @chests.open_at(@world, cx, SKY_Y, cz)
    chest = @chests.current.slots_for(0)
    quick_move_slot(HOTBAR + 1)
    into_chest = @inv.count(HOTBAR + 1) == 0 && chest.block(0) == Block::DIRT && chest.count(0) == 6
    quick_move_chest(0)
    out_of_chest = chest.count(0) == 0 && @inv.total(Block::DIRT) == 70
    @chests.close
    set_block(cx, SKY_Y, cz, Block::AIR)
    check("a Shift-click moves a stack to the other side", pack && into_chest && out_of_chest)
    @inv.clear
  end

  # The recipe list shows a recipe once the player has had its ingredient.
  def test_seen_recipes
    @recipe_book = RecipeBook.new
    @inv.clear
    @inv.add(Block::OAK_LOG)
    note_seen
    logs = shown_recipes == [recipe_for(Block::OAK_PLANKS)]
    told = @message == "2 NEW RECIPES - PRESS E, AT A FURNACE" && @recipe_book.fresh?(recipe_for(Block::OAK_PLANKS))
    toggle_inventory
    toggle_inventory
    check("a new recipe shows a message and a tag until the inventory closes", told && !@recipe_book.fresh?(recipe_for(Block::OAK_PLANKS)))
    @inv.add(Block::OAK_PLANKS)
    note_seen
    both = @message.include?("NEW RECIPES - PRESS E, AT A CRAFTING TABLE")
    @inv.add(Block::IRON)
    note_seen
    furnace = @message == "NEW RECIPE: IRON INGOT - AT A FURNACE"
    @inv.remove(Block::IRON, 1)
    check("the new recipe message says where to make the recipes", both && furnace)
    @inv.remove(Block::OAK_PLANKS, 1)
    note_seen
    planks = shown_recipes.include?(recipe_for(Block::CRAFTING_TABLE)) && !shown_recipes.include?(recipe_for(Block::STONE_PICK))
    check("the recipe list shows only the recipes for seen ingredients", logs && planks)
    @inv.add(Block::IRON)
    note_seen
    hand = shown_recipes.include?(recipe_for(Block::OAK_PLANKS)) && !shown_recipes.include?(recipe_for(Block::WOOD_PICK)) && !shown_recipes.include?(recipe_for(Block::IRON_INGOT))
    x = @player.x.floor + 2
    y = @player.y.floor
    z = @player.z.floor
    old = @world.get(x, y, z)
    set_block(x, y, z, Block::CRAFTING_TABLE)
    open_station(x, y, z, Recipe::AT_TABLE)
    table = shown_recipes.include?(recipe_for(Block::OAK_PLANKS)) && shown_recipes.include?(recipe_for(Block::WOOD_PICK)) && !shown_recipes.include?(recipe_for(Block::IRON_INGOT))
    # The table breaks while its screen is open. Then the screen works as
    # the E screen.
    3.times { @inv.add(Block::OAK_PLANKS) }
    set_block(x, y, z, Block::AIR)
    by_hand = shown_recipes.include?(recipe_for(Block::OAK_PLANKS)) && !shown_recipes.include?(recipe_for(Block::WOOD_PICK))
    craft_recipe(recipe_for(Block::WOOD_PICK))
    refused = @message == "NEED A CRAFTING TABLE" && @inv.total(Block::WOOD_PICK) == 0
    check("a crafting table that breaks while its screen is open makes only the recipes by hand", by_hand && refused)
    toggle_inventory
    set_block(x, y, z, Block::FURNACE)
    open_station(x, y, z, Recipe::AT_FURNACE)
    furnace = shown_recipes == [recipe_for(Block::IRON_INGOT), recipe_for(Block::COAL)]
    toggle_inventory
    set_block(x, y, z, old)
    check("the E screen, a crafting table and a furnace each show their own recipes", hand && table && furnace && @station == Recipe::BY_HAND)
    @inv.clear
  end

  # A crafting table shows more recipes than fit. The list scrolls to its
  # last row and no further, and it starts at the top each time it opens.
  def test_recipe_scroll
    book = @recipe_book
    @recipe_book = RecipeBook.new
    @recipe_book.recipe_count.times { |index| Block.fillers(@recipe_book.recipe(index).ingredient).each { |block| @recipe_book.learn(block) } }
    x = @player.x.floor + 2
    y = @player.y.floor
    z = @player.z.floor
    old = @world.get(x, y, z)
    set_block(x, y, z, Block::CRAFTING_TABLE)
    open_station(x, y, z, Recipe::AT_TABLE)
    shown = shown_recipes
    rows = (shown.size + 1) / 2
    top = @recipe_book.in_view(active_station) == shown[0, RecipeBook::ROWS * 2]
    picks = [Block::WOOD_PICK, Block::STONE_PICK, Block::IRON_PICK, Block::DIAMOND_PICK].map { |block| shown.index(recipe_for(block)) }
    check("a crafting table shows the planks first, then the pickaxes in one column, one to a row", shown[0] == recipe_for(Block::OAK_PLANKS) && picks == [4, 6, 8, 10])
    @recipe_book.scroll_by(100, active_station)
    end_view = @recipe_book.in_view(active_station)
    bottom = @recipe_book.top == rows - RecipeBook::ROWS && end_view[end_view.size - 1] == shown[shown.size - 1] && end_view[0] == shown[@recipe_book.top * 2]
    @recipe_book.scroll_by(-100, active_station)
    back = @recipe_book.top == 0
    @recipe_book.scroll_by(2, active_station)
    toggle_inventory
    open_station(x, y, z, Recipe::AT_TABLE)
    reset = @recipe_book.top == 0
    toggle_inventory
    set_block(x, y, z, old)
    @recipe_book = book
    check("the recipe list scrolls to its last row, and it opens at the top", rows > RecipeBook::ROWS && top && bottom && back && reset)
  end

  # The inventory screen fits the frame and leaves the hotbar and the health
  # bars free, for common frame sizes.
  def test_inventory_layout
    sizes = [1280.0, 720.0, 2560.0, 1440.0, 1920.0, 1080.0, 2880.0, 1800.0, 3840.0, 2160.0]
    fits = true
    (0...sizes.size).step(2) do |i|
      w = sizes[i]
      h = sizes[i + 1]
      s = inventory_scale(w, h)
      first = pack_cell(HOTBAR, w, h, s)
      last = recipe_cell(RecipeBook::ROWS * 2 - 1, w, h, s)
      pad = 18.0 * s
      fits = false if first[0] - pad < 0.0 || first[1] - pad - 40.0 * s < 0.0
      fits = false if last[0] + last[2] + pad > w || last[1] + last[3] + pad > h - 82.0 * ui_scale(h)
    end
    check("the inventory screen fits the frame above the hotbar", fits)
  end

  # The creative inventory screen fits the frame height, for common frame
  # sizes, with its title above the grid and its label below.
  def test_creative_layout
    fits = [[1280.0, 720.0], [1920.0, 1080.0], [2560.0, 1440.0], [3840.0, 2160.0]].all? do |w, h|
      s = creative_scale(h)
      first = inventory_cell(0, w, h, s)
      last = inventory_cell(CREATIVE_ITEMS.size - 1, w, h, s)
      first[1] - 58.0 * s >= 0.0 && last[1] + last[2] + 44.0 * s <= h
    end
    check("the creative inventory screen fits the frame height", fits)
  end

  # The pause screen fits the frame above the hotbar, for common frame
  # heights. Where it fits at the HUD scale, it keeps that scale.
  def test_menu_layout
    fits = [720.0, 1080.0, 1440.0, 1800.0, 2160.0].all? do |h|
      s = menu_scale(h)
      menu_title_y(h, s) >= 0.0 && menu_help_y(MENU_HELP.size - 1, h, s) + 10.0 * s <= hotbar_y(h, ui_scale(h))
    end
    check("the pause screen fits the frame above the hotbar", fits && menu_scale(1440.0) == ui_scale(1440.0))
  end

  # The index of the recipe that makes block.
  def recipe_for(block)
    @recipe_book.recipe_count.times { |index| return index if @recipe_book.recipe(index).result == block }
    abort "no recipe makes #{Block::NAMES[block]}"
  end

  # The recipes that the open screen lists.
  def shown_recipes = @recipe_book.shown(active_station)

  # Crafts the recipe at index on a crafting table next to the player.
  def craft_at_table(index)
    x = @player.x.floor + 2
    y = @player.y.floor
    z = @player.z.floor
    old = @world.get(x, y, z)
    set_block(x, y, z, Block::CRAFTING_TABLE)
    open_station(x, y, z, Recipe::AT_TABLE)
    craft_recipe(index)
    toggle_inventory
    set_block(x, y, z, old)
  end

  # Crafting needs room for the result, and it takes from several stacks.
  def test_crafting_limits
    INV.times { |i| @inv.set(i, Block::OAK_PLANKS, 64) }
    @inv.set(0, Block::OAK_LOG, 5)
    @inv.set(1, Block::OAK_PLANKS, 62)
    @slot = 0
    craft_recipe(recipe_for(Block::OAK_PLANKS))
    check("crafting refuses when the result does not fit", @inv.count(0) == 5 && @inv.count(1) == 62)
    @inv.clear
    @inv.set(3, Block::OAK_PLANKS, 2)
    @inv.set(20, Block::OAK_PLANKS, 4)
    craft_at_table(recipe_for(Block::BOW))
    check("a recipe takes ingredients from several stacks", @inv.total(Block::OAK_PLANKS) == 1 && @inv.total(Block::BOW) == Block.uses(Block::BOW))
    @inv.clear
    @inv.set(3, Block::SPRUCE_PLANKS, 1)
    @inv.set(4, Block::BIRCH_PLANKS, 3)
    craft_at_table(recipe_for(Block::WOOD_PICK))
    check("a recipe for planks takes the planks of any wood", @inv.total(Block::SPRUCE_PLANKS) == 0 &&
          @inv.total(Block::BIRCH_PLANKS) == 1 && @inv.total(Block::WOOD_PICK) == Block.uses(Block::WOOD_PICK))
    # A tool wears out, and a thrown tool keeps the uses that it has left.
    @inv.clear
    @inv.add(Block::WOOD_PICK)
    @inv.add(Block::WOOD_PICK)
    @slot = 0
    @inv.set(0, Block::WOOD_PICK, 1)
    survival = @survival
    @survival = true
    chips = @particles.count(Particle::CHIP)
    wear_tool(1)
    broke = @inv.count(0) == 0 && @inv.block(1) == Block::WOOD_PICK && @particles.count(Particle::CHIP) - chips == 5
    @inv.set(1, Block::WOOD_PICK, 7)
    @slot = 1
    @items.clear
    throw_selected
    collect_items
    @survival = survival
    check("a tool breaks after its last use, and a thrown tool keeps its uses", broke && @inv.count(0) == 7 && @inv.block(0) == Block::WOOD_PICK)
    # The only free slot is the one that the recipe empties.
    INV.times { |i| @inv.set(i, Block::DIRT, 64) }
    @inv.set(0, Block::OAK_LOG, 1)
    craft_recipe(recipe_for(Block::OAK_PLANKS))
    check("a recipe click counts the slot that it empties as room", @inv.block(0) == Block::OAK_PLANKS && @inv.count(0) == 4)
  end

  # The treasure chest on the island nearest to spawn fills with its loot
  # the first time that it breaks or opens, and never again.
  def test_treasure
    site = @treasure.nearest(@spawn_x, @spawn_z)
    check("an island near spawn has a treasure site", site.found?)
    return unless site.found?

    back_x = @player.x.to_f
    back_y = @player.y.to_f
    back_z = @player.z.to_f
    was_survival = @survival
    @survival = true
    x = site.chest_x
    y = site.chest_y
    z = site.chest_z
    teleport(x + 0.5, y + 0.01, z + 20.5)
    chest = @world.get(x, y, z)
    check("the treasure site has a chest", Block::BASE[chest] == Block::CHEST)
    lit = beacon_faces
    check("BEACONS=1 draws a beam over a treasure chest that is not looted", lit > 0)
    test_treasure_guards(x, y, z)
    teleport(x + 0.5, y + 0.01, z + 2.5)
    @items.clear
    set_block(x, y, z, Block::AIR)
    check("an unopened treasure chest drops its loot when it breaks", ground_count(Block::SPINEL_ORE) == 1 && ground_count(Block::IRON_INGOT) > 0)
    @items.clear
    set_block(x, y, z, chest)
    open_chest(x, y, z)
    empty = @chests.current.slots_for(0).total(Block::SPINEL_ORE) == 0
    toggle_inventory
    check("a chest in the place of a looted treasure chest stays empty", empty)
    @treasure = Treasure.new(@world.treasure_map, @seed)
    open_chest(x, y, z)
    loot = @chests.current.slots_for(0).total(Block::SPINEL_ORE)
    toggle_inventory
    check("a treasure chest holds one spinel ore when it opens", loot == 1)
    save
    @treasure = Treasure.new(@world.treasure_map, @seed)
    ok = load
    apply_loaded if ok
    open_chest(x, y, z)
    kept = @chests.current.slots_for(0).total(Block::SPINEL_ORE)
    toggle_inventory
    check("a looted treasure chest stays looted after a save", ok && kept == 1 && !@treasure.unlooted?(x, y, z))
    @mobs.clear
    teleport(x + 0.5, y + 0.01, z + 200.5)
    guard_treasure
    teleport(x + 0.5, y + 0.01, z + 10.5)
    guard_treasure
    check("a looted treasure chest has no guards", @mobs.empty?)
    teleport(x + 0.5, y + 0.01, z + 20.5)
    check("BEACONS=1 draws no beam over a looted treasure chest", beacon_faces < lit)
    test_treasure_large_chest(x, y, z)
    @survival = was_survival
    teleport(back_x, back_y, back_z)
  end

  # A chest beside the treasure chest at x, y, z joins it into a large
  # chest. Opening the other half fills the treasure half.
  def test_treasure_large_chest(x, y, z)
    right = Block::CHEST_RIGHT
    dir = Block.chest_partner_dir(right)
    other_x = x + Block::DIR_DX[dir]
    other_z = z + Block::DIR_DZ[dir]
    @chests.remove_at(World.key(x, y, z))
    set_block(x, y, z, right)
    set_block(other_x, y, other_z, Block::CHEST_LEFT)
    @treasure = Treasure.new(@world.treasure_map, @seed)
    open_chest(other_x, y, other_z)
    chest = @chests.current
    ore = chest.slots_for(0).total(Block::SPINEL_ORE) + chest.slots_for(Chest::SLOTS).total(Block::SPINEL_ORE)
    large = chest.large?
    toggle_inventory
    check("opening the other half of a large chest fills the treasure half", large && ore == 1)
  end

  # The faces that BEACONS=1 adds to the frame of the player now.
  def beacon_faces
    was = @beacons
    ex = @player.x.to_f
    ey = @player.eye_y.to_f
    ez = @player.z.to_f
    reach = @options.view + 4.0
    @beacons = false
    build_dyn(ex, ey, ez, reach)
    without = @dyn.count
    @beacons = true
    build_dyn(ex, ey, ez, reach)
    @beacons = was
    @dyn.count - without
  end

  # The guards of the treasure chest at x, y, z come when the player comes
  # within 16 blocks, once, and again after the player has gone far away.
  def test_treasure_guards(x, y, z)
    @mobs.clear
    guard_treasure
    check("a treasure chest sends no guards to a player 20 blocks away", @mobs.empty?)
    teleport(x + 0.5, y + 0.01, z + 10.5)
    update_mobs(1.0 / 60.0)
    near = @mobs.count { |mob| !mob.passive? && (mob.x - x - 0.5).abs <= 5.0 && (mob.z - z - 0.5).abs <= 5.0 }
    check("4 monsters guard a treasure chest when the player comes near", near == NaturalSpawner::GUARDS)
    @mobs.clear
    guard_treasure
    check("the guards that the player kills do not come back while the player stays", @mobs.empty?)
    teleport(x + 0.5, y + 0.01, z + 200.5)
    guard_treasure
    teleport(x + 0.5, y + 0.01, z + 10.5)
    guard_treasure
    check("the guards come back after the player goes far away", @mobs.size == NaturalSpawner::GUARDS)
    teleport(x + 0.5, y + 0.01, z + 200.5)
    guard_treasure
    teleport(x + 0.5, y + 0.01, z + 10.5)
    guard_treasure
    check("the guards that still live count toward the next pack", @mobs.size == NaturalSpawner::GUARDS)
    @mobs.clear
  end

  # Chest contents survive a save and come back when the chest breaks.
  def test_chests(cx, cz)
    set_block(cx, SKY_Y, cz, Block::CHEST)
    @inv.clear
    open_chest(cx, SKY_Y, cz)
    @chests.current.slots_for(0).set(5, Block::DIAMOND, 7)
    toggle_inventory
    save
    @chests.clear
    ok = load
    apply_loaded if ok
    @chests.open_at(@world, cx, SKY_Y, cz)
    stored = @chests.current.slots_for(0)
    @chests.close
    check("chest contents survive a save", ok && @chests.size == 1 && stored.block(5) == Block::DIAMOND && stored.count(5) == 7)
    set_block(cx, SKY_Y, cz, Block::AIR)
    dropped = ground_count(Block::DIAMOND) == 7 && @inv.total(Block::DIAMOND) == 0
    collect_items
    check("a broken chest drops its contents", dropped && @inv.total(Block::DIAMOND) == 7 && @chests.size == 0)
    # The stack in the hand goes back when the screen closes. With the
    # inventory full, it goes onto a stack of its kind in the chest first,
    # and then into an empty slot of the chest.
    @inv.clear
    @items.clear
    set_block(cx, SKY_Y, cz, Block::CHEST)
    open_chest(cx, SKY_Y, cz)
    (0...INV).each { |slot| @inv.set(slot, Block::STONE, 64) }
    chest = @chests.current.slots_for(0)
    chest.set(5, Block::DIRT, 60)
    @held.set(0, Block::DIRT, 10)
    toggle_inventory
    check("the stack in the hand fills a stack of its kind in the open chest before an empty slot",
          chest.count(5) == 64 && chest.block(0) == Block::DIRT && chest.count(0) == 6 && @held.empty?(0) && ground_count(Block::DIRT) == 0)
    set_block(cx, SKY_Y, cz, Block::AIR)
    # An open chest destroyed by a blast never duplicates its contents.
    @inv.clear
    @items.clear
    set_block(cx, SKY_Y, cz, Block::CHEST)
    open_chest(cx, SKY_Y, cz)
    @chests.current.slots_for(0).set(0, Block::DIAMOND, 7)
    set_block(cx, SKY_Y, cz, Block::AIR)
    check("a chest destroyed while open does not duplicate items", @inv.total(Block::DIAMOND) + ground_count(Block::DIAMOND) == 7 && !current_screen.inventory? && @chests.size == 0)
    @items.clear
    test_chest_screen
  end

  # The chest cells are as big as the inventory cells, and the cells of a
  # large chest fit on the screen at each window size.
  def test_chest_screen
    fits = [[1280.0, 720.0], [1920.0, 1080.0], [2560.0, 1440.0], [3840.0, 2160.0]].all? do |w, h|
      s = inventory_scale(w, h)
      last = chest_cell(Chest::SLOTS * 2 - 1, w, h, s)
      chest_cell(0, w, h, s)[2] == pack_cell(0, w, h, s)[2] && last[0] + last[2] <= w && last[1] + last[2] <= h
    end
    check("the chest cells are as big as the inventory cells and fit on the screen", fits)
  end

  # A mob drops its loot also when it dies without the player's help.
  def test_mob_drops
    @inv.clear
    @items.clear
    far = Animal.new(Mob::PIG, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    far.hp = 0.0
    @mobs.clear
    @mobs << far
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::PORKCHOP)
    check("a pig that dies on its own drops 1 to 3 porkchops", n >= 1 && n <= 3)
    @items.clear
    killed = Animal.new(Mob::PIG, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    killed.hp = 0.0
    killed.by_player = true
    @mobs << killed
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::PORKCHOP)
    dropped = n >= 1 && n <= 3
    collect_items
    check("a pig that the player kills drops 1 to 3 porkchops", dropped && @inv.total(Block::PORKCHOP) == n)
    @items.clear
    # A pig that the player hurt dies in lava, so the lava kills it inside
    # Mob#update_mob. It drops its loot once. update_mobs does not merge the
    # items, so a second drop shows as a second stack.
    lx = (@spawn_x + 30.0).floor
    lz = (@spawn_z + 3.0).floor
    set_block(lx, SKY_Y, lz, Block::LAVA)
    burnt = Animal.new(Mob::PIG, lx + 0.5, SKY_Y.to_f, lz + 0.5, 5)
    burnt.hp = 1.0
    burnt.by_player = true
    @mobs << burnt
    10.times { update_mobs(1.0 / 60.0) }
    set_block(lx, SKY_Y, lz, Block::AIR)
    stacks = @items.count { |i| i.block == Block::COOKED_PORKCHOP }
    check("a pig that dies in lava drops cooked porkchops once", burnt.dying? && stacks == 1 && ground_count(Block::PORKCHOP) == 0)
    @items.clear
    sheep = Animal.new(Mob::SHEEP, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    sheep.hp = 0.0
    sheep.by_player = true
    @mobs << sheep
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::MUTTON)
    check("a sheep that the player kills drops its wool and 1 to 2 mutton", ground_count(Block::WOOL) == 1 && n >= 1 && n <= 2)
    @items.clear
    bare = Animal.new(Mob::SHEEP, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 6)
    bare.sheared = true
    bare.hp = 0.0
    bare.by_player = true
    @mobs << bare
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::MUTTON)
    check("a sheared sheep drops no wool when killed, and still drops 1 to 2 mutton", ground_count(Block::WOOL) == 0 && n >= 1 && n <= 2)
    @items.clear
    @mobs.clear
    check("mutton is food, and a furnace cooks it", cooks?(Block::MUTTON, 2, 1.2, Block::COOKED_MUTTON, 6, 9.6))
    cow = Animal.new(Mob::COW, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    cow.hp = 0.0
    cow.by_player = true
    @mobs << cow
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::BEEF)
    check("a cow that the player kills drops 0 to 2 leather and 1 to 3 raw beef",
          ground_count(Block::LEATHER) <= 2 && n >= 1 && n <= 3 && ground_count(Block::STEAK) == 0)
    @items.clear
    # The lava kills the cow inside Mob#update_mob, so a second drop would
    # show as a second stack.
    lx = (@spawn_x + 30.0).floor
    lz = (@spawn_z + 3.0).floor
    set_block(lx, SKY_Y, lz, Block::LAVA)
    cow = Animal.new(Mob::COW, lx + 0.5, SKY_Y.to_f, lz + 0.5, 5)
    cow.hp = 1.0
    cow.by_player = true
    @mobs << cow
    10.times { update_mobs(1.0 / 60.0) }
    set_block(lx, SKY_Y, lz, Block::AIR)
    stacks = @items.count { |i| i.block == Block::STEAK }
    n = ground_count(Block::STEAK)
    check("a cow that dies in lava drops steak once", cow.dying? && stacks == 1 && n >= 1 && n <= 3 && ground_count(Block::BEEF) == 0)
    @items.clear
    @mobs.clear
    check("beef is food, and a furnace cooks it into steak", cooks?(Block::BEEF, 3, 1.8, Block::STEAK, 8, 12.8))
    test_chickens
    test_chicks
    test_eggs
    # Each zombie drops 0 to 2, so 10 zombies drop none 1 time in 59049.
    10.times do |i|
      zombie = Monster.new(Mob::ZOMBIE, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z + i, 3)
      zombie.hp = 0.0
      zombie.by_player = true
      @mobs << zombie
    end
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::ROTTEN_FLESH)
    check("zombies that the player kills drop 0 to 2 rotten flesh each", n >= 1 && n <= 20)
    @items.clear
    loot(killed, Block::BOW, 1)
    check("a bow that a mob drops is new", @items.size == 1 && @items[0].count == Block.uses(Block::BOW))
    @items.clear
    @mobs.clear
  end

  # A chicken drops 0 to 2 feathers and 1 raw chicken, or cooked chicken
  # when it dies in fire. It lays an egg each 5 to 10 minutes.
  def test_chickens
    x = @spawn_x + 30.0
    z = @spawn_z
    hen = Animal.new(Mob::CHICKEN, x, SKY_Y.to_f, z, 5)
    hen.hp = 0.0
    hen.by_player = true
    @mobs << hen
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::FEATHER)
    check("a chicken that the player kills drops 0 to 2 feathers and 1 raw chicken",
          n <= 2 && ground_count(Block::RAW_CHICKEN) == 1 && ground_count(Block::COOKED_CHICKEN) == 0)
    @items.clear
    lx = x.floor
    lz = (z + 3.0).floor
    set_block(lx, SKY_Y, lz, Block::LAVA)
    burnt = Animal.new(Mob::CHICKEN, lx + 0.5, SKY_Y.to_f, lz + 0.5, 5)
    burnt.by_player = true
    @mobs << burnt
    10.times { update_mobs(1.0 / 60.0) }
    set_block(lx, SKY_Y, lz, Block::AIR)
    check("a chicken that dies in lava drops cooked chicken once",
          burnt.dying? && ground_count(Block::COOKED_CHICKEN) == 1 && ground_count(Block::RAW_CHICKEN) == 0)
    @items.clear
    @mobs.clear
    check("chicken is food, and a furnace cooks it", cooks?(Block::RAW_CHICKEN, 2, 1.2, Block::COOKED_CHICKEN, 6, 7.2))
    hen = Animal.new(Mob::CHICKEN, x, SKY_Y.to_f, z, 11)
    due = hen.egg_time >= Animal::EGG_MIN && hen.egg_time <= Animal::EGG_MIN + Animal::EGG_MORE
    hen.egg_time = 0.001
    @mobs << hen
    update_mobs(1.0 / 60.0)
    check("a chicken lays an egg each 5 to 10 minutes",
          due && ground_count(Block::EGG) == 1 && hen.egg_time >= Animal::EGG_MIN - 0.1)
    @items.clear
    @mobs.clear
  end

  # A chick is half as large, drops nothing and lays no eggs. A chick
  # peeps, and a grown chicken clucks.
  def test_chicks
    @items.clear
    @mobs.clear
    x = @spawn_x + 30.0
    z = @spawn_z
    chick = Animal.new(Mob::CHICKEN, x, SKY_Y.to_f, z, 5)
    chick.make_baby
    small = chick.baby? && chick.half == Mob::HALF[Mob::CHICKEN] / 2.0 && chick.tall == Mob::TALL[Mob::CHICKEN] / 2.0
    chick.egg_time = 0.001
    @mobs << chick
    update_mobs(1.0 / 60.0)
    laid = ground_count(Block::EGG)
    chick.hp = 0.0
    chick.by_player = true
    update_mobs(1.0 / 60.0)
    check("a chick is half as large, lays no eggs, and drops nothing", small && laid == 0 && @items.empty?)
    @mobs.clear
    hen = Animal.new(Mob::CHICKEN, x, SKY_Y.to_f, z, 6)
    check("a chick peeps, and a grown chicken clucks",
          voice(chick, Mob::SOUND) == Sfx::CHICK && voice(hen, Mob::SOUND) == Sfx::CLUCK && voice(hen, Mob::HURT_SOUND) == Sfx::CHICKEN_HURT)
  end

  # The player throws an egg from the hand. An egg breaks on a block, and
  # on a mob, which it pushes but does not hurt. 1 in 8 eggs hatches a
  # chick, and 1 in 32 of those 4 chicks.
  def test_eggs
    @mobs.clear
    @eggs.clear
    @inv.clear
    was = @survival
    @survival = true
    @slot = 0
    @inv.set(0, Block::EGG, 2)
    throw_egg
    check("the player throws one egg of the stack", @eggs.size == 1 && @inv.count(0) == 1)
    @eggs.clear
    x = @spawn_x.floor + 30
    y = SKY_Y - 4
    z = @spawn_z.floor
    set_block(x, y, z, Block::STONE)
    @eggs << Egg.new(x + 0.5, y + 2.0, z + 0.5, 0.0, -10.0, 0.0)
    20.times { update_eggs(1.0 / 60.0) }
    landed = @eggs.empty?
    set_block(x, y, z, Block::AIR)
    @mobs.clear
    pig = Animal.new(Mob::PIG, x + 0.5, y.to_f, z + 0.5, 3)
    @mobs << pig
    @eggs << Egg.new(x + 0.5, y + 0.5, z - 2.0, 0.0, 0.0, Egg::SPEED)
    10.times { update_eggs(1.0 / 60.0) }
    hit = @eggs.empty? && pig.hurt > 0.0 && pig.hp == Mob::HP[Mob::PIG]
    check("an egg breaks on a block, and on a mob that it does not hurt", landed && hit)
    check("1 in 8 eggs hatches a chick, and 1 in 32 of those 4 chicks",
          chicks(0.1, 0.5) == 1 && chicks(0.1, 0.01) == 4 && chicks(0.2, 0.01) == 0 && chicks(0.124, 0.032) == 1)
    # 4000 eggs hatch 4000 * (1/8 * 31/32 + 1/8 * 1/32 * 4) = 546.9 chicks
    # on average. Fewer than 450 or more than 650 comes 1 time in a million.
    hatched = 0
    4000.times { hatched += chicks(@rng.rand01, @rng.rand01) }
    # An egg hatches 1 time in 8, so 400 eggs all fail 1 time in 10^23.
    @mobs.clear
    tries = 0
    while @mobs.empty? && tries < 400
      set_block(x, y, z, Block::STONE)
      @eggs << Egg.new(x + 0.5, y + 1.5, z + 0.5, 0.0, -10.0, 0.0)
      5.times { update_eggs(1.0 / 20.0) }
      tries += 1
    end
    set_block(x, y, z, Block::AIR)
    check("thrown eggs hatch chicks at Minecraft's rate",
          hatched > 450 && hatched < 650 && !@mobs.empty? && @mobs.all? { |m| m.baby? && m.kind == Mob::CHICKEN })
    @mobs.clear
    @eggs.clear
    @inv.clear
    @items.clear
    drop_item(Block::EGG, 20, @player.x.to_f, @player.y.to_f, @player.z.to_f, 0.0, 0.0, 0.0, 0.0)
    collect_items
    picked = @inv.count(0) == 16 && @inv.block(1) == Block::EGG && @inv.count(1) == 4
    @inv.clear
    run_chat("/give egg 20")
    check("eggs stack to 16 when the player picks them up and from /give",
          picked && @inv.count(0) == 16 && @inv.block(1) == Block::EGG && @inv.count(1) == 4 && !last_chat_error?)
    @items.clear
    @inv.clear
    @survival = was
  end

  # A dead mob lies on the ground for DEATH_TIME and takes no hits. Then it
  # goes up in smoke.
  def test_mob_death
    pig = Animal.new(Mob::PIG, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    @mobs.clear
    @mobs << pig
    pig.hit(100.0, pig.x - 1.0, pig.z)
    hp = pig.hp
    30.times { update_mobs(1.0 / 60.0) }
    struck = pig.wound(5.0)
    check("a dead mob stays for a while and takes no hits", pig.alive && pig.dying? && !struck && pig.hp == hp)
    smoke = @particles.count(Particle::SMOKE)
    40.times { update_mobs(1.0 / 60.0) }
    check("a dead mob goes up in smoke after DEATH_TIME", !pig.alive && @particles.count(Particle::SMOKE) > smoke)
  end

  # A hit pig runs away from the hit, and it panics for a while.
  def test_mob_panic
    bx = @spawn_x.floor + 30
    bz = @spawn_z.floor + 20
    (-10..10).each { |i| (-10..10).each { |j| set_block(bx + i, SKY_Y - 2, bz + j, Block::STONE) } }
    pig = Animal.new(Mob::PIG, bx + 0.5, SKY_Y - 1.0, bz + 0.5, 5)
    @mobs.clear
    @mobs << pig
    pig.hit(1.0, pig.x - 1.0, pig.z)
    60.times { update_mobs(1.0 / 60.0) }
    away = pig.x > bx + 2.0
    120.times { update_mobs(1.0 / 60.0) }
    check("a hit pig runs away from the hit and panics for a while", away && pig.panic > 0.0)
    @mobs.clear
  end

  # By day, grass spreads onto the dirt in the middle of a patch of grass,
  # but not onto dirt under stone or under water. At night it does not
  # spread.
  def test_grass_spread
    bx = @spawn_x.floor - 30
    bz = @spawn_z.floor + 30
    y = SKY_Y - 4
    time = @clock.time_of_day
    keep_pose
    @player.x = bx + 0.5
    @player.z = bz + 0.5
    fill_box(bx - 3, y + 1, bz - 3, bx + 3, SKY_Y - 1, bz + 3, Block::AIR)
    fill_box(bx - 3, y, bz - 3, bx + 3, y, bz + 3, Block::GRASS)
    fill_box(bx - 1, y, bz - 1, bx + 1, y, bz + 1, Block::DIRT)
    @clock.time_of_day = 0.75
    spread_grass(1800.0)
    night = count_box(bx - 1, y, bz - 1, bx + 1, y, bz + 1, Block::DIRT) == 9
    set_block(bx + 3, y, bz - 3, Block::DIRT)
    set_block(bx + 3, y + 1, bz - 3, Block::STONE)
    set_block(bx - 3, y, bz + 3, Block::DIRT)
    set_block(bx - 3, y + 1, bz + 3, Block::WATER)
    @clock.time_of_day = 0.3
    spread_grass(1800.0)
    day = count_box(bx - 1, y, bz - 1, bx + 1, y, bz + 1, Block::GRASS) == 9
    covered = @world.get(bx + 3, y, bz - 3) == Block::DIRT && @world.get(bx - 3, y, bz + 3) == Block::DIRT
    check("grass spreads onto dirt by day, but not at night, under stone or under water", night && day && covered)
    fill_box(bx - 3, y, bz - 3, bx + 3, y + 1, bz + 3, Block::AIR)
    @clock.time_of_day = time
    restore_pose
  end

  # Grass under a block that the player placed dies and turns to dirt.
  # The grass beside it, under the open sky, stays.
  def test_covered_grass
    bx = @spawn_x.floor - 30
    bz = @spawn_z.floor + 30
    y = SKY_Y - 4
    keep_pose
    @player.x = bx + 0.5
    @player.z = bz + 0.5
    fill_box(bx - 1, y + 1, bz - 1, bx + 1, SKY_Y - 1, bz + 1, Block::AIR)
    fill_box(bx - 1, y, bz - 1, bx + 1, y, bz + 1, Block::GRASS)
    set_block(bx, y + 1, bz, Block::OAK_PLANKS)
    kill_covered_grass(1800.0)
    covered = @world.get(bx, y, bz) == Block::DIRT
    open = count_box(bx - 1, y, bz - 1, bx + 1, y, bz + 1, Block::GRASS) == 8
    check("grass under a placed block turns to dirt, and the grass beside it stays", covered && open)
    fill_box(bx - 1, y, bz - 1, bx + 1, y + 1, bz + 1, Block::AIR)
    restore_pose
  end

  # Leaves with no log within 6 steps through leaves decay, and leaves
  # that the player placed stay. A row of 8 leaves from a log in the air
  # keeps its first 6.
  def test_leaf_decay
    bx = @spawn_x.floor + 20
    bz = @spawn_z.floor - 20
    y = SKY_Y - 4
    set_block(bx, y, bz, Block::OAK_LOG)
    (1..8).each { |i| set_block(bx + i, y, bz, Block::OAK_LEAVES) }
    keep_pose
    survival = @survival
    @survival = false
    held = @hotbar[0]
    @slot = 0
    @hotbar[0] = Block::OAK_LEAVES
    @player.x = bx + 10.5
    @player.y = y + 2.0
    @player.z = bz + 0.5
    @player.pitch = -1.55
    @player.flying = true
    set_block(bx + 10, y - 1, bz, Block::STONE)
    @target_block.trace(@world, @player)
    place
    set_block(bx + 10, y - 1, bz, Block::AIR)
    placed = @world.get(bx + 10, y, bz) == Block::PLACED_OAK_LEAVES
    @hotbar[0] = held
    @survival = survival
    restore_pose
    decay_leaves(1200.0)
    near = (1..6).all? { |k| @world.get(bx + k, y, bz) == Block::OAK_LEAVES }
    far = @world.get(bx + 7, y, bz) == Block::AIR && @world.get(bx + 8, y, bz) == Block::AIR
    set_block(bx, y, bz, Block::AIR)
    decay_leaves(1200.0)
    cut = (1..6).all? { |k| @world.get(bx + k, y, bz) == Block::AIR }
    kept = @world.get(bx + 10, y, bz) == Block::PLACED_OAK_LEAVES
    set_block(bx + 10, y, bz, Block::AIR)
    @items.clear
    check("leaves with no log near decay, and placed leaves stay", placed && near && far && cut && kept)
    # Oak leaves drop a sapling or an apple about 1 time in 18 when they
    # decay, so 100 leaves drop at least one with this seed.
    @rng = Rng.new(3)
    fill_box(bx + 1, y + 3, bz + 3, bx + 5, y + 6, bz + 7, Block::OAK_LEAVES)
    decay_leaves(1200.0)
    gone = (3..6).all? { |dy| @world.get(bx + 3, y + dy, bz + 5) == Block::AIR }
    dropped = @items.any? { |item| item.block == Block::OAK_SAPLING || item.block == Block::APPLE }
    @items.clear
    check("decayed leaves drop a sapling or an apple now and then", gone && dropped)
  end

  # Oak leaves drop a sapling 1 time in 20 and an apple 1 time in 200,
  # and spruce leaves never drop an apple (minecraft.wiki/w/Leaves). Ripe
  # wheat drops 1 to 4 seeds, about 2 5/7 on average
  # (minecraft.wiki/w/Wheat_Seeds). The bounds are more than 3 standard
  # deviations wide, and the seed of @rng is fixed.
  def test_drop_rates
    @rng = Rng.new(11)
    oak = [0, 0]
    spruce = [0, 0]
    seeds = [0, 0, 0, 0, 0]
    4000.times do
      oak[0] += drops_of(Block::OAK_LEAVES, Block::OAK_SAPLING)
      oak[1] += ground_count(Block::APPLE)
      spruce[0] += drops_of(Block::SPRUCE_LEAVES, Block::SPRUCE_SAPLING)
      spruce[1] += ground_count(Block::APPLE)
    end
    2000.times do
      count = drops_of(Block::WHEAT_RIPE, Block::SEEDS)
      seeds[count] += 1 if count <= 4
    end
    @items.clear
    average = (seeds[1] + seeds[2] * 2 + seeds[3] * 3 + seeds[4] * 4) / 2000.0
    check("oak leaves drop a sapling 1 time in 20 and an apple 1 time in 200, and spruce leaves no apple",
          oak[0].between?(160, 240) && oak[1].between?(8, 34) && spruce[0].between?(160, 240) && spruce[1] == 0)
    check("ripe wheat drops 1 to 4 seeds, about 2 5/7 on average",
          seeds.sum == 2000 && seeds[0] == 0 && seeds[1] > 0 && seeds[4] > 0 && (average - 2.714).abs < 0.1)
  end

  # Breaks block with no tool on an empty ground, and gives how many of
  # item it drops. The other drops stay on the ground.
  def drops_of(block, item)
    @items.clear
    drop_broken(block, @spawn_x.floor + 30, SKY_Y, @spawn_z.floor + 30, Block::AIR)
    ground_count(item)
  end

  # Stands the player on the first item until the ground is empty or the
  # frames run out.
  def cooks?(raw, raw_food, raw_saturation, cooked, cooked_food, cooked_saturation)
    Block.food(raw) == raw_food && Block.saturation(raw) == raw_saturation &&
      Block.food(cooked) == cooked_food && Block.saturation(cooked) == cooked_saturation &&
      !@recipe_book.smelt_recipe(raw).nil? && @recipe_book.smelt_recipe(raw).result == cooked
  end

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
    y = SKY_Y + 2
    fill_box(cx - 1, y, cz - 1, cx + 3, y, cz + 1, Block::STONE)
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
    INV.times { |i| @inv.set(i, Block::STONE, Slots::STACK) }
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
    set_block(cx + 2, y + 1, cz, Block::CACTUS)
    drop_item(Block::SAND, 1, cx + 2.5, y + 3.0, cz + 0.5, 0.0, 0.0, 0.0, 0.0)
    run_items(1.0)
    top = @items.empty?
    drop_item(Block::SAND, 1, cx + 0.5, y + 1.0, cz + 0.5, 2.0, 0.0, 0.0, 0.0)
    run_items(1.5)
    check("a cactus destroys an item that falls on it or slides into it", top && @items.empty?)
    set_block(cx + 2, y + 1, cz, Block::AIR)
    @chunk_meshes.flush_all
  end

  # Wool does not glow, lava gives light, and water turns lava into cobblestone.
  # The tint of the face of block at (cx, SKY_Y, cz) in direction f, from
  # its face record (Mesher.face_tint), or -1 when the mesh has no such face.
  def face_tint(cx, cz, block, f)
    set_block(cx, SKY_Y, cz, block)
    mesher = Mesher.new(@world)
    mesher.build(cx / CHUNK, cz / CHUNK)
    tint = -1
    (0...mesher.opaque.size).step(2) do |k|
      w0 = mesher.opaque[k]
      if Mesher.face_x(w0) == (cx & LMASK) && Mesher.face_y(w0) == SKY_Y && Mesher.face_z(w0) == (cz & LMASK) && Mesher.face_dir(w0) == f
        tint = Mesher.face_tint(mesher.opaque[k + 1])
      end
    end
    set_block(cx, SKY_Y, cz, Block::AIR)
    tint
  end

  def test_tint(cx, cz)
    check("grass takes the grass color and oak leaves the foliage color",
          face_tint(cx, cz, Block::GRASS, 2) == 1 && face_tint(cx, cz, Block::GRASS, 0) == 1 &&
          face_tint(cx, cz, Block::OAK_LEAVES, 2) == 2 && face_tint(cx, cz, Block::SPRUCE_LEAVES, 2) == 0 &&
          face_tint(cx, cz, Block::STONE, 2) == 0)
    k = ((cz >> 2) & (Tint::SIZE - 1)) * Tint::SIZE + ((cx >> 2) & (Tint::SIZE - 1))
    # to_i keeps the world generator typed (see ChunkMeshes#stream).
    x = ((cx >> 2) * 4 + 2).to_i
    z = ((cz >> 2) * 4 + 2).to_i
    b = @world.terrain.biome(x, z, @world.terrain.surface_height(x, z))
    plains = Tint.ratio(Biome::GRASS_COLOR[Biome::PLAINS], Biome::GRASS_COLOR[Biome::PLAINS])
    check("the tint map holds the ratio of the biome color to the plains color",
          plains == 0xff404040 && @tint.pixels[k] == Tint.ratio(Biome::GRASS_COLOR[b], Biome::GRASS_COLOR[Biome::PLAINS]))
  end

  def test_light_sources(cx, cz)
    # Wool is not a light source.
    set_block(cx, SKY_Y, cz, Block::WOOL)
    mesher = Mesher.new(@world)
    mesher.build(cx / CHUNK, cz / CHUNK)
    faces = 0
    glow = false
    (0...mesher.opaque.size).step(2) do |k|
      w0 = mesher.opaque[k]
      if Mesher.face_x(w0) == (cx & LMASK) && Mesher.face_y(w0) == SKY_Y && Mesher.face_z(w0) == (cz & LMASK)
        faces += 1
        glow = true if Mesher.face_light(mesher.opaque[k + 1]) == 14
      end
    end
    check("wool does not glow", faces > 0 && !glow)
    set_block(cx, SKY_Y, cz, Block::AIR)
    lx = @spawn_x.floor - 6
    lz = @spawn_z.floor - 6
    (-1..1).each do |i|
      set_block(lx + i, SKY_Y - 5, lz, Block::STONE)
      set_block(lx + i, SKY_Y - 4, lz, Block::AIR)
    end
    set_block(lx, SKY_Y - 4, lz, Block::LAVA)
    mesher.build(lx / CHUNK, lz / CHUNK)
    check("lava lights its surroundings", mesher.torch_light(lx, SKY_Y - 3, lz) == 14)
    set_block(lx + 1, SKY_Y - 4, lz, Block::WATER)
    20.times { update_fluids(Fluids::LAVA_STEP) }
    check("water turns lava into cobblestone", @world.get(lx, SKY_Y - 4, lz) == Block::COBBLE)
    set_block(lx + 1, SKY_Y - 4, lz, Block::AIR)
    set_block(lx, SKY_Y - 4, lz, Block::AIR)
    20.times { update_fluids(Fluids::LAVA_STEP) }
  end

  # Builds a stone platform and shoots a pig on it with a full bow draw.
  def test_bow(bx, bz)
    @mobs.clear
    (-2..12).each { |i| set_block(bx + i, SKY_Y - 2, bz, Block::STONE) }
    @player.x = bx + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = bz + 0.5
    @player.yaw = 1.5708
    @player.pitch = -0.12
    @inv.clear
    @inv.add(Block::ARROW)
    pig = Animal.new(Mob::PIG, bx + 8.5, SKY_Y - 1.0, bz + 0.5, 3)
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
    full = Monster.new(Mob::ZOMBIE, bx + 2.5, SKY_Y - 1.0, bz + 0.5, 3)
    quick = Monster.new(Mob::ZOMBIE, bx + 2.5, SKY_Y - 1.0, bz + 0.5, 4)
    @mobs << full
    @mobs << quick
    @player.melee_attack.restart
    @player.melee_attack.advance(1.0)
    @target_mob = 0
    left_button(0.0, true, true)
    @target_mob = 1
    left_button(0.0, true, true)
    check("a hit right after an attack does less damage", full.hp == 16.0 && quick.hp > 19.0 && quick.hp < 19.2)
    falling = Monster.new(Mob::ZOMBIE, bx + 2.5, SKY_Y - 1.0, bz + 0.5, 5)
    @mobs << falling
    @player.melee_attack.restart
    @player.melee_attack.advance(1.0)
    @player.on_ground = false
    @player.in_water = false
    @player.vy = -2.0
    sparks = @particles.count(Particle::CRIT)
    @target_mob = 2
    left_button(0.0, true, true)
    @player.vy = 0.0
    @player.on_ground = true
    check("a falling attack is a critical hit: 1.5 times the damage, with sparks", falling.hp == 14.0 && @particles.count(Particle::CRIT) > sparks)
    @inv.clear
    @mobs.clear
    @target_mob = -1
    @survival = survival
  end

  # A right click with a bow in hand opens a furnace or a crafting table,
  # as with any other item, and does not draw the bow.
  def test_bow_on_stations
    x = @spawn_x.floor + 35
    z = @spawn_z.floor - 45
    y = SKY_Y - 20
    keep_pose
    survival = @survival
    @survival = true
    @inv.clear
    @inv.add(Block::BOW)
    @slot = 0
    opened = [Block::FURNACE, Block::CRAFTING_TABLE].all? do |block|
      set_block(x, y, z, block)
      aim_down(x, y, z)
      @action_cooldown = 0.0
      @draw_time = -1.0
      right_button(0.05, true)
      open = current_screen.inventory? && @station != Recipe::BY_HAND && @draw_time < 0.0
      toggle_inventory if current_screen.inventory?
      open
    end
    set_block(x, y, z, Block::AIR)
    @inv.clear
    @survival = survival
    restore_pose
    check("a bow in hand opens a furnace or a crafting table, and does not draw", opened)
  end

  # Sneaking, walking off an edge, and the bed, on the platform from test_bow.
  def test_sneak_and_bed(bx, bz)
    # The platform is one block wide in z: sneaking toward its edge stays on it.
    @player.move_to(bx + 4.5, SKY_Y - 1.0, bz + 0.5)
    @player.yaw = 3.14159
    @player.flying = false
    @player.on_ground = true
    @player.controls.hold(1.0, 0.0, jump: false, sneak: true, sprint: false)
    120.times { @player.update(@world, 1.0 / 60.0) }
    low = (@player.eye_y - @player.y - Player::SNEAK_EYE).abs < 0.01
    @mobs.clear
    set_block(bx + 6, SKY_Y - 1, bz, Block.bed_id(0, true))
    @clock.time_of_day = 0.75
    day = @clock.day
    use_bed(bx + 6, SKY_Y - 1, bz)
    check("sleeping in a bed skips the night and sets spawn", @clock.time_of_day == Clock::MORNING && @spawn_x == bx + 6.5 && @clock.day == day + 1)
    @clock.set_ticks(12200)
    evening = @clock.time_of_day
    use_bed(bx + 6, SKY_Y - 1, bz)
    dusk = @clock.time_of_day == evening
    @weather.start_rain
    @weather.settle
    use_bed(bx + 6, SKY_Y - 1, bz)
    @weather.stop_rain
    @weather.settle
    check("a bed works earlier in the evening in rain", dusk && @clock.time_of_day == Clock::MORNING)
    awake = [[3.0, 0.0], [0.0, 6.0], [9.0, 0.0]].map do |(across, up)|
      @mobs.clear
      @mobs << Monster.new(Mob::ZOMBIE, bx + 6.5 + across, SKY_Y - 1.0 + up, bz + 0.5, 9)
      @clock.time_of_day = 0.75
      use_bed(bx + 6, SKY_Y - 1, bz)
      @clock.time_of_day == 0.75
    end
    @mobs.clear
    check("a zombie 3 blocks from a bed keeps the player awake, but not 6 blocks up or 9 blocks away", awake == [true, false, false])
    set_block(bx + 6, SKY_Y - 1, bz, Block::AIR)
    @clock.time_of_day = 0.3
    check("sneaking stops at an edge", @player.y > SKY_Y - 1.1 && @player.z < bz + 1.4)
    @player.controls.hold(1.0, 0.0, jump: false, sneak: false, sprint: false)
    120.times { @player.update(@world, 1.0 / 60.0) }
    check("walking without sneaking falls off", @player.y < SKY_Y - 2.0)
    check("a sneaking player's eyes are lower, and come back up", low && (@player.eye_y - @player.y - Player::EYE).abs < 0.01)
  end

  # A jump against the shore of a pool 2 deep lifts the player out of the
  # water onto the shore.
  def test_swim_out
    wx = @spawn_x.floor + 20
    wz = @spawn_z.floor + 20
    (-1..3).each do |i|
      (-2..2).each do |k|
        set_block(wx + i, SKY_Y - 2, wz + k, Block::STONE)
        (SKY_Y - 1..SKY_Y + 4).each { |y| set_block(wx + i, y, wz + k, Block::AIR) }
      end
    end
    set_block(wx, SKY_Y - 1, wz, Block::WATER)
    set_block(wx, SKY_Y, wz, Block::WATER)
    set_block(wx + 1, SKY_Y - 1, wz, Block::WATER)
    set_block(wx + 1, SKY_Y, wz, Block::WATER)
    set_block(wx + 2, SKY_Y - 1, wz, Block::STONE)
    set_block(wx + 2, SKY_Y, wz, Block::STONE)
    @fluids.clear
    @player.move_to(wx + 0.5, SKY_Y - 1.0, wz + 0.5)
    @player.yaw = 1.5708
    @player.flying = false
    @player.on_ground = true
    # The shore is one block wide, so the player stands on it only for a while.
    out = false
    240.times do
      @player.controls.hold(1.0, 0.0, jump: true, sneak: false, sprint: false)
      @player.update(@world, 1.0 / 60.0)
      out = true if @player.on_ground && @player.y >= SKY_Y + 1.0 && @player.x + Player::HALF > wx + 2.0
    end
    check("a jump against the shore lifts the player out of the water", out)
  end

  # A door does not stand on a door, and it does not close on a mob.
  def test_door_rules
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 56
    y = @world.height_at(x, z)
    set_block(x, y - 1, z, Block::STONE)
    set_block(x, y, z, Block.door_id(0, false, false))
    set_block(x, y + 1, z, Block.door_id(0, true, false))
    stacked = @world.door_fits?(x, y + 2, z)
    toggle_door(x, y, z)
    @mobs.clear
    @mobs << Monster.new(Mob::ZOMBIE, x + 0.5, y.to_f, z + 0.5, 3)
    toggle_door(x, y, z)
    open = Block.door_open?(@world.get(x, y, z))
    @mobs.clear
    set_block(x, y, z, Block::AIR)
    check("a door does not stand on a door or close on a mob", !stacked && open)
  end

  # A door is a thin board on one edge of its cell. The player walks into the
  # cell up to the board of a closed door, and through an open door.
  def test_door_board
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 62
    y = @world.height_at(x, z) + 3
    [-1, 0, 1, 2].each do |dz|
      set_block(x, y - 1, z + dz, Block::STONE)
      set_block(x, y, z + dz, Block::AIR)
      set_block(x, y + 1, z + dz, Block::AIR)
    end
    # The closed door faces -z, so its board is on the -z edge of the cell.
    set_block(x, y, z + 1, Block.door_id(3, false, false))
    set_block(x, y + 1, z + 1, Block.door_id(3, true, false))
    @player.x = x + 0.5
    @player.y = y.to_f
    @player.z = z - 0.5
    @player.move(@world, 0.0, 0.0, 0.6)
    @player.move(@world, 0.0, 0.0, 0.6)
    stops = (@player.z - (z + 1 - Player::HALF - 0.001)).abs < 0.0001
    # The board of a closed door that faces +z is on the far edge of its cell.
    set_block(x, y, z + 1, Block.door_id(2, false, false))
    set_block(x, y + 1, z + 1, Block.door_id(2, true, false))
    @player.z = z + 0.5
    @player.move(@world, 0.0, 0.0, 0.6)
    @player.move(@world, 0.0, 0.0, 0.6)
    inside = (@player.z - (z + 1 + 0.8125 - Player::HALF - 0.001)).abs < 0.0001
    toggle_door(x, y, z + 1)
    @player.z = z + 0.5
    4.times { @player.move(@world, 0.0, 0.0, 0.6) }
    through = @player.z > z + 2.5
    set_block(x, y, z + 1, Block::AIR)
    check("a door stops the player at its board, and an open door lets the player through", stops && inside && through)
  end

  # A door does not open onto the player or a mob. Else the body is inside
  # its board and climbs out to the top of the column.
  def test_door_swing
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 68
    y = @world.height_at(x, z) + 3
    set_block(x, y - 1, z, Block::STONE)
    set_block(x, y + 2, z, Block::DIRT)
    # The closed door faces +x, so its board is on the +x edge of the cell,
    # and the open board is on the +z edge.
    set_block(x, y, z, Block.door_id(0, false, false))
    set_block(x, y + 1, z, Block.door_id(0, true, false))
    @player.move_to(x + 0.5, y.to_f, z + 0.6)
    @player.flying = false
    toggle_door(x, y, z)
    closed = !Block.door_open?(@world.get(x, y, z))
    10.times { @player.move(@world, 0.0, 0.0, 0.0) }
    stays = @player.y == y.to_f
    @player.move_to(x + 0.5, y.to_f, z - 1.5)
    @mobs.clear
    @mobs << Monster.new(Mob::ZOMBIE, x + 0.5, y.to_f, z + 0.6, 3)
    toggle_door(x, y, z)
    mob_closed = !Block.door_open?(@world.get(x, y, z))
    @mobs.clear
    set_block(x, y, z, Block::AIR)
    set_block(x, y + 2, z, Block::AIR)
    check("a door does not open onto the player or a mob", closed && stays && mob_closed)
  end

  # An item in a chunk that is not loaded waits there.
  def test_far_items
    @items.clear
    drop_item(Block::DIRT, 1, @player.x + 3000.0, 60.0, @player.z, 0.0, 0.0, 0.0, 0.0)
    run_items(6.0)
    check("an item in a chunk that is not loaded waits there", @items.size == 1 && @items[0].y == 60.0 && @items[0].age == 0.0)
    @items.clear
  end

  # A door opens and closes as a whole and goes as a whole. Smelting needs
  # the screen of a furnace. A sapling grows into a tree.
  def test_door_furnace_sapling
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 50
    y = @world.height_at(x, z)
    set_block(x, y - 1, z, Block::GRASS)
    set_block(x, y, z, Block.door_id(0, false, false))
    set_block(x, y + 1, z, Block.door_id(0, true, false))
    toggle_door(x, y + 1, z)
    opened = @world.get(x, y, z) == Block.door_id(0, false, true) && @world.get(x, y + 1, z) == Block.door_id(0, true, true)
    toggle_door(x, y, z)
    closed = @world.get(x, y, z) == Block.door_id(0, false, false) && @world.get(x, y + 1, z) == Block.door_id(0, true, false)
    set_block(x, y, z, Block::AIR)
    check("a door opens and closes as a whole, and breaks as a whole", opened && closed && @world.get(x, y + 1, z) == Block::AIR)
    # Each lower half takes its upper half: the closed door, then the open door.
    unheld = [Block.door_id(0, false, false), Block.door_id(0, false, true)].all? do |lower|
      @items.clear
      set_block(x, y - 1, z, Block::GRASS)
      set_block(x, y, z, lower)
      set_block(x, y + 1, z, Block.door_id(0, true, Block.door_open?(lower)))
      set_block(x, y - 1, z, Block::AIR)
      @world.get(x, y, z) == Block::AIR && @world.get(x, y + 1, z) == Block::AIR && ground_count(Block::DOOR) == 1
    end
    @items.clear
    set_block(x, y - 1, z, Block::GRASS)
    check("a closed or an open door breaks and drops once when the block under it goes", unheld)
    @player.x = x + 0.5
    @player.y = y.to_f
    @player.z = z + 3.5
    @inv.clear
    9.times { @inv.add(Block::IRON) }
    @inv.add(Block::COAL)
    2.times { @inv.add(Block::OAK_PLANKS) }
    smelt = recipe_for(Block::IRON_INGOT)
    craft_recipe(smelt)
    far = @inv.total(Block::IRON) == 9
    check("smelting needs a furnace", far)
    set_block(x + 2, y, z + 3, Block::FURNACE)
    open_station(x + 2, y, z + 3, Recipe::AT_FURNACE)
    @furnaces.clear
    f = open_furnace
    slots = f.slots
    # A Shift-click sends the iron ore to the input and the planks to the
    # fuel. An item takes 10 seconds.
    quick_move_slot(0)
    quick_move_slot(2)
    update_furnaces(10.0)
    one = slots.block(Furnace::OUTPUT) == Block::IRON_INGOT && slots.count(Furnace::OUTPUT) == 1 && slots.count(Furnace::INPUT) == 8 &&
          slots.count(Furnace::FUEL) == 1 && f.burn == 101 && @inv.total(Block::COAL) == 1
    lit = @world.get(x + 2, y, z + 3) == Block.furnace_id(0, true)
    # 2 planks burn for 600 ticks: 3 items.
    update_furnaces(30.0)
    two = slots.count(Furnace::OUTPUT) == 3 && slots.count(Furnace::INPUT) == 6 && slots.empty?(Furnace::FUEL) && !f.lit?
    dark = @world.get(x + 2, y, z + 3) == Block::FURNACE
    check("a furnace smelts an item in 10 seconds, and 2 planks smelt 3 items", one && two)
    check("a furnace with heat is lit, and a furnace with none is not", dark && lit)
    # A plank runs out 100 ticks into the second item. Then the progress goes
    # back 2 ticks for each tick, and new fuel continues from there.
    @held.set(0, Block::OAK_PLANKS, 1)
    click_furnace(Furnace::FUEL, true)
    update_furnaces(15.0)
    update_furnaces(1.0)
    cooled = slots.count(Furnace::OUTPUT) == 4 && f.progress == 60 && !f.lit?
    @held.set(0, Block::OAK_PLANKS, 1)
    click_furnace(Furnace::FUEL, true)
    update_furnaces(7.0)
    resumed = slots.count(Furnace::OUTPUT) == 5 && f.progress == 0
    check("the progress goes back while a furnace is out, and new fuel continues it", cooled && resumed)
    # The burning plank burns to its end, but no new fuel burns without
    # something to smelt or room for the result.
    slots.move_stack(Furnace::OUTPUT, @inv, 0...INV)
    slots.move_stack(Furnace::INPUT, @inv, 0...INV)
    slots.set(Furnace::FUEL, Block::OAK_PLANKS, 2)
    update_furnaces(10.0)
    no_input = slots.count(Furnace::FUEL) == 2 && !f.lit? && @inv.total(Block::IRON_INGOT) == 5 && @inv.total(Block::IRON) == 4
    slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Slots::STACK)
    slots.set(Furnace::INPUT, Block::IRON, 1)
    update_furnaces(10.0)
    full = slots.count(Furnace::FUEL) == 2 && slots.count(Furnace::INPUT) == 1 && !f.lit?
    check("a furnace burns no new fuel without something to smelt or room for the result", no_input && full)
    # A smelting recipe puts its ingredient into the input slot.
    slots.set(Furnace::OUTPUT, Block::AIR, 0)
    slots.set(Furnace::INPUT, Block::AIR, 0)
    craft_recipe(smelt)
    first = slots.count(Furnace::INPUT) == 1 && @inv.total(Block::IRON) == 3
    craft_recipe(smelt, CRAFT_ALL)
    rest = slots.count(Furnace::INPUT) == 4 && @inv.total(Block::IRON) == 0
    @inv.add(Block::SAND)
    craft_recipe(recipe_for(Block::GLASS))
    other = @inv.total(Block::SAND) == 1 && @message == "THE FURNACE HOLDS IRON ORE"
    check("a smelting recipe puts its ingredient into the furnace", first && rest && other)
    @held.set(0, Block::IRON_INGOT, 1)
    click_furnace(Furnace::FUEL, true)
    not_fuel = @held.count(0) == 1 && slots.count(Furnace::FUEL) == 2 && @message == "NOT A FUEL"
    @held.set(0, Block::DIRT, 1)
    click_furnace(Furnace::INPUT, true)
    not_smelted = @held.block(0) == Block::DIRT && slots.block(Furnace::INPUT) == Block::IRON && @message == "THE FURNACE DOES NOT SMELT THAT"
    click_furnace(Furnace::OUTPUT, true)
    no_output = @held.block(0) == Block::DIRT && slots.empty?(Furnace::OUTPUT)
    @held.clear
    survival = @survival
    @survival = true
    @items.clear
    furnaces = @furnaces.size
    set_block(x + 2, y, z + 3, Block::AIR)
    dropped = ground_count(Block::IRON) == 4 && ground_count(Block::OAK_PLANKS) == 2 && @furnaces.size == furnaces - 1
    @items.clear
    @survival = survival
    toggle_inventory
    check("the furnace slots take only what fits them, and a broken furnace drops what it holds", not_fuel && not_smelted && no_output && dropped)
    # A log smelts into coal, and coal burns for 1600 ticks.
    set_block(x + 2, y, z + 3, Block::FURNACE)
    open_station(x + 2, y, z + 3, Recipe::AT_FURNACE)
    @furnaces.clear
    f = open_furnace
    f.slots.set(Furnace::INPUT, Block::OAK_LOG, 1)
    f.slots.set(Furnace::FUEL, Block::COAL, 1)
    update_furnaces(10.0)
    coal = f.slots.block(Furnace::OUTPUT) == Block::COAL && f.slots.count(Furnace::OUTPUT) == 1 && f.slots.empty?(Furnace::FUEL) && f.burn > 1300
    toggle_inventory
    set_block(x + 2, y, z + 3, Block::AIR)
    check("a log smelts into coal, coal burns for 1600 ticks, and coal ore drops coal", coal && Block::DROPS[Block::COAL_ORE] == Block::COAL)
    set_block(x, y, z, Block::OAK_SAPLING)
    # The crop stands out of reach of the tree's leaves, on top of its column.
    cy = @world.height_at(x + 4, z)
    set_block(x + 4, cy - 1, z, Block::DIRT)
    set_block(x + 4, cy, z, Block::SEEDS)
    grow_plants(1200.0)
    check("a sapling grows into a tree", @world.get(x, y, z) == Block::OAK_LOG && @world.get(x, y + 3, z) == Block::OAK_LOG)
    sx = x - 10
    sy = @world.height_at(sx, z)
    plan = Array.new(0, 0)
    @plants.grow_tree(sx, sy, z, Block::SPRUCE_WOOD, plan)
    kinds = (0...plan.size / 4).map { |i| plan[i * 4 + 3] }
    spruce = kinds.include?(Block::SPRUCE_LOG) && kinds.include?(Block::SPRUCE_LEAVES) &&
             kinds.all? { |block| block == Block::SPRUCE_LOG || block == Block::SPRUCE_LEAVES || block == Block::DIRT }
    set_block(sx, sy + 2, z, Block::STONE)
    plan.clear
    @plants.grow_tree(sx, sy, z, Block::SPRUCE_WOOD, plan)
    blocked = plan.empty?
    set_block(sx, sy + 2, z, Block::AIR)
    check("a spruce sapling grows a spruce, and a block in the way of its trunk stops it", spruce && blocked)
    check("seeds grow into ripe wheat", @world.get(x + 4, cy, z) == Block::WHEAT_RIPE)
    set_block(x + 4, cy, z, Block::AIR)
  end

  # A bed takes two blocks along the view, needs room for both, and breaks
  # as a whole.
  def test_bed
    x = @spawn_x.floor + 20
    z = @spawn_z.floor - 70
    g = @world.height_at(x, z) + 2
    fill_box(x - 3, g - 1, z - 2, x + 3, g - 1, z + 2, Block::STONE)
    fill_box(x - 3, g, z - 2, x + 3, g + 2, z + 2, Block::AIR)
    survival = @survival
    @survival = true
    @inv.clear
    @inv.add(Block::BED)
    @slot = 0
    @player.x = x - 1.5
    @player.y = g.to_f
    @player.z = z + 0.5
    @player.yaw = Math::PI / 2.0
    @player.pitch = -Math.atan(Player::EYE / 2.0)
    set_block(x + 1, g, z, Block::STONE)
    @target_block.trace(@world, @player)
    place
    blocked = @world.get(x, g, z) == Block::AIR && @inv.count(0) == 1
    set_block(x + 1, g, z, Block::AIR)
    @target_block.trace(@world, @player)
    place
    two = @world.get(x, g, z) == Block.bed_id(1, false) && @world.get(x + 1, g, z) == Block.bed_id(0, true) && @inv.empty?(0)
    set_block(x + 1, g, z, Block::AIR)
    gone = @world.get(x, g, z) == Block::AIR
    @inv.clear
    @inv.add(Block::FURNACE)
    @target_block.trace(@world, @player)
    place
    furnace = @world.get(x, g, z)
    set_block(x, g, z, Block::AIR)
    @inv.clear
    @inv.add(Block::DOOR)
    @target_block.trace(@world, @player)
    place
    door = @world.get(x, g, z) == Block.door_id(1, false, false) && @world.get(x, g + 1, z) == Block.door_id(1, true, false)
    set_block(x, g, z, Block::AIR)
    @survival = survival
    @inv.clear
    check("a bed takes two blocks along the view and breaks as a whole", blocked && two && gone)
    check("a furnace and a door turn their front to the player", furnace == Block.facing_id(Block::FURNACE, 1) && door)
  end

  # Each half of a bed and of a door takes the place of water and of tall
  # grass, as the block that a player places does.
  def test_place_cells
    x = @spawn_x.floor + 20
    z = @spawn_z.floor - 70
    g = @world.height_at(x, z) + 2
    fill_box(x - 3, g - 1, z - 2, x + 3, g - 1, z + 2, Block::STONE)
    survival = @survival
    @survival = true
    @player.x = x - 1.5
    @player.y = g.to_f
    @player.z = z + 0.5
    @player.yaw = Math::PI / 2.0
    @player.pitch = -Math.atan(Player::EYE / 2.0)
    placed = [Block::WATER, Block::TALL_GRASS].map do |cell|
      bed = place_with_cell(Block::BED, x + 1, g, z, cell, x, g, z) == Block.bed_id(1, false)
      door = place_with_cell(Block::DOOR, x, g + 1, z, cell, x, g, z) == Block.door_id(1, false, false)
      bed && door
    end
    @fluids.clear
    @survival = survival
    @inv.clear
    check("each half of a bed and of a door takes the place of water and of tall grass", placed == [true, true])
  end

  # Puts cell at cx, cy, cz, places block from the hand, and gives the block
  # that it leaves at x, y, z. The cells of the test go back to air.
  def place_with_cell(block, cx, cy, cz, cell, x, y, z)
    fill_box(x - 1, y, z - 1, x + 2, y + 2, z + 1, Block::AIR)
    @world.set(cx, cy, cz, cell)
    @inv.clear
    @inv.add(block)
    @slot = 0
    @target_block.trace(@world, @player)
    place
    left = @world.get(x, y, z)
    fill_box(x - 1, y, z - 1, x + 2, y + 2, z + 1, Block::AIR)
    left
  end

  # A chest placed next to a chest that faces the same way joins it into a
  # large chest of 54 slots. When one half breaks, it drops what it holds,
  # and the other half is a chest again with its own contents.
  def test_large_chest
    x = @spawn_x.floor + 20
    z = @spawn_z.floor - 80
    g = @world.height_at(x, z) + 2
    fill_box(x - 3, g - 1, z - 2, x + 3, g - 1, z + 3, Block::STONE)
    fill_box(x - 3, g, z - 2, x + 3, g + 2, z + 3, Block::AIR)
    survival = @survival
    @survival = true
    @items.clear
    @inv.clear
    @inv.set(0, Block::CHEST, 2)
    @slot = 0
    @player.x = x - 1.5
    @player.y = g.to_f
    @player.yaw = Math::PI / 2.0
    @player.pitch = -Math.atan(Player::EYE / 2.0)
    # The player looks along +x, so the chest on the left is at -z.
    [z, z + 1].each do |cz|
      @player.z = cz + 0.5
      @target_block.trace(@world, @player)
      place
    end
    left = @world.get(x, g, z)
    right = @world.get(x, g, z + 1)
    check("two chests side by side join into a large chest", Block.chest_left?(left) && Block.chest_right?(right) &&
          Block::FACING[left] == 1 && Block::FACING[right] == 1)
    open_chest(x, g, z + 1)
    INV.times { |i| @inv.set(i, Block::DIRT, 64) }
    INV.times { |i| quick_move_slot(i) }
    check("a large chest takes more than 27 stacks", current_screen.inventory? && @chests.current.cells == Chest::SLOTS * 2 && @inv.total(Block::DIRT) == 0)
    toggle_inventory
    set_block(x, g, z + 1, Block::AIR)
    kept = @chests.remove_at(World.key(x, g, z))
    check("a broken half of a large chest drops its half, and the other half is a chest",
          ground_count(Block::DIRT) == 9 * 64 && @world.get(x, g, z) == Block.facing_id(Block::CHEST, 1) &&
          !kept.nil? && kept.total(Block::DIRT) == Chest::SLOTS * 64)
    @items.clear
    @inv.clear
    # A large chest that loses a half while it is open closes.
    @player.z = z + 1.5
    @target_block.trace(@world, @player)
    @inv.set(0, Block::CHEST, 1)
    place
    open_chest(x, g, z)
    set_block(x, g, z + 1, Block::AIR)
    check("a large chest closes when a half breaks while it is open", !current_screen.inventory? && !@chests.open?)
    set_block(x, g, z, Block::AIR)
    @items.clear
    @inv.clear
    @survival = survival
  end

  # The view ray hits a plant only in its small box, and goes on past it.
  def test_plant_box
    x = @spawn_x.floor + 30
    z = @spawn_z.floor - 60
    g = @world.height_at(x, z) + 2
    (-2..2).each do |dx|
      set_block(x + dx, g, z, Block::STONE)
      set_block(x + dx, g + 1, z, dx == 2 ? Block::STONE : Block::AIR)
      set_block(x + dx, g + 2, z, Block::AIR)
    end
    set_block(x, g + 1, z, Block::ROSE)
    p = Player.new(x - 1.5, g + 1.5 - Player::EYE, z + 0.1)
    p.yaw = Math::PI / 2.0
    target = BlockTarget.new
    target.trace(@world, p)
    past = target.hit? && target.x == x + 2
    p.z = z + 0.5
    target.trace(@world, p)
    on = target.hit? && target.x == x
    set_block(x, g + 1, z, Block::AIR)
    check("the view ray hits a flower only in its small box", past && on)
  end

  # An empty bucket takes a water or lava source that the player looks at,
  # and a full bucket puts the source back.
  def test_buckets
    x = @spawn_x.floor + 40
    z = @spawn_z.floor - 50
    y = @world.height_at(x, z) + 3
    fill_box(x - 1, y - 2, z - 1, x + 1, y - 1, z + 1, Block::STONE)
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
      @target_block.trace(@world, @player)
      use_bucket
      took = @inv.block(0) == full && @world.get(x, y - 1, z) == Block::AIR
      @target_block.trace(@world, @player)
      use_bucket
      ok = false unless took && @inv.block(0) == Block::BUCKET && @world.get(x, y - 1, z) == fluid
      @inv.remove(Block::BUCKET, 1)
    end
    check("a bucket takes a water or lava source and puts it back", ok)
    # Two buckets from a stack of 16 fill two slots, as full buckets do
    # not stack.
    @inv.set(0, Block::BUCKET, 16)
    2.times do
      set_block(x, y - 1, z, Block::WATER)
      @target_block.trace(@world, @player)
      use_bucket
    end
    filled = @inv.count(0) == 14 && @inv.block(1) == Block::WATER_BUCKET && @inv.block(2) == Block::WATER_BUCKET &&
             @inv.count(1) == 1 && @inv.count(2) == 1
    set_block(x, y - 1, z, Block::STONE)
    # The player stands beside the rose, so the view ray passes it.
    @player.x = x + 0.05
    roses = [Block::WATER_BUCKET, Block::LAVA_BUCKET].map do |full|
      @items.clear
      set_block(x, y, z, Block::ROSE)
      @inv.clear
      @inv.add(full)
      @target_block.trace(@world, @player)
      use_bucket
      poured = @world.get(x, y, z) != Block::ROSE
      set_block(x, y, z, Block::AIR)
      poured ? ground_count(Block::ROSE) : -1
    end
    @player.x = x + 0.5
    @items.clear
    check("water from a bucket washes away a rose and it drops, and lava burns it", roses == [1, 0])
    was = @survival
    @survival = true
    @inv.clear
    run_chat("/give bucket 20")
    given = @inv.count(0) == 16 && @inv.count(1) == 4
    @inv.clear
    run_chat("/give milk_bucket 2")
    run_chat("/give bed 2")
    check("empty buckets stack to 16, and full buckets and beds do not stack",
          filled && given && @inv.count(1) == 1 && @inv.block(1) == Block::MILK_BUCKET &&
          @inv.count(3) == 1 && @inv.block(3) == Block::BED && !last_chat_error?)
    @survival = was
    @mobs.clear
    @mobs << Animal.new(Mob::COW, x + 0.5, y.to_f, z - 1.5, 5)
    @player.yaw = 0.0
    @player.pitch = -0.2
    @target_block.trace(@world, @player)
    find_targets
    @inv.clear
    @inv.add(Block::BUCKET)
    use_bucket
    milked = @inv.block(0) == Block::MILK_BUCKET && @inv.count(0) == 1
    # With no cow in view, the held button does not milk again. Unlike
    # food, milk needs no hunger.
    @mobs.clear
    @target_mob = -1
    was = @survival
    @survival = true
    @player.revive
    @player.vitals.give_hunger_effect
    @eat_time = -1.0
    34.times { right_button(0.05, true) }
    right_button(0.05, false)
    check("a bucket milks a cow, and the milk ends the Hunger effect", milked && !@player.vitals.hunger_effect? && @inv.block(0) == Block::BUCKET)
    @survival = was
    @player.revive
    @inv.clear
  end

  # Shears carve a pumpkin on the side in view and drop 4 seeds. A carved
  # pumpkin and a torch make a jack o'lantern, which lights its
  # surroundings. A ripe stem grows one pumpkin next to it.
  # Skeletons drop bones, a bone makes 3 bone meal, and bone meal grows a
  # crop, a pumpkin stem, a sapling, and plants on a grass block.
  def test_bone_meal
    bone_meal = @recipe_book.recipe(recipe_for(Block::BONE_MEAL))
    recipe = bone_meal.need == "1 BONE" && bone_meal.result_count == 3 && bone_meal.where == Recipe::BY_HAND
    # Each skeleton drops 0 to 2, so 10 skeletons drop none 1 time in 59049.
    @items.clear
    @mobs.clear
    10.times do |i|
      skeleton = Monster.new(Mob::SKELETON, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z + i, 3)
      skeleton.hp = 0.0
      skeleton.by_player = true
      @mobs << skeleton
    end
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::BONE)
    check("skeletons drop 0 to 2 bones each, and a bone makes 3 bone meal", recipe && n >= 1 && n <= 20)
    @items.clear
    @mobs.clear
    # A stone floor high in the air, with a field of grass 9 blocks wide in
    # the middle, and dirt for the crops.
    x = @spawn_x.floor - 40
    z = @spawn_z.floor + 40
    g = SKY_Y - 20
    fill_box(x - 10, g - 1, z - 10, x + 10, g, z + 10, Block::STONE)
    fill_box(x - 4, g, z - 4, x + 4, g, z + 4, Block::GRASS)
    fill_box(x - 10, g + 1, z - 10, x + 10, g + 8, z + 10, Block::AIR)
    # Bone meal adds 2 to 5 of the 8 ages of a Minecraft crop or stem. Wheat
    # has 3 steps of stage here, and a stem 2.
    wheat = [2, 3, 4, 5].map { |a| Plants.meal_stage(0, a, 3) } == [1, 1, 2, 2] && Plants.meal_stage(2, 5, 3) == 3
    stem = [2, 3, 4, 5].map { |a| Plants.meal_stage(0, a, 2) } == [1, 1, 1, 1]
    survival = @survival
    @survival = true
    @inv.set(5, Block::BONE_MEAL, 20)
    @slot = 5
    set_block(x + 7, g, z, Block::DIRT)
    set_block(x + 7, g + 1, z, Block::SEEDS)
    aim_down(x + 7, g + 1, z)
    use_bone_meal
    grew = @world.get(x + 7, g + 1, z) != Block::SEEDS && @inv.count(5) == 19
    2.times { use_bone_meal }
    ripe = @world.get(x + 7, g + 1, z) == Block::WHEAT_RIPE
    left = @inv.count(5)
    use_bone_meal
    check("bone meal grows a crop 1 or 2 stages, and ripe wheat does not spend it", wheat && grew && ripe && @inv.count(5) == left)
    set_block(x + 7, g, z + 2, Block::DIRT)
    set_block(x + 7, g + 1, z + 2, Block::PUMPKIN_SEEDS)
    aim_down(x + 7, g + 1, z + 2)
    seeds_left = @inv.count(5)
    use_bone_meal
    young = @world.get(x + 7, g + 1, z + 2) == Block::PUMPKIN_STEM
    use_bone_meal
    old = @world.get(x + 7, g + 1, z + 2) == Block::PUMPKIN_STEM_RIPE
    left = @inv.count(5)
    use_bone_meal
    check("bone meal grows a pumpkin stem 1 stage, and a ripe stem does not spend it",
          stem && young && old && @inv.count(5) == left && left == seeds_left - 2)
    # 45% of bone meal grows a sapling, so 10 tries fail 1 time in 400.
    set_block(x - 7, g, z, Block::DIRT)
    set_block(x - 7, g + 1, z, Block::OAK_SAPLING)
    aim_down(x - 7, g + 1, z)
    tries = 0
    while tries < 10 && @world.get(x - 7, g + 1, z) == Block::OAK_SAPLING
      use_bone_meal
      tries += 1
    end
    check("bone meal grows a sapling into a tree", @world.get(x - 7, g + 1, z) == Block::OAK_LOG && @inv.count(5) == left - tries)
    @inv.set(5, Block::BONE_MEAL, 20)
    # Bone meal on a grass block grows tall grass and some flowers on the
    # grass around it, and none on the stone. A flower is 1 plant in 8, so
    # the test counts the plants of 4 uses.
    aim_down(x, g, z)
    fewest = 1000
    flowers = 0
    on_stone = 0
    spent = true
    4.times do
      before = @inv.count(5)
      use_bone_meal
      spent &&= @inv.count(5) == before - 1
      plants = 0
      (-10..10).each do |dx|
        (-10..10).each do |dz|
          block = @world.get(x + dx, g + 1, z + dz)
          if block == Block::TALL_GRASS || block == Block::ROSE || block == Block::DANDELION
            if dx.abs <= 4 && dz.abs <= 4
              plants += 1
              flowers += 1 if block != Block::TALL_GRASS
            else
              on_stone += 1
            end
          end
          set_block(x + dx, g + 1, z + dz, Block::AIR) if Block.plant?(block) && block != Block::OAK_SAPLING && !Block.growing?(block) && block != Block::WHEAT_RIPE && block != Block::PUMPKIN_STEM_RIPE
        end
      end
      fewest = plants if plants < fewest
    end
    # With a plant on it, the grass block takes no bone meal.
    set_block(x, g + 1, z, Block::TALL_GRASS)
    before = @inv.count(5)
    use_bone_meal
    check("bone meal on grass grows tall grass and flowers around it, only on grass",
          fewest >= 15 && flowers >= 1 && on_stone == 0 && spent && @inv.count(5) == before)
    @inv.set(5, Block::AIR, 0)
    @survival = survival
    fill_box(x - 10, g - 1, z - 10, x + 10, g + 8, z + 10, Block::AIR)
  end

  # Puts the player 2 blocks above the cell x, y, z, looking straight down
  # at it.
  def aim_down(x, y, z)
    @player.x = x + 0.5
    @player.y = y + 2.0
    @player.z = z + 0.5
    @player.pitch = -Math::PI / 2.0 + 0.001
    @target_block.trace(@world, @player)
  end

  def test_pumpkins
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 60
    y = SKY_Y - 20
    fill_box(bx - 3, y, bz - 3, bx + 3, y, bz + 3, Block::GRASS)
    set_block(bx, y + 1, bz, Block::STONE)
    set_block(bx, y + 2, bz, Block::PUMPKIN)
    survival = @survival
    keep_pose
    @survival = true
    @inv.clear
    @inv.add(Block::SHEARS)
    @slot = 0
    @items.clear
    @player.x = bx - 1.5
    @player.y = y + 1.0
    @player.z = bz + 0.5
    @player.yaw = 1.5708
    @player.pitch = 0.0
    @player.flying = true
    @action_cooldown = 0.0
    @target_block.trace(@world, @player)
    right_button(0.05, true)
    seeds = @items.size == 1 && @items[0].block == Block::PUMPKIN_SEEDS && @items[0].count == 4
    side = @world.get(bx, y + 2, bz) == Block.facing_id(Block::CARVED_PUMPKIN, 1)
    worn = @inv.count(0) == Block.uses(Block::SHEARS) - 1
    # From above, the face turns to the player.
    set_block(bx, y + 2, bz, Block::PUMPKIN)
    @player.x = bx + 0.5
    @player.y = y + 3.5
    @player.pitch = -1.55
    @action_cooldown = 0.0
    @target_block.trace(@world, @player)
    right_button(0.05, true)
    top = @world.get(bx, y + 2, bz) == Block.facing_id(Block::CARVED_PUMPKIN, look_direction ^ 1)
    @items.clear
    @action_cooldown = 0.0
    check("shears carve a pumpkin on the side in view, and it drops 4 seeds", seeds && side && worn && top)
    # At a slant, the face goes on the side that the view ray hits, not on
    # the side that the player looks most toward.
    slants = [[-0.3, -0.6, 2.7616, 1.0], [-0.6, -0.3, 1.9513, 3.0], [1.3, 1.6, -0.3803, 0.0], [1.6, 1.3, -1.1903, 2.0]]
    slanted = slants.all? do |s|
      set_block(bx, y + 2, bz, Block::PUMPKIN)
      @player.x = bx + s[0].to_f
      @player.y = y + 1.0
      @player.z = bz + s[1].to_f
      @player.yaw = s[2].to_f
      @player.pitch = 0.0
      @action_cooldown = 0.0
      @target_block.trace(@world, @player)
      right_button(0.05, true)
      @world.get(bx, y + 2, bz) == Block.facing_id(Block::CARVED_PUMPKIN, s[3].to_i)
    end
    set_block(bx, y + 2, bz, Block::PUMPKIN)
    @player.x = bx - 1.5
    @player.z = bz + 0.5
    @player.yaw = 1.5708
    @inv.set(0, Block::AIR, 0)
    @action_cooldown = 0.0
    @target_block.trace(@world, @player)
    right_button(0.05, true)
    by_hand = @world.get(bx, y + 2, bz) == Block::PUMPKIN
    set_block(bx, y + 2, bz, Block::STONE)
    @inv.add(Block::SHEARS)
    @items.clear
    @action_cooldown = 0.0
    @target_block.trace(@world, @player)
    right_button(0.05, true)
    on_stone = @world.get(bx, y + 2, bz) == Block::STONE && @items.empty?
    @items.clear
    @action_cooldown = 0.0
    check("only shears carve, only a pumpkin, and the face goes on the side that the view ray hits", slanted && by_hand && on_stone)

    @inv.clear
    @inv.add(Block::CARVED_PUMPKIN)
    jack = recipe_for(Block::JACK_O_LANTERN)
    craft_recipe(jack)
    refused = @inv.total(Block::JACK_O_LANTERN) == 0 && @inv.total(Block::CARVED_PUMPKIN) == 1
    @inv.add(Block::TORCH)
    @inv.add(Block::TORCH)
    craft_recipe(jack)
    made = @inv.total(Block::JACK_O_LANTERN) == 1 && @inv.total(Block::CARVED_PUMPKIN) == 0 && @inv.total(Block::TORCH) == 1
    check("a carved pumpkin and a torch make a jack o'lantern, and one without the other does not", refused && made)
    @inv.clear
    @inv.add(Block::CARVED_PUMPKIN)
    @inv.add(Block::CARVED_PUMPKIN)
    3.times { @inv.add(Block::TORCH) }
    craft_recipe(jack, CRAFT_ALL)
    all = @inv.total(Block::JACK_O_LANTERN) == 2 && @inv.total(Block::CARVED_PUMPKIN) == 0 && @inv.total(Block::TORCH) == 1
    @inv.clear
    @inv.add(Block::IRON_INGOT)
    craft_recipe(recipe_for(Block::SHEARS))
    short = @inv.total(Block::SHEARS) == 0 && @inv.total(Block::IRON_INGOT) == 1
    text = @recipe_book.recipe(jack).need == "1 CARVED PUMPKIN + 1 TORCH" && @recipe_book.recipe(recipe_for(Block::SHEARS)).need == "2 IRON INGOT"
    check("a recipe with two ingredients takes each of them for each result, and names both", all && short && text)
    @inv.clear
    @survival = survival
    restore_pose

    set_block(bx, y + 2, bz, Block::AIR)
    set_block(bx, y + 1, bz, Block.facing_id(Block::JACK_O_LANTERN, 2))
    torches = @world.chunk_torches[World.slot(bx >> 4, bz >> 4)]
    listed = (0...torches.size / 3).any? { |i| torches[i * 3] == bx && torches[i * 3 + 1] == y + 1 && torches[i * 3 + 2] == bz }
    mesher = Mesher.new(@world)
    mesher.build(bx / CHUNK, bz / CHUNK)
    near = mesher.torch_light(bx + 1, y + 1, bz) == 14 && mesher.torch_light(bx + 15, y + 1, bz) == 0 &&
           mesher.torch_light(bx + 14, y + 1, bz) == 1
    glow = true
    faces = 0
    (0...mesher.opaque.size).step(2) do |i|
      w0 = mesher.opaque[i]
      if Mesher.face_x(w0) == (bx & LMASK) && Mesher.face_y(w0) == y + 1 && Mesher.face_z(w0) == (bz & LMASK)
        faces += 1
        glow = false if Mesher.face_light(mesher.opaque[i + 1]) != Mesher::LIGHT_MAX
      end
    end
    lit = @light.level(bx + 3, y + 1, bz, 0, true, 0) == -1 && @light.level(bx + 14, y + 1, bz, 0, true, 0) == -1 &&
          @light.level(bx + 15, y + 1, bz, 0, true, 0) >= 0
    set_block(bx - 1, y + 1, bz, Block::TORCH)
    @world.find_torches(bx >> 4, bz >> 4, WY)
    torches = @world.chunk_torches[World.slot(bx >> 4, bz >> 4)]
    found = (0...torches.size / 3).count { |i| torches[i * 3 + 1] == y + 1 && torches[i * 3 + 2] == bz && (torches[i * 3] == bx || torches[i * 3] == bx - 1) }
    listed &&= found == 2
    set_block(bx - 1, y + 1, bz, Block::AIR)
    check("a jack o'lantern glows and lights its surroundings, so no monster spawns near it", listed && near && glow && faces > 0 && lit)
    set_block(bx, y + 1, bz, Block::AIR)

    set_block(bx, y + 1, bz, Block::PUMPKIN_STEM_RIPE)
    grown = 0
    40.times do
      grow_pumpkin_now(bx, y + 1, bz)
      grown = (0...4).count { |d| @world.get(bx + Block::DIR_DX[d], y + 1, bz + Block::DIR_DZ[d]) == Block::PUMPKIN }
    end
    # With stone on three sides, the pumpkin can only go on the fourth, and
    # only over dirt or grass.
    (0...4).each { |d| set_block(bx + Block::DIR_DX[d], y + 1, bz + Block::DIR_DZ[d], d == 1 ? Block::AIR : Block::STONE) }
    40.times { grow_pumpkin_now(bx, y + 1, bz) }
    on_grass = @world.get(bx - 1, y + 1, bz) == Block::PUMPKIN
    set_block(bx - 1, y + 1, bz, Block::AIR)
    set_block(bx - 1, y, bz, Block::STONE)
    40.times { grow_pumpkin_now(bx, y + 1, bz) }
    on_stone = @world.get(bx - 1, y + 1, bz) == Block::AIR
    on_dirt = [Block::DIRT, Block::SNOW_GRASS].all? do |ground|
      set_block(bx - 1, y + 1, bz, Block::AIR)
      set_block(bx - 1, y, bz, ground)
      40.times { grow_pumpkin_now(bx, y + 1, bz) }
      @world.get(bx - 1, y + 1, bz) == Block::PUMPKIN
    end
    set_block(bx - 1, y, bz, Block::GRASS)
    check("a ripe stem grows one pumpkin next to it, only on a free side over dirt or grass", grown == 1 && on_grass && on_stone && on_dirt)
    check("pumpkin seeds and a young stem grow, and pumpkins sound like wood",
          Block.growing?(Block::PUMPKIN_SEEDS) && Block.growing?(Block::PUMPKIN_STEM) && !Block.growing?(Block::PUMPKIN_STEM_RIPE) &&
          !Block.growing?(Block::PUMPKIN) && material(Block::PUMPKIN) == M_WOOD && material(Block.facing_id(Block::JACK_O_LANTERN, 3)) == M_WOOD &&
          material(Block::PLACED_BIRCH_LEAVES) == M_LEAVES && material(Block::PUMPKIN_STEM) == M_LEAVES)
    # A plant draws its top texture, and an item in the hand, on the ground
    # or in a slot its side and front textures.
    check("pumpkin seeds look like seeds as an item and like a stem when planted",
          Block::TOP[Block::PUMPKIN_SEEDS] == Tex::PUMPKIN_STEM && Block::SIDE[Block::PUMPKIN_SEEDS] == Tex::PUMPKIN_SEEDS &&
          Block::FRONT[Block::PUMPKIN_SEEDS] == Tex::PUMPKIN_SEEDS)
    fill_box(bx - 3, y, bz - 3, bx + 3, y + 2, bz + 3, Block::AIR)
    @items.clear
  end

  # Seeds, saplings, flowers and tall grass go only on dirt, grass or snowy
  # grass. A torch still goes on any solid block.
  def test_seed_soil
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 70
    y = SKY_Y - 20
    keep_pose
    survival = @survival
    held = @hotbar[0]
    @survival = false
    @slot = 0
    @player.x = bx + 0.5
    @player.y = y + 2.0
    @player.z = bz + 0.5
    @player.pitch = -1.55
    @player.flying = true
    # Stone under the ground block keeps the sand from falling.
    set_block(bx, y - 1, bz, Block::STONE)
    grounds = [Block::DIRT, Block::GRASS, Block::SNOW_GRASS, Block::STONE, Block::OAK_PLANKS, Block::SAND]
    plants = [Block::PUMPKIN_SEEDS, Block::SEEDS, Block::OAK_SAPLING, Block::SPRUCE_SAPLING, Block::BIRCH_SAPLING, Block::ROSE,
              Block::DANDELION, Block::TALL_GRASS, Block::TORCH]
    planted = plants.map do |plant|
      grounds.map do |ground|
        set_block(bx, y + 1, bz, Block::AIR)
        set_block(bx, y, bz, ground)
        @hotbar[0] = plant
        @target_block.trace(@world, @player)
        place
        @world.get(bx, y + 1, bz) == plant
      end
    end
    set_block(bx, y + 1, bz, Block::AIR)
    set_block(bx, y, bz, Block::AIR)
    set_block(bx, y - 1, bz, Block::AIR)
    @hotbar[0] = held
    @survival = survival
    restore_pose
    soil = (0...plants.size - 1).all? { |i| planted[i] == [true, true, true, false, false, false] }
    torch = planted[plants.size - 1].all?
    check("seeds, saplings, flowers and tall grass go only on dirt, grass or snowy grass, and a torch on any solid block", soil && torch)
  end

  # The view ray stops at a mob, so a right-click on a mob never acts on
  # the block behind it. A held click with shears on a sheep in front of a
  # pumpkin takes the wool once and does not carve the pumpkin. A click on
  # a sheared sheep in front of a chest does not open the chest.
  def test_mob_hides_block
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 100
    y = SKY_Y - 20
    fill_box(bx - 4, y + 1, bz - 3, bx + 5, y + 4, bz + 3, Block::AIR)
    fill_box(bx - 4, y, bz - 3, bx + 5, y, bz + 3, Block::STONE)
    set_block(bx + 2, y + 1, bz, Block::PUMPKIN)
    survival = @survival
    keep_pose
    @survival = true
    @inv.clear
    @inv.add(Block::SHEARS)
    @slot = 0
    @items.clear
    @mobs.clear
    sheep = Animal.new(Mob::SHEEP, bx + 0.5, y + 1.0, bz + 0.5, 7)
    @mobs << sheep
    @player.x = bx - 1.5
    @player.y = y + 1.0
    @player.z = bz + 0.5
    @player.flying = true
    @player.yaw = 1.5708
    @player.pitch = Math.atan2(0.5 - Player::EYE, 3.5)
    @action_cooldown = 0.0
    60.times do
      @action_cooldown -= 1.0 / 60.0
      @target_block.trace(@world, @player)
      find_targets
      right_button(1.0 / 60.0, true)
    end
    aimed = @target_mob == 0 && @target_block.hit? && @target_block.x == bx + 2
    check("held shears on a sheep in front of a pumpkin take the wool once and do not carve the pumpkin",
          aimed && sheep.sheared && @world.get(bx + 2, y + 1, bz) == Block::PUMPKIN && @inv.count(0) == Block.uses(Block::SHEARS) - 1)
    set_block(bx + 2, y + 1, bz, Block.facing_id(Block::CHEST, 1))
    @action_cooldown = 0.0
    @target_block.trace(@world, @player)
    find_targets
    right_button(1.0 / 60.0, true)
    check("a click on a sheared sheep in front of a chest does not open the chest", @target_mob == 0 && @target_block.hit? && !@chests.open?)
    set_block(bx + 2, y + 1, bz, Block::AIR)
    @chests.close
    show_screen(Screen::PLAYING)
    @mobs.clear
    @items.clear
    @inv.clear
    @survival = survival
    restore_pose
  end

  # Shears take 1 to 3 wool from a sheep without a hit, and a sheared sheep
  # grows its wool back when it eats grass.
  def test_shear_sheep
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 80
    y = SKY_Y - 20
    fill_box(bx - 2, y, bz - 2, bx + 2, y, bz + 2, Block::GRASS)
    survival = @survival
    @survival = true
    @inv.clear
    @inv.add(Block::SHEARS)
    @slot = 0
    @items.clear
    @mobs.clear
    sheep = Animal.new(Mob::SHEEP, bx + 0.5, y + 1.0, bz + 0.5, 7)
    @mobs << sheep
    @target_boat = -1
    @target_mob = 0
    @action_cooldown = 0.0
    right_button(0.05, true)
    wool = ground_count(Block::WOOL)
    sheared = sheep.sheared && sheep.hp == Mob::HP[Mob::SHEEP] && wool >= 1 && wool <= 3 &&
              @inv.count(0) == Block.uses(Block::SHEARS) - 1
    @action_cooldown = 0.0
    right_button(0.05, true)
    once = ground_count(Block::WOOL) == wool && @inv.count(0) == Block.uses(Block::SHEARS) - 1
    check("shears take 1 to 3 wool from a sheep without a hit, once, for 1 use", sheared && once)
    @items.clear
    # A grazing sheep stays bare until its bite near the end of the eating,
    # then the grass under it is dirt and its wool is back.
    sheep.start_graze
    40.times { update_mobs(1.0 / 60.0) }
    early = sheep.sheared && @world.get(bx, y, bz) == Block::GRASS && sheep.graze > 0.0
    (Animal::GRAZE_TIME * 60.0).to_i.times { update_mobs(1.0 / 60.0) }
    on_grass = !sheep.sheared && @world.get(bx, y, bz) == Block::DIRT
    # The tall grass in its cell goes before the grass block.
    sheep.sheared = true
    sheep.x = bx + 0.5
    sheep.z = bz + 0.5
    set_block(bx, y, bz, Block::GRASS)
    set_block(bx, y + 1, bz, Block::TALL_GRASS)
    sheep.grass_bite = true
    bite_grass(sheep)
    on_tall = !sheep.sheared && @world.get(bx, y + 1, bz) == Block::AIR && @world.get(bx, y, bz) == Block::GRASS
    sheep.sheared = true
    set_block(bx, y, bz, Block::STONE)
    sheep.grass_bite = true
    bite_grass(sheep)
    on_stone = sheep.sheared && !sheep.can_graze?(@world)
    check("a sheared sheep grows its wool back when its bite of grass ends, and grass turns to dirt",
          early && on_grass && on_tall && on_stone)
    # A hit makes the sheep panic: it stops eating before the bite, and it
    # does not start again while it panics. So a sheep sheared in creative
    # and then killed in survival stays bare and drops no wool.
    set_block(bx, y, bz, Block::GRASS)
    sheep.x = bx + 0.5
    sheep.z = bz + 0.5
    sheep.start_graze
    @player.x = bx + 0.5
    @player.y = y + 1.0
    @player.z = bz + 2.5
    @player.yaw = 0.0
    @player.pitch = -0.35
    @player.flying = false
    @survival = true
    @inv.clear
    @slot = 0
    @items.clear
    @target_block.trace(@world, @player)
    find_targets
    aimed = @target_mob == 0
    left_button(1.0 / 60.0, true, true)
    update_mobs(1.0 / 60.0)
    stopped = sheep.graze <= 0.0 && sheep.sheared && !sheep.can_graze?(@world)
    sheep.hp = 0.5
    sheep.by_player = true
    (Mob::IMMUNE * 60.0 + 2.0).to_i.times { update_mobs(1.0 / 60.0) }
    # The panicked sheep ran off. The player catches up with it and waits
    # for a full attack charge.
    sheep.x = bx + 0.5
    sheep.y = y + 1.0
    sheep.z = bz + 0.5
    @player.melee_attack.restart
    @player.melee_attack.advance(1.0)
    @target_block.trace(@world, @player)
    find_targets
    left_button(1.0 / 60.0, true, true)
    update_mobs(1.0 / 60.0)
    check("a hit stops a sheep from eating, so a sheared sheep killed while it grazes drops no wool",
          aimed && stopped && sheep.dying? && ground_count(Block::WOOL) == 0 && ground_count(Block::MUTTON) >= 1)
    @mobs.clear
    @inv.clear
    @survival = survival
    fill_box(bx - 2, y, bz - 2, bx + 2, y + 1, bz + 2, Block::AIR)
  end

  # An adult sheep on grass starts to eat about once each 50 seconds:
  # Animal::GRAZE_CHANCE is 10/500 each second. Each time that it is
  # done, the pen gets its grass back.
  def test_graze_rate
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 100
    y = SKY_Y - 20
    fill_box(bx - 3, y, bz - 3, bx + 3, y + 3, bz + 3, Block::STONE)
    fill_box(bx - 2, y + 1, bz - 2, bx + 2, y + 3, bz + 2, Block::AIR)
    fill_box(bx - 2, y, bz - 2, bx + 2, y, bz + 2, Block::GRASS)
    @mobs.clear
    sheep = Animal.new(Mob::SHEEP, bx + 0.5, y + 1.0, bz + 0.5, 7)
    @mobs << sheep
    grazes = 0
    60_000.times do
      eating = sheep.graze > 0.0
      update_mobs(0.05)
      grazes += 1 if !eating && sheep.graze > 0.0
      fill_box(bx - 2, y, bz - 2, bx + 2, y, bz + 2, Block::GRASS) if eating && sheep.graze <= 0.0
    end
    check("an adult sheep on grass starts to eat about once each 50 seconds", grazes >= 30 && grazes <= 90)
    @mobs.clear
  end

  # A baby sheep has wool that shears do not take. Each bite of grass
  # takes 1 minute off its growth time.
  def test_lambs
    bx = @spawn_x.floor + 50
    bz = @spawn_z.floor - 80
    y = SKY_Y - 20
    (-2..2).each { |dx| (-2..2).each { |dz| set_block(bx + dx, y, bz + dz, Block::GRASS) } }
    survival = @survival
    @survival = true
    @inv.clear
    @inv.add(Block::SHEARS)
    @slot = 0
    @items.clear
    @mobs.clear
    lamb = Animal.new(Mob::SHEEP, bx + 0.5, y + 1.0, bz + 0.5, 7)
    lamb.make_baby
    @mobs << lamb
    right_click_mob(lamb)
    check("shears take no wool from a baby sheep",
          @target_mob == 0 && !lamb.sheared && ground_count(Block::WOOL) == 0 && @inv.count(0) == Block.uses(Block::SHEARS))
    put_mob(lamb, bx + 0.5, y + 1.0, bz + 0.5)
    grow = lamb.grow_left
    lamb.grass_bite = true
    bite_grass(lamb)
    check("a bite of grass takes 1 minute off the growth time of a baby sheep",
          (lamb.grow_left - (grow - 60.0)).abs < 0.001 && @world.get(bx, y, bz) == Block::DIRT)
    @mobs.clear
    @inv.clear
    @items.clear
    @survival = survival
    (-2..2).each { |dx| (-2..2).each { |dz| (0..1).each { |dy| set_block(bx + dx, y + dy, bz + dz, Block::AIR) } } }
  end

  # The player stands 2 blocks south of the mob m, looks at its middle,
  # and presses the right button once with the selected item.
  def right_click_mob(m)
    @player.x = m.x.to_f
    @player.y = m.y.to_f
    @player.z = m.z.to_f + 2.0
    @player.yaw = 0.0
    @player.pitch = Math.atan2(m.y.to_f + m.tall * 0.5 - @player.eye_y.to_f, 2.0).to_f
    @player.flying = false
    @target_block.trace(@world, @player)
    @target_boat = -1
    find_targets
    @action_cooldown = 0.0
    right_button(0.05, true)
  end

  # A boat in view takes the right click: the player gets in once the
  # cooldown is over, and a click on the boat stops the eating and the
  # drawing of the bow.
  def test_right_click_boat
    @boats.clear
    @riding = -1
    @boats << Boat.new(Block::OAK_BOAT, @player.x.to_f + 1.0, @player.y.to_f, @player.z.to_f, 0.0)
    @target_boat = 0
    @eat_time = 0.5
    @draw_time = 0.5
    @action_cooldown = 0.1
    right_button(0.05, true)
    waited = !riding? && @eat_time < 0.0 && @draw_time < 0.0
    @action_cooldown = 0.0
    right_button(0.05, true)
    check("the right click gets the player in a boat in view after the cooldown", waited && @riding == 0)
    @riding = -1
    @boats.clear
    @target_boat = -1
  end

  # Puts the mob m back on the floor at x, z.
  def put_mob(m, x, y, z)
    m.x = x
    m.y = y
    m.z = z
    m.vx = 0.0
    m.vy = 0.0
    m.vz = 0.0
  end

  # An adult that eats its food from the hand enters love mode, and two
  # lovers make one baby. The parents then wait 5 minutes, and a baby
  # only grows up faster. Survival uses the food, and creative keeps it.
  def test_breeding
    bx = @spawn_x.floor - 40
    bz = @spawn_z.floor + 40
    y = SKY_Y - 12
    (-10..10).each { |dx| (-10..10).each { |dz| set_block(bx + dx, y, bz + dz, Block::STONE) } }
    fy = y + 1.0
    survival = @survival
    @survival = true
    @inv.clear
    @inv.set(0, Block::WHEAT, 10)
    @inv.set(1, Block::SEEDS, 10)
    @slot = 0
    @mobs.clear
    @items.clear
    cow = Animal.new(Mob::COW, bx + 0.5, fy, bz + 0.5, 3)
    @mobs << cow
    hearts = @particles.count(Particle::HEART)
    right_click_mob(cow)
    loved = cow.love.on? && cow.love.left == Love::TIME && @inv.count(0) == 9 &&
            @particles.count(Particle::HEART) == hearts + 7
    right_click_mob(cow)
    again = @inv.count(0) == 9
    cow.love.clock(Love::TIME - 1.0)
    still = cow.love.on?
    cow.love.clock(1.0)
    check("wheat from the hand puts a cow in love mode for 30 seconds and uses 1 wheat, once",
          loved && again && still && !cow.love.on?)
    @slot = 1
    right_click_mob(cow)
    seeds_on_cow = @target_mob == 0 && !cow.love.on? && @inv.count(1) == 10
    hen = Animal.new(Mob::CHICKEN, bx + 0.5, fy, bz - 4.5, 3)
    @mobs << hen
    @slot = 0
    right_click_mob(hen)
    wheat_on_hen = @target_mob == 1 && !hen.love.on? && @inv.count(0) == 9
    @slot = 1
    right_click_mob(hen)
    check("a cow takes no seeds and a chicken no wheat, but a chicken takes seeds",
          seeds_on_cow && wheat_on_hen && hen.love.on? && @inv.count(1) == 9)
    # The hen is in love mode, and the cow is not. Old particles go first.
    # In 70 frames, the hen gives off its hearts at 0.5 and 1 second.
    @mobs.clear
    @mobs << cow
    @particles.update(@world, 10.0)
    60.times { update_mobs(1.0 / 60.0) }
    cold = @particles.count(Particle::HEART)
    @mobs << hen
    70.times { update_mobs(1.0 / 60.0) }
    warm = @particles.count(Particle::HEART)
    check("an animal in love mode gives off a heart each half second, and one out of love mode gives off none",
          cold == 0 && warm == 2 && hen.love.on?)
    @mobs.clear
    @slot = 0
    a = Animal.new(Mob::COW, bx + 0.5, fy, bz + 0.5, 3)
    b = Animal.new(Mob::COW, bx + 5.5, fy, bz + 0.5, 4)
    @mobs << a
    @mobs << b
    right_click_mob(a)
    right_click_mob(b)
    frames = 0
    while frames < 600 && @mobs.none?(&:baby?)
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    babies = @mobs.select(&:baby?)
    near = (a.x - b.x).abs < Love::MATE_NEAR
    check("two cows in love mode walk to each other and make one baby cow",
          babies.size == 1 && babies[0].kind == Mob::COW && near && frames >= (Love::COURT_TIME * 60.0).to_i &&
          !a.love.on? && !b.love.on? && a.love.wait > Love::BREED_WAIT - 0.1 && b.love.wait > Love::BREED_WAIT - 0.1)
    calf = babies[0]
    put_mob(a, bx + 0.5, fy, bz + 0.5)
    left = @inv.count(0)
    right_click_mob(a)
    waits = !a.love.on? && @inv.count(0) == left
    a.love.clock(Love::BREED_WAIT - 1.0)
    right_click_mob(a)
    waits &&= !a.love.on?
    a.love.clock(1.0)
    right_click_mob(a)
    check("a parent takes no food for 5 minutes, then enters love mode again",
          waits && a.love.on? && @inv.count(0) == left - 1)
    @mobs.clear
    @mobs << calf
    put_mob(calf, bx + 0.5, fy, bz + 0.5)
    grow = calf.grow_left
    left = @inv.count(0)
    right_click_mob(calf)
    faster = (calf.grow_left - grow * (1.0 - Animal::FEED_GROWTH)).abs < 0.001 && @inv.count(0) == left - 1
    calf.grow_up(calf.grow_left - 8.0)
    right_click_mob(calf)
    late = (calf.grow_left - 8.0).abs < 0.001 && @inv.count(0) == left - 2
    check("a baby eats wheat but does not enter love mode, and each wheat takes 10% off its growth time",
          faster && late && calf.baby? && !calf.love.on?)
    calf2 = Animal.new(Mob::COW, bx + 2.5, fy, bz + 0.5, 5)
    calf2.make_baby
    @mobs << calf2
    right_click_mob(calf2)
    300.times { update_mobs(1.0 / 60.0) }
    check("two babies fed wheat make no baby", @mobs.count(&:baby?) == 2)
    @mobs.clear
    @survival = false
    held = @hotbar[@slot]
    @hotbar[@slot] = Block::WHEAT
    @inv.clear
    cow = Animal.new(Mob::COW, bx + 0.5, fy, bz + 0.5, 6)
    @mobs << cow
    right_click_mob(cow)
    check("in creative, wheat puts a cow in love mode and stays in the hand",
          cow.love.on? && @hotbar[@slot] == Block::WHEAT && @inv.empty?(0))
    @hotbar[@slot] = held
    test_tempt(bx, bz, fy)
    @mobs.clear
    @inv.clear
    @survival = survival
    (-10..10).each { |dx| (-10..10).each { |dz| set_block(bx + dx, y, bz + dz, Block::AIR) } }
  end

  # Mobs push each other apart where their boxes overlap, monsters too,
  # but a push does not move a mob into a block. Tempted animals around
  # the player do not stand on one spot.
  def test_push
    bx = @spawn_x.floor - 40
    bz = @spawn_z.floor - 40
    y = SKY_Y - 12
    (-10..10).each { |dx| (-10..10).each { |dz| set_block(bx + dx, y, bz + dz, Block::STONE) } }
    (-10..10).each { |dz| set_block(bx + 5, y + 1, bz + dz, Block::STONE) }
    fy = y + 1.0
    survival = @survival
    px = @player.x
    py = @player.y
    pz = @player.z
    # The creepers stand still with the player 40 blocks away.
    @player.x = bx + 0.5
    @player.y = fy
    @player.z = bz + 40.5
    @mobs.clear
    a = Monster.new(Mob::CREEPER, bx + 0.5, fy, bz + 0.5, 3)
    b = Monster.new(Mob::CREEPER, bx + 0.5, fy, bz + 0.5, 4)
    @mobs << a
    @mobs << b
    60.times { update_mobs(1.0 / 60.0) }
    d = Math.sqrt(((a.x - b.x) ** 2 + (a.z - b.z) ** 2).to_f)
    check("two mobs on one spot push each other apart within a second", d >= Mob::HALF[Mob::CREEPER] * 2.0 - 0.05)
    @mobs.clear
    # The wall of stone is at x bx + 5. The creeper by the wall gets a push
    # to it.
    wall = Monster.new(Mob::CREEPER, bx + 4.69, fy, bz + 0.5, 5)
    other = Monster.new(Mob::CREEPER, bx + 4.5, fy, bz + 0.5, 6)
    @mobs << wall
    @mobs << other
    60.times { update_mobs(1.0 / 60.0) }
    check("a push does not move a mob into a block",
          !wall.blocked?(@world) && wall.x + Mob::HALF[Mob::CREEPER] <= bx + 5.0 && other.x < bx + 4.2)
    @mobs.clear
    @survival = true
    @inv.clear
    @inv.set(0, Block::WHEAT, 10)
    @slot = 0
    @player.z = bz + 0.5
    cows = []
    4.times do |i|
      cow = Animal.new(Mob::COW, bx + 0.5, fy, bz - 3.5, 10 + i)
      @mobs << cow
      cows << cow
    end
    240.times { update_mobs(1.0 / 60.0) }
    gap = 100.0
    cows.each_with_index do |c, i|
      cows.each_with_index do |o, j|
        next unless j > i

        g = Math.sqrt(((c.x - o.x) ** 2 + (c.z - o.z) ** 2).to_f)
        gap = g if g < gap
      end
    end
    check("cows that follow wheat to the player do not stand on one spot", cows.all?(&:tempted) && gap > 0.5)
    @mobs.clear
    @inv.clear
    @survival = survival
    @player.x = px
    @player.y = py
    @player.z = pz
    (-10..10).each { |dx| (-10..10).each { |dz| (0..1).each { |dy| set_block(bx + dx, y + dy, bz + dz, Block::AIR) } } }
  end

  # A cow follows a player who holds wheat within 6 blocks, until the
  # player is 10 blocks away, and stops 2.5 blocks from the player. The
  # floor at y fy - 1 is around bx, bz.
  def test_tempt(bx, bz, fy)
    @survival = true
    @inv.clear
    @inv.set(0, Block::WHEAT, 10)
    @inv.set(1, Block::SEEDS, 10)
    @slot = 0
    @mobs.clear
    cow = Animal.new(Mob::COW, bx + 0.5, fy, bz - 4.5, 7)
    @mobs << cow
    @player.x = bx + 0.5
    @player.y = fy
    @player.z = bz + 0.5
    @player.flying = false
    240.times { update_mobs(1.0 / 60.0) }
    d = Math.sqrt(((cow.x - @player.x) ** 2 + (cow.z - @player.z) ** 2).to_f)
    check("a cow walks to a player who holds wheat 5 blocks away, and stops near the player",
          cow.tempted && d < 3.0 && d > 1.5)
    @slot = 1
    update_mobs(1.0 / 60.0)
    seeds = !cow.tempted
    @slot = 0
    put_mob(cow, bx + 0.5, fy, bz - 7.5)
    update_mobs(1.0 / 60.0)
    far = !cow.tempted
    put_mob(cow, bx + 0.5, fy, bz - 4.5)
    update_mobs(1.0 / 60.0)
    put_mob(cow, bx + 0.5, fy, bz - 8.5)
    update_mobs(1.0 / 60.0)
    keeps = cow.tempted
    put_mob(cow, bx + 0.5, fy, bz - 9.9)
    update_mobs(1.0 / 60.0)
    check("a cow does not follow seeds or wheat 8 blocks away, and a cow that follows stops 10 blocks away",
          seeds && far && keeps && !cow.tempted)
  end

  # A ladder lifts the player at 2.35 m/s on jump, holds the player on
  # Shift, and lets the player slide down at 3 m/s.
  def test_ladder
    x = @spawn_x.floor + 40
    z = @spawn_z.floor - 40
    y = @world.height_at(x, z)
    6.times do |i|
      set_block(x, y + i, z, Block.facing_id(Block::LADDER, 1))
      set_block(x + 1, y + i, z, Block::STONE)
    end
    p = Player.new(x + 0.5, y.to_f, z + 0.5)
    p.controls.hold(0.0, 0.0, jump: true, sneak: false, sprint: false)
    50.times { p.update(@world, 0.02) }
    up = (p.y - y - 2.35).abs < 0.05
    h = p.y
    p.controls.hold(0.0, 0.0, jump: false, sneak: true, sprint: false)
    50.times { p.update(@world, 0.02) }
    held = (p.y - h).abs < 0.05
    p.controls.hold(0.0, 0.0, jump: false, sneak: false, sprint: false)
    25.times { p.update(@world, 0.02) }
    slid = (h - p.y - 1.5).abs < 0.05
    # Forward into the wall climbs to its top and steps onto it.
    p = Player.new(x + 0.5, y.to_f, z + 0.5)
    p.yaw = Math::PI / 2.0
    frames = 0
    while frames < 150 && p.x < x + 1.5
      p.controls.hold(1.0, 0.0, jump: false, sneak: false, sprint: false)
      p.update(@world, 0.02)
      frames += 1
    end
    top = p.x >= x + 1.5 && (p.y - (y + 6)).abs < 0.05
    6.times do |i|
      set_block(x, y + i, z, Block::AIR)
      set_block(x + 1, y + i, z, Block::AIR)
    end
    check("a ladder climbs at 2.35 m/s on jump, holds on Shift, and slides down at 3 m/s", up && held && slid)
    check("forward on a ladder climbs onto the block at its top", top)
  end

  # A ladder hangs only on the side of a solid block, as a thin board on
  # that side, and it falls with the block.
  def test_ladder_wall
    x = @spawn_x.floor + 44
    z = @spawn_z.floor - 40
    g = @world.height_at(x, z) + 3
    fill_box(x - 2, g - 1, z, x + 1, g - 1, z, Block::STONE)
    fill_box(x - 2, g, z, x + 1, g + 1, z, Block::AIR)
    set_block(x + 1, g, z, Block::STONE)
    survival = @survival
    @survival = true
    @inv.clear
    @inv.add(Block::LADDER)
    @inv.add(Block::LADDER)
    @slot = 0
    # The player looks at the -x side of the stone.
    @player.x = x - 1.5
    @player.y = g.to_f
    @player.z = z + 0.5
    @player.yaw = Math::PI / 2.0
    @player.pitch = -0.45
    @target_block.trace(@world, @player)
    place
    hung = @world.get(x, g, z) == Block.facing_id(Block::LADDER, 1)
    # A view ray across the middle of the cell misses the board.
    @player.x = x + 0.5
    @player.z = z - 1.5
    @player.yaw = Math::PI
    @target_block.trace(@world, @player)
    thin = !(@target_block.hit? && @target_block.x == x && @target_block.y == g && @target_block.z == z)
    set_block(x + 1, g, z, Block::AIR)
    fell = @world.get(x, g, z) == Block::AIR
    # On the top of a block, a ladder does not hang.
    @player.x = x - 1.5
    @player.z = z + 0.5
    @player.yaw = Math::PI / 2.0
    @player.pitch = -1.2
    @target_block.trace(@world, @player)
    place
    floor = @target_block.y == g - 1 && @world.get(x - 1, g, z) == Block::AIR && @inv.count(0) == 1
    @survival = survival
    @inv.clear
    check("a ladder hangs on the side of a solid block as a thin board, and falls with it", hung && thin && fell && floor)
  end

  # The player and a mob land on the top of a bed (9/16 high) and of a chest
  # (14/16 high), as in Minecraft.
  def test_low_blocks
    x = @spawn_x.floor + 48
    z = @spawn_z.floor - 40
    g = @world.height_at(x, z) + 3
    fill_box(x, g - 1, z, x + 2, g - 1, z, Block::STONE)
    fill_box(x, g, z, x + 2, g + 2, z, Block::AIR)
    set_block(x, g, z, Block.bed_id(0, true))
    set_block(x + 2, g, z, Block.facing_id(Block::CHEST, 3))
    p = Player.new(x + 0.5, g + 1.5, z + 0.5)
    p.controls.hold(0.0, 0.0, jump: false, sneak: false, sprint: false)
    60.times { p.update(@world, 1.0 / 60.0) }
    bed = (p.y - (g + 0.5625)).abs < 0.001 && p.on_ground
    p = Player.new(x + 2.5, g + 1.5, z + 0.5)
    p.controls.hold(0.0, 0.0, jump: false, sneak: false, sprint: false)
    60.times { p.update(@world, 1.0 / 60.0) }
    chest = (p.y - (g + 0.875)).abs < 0.001
    m = Animal.new(Mob::PIG, x + 0.5, g + 1.5, z + 0.5, 1)
    m.move(@world, 0.0, -1.0, 0.0)
    pig = (m.y - (g + 0.5625)).abs < 0.001
    set_block(x, g, z, Block::AIR)
    set_block(x + 2, g, z, Block::AIR)
    check("the player and a mob land on the top of a bed and of a chest", bed && chest && pig)
  end

  # Water spreads 7 blocks and lava 3 over a floor, and both drain without
  # their source.
  def test_water
    wx = @spawn_x.floor
    wz = @spawn_z.floor + 3
    (-10..10).each do |i|
      set_block(wx + i, SKY_Y - 5, wz, Block::STONE)
      set_block(wx + i, SKY_Y - 4, wz, Block::AIR)
    end
    @fluids.clear
    @items.clear
    set_block(wx + 2, SKY_Y - 4, wz, Block::TORCH)
    set_block(wx - 2, SKY_Y - 4, wz, Block::ROSE)
    set_block(wx, SKY_Y - 4, wz, Block::WATER)
    40.times { update_fluids(Fluids::LAVA_STEP) }
    check("water spreads 7 blocks over a floor", Block::WATER_LEVEL[@world.get(wx + 7, SKY_Y - 4, wz)] == 1 && @world.get(wx + 8, SKY_Y - 4, wz) == Block::AIR && Block::WATER_LEVEL[@world.get(wx - 3, SKY_Y - 4, wz)] == 5)
    check("water washes away a torch and a rose, and they drop",
          Block.water?(@world.get(wx + 2, SKY_Y - 4, wz)) && ground_count(Block::TORCH) == 1 && ground_count(Block::ROSE) == 1)
    @items.clear
    set_block(wx, SKY_Y - 4, wz, Block::AIR)
    40.times { update_fluids(Fluids::LAVA_STEP) }
    check("water drains when its source is gone", @world.get(wx + 3, SKY_Y - 4, wz) == Block::AIR && @world.get(wx - 6, SKY_Y - 4, wz) == Block::AIR)
    set_block(wx + 2, SKY_Y - 4, wz, Block::TORCH)
    set_block(wx, SKY_Y - 4, wz, Block::LAVA)
    40.times { update_fluids(Fluids::LAVA_STEP) }
    check("lava spreads 3 blocks over a floor", Block::LAVA_LEVEL[@world.get(wx + 3, SKY_Y - 4, wz)] == 1 && @world.get(wx + 4, SKY_Y - 4, wz) == Block::AIR && Block::LAVA_LEVEL[@world.get(wx - 1, SKY_Y - 4, wz)] == 3)
    check("lava burns a torch, and it drops nothing", Block.lava?(@world.get(wx + 2, SKY_Y - 4, wz)) && @items.empty?)
    set_block(wx, SKY_Y - 4, wz, Block::AIR)
    40.times { update_fluids(Fluids::LAVA_STEP) }
    check("lava drains when its source is gone", @world.get(wx + 2, SKY_Y - 4, wz) == Block::AIR && @world.get(wx - 3, SKY_Y - 4, wz) == Block::AIR)
  end

  # Stacks spill into the backpack, and clicks move and merge them.
  def test_inventory_clicks
    @inv.clear
    (9 * Slots::STACK + 3).times { @inv.add(Block::DIRT) }
    check("a full hotbar spills into the backpack", @inv.block(9) == Block::DIRT && @inv.count(9) == 3)
    @inv.click(9, @held)
    @inv.click(20, @held)
    check("clicks move a stack", @inv.count(9) == 0 && @inv.block(20) == Block::DIRT && @inv.count(20) == 3 && @held.empty?(0))
    @inv.click(20, @held)
    @inv.click(0, @held)
    check("clicks merge into a full stack and keep the rest", @inv.count(0) == 64 && @held.count(0) == 3)
    return_held
  end

  # True when m is an animal that stands on grass or snowy grass, where
  # NaturalSpawner#spawn_animal puts animals.
  def animal_on_grass?(m)
    ground = @world.get(m.x.floor, m.y.floor - 1, m.z.floor)
    m.passive? && (ground == Block::GRASS || ground == Block::SNOW_GRASS)
  end

  # The chunks in the view draw with the sides that can face the eye, and
  # their water draws from far to near.
  def test_culling
    ex = @player.x.to_f
    ez = @player.z.to_f
    @chunk_meshes.stream(ex.floor >> 4, ez.floor >> 4, -1, SYNC_R)
    # Water in the chunk of the player and in chunks 2, 4 and 6 ahead.
    waters = [0, 2, 4, 6]
    waters.each { |k| set_block(ex.floor, SKY_Y, ez.floor - k * CHUNK, Block::WATER) }
    @fluids.clear
    @chunk_meshes.flush_all
    # The camera looks along -z.
    @camera.update_camera(ex, @player.eye_y.to_f, ez, 0.0, 0.0, 16.0 / 9.0, @options.view + 40.0, @fov)
    cull_view(@options.view + 4.0)
    visible = @chunk_meshes.visible
    water = @chunk_meshes.water_visible
    pcx = ex.floor >> 4
    pcz = ez.floor >> 4
    sides = {}
    (0...visible.size).step(2) { |k| sides[visible[k] / 2] = visible[k + 1] }
    ahead = sides[World.slot(pcx, pcz - 2)]
    check("a chunk ahead draws with the sides that face the eye, and a chunk behind does not draw",
          ahead == (4 | 8 | 64 | 1 | 2 | 16) && !sides.key?(World.slot(pcx, pcz + 3)))
    # The order goes by the whole part of the distance, so chunks with the
    # same whole part can come in either order.
    far_first = true
    (2...water.size).step(2) do |k|
      far_first = false if water_distance2(water[k - 2]).to_i < water_distance2(water[k]).to_i
    end
    check("water draws from the far chunks to the near ones", water.size >= waters.size * 2 && far_first)
    waters.each { |k| set_block(ex.floor, SKY_Y, ez.floor - k * CHUNK, Block::AIR) }
    @chunk_meshes.flush_all
    # Far terrain for a view of 1000 blocks. The full detail of 8 rings
    # covers the tile of the player.
    view = 1000.0
    @far.build_tiles(ex.floor.to_i, ez.floor.to_i, view, 10_000_000_000)
    @chunk_meshes.detail_square(8, @uniforms, 28)
    @far.cull_tiles(@camera, view, view + 4.0, @uniforms, 28)
    tiles = {}
    (0...@far.visible.size).step(2) { |k| tiles[@far.visible[k]] = @far.visible[k + 1] }
    shift = @far.lod(0).tile_shift
    tx = ex.floor.to_i >> shift
    tz = ez.floor.to_i >> shift
    check("a far tile ahead draws with the sides that face the eye, and a tile behind or under the full detail does not draw",
          tiles[LOD_SLOT0 + Lod.slot(tx, tz - 3)] == (4 | 1 | 2 | 16) && !tiles.key?(LOD_SLOT0 + Lod.slot(tx, tz + 3)) &&
          !tiles.key?(LOD_SLOT0 + Lod.slot(tx, tz)))
    # test_streaming counts the tiles that a new far terrain builds.
    @far = FarTerrain.new(@world.terrain, LOD_SLOT0)
  end

  # The square of the distance along x and z from the eye to the chunk of
  # the water mesh of slot, the number that ChunkMeshes#water_visible holds.
  def water_distance2(slot)
    s = slot / 2
    x0 = (@world.slot_cx[s] * CHUNK).to_f
    z0 = (@world.slot_cz[s] * CHUNK).to_f
    @camera.box_distance2(x0, z0, x0 + 16.0, z0 + 16.0)
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
    @chunk_meshes.stream((ex >> 4) + RING, ez >> 4, -1, SYNC_R)
    gone = !@world.loaded?(ex, ez)
    @chunk_meshes.stream(ex >> 4, ez >> 4, -1, SYNC_R)
    check("an edited chunk unloads and comes back the same", gone && @world.get(ex, eh + 4, ez) == Block::GLASS && @world.chunk_bytes(ex >> 4, ez >> 4) == before)
    check("an unloaded chunk generates the same blocks again", @world.chunk_bytes((ex >> 4) + 3, ez >> 4) == far)
    # The chunks within 2 rings of the player draw in full detail, and the
    # far terrain skips their square.
    pcx = ex.to_i >> 4
    pcz = ez.to_i >> 4
    square = Array.new(4, 0.0)
    @chunk_meshes.detail_square(2, square, 0)
    slots = @chunk_meshes.detail_slots(2)
    check("the full-detail chunks are the meshed chunks within the rings, and the far terrain skips their square",
          square == [((pcx - 2) * CHUNK).to_f, ((pcz - 2) * CHUNK).to_f, ((pcx + 3) * CHUNK).to_f, ((pcz + 3) * CHUNK).to_f] &&
          slots.size == 25 && slots.include?(World.slot(pcx, pcz)) && slots.include?(World.slot(pcx + 2, pcz - 2)) &&
          !slots.include?(World.slot(pcx + 3, pcz)))
    set_block(ex, eh + 4, ez, Block::AIR)
    far = @far.lod(FarTerrain::LEVELS - 1)
    slot = far.build(3, -2)
    check("a far tile has a top face for each cell, sorted by direction", far.faces.size / 2 == far.offsets[7] && far.offsets[3] - far.offsets[2] == Lod::CELLS * Lod::CELLS && slot == Lod.slot(3, -2))
    # A view of the full reach of level 0 needs no other level. Level 0
    # builds all of its 11 rings: 23 x 23 tiles.
    view = FarTerrain::REACH.to_f
    @far.take_builds
    @far.build_tiles(ex.to_i, ez.to_i, view, 10_000_000_000)
    near = @far.lod(0)
    tx = ex.to_i >> near.tile_shift
    tz = ez.to_i >> near.tile_shift
    square = Array.new(4, 0.0)
    @far.skip_square(0, view, square, 0)
    check("far terrain builds the rings of tiles around the player, and the next level skips them",
          @far.take_builds == 23 * 23 && @far.take_builds == 0 && near.ready?(tx, tz) && near.ready?(tx + 11, tz - 11) &&
          !near.ready?(tx + 12, tz) && !@far.lod(1).ready?(tx >> 1, tz >> 1) &&
          square[0] == ((tx - 11) * near.tile).to_f && square[3] == ((tz + 12) * near.tile).to_f)
    # The world of the self-test has grass near the player, so animals
    # spawn on it.
    @mobs.clear
    @spawner.spawn_animals(@mobs, @player)
    check("animals spawn on the grass near the player", @mobs.size > 0 && @mobs.all? { |m| animal_on_grass?(m) })
    old_seed = @seed
    @inv.add(Block::DIAMOND)
    @hotbar[0] = Block::GLASS
    @mobs << Monster.new(Mob::ZOMBIE, @player.x, @player.y, @player.z, 1)
    new_world(clock_seed)
    h = @world.height_at(@player.x.floor, @player.z.floor)
    # A new world can start on sand with no grass in reach, which Java
    # Edition allows (minecraft.wiki/w/World_spawn). Then no animal spawns,
    # so the test does not count them. The mobs of the old world must go,
    # and each new mob must be an animal on grass.
    check("a new world has a new seed, the player stands on it, and the old mobs are gone",
          @seed != old_seed && h > 0 && (@player.y - h).abs < 1.5 && @mobs.all? { |m| animal_on_grass?(m) })
    check("a new world starts with an empty inventory", @inv.room_for(Block::DIRT) == INV * Slots::STACK && @hotbar == HOTBAR_START)
  end
end
