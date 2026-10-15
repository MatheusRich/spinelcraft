# Test switches: SELFTEST, SHOWMOBS, SHOWITEMS, and DEMO.
class Game
  # A height above the land and the trees, where the tests and the
  # screenshot scenes build in open air.
  SKY_Y = WY - 6
  # SHOWMOBS=1 lines up one mob of each kind on a stone floor in front of the player.
  def show_mobs
    @mobs.clear
    bx = @player.x.floor
    bz = @player.z.floor - 6
    y = SKY_Y - 10
    dx = -4
    while dx <= 4
      dz = -3
      while dz <= 3
        set_block(bx + dx, y, bz + dz, Block::STONE)
        dz += 1
      end
      dx += 1
    end
    set_block(bx - 3, y + 1, bz + 2, Block.bed_id(1, false))
    set_block(bx - 2, y + 1, bz + 2, Block.bed_id(0, true))
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
    y = SKY_Y - 10
    dx = -4
    while dx <= 4
      dz = -3
      while dz <= 3
        set_block(bx + dx, y, bz + dz, Block::STONE)
        dz += 1
      end
      dx += 1
    end
    shown = [Block::GRASS, Block::CHEST, Block::DOOR, Block::FURNACE, Block::OAK_SAPLING, Block::APPLE,
             Block::BREAD, Block::WHEAT, Block::IRON_SWORD, Block::IRON_AXE, Block::STONE_SHOVEL, Block::ARROW]
    shown.each_with_index do |b, i|
      drop_item(b, i == 11 ? 3 : 1, bx - 3.6 + i * 0.65, y + 1.0, bz + 0.5, 0.0, 0.0, 0.0, 1.0e9)
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
    [Block::SEEDS, Block::WHEAT_1, Block::WHEAT_2, Block::WHEAT_RIPE].each_with_index do |b, i|
      set_block(bx - 4 + i, y + 1, bz - 1, b)
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

  # Flight is as fast as in Minecraft at the ground, and gets faster up to
  # Player::FLY_BOOST times as fast at Player::FLY_HIGH above it.
  def test_fly_speed(x, z, ground)
    y = @player.y
    @player.x = x + 0.5
    @player.z = z + 0.5
    @player.y = ground + 1.0
    low = @player.fly_boost(@world)
    @player.y = ground + 1.0 + Player::FLY_HIGH / 2.0
    mid = @player.fly_boost(@world)
    @player.y = ground + 1.0 + Player::FLY_HIGH * 2.0
    high = @player.fly_boost(@world)
    @player.y = y
    check("flight is slow near the ground and fast high above it",
          low == 1.0 && mid == (1.0 + Player::FLY_BOOST) / 2.0 && high == Player::FLY_BOOST)
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
    test_fly_speed(x, z, ground)
    test_survival(x, z, ground)
    test_monsters
    test_fire
    test_rain
    test_clock
    test_save(x, z, ground)
    test_crafting_limits
    test_inventory_layout
    test_seen_recipes
    test_recipe_scroll
    test_split_and_quick_move
    cx = @spawn_x.floor + 4
    cz = @spawn_z.floor + 4
    test_chests(cx, cz)
    test_mob_drops
    test_mob_death
    test_mob_panic
    test_leaf_decay
    test_items(cx, cz)
    test_light_sources(cx, cz)
    test_tint(cx, cz)
    test_dark
    test_door_furnace_sapling
    test_door_rules
    test_door_board
    test_ladder
    test_ladder_wall
    test_low_blocks
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
    test_pause
    test_menu
    test_chips
    test_sounds
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
    check("the player spawns on dry land", h > SEA + 2 && Block.solid?(b) && !Block.leaves?(b) && !Block.water?(b))
  end

  # The terrain tables are read by position, so each must have one entry
  # for each biome or tree kind, and the spline needs rising points.
  def test_terrain_tables
    biomes = [Biome::GROUND, Biome::TREES, Biome::TREE, Biome::BIRCHES, Biome::LARGE_OAKS, Biome::PINES, Biome::GRASS, Biome::FLOWERS, Biome::GRASS_COLOR, Biome::FOLIAGE_COLOR].all? { |t| t.size == Biome::ALL.size }
    kinds = World::TRUNK.size == Biome::TREE_KINDS.size && World::WOOD.size == Biome::TREE_KINDS.size && Biome::TREE.all? { |k| k < Biome::TREE_KINDS.size }
    xs = World::CONTINENT
    rising = (1...xs.size).all? { |i| xs[i] > xs[i - 1] }
    check("each terrain table has one entry for each biome or tree kind", biomes && kinds)
    check("the continent spline has rising points and one height for each", rising && World::BASE.size == xs.size)
  end

  # The pause screen stops the world, but the inventory and the death
  # screen do not.
  def test_pause
    @captured = false
    paused = paused?
    @inventory_open = true
    inventory = paused?
    @inventory_open = false
    @vitals.health = 0.0
    dead = paused?
    @vitals.health = Vitals::MAX_HEALTH
    @captured = true
    check("only the pause screen stops the world", paused && !inventory && !dead && !paused?)
  end

  # The sliders of the pause menu set the options, and New world asks for a
  # second click.
  def test_menu
    view = @fog_end
    volume = @volume
    fov = @fov_degrees
    set_slider(M_VIEW, 0.5)
    half = @fog_end
    set_slider(M_VIEW, 0.0)
    near = @fog_end
    @fog_end = view
    check("the render distance slider goes in steps of 100 blocks", half == 2600.0 && near == VIEW_MIN)
    set_slider(M_BRIGHTNESS, 1.0)
    set_slider(M_VOLUME, 0.25)
    check("the brightness and volume sliders set the options", @brightness == 1.0 && slider_value(M_VOLUME) == 0.25 && menu_label(M_VOLUME) == "VOLUME: 25%")
    set_slider(M_FOV, 0.5)
    normal = menu_label(M_FOV)
    set_slider(M_FOV, 1.0)
    quake = menu_label(M_FOV)
    set_slider(M_FOV, 0.0)
    check("the field of view slider goes from 30 to 110 degrees, with 70 as normal",
          @fov_degrees == FOV_MIN && menu_label(M_FOV) == "FIELD OF VIEW: 30" && normal == "FIELD OF VIEW: NORMAL" && quake == "FIELD OF VIEW: QUAKE PRO")
    check("the view takes the new field of view at once", @fov == FOV_MIN * Math::PI / 360.0)
    @fov_degrees = 90.0
    @fog_end = 1200.0
    @show_debug = false
    save_options
    @brightness = 0.0
    @volume = volume
    @fog_end = view
    @fov_degrees = fov
    @show_debug = true
    load_options
    File.delete(OPTIONS_PATH)
    check("the options load from the file that save_options writes",
          @brightness == 1.0 && @volume == 0.25 && @fog_end == 1200.0 && @fov_degrees == 90.0 && !@show_debug && !@fullscreen)
    @brightness = 0.0
    @volume = volume
    @fog_end = view
    @fov_degrees = fov
    @fov = option_fov
    @show_debug = true
    seed = @seed
    click_menu(M_NEW_WORLD)
    once = @seed == seed && @menu_confirm
    click_menu(M_DEBUG)
    check("new world asks for a second click", once && !@menu_confirm && @seed == seed)
    click_menu(M_DEBUG)
  end

  # Every sound file loads, footsteps follow the block underfoot, and a
  # creeper hisses once when it lights its fuse.
  def test_sounds
    check("every sound file loads", Sfx.load_files == Sfx::FILES.size && Gfx.au_seconds(Sfx::RAIN) > 5.0)
    check("blocks sound like their material",
          MATERIAL_STEP[material(Block::GRASS)] == Sfx::STEP_GRASS && MATERIAL_STEP[material(Block::STONE)] == Sfx::STEP_HARD &&
          MATERIAL_STEP[material(Block::OAK_PLANKS)] == Sfx::STEP_WOOD && MATERIAL_STEP[material(Block::SAND)] == Sfx::STEP_SAND &&
          MATERIAL_BREAK[material(Block::GLASS)] == Sfx::BREAK_GLASS && MATERIAL_DIG[material(Block::OAK_LEAVES)] == Sfx::DIG_LEAVES &&
          MATERIAL_DIG[material(Block::ROSE)] == Sfx::DIG_LEAVES && material(Block::TORCH) == M_WOOD &&
          MATERIAL_STEP[material(Block::WOOL)] == Sfx::CLOTH && MATERIAL_STEP[material(Block::SNOW)] == Sfx::SNOW)
    creeper = Mob.new(Mob::CREEPER, @player.x + 1.5, @player.y, @player.z, 11)
    hisses = 0
    20.times do
      creeper.update_mob(@world, 1.0 / 60.0, @player, 0.3)
      hisses += 1 if creeper.hiss
      creeper.hiss = false
    end
    check("a creeper hisses once when it lights its fuse", hisses == 1 && creeper.fuse > 0.0)
    pig = Mob.new(Mob::PIG, @player.x, @player.y, @player.z, 5)
    pig.wound(1.0)
    check("a hit makes a mob cry out", pig.ouch)
    # The zombie walks toward the player on a strip of stone in the sky.
    px = @player.x.floor
    zz = @player.z.floor
    y = WY - 4
    (0..9).each { |dx| set_block(px + dx, y, zz, Block::STONE) }
    zombie = Mob.new(Mob::ZOMBIE, px + 8.5, y + 1.0, zz + 0.5, 3)
    steps = 0
    120.times do
      zombie.update_mob(@world, 1.0 / 60.0, @player, 0.0)
      steps += 1 if zombie.step
      zombie.step = false
    end
    (0..9).each { |dx| set_block(px + dx, y, zz, Block::AIR) }
    check("a walking mob makes step sounds", steps >= 1)
    test_sound_position
    test_arrow_lands
    test_block_sounds
    test_lava_swim
    test_eat_slowdown
    test_jump
    test_swim_speed
    test_cave_sound
  end

  # A jump lifts the feet 1.2522 blocks, and sprint-jumps move faster than
  # a sprint, at 7.127 m/s on average.
  def test_jump
    px = @player.x
    py = @player.y
    pz = @player.z
    yaw = @player.yaw
    flying = @player.flying
    x = px.floor
    z = pz.floor
    y = WY - 4
    (0..40).each { |d| set_block(x, y, z - d, Block::STONE) }
    @player.flying = false
    @player.yaw = 0.0
    @player.x = x + 0.5
    @player.y = y + 1.0
    @player.z = z + 0.5
    @player.vx = 0.0
    @player.vz = 0.0
    top = 0.0
    50.times do
      @player.update(@world, 0.02, 0.0, 0.0, true, false, false)
      top = @player.y if @player.y > top
    end
    height = top - (y + 1.0)
    @player.z = z + 0.5
    25.times { @player.update(@world, 0.02, 1.0, 0.0, false, false, true) }
    z0 = @player.z
    150.times { @player.update(@world, 0.02, 1.0, 0.0, true, false, true) }
    speed = (z0 - @player.z) / 3.0
    (0..40).each { |d| set_block(x, y, z - d, Block::AIR) }
    @player.x = px
    @player.y = py
    @player.z = pz
    @player.yaw = yaw
    @player.flying = flying
    check("a jump lifts the feet 1.25 blocks, and sprint-jumps move at 7.1 m/s",
          (height - 1.2522).abs < 0.01 && (speed - 7.127).abs < 0.15)
  end

  # The player swims at 2.2 m/s at the surface, 1.97 m/s under water, and
  # 3.918 m/s in a sprint. In lava the player swims at 0.4 times the speed
  # in water, and a sprint does not make it faster. A held jump does not
  # make the player faster in water or in lava.
  def test_swim_speed
    px = @player.x
    py = @player.y
    pz = @player.z
    yaw = @player.yaw
    flying = @player.flying
    x = px.floor
    z = pz.floor
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
      @player.x = x + 0.5
      @player.y = y + 1.0
      @player.z = z + 0.5
      @player.vx = 0.0
      @player.vz = 0.0
      25.times { @player.update(@world, 0.02, 1.0, 0.0, jump, false, sprint) }
      z0 = @player.z
      100.times { @player.update(@world, 0.02, 1.0, 0.0, jump, false, sprint) }
      (z0 - @player.z) / 2.0
    end
    (0..20).each do |d|
      set_block(x, y, z - d, Block::AIR)
      set_block(x, y + 1, z - d, Block::AIR)
      set_block(x, y + 2, z - d, Block::AIR)
    end
    @flow_queue.clear
    @player.x = px
    @player.y = py
    @player.z = pz
    @player.yaw = yaw
    @player.flying = flying
    check("the player swims at 2.2 m/s, 1.97 m/s under water, and 3.918 m/s in a sprint",
          (speeds[0] - 2.2).abs < 0.05 && (speeds[1] - 3.918).abs < 0.05 && (speeds[2] - 1.97).abs < 0.05)
    check("the player swims in lava at 0.88 m/s, also in a sprint", (speeds[3] - 0.88).abs < 0.03)
    check("a held jump does not make a swim faster", (speeds[4] - 2.2).abs < 0.05 && (speeds[5] - 0.88).abs < 0.03)
  end

  # A player who eats or draws the bow walks at sneaking speed.
  def test_eat_slowdown
    px = @player.x
    py = @player.y
    pz = @player.z
    yaw = @player.yaw
    flying = @player.flying
    x = px.floor
    z = pz.floor
    y = WY - 4
    (0..30).each { |d| set_block(x, y, z - d, Block::STONE) }
    @player.flying = false
    @player.yaw = 0.0
    speeds = [false, true].map do |slowed|
      @player.x = x + 0.5
      @player.y = y + 1.0
      @player.z = z + 0.5
      @player.vx = 0.0
      @player.vz = 0.0
      @player.slowed = slowed
      40.times { @player.update(@world, 0.02, 1.0, 0.0, false, false, true) }
      Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz)
    end
    (0..30).each { |d| set_block(x, y, z - d, Block::AIR) }
    @player.slowed = false
    @player.x = px
    @player.y = py
    @player.z = pz
    @player.yaw = yaw
    @player.flying = flying
    @draw_time = 0.5
    bow = using_item?
    @draw_time = -1.0
    check("a player who eats or draws the bow walks at sneaking speed, not a sprint",
          speeds[0] > 5.0 && speeds[1] < 1.5 && bow && !using_item?)
  end

  # The player swims in lava as in water, but only water counts for the
  # splash and the swim sound.
  def test_lava_swim
    px = @player.x
    py = @player.y
    pz = @player.z
    flying = @player.flying
    x = px.floor
    z = pz.floor
    y = WY - 4
    @player.flying = false
    @player.x = x + 0.5
    @player.y = y.to_f
    @player.z = z + 0.5
    set_block(x, y, z, Block::LAVA)
    @player.update(@world, 1.0 / 60.0, 0.0, 0.0, false, false, false)
    lava = @player.in_water && @player.in_lava
    set_block(x, y, z, Block::WATER)
    @player.y = y.to_f
    @player.update(@world, 1.0 / 60.0, 0.0, 0.0, false, false, false)
    water = @player.in_water && !@player.in_lava
    set_block(x, y, z, Block::AIR)
    @player.x = px
    @player.y = py
    @player.z = pz
    @player.flying = flying
    check("lava is not water for the swim sounds", lava && water)
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

  # An arrow that sticks in the ground lands once, so its sound plays once.
  def test_arrow_lands
    x = @spawn_x.floor + 0.5
    z = @spawn_z.floor + 0.5
    arrow = Arrow.new(x, @world.height_at(x.floor, z.floor) + 2.0, z, 0.0, -10.0, 0.0, 5.0, 0)
    steps = 0
    steps += 1 while arrow.fly(@world, 1.0 / 60.0) && steps < 120
    landed = arrow.landed
    arrow.landed = false
    arrow.fly(@world, 1.0 / 60.0)
    check("an arrow lands once when it sticks in a block", landed && !arrow.landed)
  end

  # A sound to the side pans to that side, a sound far below is quiet,
  # and an explosion reaches farther. At yaw 0 the player looks toward -z,
  # so +x is to the right.
  def test_sound_position
    yaw = @player.yaw
    @player.yaw = 0.0
    x = @player.x
    y = @player.eye_y
    z = @player.z
    right = pan_to(x + 5.0, y, z)
    left = pan_to(x - 5.0, y, z)
    above = pan_to(x, y + 5.0, z)
    ahead = pan_to(x, y, z - 5.0)
    check("a sound pans toward the side that it comes from", right > 0.99 && left < -0.99 && above.abs < 0.01 && ahead.abs < 0.01)
    check("a sound far below is quiet", near_volume(x, y - 12.0, z, 1.0, SOUND_RANGE) < 0.3 && near_volume(x, y - 20.0, z, 1.0, SOUND_RANGE) == 0.0)
    check("an explosion carries farther than other sounds",
          near_volume(x, y, z - 40.0, 1.0, EXPLOSION_RANGE) > 0.0 && near_volume(x, y, z - 40.0, 1.0, SOUND_RANGE) == 0.0)
    @player.yaw = yaw
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
    px = @player.x
    py = @player.y
    pz = @player.z
    @player.x = cx + 0.5
    @player.y = 5.0
    @player.z = cz + 0.5
    @cave_fear = 0.0
    @cave_timer = 0.0
    update_cave_sound(0.0)
    grew = @cave_fear == 3.0
    @cave_fear = 299.0
    @cave_timer = 0.0
    update_cave_sound(0.0)
    check("the dark builds fear, and full fear plays a cave sound", grew && @cave_fear == 0.0)
    @player.x = px
    @player.y = py
    @player.z = pz
  end

  # A broken block throws 64 chips, as in Minecraft.
  def test_chips
    before = @particles.count(Particle::CHIP)
    @particles.burst(@spawn_x.floor, SKY_Y, @spawn_z.floor, Block::STONE)
    check("a broken block throws 64 chips", @particles.count(Particle::CHIP) - before == 64)
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
    wall_torch = Block.facing_id(Block::TORCH, 1)
    set_block(x, ground + 1, z, wall_torch)
    check("wall torch is listed", torches.size == lights + 3)
    set_block(x, ground, z, Block::AIR)
    check("breaking the block under a wall torch keeps it", @world.get(x, ground + 1, z) == wall_torch)
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
    3.times { @inv.add(Block::OAK_LOG) }
    @slot = 0
    craft_recipe(recipe_for(Block::OAK_PLANKS))
    check("craft log into planks", @inv.block(0) == Block::OAK_LOG && @inv.count(0) == 2 && @inv.block(1) == Block::OAK_PLANKS && @inv.count(1) == 4)
    70.times { @inv.add(Block::DIRT) }
    check("stacks split at 64", @inv.count(2) == 64 && @inv.block(3) == Block::DIRT && @inv.count(3) == 6)
    @vitals.health = Vitals::MAX_HEALTH
    hurt(5, Sfx::HURT)
    check("hurt lowers health", @vitals.health == 15.0 && !@vitals.dead?)
    kept = @inv.copy
    @items.clear
    toggle_inventory
    hurt(30, Sfx::HURT)
    check("death at zero health, and it closes the inventory", @vitals.health == 0.0 && @vitals.dead? && !@inventory_open)
    check("death drops the inventory on the ground", @inv.room_for(Block::DIRT) == INV * Slots::STACK && ground_count(Block::DIRT) == 70 && ground_count(Block::OAK_PLANKS) == 4)
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
    check("survival place uses one item", @inv.count(1) == before - 1 && @world.get(x, ground + 1, z) == Block::OAK_PLANKS)
    set_block(x, ground + 1, z, Block::TALL_GRASS)
    @player.raycast(@world)
    place
    check("a block placed on tall grass takes its cell", @world.get(x, ground + 1, z) == Block::OAK_PLANKS && @world.get(x, ground + 2, z) == Block::AIR)
    set_block(x, ground + 1, z, Block::LAVA)
    @player.raycast(@world)
    place
    check("a block placed in lava takes its cell", @world.get(x, ground + 1, z) == Block::OAK_PLANKS)
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
      @player.raycast(@world)
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
    # 1.5 hardness * 1.5 seconds / speed 4 = 0.5625 seconds, as in Minecraft.
    check("a stone pickaxe breaks stone in 12 frames", frames_to_mine(x, ground + 1, z, Block::STONE, Block::STONE_PICK) == 12)
    @items.clear
    @inv.set(5, Block::COOKED_PORKCHOP, 2)
    @slot = 5
    @vitals.hunger = 5
    # Eating takes 1.6 seconds of holding the button, and a release starts
    # it over.
    20.times { right_button(0.05, true) }
    right_button(0.05, false)
    31.times { right_button(0.05, true) }
    early = @vitals.hunger == 5 && @inv.count(5) == 2
    2.times { right_button(0.05, true) }
    check("holding the button for 1.6 seconds eats the food", early && @vitals.hunger == 13 && @inv.count(5) == 1)
    # A minute of standing still costs no hunger. 400 meters of sprint take
    # 40 exhaustion: the 5 points of saturation, then 5 points of hunger.
    @vitals = Vitals.new
    1200.times { @vitals.update_vitals(0.05, false, false) }
    idle = @vitals.hunger == Vitals::MAX_HUNGER
    @vitals.move(400.0, true, false, false)
    @vitals.update_vitals(0.05, false, false)
    check("standing still costs no hunger, and a sprint does", idle && @vitals.hunger == 15)
    # Rotten flesh gives 4 hunger and 0.8 saturation. The Hunger effect
    # adds 3 exhaustion in its 30 seconds, and then no more.
    @vitals = Vitals.new
    @vitals.hunger = 10
    @vitals.saturation = 0.0
    @inv.set(5, Block::ROTTEN_FLESH, 1)
    @slot = 5
    eat
    fed = @vitals.hunger == 14 && @vitals.saturation == 0.8
    @vitals.give_hunger_effect
    601.times { @vitals.update_vitals(0.05, false, false) }
    drained = !@vitals.hunger_effect? && (@vitals.exhaustion - 3.0).abs < 0.01
    20.times { @vitals.update_vitals(0.05, false, false) }
    check("rotten flesh feeds, and its Hunger effect adds exhaustion for 30 seconds", fed && drained && (@vitals.exhaustion - 3.0).abs < 0.01)
    before = @particles.count(Particle::EFFECT)
    @vitals.give_hunger_effect
    update_survival(0.5)
    check("the Hunger effect makes green specks around the player", @particles.count(Particle::EFFECT) > before)
    # Full hunger with 3 saturation heals 3 / 6 each half second, for 3
    # exhaustion. 18 hunger heals 1 each 4 seconds, for 6 exhaustion.
    @vitals = Vitals.new
    @vitals.health = 10.0
    @vitals.saturation = 3.0
    11.times { @vitals.update_vitals(0.05, false, false) }
    saturated = @vitals.health == 10.5 && (@vitals.exhaustion - 3.0).abs < 0.01
    @vitals = Vitals.new
    @vitals.health = 10.0
    @vitals.hunger = 18
    @vitals.saturation = 0.0
    79.times { @vitals.update_vitals(0.05, false, false) }
    early = @vitals.health == 10.0
    2.times { @vitals.update_vitals(0.05, false, false) }
    check("a full stomach heals as in Minecraft", saturated && early && @vitals.health == 11.0)
    @vitals = Vitals.new
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
      set_block(px + i, SKY_Y - 2, pz, Block::STONE)
      i += 1
    end
    flush_dirty
    @mobs.clear
    @time_of_day = 0.75
    @vitals.health = Vitals::MAX_HEALTH
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    @mobs << Mob.new(Mob::SKELETON, px + 12.5, SKY_Y - 1.0, pz + 0.5, 7)
    frames = 0
    while frames < 400 && @vitals.health == Vitals::MAX_HEALTH
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("skeleton arrow hurts the player", @vitals.health < Vitals::MAX_HEALTH)
    @mobs.clear
    @mobs << Mob.new(Mob::ZOMBIE, px + 1.5, SKY_Y - 1.0, pz + 0.5, 9)
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
      set_block(px + dx, SKY_Y - 2, pz - 1, Block::STONE)
      set_block(px + dx, SKY_Y - 2, pz + 1, Block::STONE)
    end
    @mobs << Mob.new(Mob::CREEPER, px + 2.5, SKY_Y - 1.0, pz + 0.5, 11)
    # A blast this near kills a player with full health, so the player
    # gets more health for the test.
    @vitals.health = 100.0
    @items.clear
    frames = 0
    while frames < 300 && @world.get(px + 2, SKY_Y - 2, pz) == Block::STONE
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("a creeper explodes, breaks blocks and hurts", @world.get(px + 2, SKY_Y - 2, pz) == Block::AIR && @vitals.health < 100.0 && frames > 60)
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
    zombie = Mob.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
    @mobs << zombie
    @player.x = px + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = pz + 0.5
    60.times { update_mobs(1.0 / 60.0) }
    check("a zombie in the sun burns and makes flames", zombie.fire > 0.0 && zombie.hp < Mob::HP[Mob::ZOMBIE] && @particles.count(Particle::FLAME) > 0)
    @mobs.clear
    @survival = true
    @vitals.health = Vitals::MAX_HEALTH
    @world.set(px + 1, SKY_Y - 1, pz, Block::LAVA)
    @player.x = px + 1.5
    update_survival(0.1)
    @world.set(px + 1, SKY_Y - 1, pz, Block::AIR)
    @vitals.health = Vitals::MAX_HEALTH
    150.times { update_survival(1.0 / 60.0) }
    burned = @vitals.fire > 0.0 && @vitals.health < Vitals::MAX_HEALTH
    @world.set(px + 1, SKY_Y - 1, pz, Block::WATER)
    update_survival(1.0 / 60.0)
    @world.set(px + 1, SKY_Y - 1, pz, Block::AIR)
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
    zombie = Mob.new(Mob::ZOMBIE, px + 8.5, SKY_Y - 1.0, pz + 0.5, 9)
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

  # The time of day wraps at 6:00 and counts the day.
  def test_clock
    @time_of_day = 0.99
    @day = 4
    update_clock(DAY_SECONDS * 0.02)
    check("the clock counts a day at 6:00", @day == 5 && (@time_of_day - 0.01).abs < 1.0e-9)
    @time_of_day = 0.3
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
    @weather.set(true)
    @weather.timer = 77.5
    @seen.fill(0)
    @seen[Block::DIAMOND] = 1
    @furnaces = {}
    hot = Furnace.new(3, 70, 4)
    hot.burn = 500
    hot.burn_total = 1600
    hot.progress = 37
    hot.slots.set(Furnace::INPUT, Block::SAND, 2)
    hot.slots.set(Furnace::FUEL, Block::OAK_LOG, 3)
    @furnaces[World.key(3, 70, 4)] = hot
    @furnaces[World.key(5, 70, 4)] = Furnace.new(5, 70, 4)
    @day = 37
    @alive_time = 1500.0
    save
    @world.set(x, ground + 1, z, Block::GLASS)
    @vitals.health = 3.0
    @inv.set(1, Block::AIR, 0)
    @items.clear
    @weather.set_now(false)
    @seen.fill(0)
    @furnaces = {}
    @day = 0
    @alive_time = 0.0
    ok = load
    apply_loaded if ok
    check("the save keeps the day and the time alive", ok && @day == 37 && @alive_time == 1500.0)
    check("save and load round trip", ok && @world.get(x, ground + 1, z) == old && @vitals.health == Vitals::MAX_HEALTH && @inv.block(1) == kept_block && @inv.count(1) == kept_count && kept_count > 0 && @survival)
    check("the save keeps the items on the ground and the weather",
          @items.size == 1 && @items[0].block == Block::STONE_SWORD && @items[0].count == 17 &&
          @items[0].x == x + 0.25 && @items[0].y == ground + 1.0 && @items[0].z == z + 0.75 &&
          @weather.raining? && @weather.rain == 1.0 && @weather.timer == 77.5)
    loaded = @furnaces[World.key(3, 70, 4)]
    check("the save keeps the seen items, and the slots and the fire of furnaces",
          @seen[Block::DIAMOND] == 1 && @furnaces.size == 1 && !loaded.nil? && loaded.x == 3 && loaded.burn == 500 && loaded.burn_total == 1600 && loaded.progress == 37 &&
          loaded.slots.block(Furnace::INPUT) == Block::SAND && loaded.slots.count(Furnace::INPUT) == 2 && loaded.slots.block(Furnace::FUEL) == Block::OAK_LOG && loaded.slots.count(Furnace::FUEL) == 3)
    @furnaces = {}
    @items.clear
    @weather.set_now(false)
    @vitals.health = 0.0
    save
    ok = load
    apply_loaded if ok
    check("loading a save made while dead respawns", ok && @vitals.health == Vitals::MAX_HEALTH && !@vitals.dead? && @alive_time == 0.0)
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
    @inv.add(Block::OAK_LOG)
    note_seen
    logs = shown_recipes == [recipe_for(Block::OAK_PLANKS)]
    told = @message == "2 NEW RECIPES - PRESS E, AT A FURNACE" && @recipe_new[recipe_for(Block::OAK_PLANKS)] == 1
    toggle_inventory
    toggle_inventory
    check("a new recipe shows a message and a tag until the inventory closes", told && @recipe_new[recipe_for(Block::OAK_PLANKS)] == 0)
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
    open_station(x, y, z, AT_TABLE)
    table = shown_recipes.include?(recipe_for(Block::OAK_PLANKS)) && shown_recipes.include?(recipe_for(Block::WOOD_PICK)) && !shown_recipes.include?(recipe_for(Block::IRON_INGOT))
    toggle_inventory
    set_block(x, y, z, Block::FURNACE)
    open_station(x, y, z, AT_FURNACE)
    furnace = shown_recipes == [recipe_for(Block::IRON_INGOT), recipe_for(Block::COAL)]
    toggle_inventory
    set_block(x, y, z, old)
    check("the E screen, a crafting table and a furnace each show their own recipes", hand && table && furnace && @station == BY_HAND)
    @inv.clear
  end

  # A crafting table shows more recipes than fit. The list scrolls to its
  # last row and no further, and it starts at the top each time it opens.
  def test_recipe_scroll
    seen = @seen.dup
    RECIPES.each { |r| Block.fillers(r[0]).each { |b| @seen[b] = 1 } }
    x = @player.x.floor + 2
    y = @player.y.floor
    z = @player.z.floor
    old = @world.get(x, y, z)
    set_block(x, y, z, Block::CRAFTING_TABLE)
    open_station(x, y, z, AT_TABLE)
    shown = shown_recipes
    rows = (shown.size + 1) / 2
    top = recipes_in_view == shown[0, RECIPE_ROWS * 2]
    picks = [Block::WOOD_PICK, Block::STONE_PICK, Block::IRON_PICK, Block::DIAMOND_PICK].map { |b| shown.index(recipe_for(b)) }
    check("a crafting table shows the planks first, then the pickaxes in one column, one to a row", shown[0] == recipe_for(Block::OAK_PLANKS) && picks == [4, 6, 8, 10])
    scroll_recipes(100)
    end_view = recipes_in_view
    bottom = @recipe_top == rows - RECIPE_ROWS && end_view[end_view.size - 1] == shown[shown.size - 1] && end_view[0] == shown[@recipe_top * 2]
    scroll_recipes(-100)
    back = @recipe_top == 0
    scroll_recipes(2)
    toggle_inventory
    open_station(x, y, z, AT_TABLE)
    reset = @recipe_top == 0
    toggle_inventory
    set_block(x, y, z, old)
    @seen = seen
    check("the recipe list scrolls to its last row, and it opens at the top", rows > RECIPE_ROWS && top && bottom && back && reset)
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

  # Crafts recipe k on a crafting table next to the player.
  def craft_at_table(k)
    x = @player.x.floor + 2
    y = @player.y.floor
    z = @player.z.floor
    old = @world.get(x, y, z)
    set_block(x, y, z, Block::CRAFTING_TABLE)
    open_station(x, y, z, AT_TABLE)
    craft_recipe(k)
    toggle_inventory
    set_block(x, y, z, old)
  end

  # Crafting needs room for the result, and it takes from several stacks.
  def test_crafting_limits
    i = 0
    while i < INV
      @inv.set(i, Block::OAK_PLANKS, 64)
      i += 1
    end
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
    i = 0
    while i < INV
      @inv.set(i, Block::DIRT, 64)
      i += 1
    end
    @inv.set(0, Block::OAK_LOG, 1)
    craft_recipe(recipe_for(Block::OAK_PLANKS))
    check("a recipe click counts the slot that it empties as room", @inv.block(0) == Block::OAK_PLANKS && @inv.count(0) == 4)
  end

  # Chest contents survive a save and come back when the chest breaks.
  def test_chests(cx, cz)
    set_block(cx, SKY_Y, cz, Block::CHEST)
    @inv.clear
    open_chest(cx, SKY_Y, cz)
    @chest.set(5, Block::DIAMOND, 7)
    toggle_inventory
    save
    @chests = {}
    ok = load
    apply_loaded if ok
    stored = @chests[World.key(cx, SKY_Y, cz)]
    check("chest contents survive a save", ok && !stored.nil? && stored.block(5) == Block::DIAMOND && stored.count(5) == 7)
    set_block(cx, SKY_Y, cz, Block::AIR)
    dropped = ground_count(Block::DIAMOND) == 7 && @inv.total(Block::DIAMOND) == 0
    collect_items
    check("a broken chest drops its contents", dropped && @inv.total(Block::DIAMOND) == 7 && @chests.empty?)
    # An open chest destroyed by a blast never duplicates its contents.
    @inv.clear
    @items.clear
    set_block(cx, SKY_Y, cz, Block::CHEST)
    open_chest(cx, SKY_Y, cz)
    @chest.set(0, Block::DIAMOND, 7)
    set_block(cx, SKY_Y, cz, Block::AIR)
    check("a chest destroyed while open does not duplicate items", @inv.total(Block::DIAMOND) + ground_count(Block::DIAMOND) == 7 && !@inventory_open && @chests.empty?)
    @items.clear
  end

  # Mobs that die without the player's help drop nothing.
  def test_mob_drops
    @inv.clear
    far = Mob.new(Mob::PIG, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    far.hp = 0.0
    @mobs.clear
    @mobs << far
    update_mobs(1.0 / 60.0)
    check("a pig that dies on its own drops nothing", @items.empty?)
    killed = Mob.new(Mob::PIG, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    killed.hp = 0.0
    killed.by_player = true
    @mobs << killed
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::PORKCHOP)
    dropped = n >= 1 && n <= 3
    collect_items
    check("a pig that the player kills drops 1 to 3 porkchops", dropped && @inv.total(Block::PORKCHOP) == n)
    @items.clear
    sheep = Mob.new(Mob::SHEEP, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
    sheep.hp = 0.0
    sheep.by_player = true
    @mobs << sheep
    update_mobs(1.0 / 60.0)
    n = ground_count(Block::MUTTON)
    check("a sheep that the player kills drops its wool and 1 to 2 mutton", ground_count(Block::WOOL) == 1 && n >= 1 && n <= 2)
    @items.clear
    # Raw mutton gives 2 hunger and 1.2 saturation, and cooked mutton 6 and
    # 9.6. A furnace cooks it.
    raw = Block.food(Block::MUTTON) == 2 && Block.saturation(Block::MUTTON) == 1.2
    cooked = Block.food(Block::COOKED_MUTTON) == 6 && Block.saturation(Block::COOKED_MUTTON) == 9.6
    smelts = RECIPES.any? { |r| r[0] == Block::MUTTON && r[2] == Block::COOKED_MUTTON && r[4] == AT_FURNACE }
    check("mutton is food, and a furnace cooks it", raw && cooked && smelts)
    # Each zombie drops 0 to 2, so 10 zombies drop none 1 time in 59049.
    10.times do |i|
      zombie = Mob.new(Mob::ZOMBIE, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z + i, 3)
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

  # A dead mob lies on the ground for DEATH_TIME and takes no hits. Then it
  # goes up in smoke.
  def test_mob_death
    pig = Mob.new(Mob::PIG, @spawn_x + 30.0, SKY_Y.to_f, @spawn_z, 5)
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

  # A hit pig runs away from the hit, and it panics for a while. The legs
  # of a mob that stops come to rest.
  def test_mob_panic
    bx = @spawn_x.floor + 30
    bz = @spawn_z.floor + 20
    i = -10
    while i <= 10
      j = -10
      while j <= 10
        set_block(bx + i, SKY_Y - 2, bz + j, Block::STONE)
        j += 1
      end
      i += 1
    end
    pig = Mob.new(Mob::PIG, bx + 0.5, SKY_Y - 1.0, bz + 0.5, 5)
    @mobs.clear
    @mobs << pig
    pig.hit(1.0, pig.x - 1.0, pig.z)
    60.times { update_mobs(1.0 / 60.0) }
    away = pig.x > bx + 2.0
    120.times { update_mobs(1.0 / 60.0) }
    check("a hit pig runs away from the hit and panics for a while", away && pig.panic > 0.0)
    @mobs.clear
    px = @player.x
    py = @player.y
    pz = @player.z
    @player.x = bx + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = bz - 8.5
    zombie = Mob.new(Mob::ZOMBIE, bx + 0.5, SKY_Y - 1.0, bz + 8.5, 3)
    30.times { zombie.update_mob(@world, 1.0 / 60.0, @player, 0.0) }
    walking = zombie.leg_swing > 0.5
    @player.z = bz + 300.0
    60.times { zombie.update_mob(@world, 1.0 / 60.0, @player, 0.0) }
    check("the legs of a mob swing as it walks and come to rest when it stops", walking && zombie.leg_swing < 0.05)
    @player.x = px
    @player.y = py
    @player.z = pz
  end

  # Leaves with no log within 6 steps through leaves decay, and leaves
  # that the player placed stay. A row of 8 leaves from a log in the air
  # keeps its first 6.
  def test_leaf_decay
    bx = @spawn_x.floor + 20
    bz = @spawn_z.floor - 20
    y = SKY_Y - 4
    set_block(bx, y, bz, Block::OAK_LOG)
    i = 1
    while i <= 8
      set_block(bx + i, y, bz, Block::OAK_LEAVES)
      i += 1
    end
    px = @player.x
    py = @player.y
    pz = @player.z
    pitch = @player.pitch
    flying = @player.flying
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
    @player.raycast(@world)
    place
    set_block(bx + 10, y - 1, bz, Block::AIR)
    placed = @world.get(bx + 10, y, bz) == Block::PLACED_OAK_LEAVES
    @hotbar[0] = held
    @survival = survival
    @player.x = px
    @player.y = py
    @player.z = pz
    @player.pitch = pitch
    @player.flying = flying
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
    y = SKY_Y + 2
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
  # The tint of the face of block b at (cx, SKY_Y, cz) in direction f, from
  # its face record (Mesher.face_tint), or -1 when the mesh has no such face.
  def face_tint(cx, cz, b, f)
    set_block(cx, SKY_Y, cz, b)
    @mesher.build(cx / CHUNK, cz / CHUNK)
    tint = -1
    k = 0
    while k < @mesher.opaque.size
      w0 = @mesher.opaque[k]
      if Mesher.face_x(w0) == (cx & LMASK) && Mesher.face_y(w0) == SKY_Y && Mesher.face_z(w0) == (cz & LMASK) && Mesher.face_dir(w0) == f
        tint = Mesher.face_tint(@mesher.opaque[k + 1])
      end
      k += 2
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
    # to_i keeps the world generator typed (see stream_around).
    x = ((cx >> 2) * 4 + 2).to_i
    z = ((cz >> 2) * 4 + 2).to_i
    b = @world.biome(x, z, @world.surface_height(x, z))
    plains = Tint.ratio(Biome::GRASS_COLOR[Biome::PLAINS], Biome::GRASS_COLOR[Biome::PLAINS])
    check("the tint map holds the ratio of the biome color to the plains color",
          plains == 0xff404040 && @tint.pixels[k] == Tint.ratio(Biome::GRASS_COLOR[b], Biome::GRASS_COLOR[Biome::PLAINS]))
  end

  def test_light_sources(cx, cz)
    # Wool is not a light source.
    set_block(cx, SKY_Y, cz, Block::WOOL)
    @mesher.build(cx / CHUNK, cz / CHUNK)
    faces = 0
    glow = false
    k = 0
    while k < @mesher.opaque.size
      w0 = @mesher.opaque[k]
      if Mesher.face_x(w0) == (cx & LMASK) && Mesher.face_y(w0) == SKY_Y && Mesher.face_z(w0) == (cz & LMASK)
        faces += 1
        glow = true if Mesher.face_light(@mesher.opaque[k + 1]) == 14
      end
      k += 2
    end
    check("wool does not glow", faces > 0 && !glow)
    set_block(cx, SKY_Y, cz, Block::AIR)
    lx = @spawn_x.floor - 6
    lz = @spawn_z.floor - 6
    i = -1
    while i <= 1
      set_block(lx + i, SKY_Y - 5, lz, Block::STONE)
      set_block(lx + i, SKY_Y - 4, lz, Block::AIR)
      i += 1
    end
    set_block(lx, SKY_Y - 4, lz, Block::LAVA)
    @mesher.build(lx / CHUNK, lz / CHUNK)
    check("lava lights its surroundings", @mesher.torch_light(lx, SKY_Y - 3, lz) == 13)
    set_block(lx + 1, SKY_Y - 4, lz, Block::WATER)
    20.times { update_water }
    check("water turns lava into cobblestone", @world.get(lx, SKY_Y - 4, lz) == Block::COBBLE)
    set_block(lx + 1, SKY_Y - 4, lz, Block::AIR)
    set_block(lx, SKY_Y - 4, lz, Block::AIR)
    20.times { update_water }
  end

  # Builds a stone platform and shoots a pig on it with a full bow draw.
  def test_bow(bx, bz)
    @mobs.clear
    i = -2
    while i <= 12
      set_block(bx + i, SKY_Y - 2, bz, Block::STONE)
      i += 1
    end
    @player.x = bx + 0.5
    @player.y = SKY_Y - 1.0
    @player.z = bz + 0.5
    @player.yaw = 1.5708
    @player.pitch = -0.12
    @inv.clear
    @inv.add(Block::ARROW)
    pig = Mob.new(Mob::PIG, bx + 8.5, SKY_Y - 1.0, bz + 0.5, 3)
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
    full = Mob.new(Mob::ZOMBIE, bx + 2.5, SKY_Y - 1.0, bz + 0.5, 3)
    quick = Mob.new(Mob::ZOMBIE, bx + 2.5, SKY_Y - 1.0, bz + 0.5, 4)
    @mobs << full
    @mobs << quick
    @attack_time = 1.0
    @target_mob = 0
    left_button(0.0, true, true)
    @target_mob = 1
    left_button(0.0, true, true)
    check("a hit right after an attack does less damage", full.hp == 16.0 && quick.hp > 19.0 && quick.hp < 19.2)
    falling = Mob.new(Mob::ZOMBIE, bx + 2.5, SKY_Y - 1.0, bz + 0.5, 5)
    @mobs << falling
    @attack_time = 1.0
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
    @survival = survival
  end

  # Sneaking, walking off an edge, and the bed, on the platform from test_bow.
  def test_sneak_and_bed(bx, bz)
    # The platform is one block wide in z: sneaking toward its edge stays on it.
    @player.x = bx + 4.5
    @player.y = SKY_Y - 1.0
    @player.z = bz + 0.5
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    @player.yaw = 3.14159
    @player.flying = false
    @player.on_ground = true
    120.times { @player.update(@world, 1.0 / 60.0, 1.0, 0.0, false, true, false) }
    low = (@player.eye_y - @player.y - Player::SNEAK_EYE).abs < 0.01
    @mobs.clear
    set_block(bx + 6, SKY_Y - 1, bz, Block.bed_id(0, true))
    @time_of_day = 0.75
    day = @day
    use_bed(bx + 6, SKY_Y - 1, bz)
    check("sleeping in a bed skips the night and sets spawn", daylight > 0.35 && @spawn_x == bx + 6.5 && @day == day + 1)
    set_block(bx + 6, SKY_Y - 1, bz, Block::AIR)
    @time_of_day = 0.3
    check("sneaking stops at an edge", @player.y > SKY_Y - 1.1 && @player.z < bz + 1.4)
    120.times { @player.update(@world, 1.0 / 60.0, 1.0, 0.0, false, false, false) }
    check("walking without sneaking falls off", @player.y < SKY_Y - 2.0)
    check("a sneaking player's eyes are lower, and come back up", low && (@player.eye_y - @player.y - Player::EYE).abs < 0.01)
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
        set_block(wx + i, SKY_Y - 2, wz + k, Block::STONE)
        y = SKY_Y - 1
        while y <= SKY_Y + 4
          set_block(wx + i, y, wz + k, Block::AIR)
          y += 1
        end
        k += 1
      end
      i += 1
    end
    set_block(wx, SKY_Y - 1, wz, Block::WATER)
    set_block(wx, SKY_Y, wz, Block::WATER)
    set_block(wx + 1, SKY_Y - 1, wz, Block::WATER)
    set_block(wx + 1, SKY_Y, wz, Block::WATER)
    set_block(wx + 2, SKY_Y - 1, wz, Block::STONE)
    set_block(wx + 2, SKY_Y, wz, Block::STONE)
    @flow_queue.clear
    @player.x = wx + 0.5
    @player.y = SKY_Y - 1.0
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
      out = true if @player.on_ground && @player.y >= SKY_Y + 1.0 && @player.x + Player::HALF > wx + 2.0
    end
    check("a jump against the shore lifts the player out of the water", out)
  end

  # Monsters spawn only in the dark: under the sky at night, or under a
  # block, and never near a torch. The sky light follows the wiki's table.
  def test_dark
    time = @time_of_day
    raining = @weather.raining?
    @weather.set_now(false)
    @time_of_day = 0.25
    noon = sky_light
    @time_of_day = 0.55
    dusk = sky_light
    @time_of_day = 0.75
    midnight = sky_light
    @time_of_day = 0.25
    @weather.set_now(true)
    rain_noon = sky_light
    @weather.set_now(raining)
    @time_of_day = time
    check("the sky light is 15 at noon, 7 at tick 13200, 4 at midnight and 12 in rain", noon == 15 && dusk == 7 && midnight == 4 && rain_noon == 12)
    x = @spawn_x.floor + 40
    z = @spawn_z.floor + 40
    h = @world.height_at(x, z)
    open_day = dark?(x, h, z, 15)
    # At sky light 4, a random number from 0 to 7 lets half the tries pass.
    passes = 0
    200.times { passes += 1 if dark?(x, h, z, 4) }
    check("monsters do not spawn under the sky by day, and half the tries pass at night", !open_day && passes > 70 && passes < 130)
    # Sky light comes in from the side under the edge of a roof.
    set_block(x, h + 1, z, Block::STONE)
    under_roof = dark?(x, h, z, 15)
    # Walls on the four sides close the cell.
    walls = [[1, 0], [-1, 0], [0, 1], [0, -1]]
    walls.each { |w| set_block(x + w[0], h, z + w[1], Block::STONE) }
    closed = dark?(x, h, z, 15)
    check("sky light reaches under the edge of a roof, and not into a closed cell", !under_roof && closed)
    # A torch 2 steps away, behind the wall on the +x side.
    set_block(x + 2, h, z, Block::TORCH)
    behind_wall = dark?(x, h, z, 0)
    set_block(x + 1, h, z, Block::AIR)
    through_opening = dark?(x, h, z, 0)
    check("torch light does not go through a wall, and goes through an opening", behind_wall && !through_opening)
    set_block(x + 2, h, z, Block::AIR)
    walls.each { |w| set_block(x + w[0], h, z + w[1], Block::AIR) }
    set_block(x, h + 1, z, Block::AIR)
    set_block(x, h + 3, z, Block::OAK_LEAVES)
    under_leaves = dark?(x, h, z, 15)
    set_block(x, h + 3, z, Block::AIR)
    check("leaves let the daylight through", !under_leaves)
  end

  # A door does not stand on a door, and it does not close on a mob.
  def test_door_rules
    x = @spawn_x.floor + 50
    z = @spawn_z.floor + 56
    y = @world.height_at(x, z)
    set_block(x, y - 1, z, Block::STONE)
    set_block(x, y, z, Block.door_id(0, false, false))
    set_block(x, y + 1, z, Block.door_id(0, true, false))
    stacked = door_fits?(x, y + 2, z)
    toggle_door(x, y, z)
    @mobs.clear
    @mobs << Mob.new(Mob::ZOMBIE, x + 0.5, y.to_f, z + 0.5, 3)
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
    open_station(x + 2, y, z + 3, AT_FURNACE)
    f = open_furnace
    slots = f.slots
    @furnace_clock = 0.0
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
    @held_block = Block::OAK_PLANKS
    @held_count = 1
    click_furnace(Furnace::FUEL, true)
    update_furnaces(15.0)
    update_furnaces(1.0)
    cooled = slots.count(Furnace::OUTPUT) == 4 && f.progress == 60 && !f.lit?
    @held_block = Block::OAK_PLANKS
    @held_count = 1
    click_furnace(Furnace::FUEL, true)
    update_furnaces(7.0)
    resumed = slots.count(Furnace::OUTPUT) == 5 && f.progress == 0
    check("the progress goes back while a furnace is out, and new fuel continues it", cooled && resumed)
    # The burning plank burns to its end, but no new fuel burns without
    # something to smelt or room for the result.
    slots.move_stack(Furnace::OUTPUT, @inv, 0, INV)
    slots.move_stack(Furnace::INPUT, @inv, 0, INV)
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
    @held_block = Block::IRON_INGOT
    @held_count = 1
    click_furnace(Furnace::FUEL, true)
    not_fuel = @held_count == 1 && slots.count(Furnace::FUEL) == 2 && @message == "NOT A FUEL"
    @held_block = Block::DIRT
    click_furnace(Furnace::INPUT, true)
    not_smelted = @held_block == Block::DIRT && slots.block(Furnace::INPUT) == Block::IRON && @message == "THE FURNACE DOES NOT SMELT THAT"
    click_furnace(Furnace::OUTPUT, true)
    no_output = @held_block == Block::DIRT && slots.empty?(Furnace::OUTPUT)
    @held_count = 0
    @held_block = Block::AIR
    survival = @survival
    @survival = true
    @items.clear
    set_block(x + 2, y, z + 3, Block::AIR)
    dropped = ground_count(Block::IRON) == 4 && ground_count(Block::OAK_PLANKS) == 2 && @furnaces[World.key(x + 2, y, z + 3)].nil?
    @items.clear
    @survival = survival
    toggle_inventory
    check("the furnace slots take only what fits them, and a broken furnace drops what it holds", not_fuel && not_smelted && no_output && dropped)
    # A log smelts into coal, and coal burns for 1600 ticks.
    set_block(x + 2, y, z + 3, Block::FURNACE)
    open_station(x + 2, y, z + 3, AT_FURNACE)
    f = open_furnace
    @furnace_clock = 0.0
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
    plan = @world.plan_tree(sx, sy, z, Block::SPRUCE_WOOD)
    kinds = (0...plan.size / 4).map { |i| plan[i * 4 + 3] }
    spruce = kinds.include?(Block::SPRUCE_LOG) && kinds.include?(Block::SPRUCE_LEAVES) &&
             kinds.all? { |b| b == Block::SPRUCE_LOG || b == Block::SPRUCE_LEAVES || b == Block::DIRT }
    set_block(sx, sy + 2, z, Block::STONE)
    blocked = @world.plan_tree(sx, sy, z, Block::SPRUCE_WOOD).empty?
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
    two = @world.get(x, g, z) == Block.bed_id(1, false) && @world.get(x + 1, g, z) == Block.bed_id(0, true) && @inv.count(0) == 1
    set_block(x + 1, g, z, Block::AIR)
    gone = @world.get(x, g, z) == Block::AIR
    @inv.clear
    @inv.add(Block::FURNACE)
    @player.raycast(@world)
    place
    furnace = @world.get(x, g, z)
    set_block(x, g, z, Block::AIR)
    @inv.clear
    @inv.add(Block::DOOR)
    @player.raycast(@world)
    place
    door = @world.get(x, g, z) == Block.door_id(1, false, false) && @world.get(x, g + 1, z) == Block.door_id(1, true, false)
    set_block(x, g, z, Block::AIR)
    @survival = survival
    @inv.clear
    check("a bed takes two blocks along the view and breaks as a whole", blocked && two && gone)
    check("a furnace and a door turn their front to the player", furnace == Block.facing_id(Block::FURNACE, 1) && door)
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

  # A ladder lifts the player at 2.35 m/s on jump, holds the player on
  # Shift, and lets the player slide down at 3 m/s.
  def test_ladder
    x = @spawn_x.floor + 40
    z = @spawn_z.floor - 40
    y = @world.height_at(x, z)
    i = 0
    while i < 6
      set_block(x, y + i, z, Block.facing_id(Block::LADDER, 1))
      set_block(x + 1, y + i, z, Block::STONE)
      i += 1
    end
    p = Player.new(x + 0.5, y.to_f, z + 0.5)
    50.times { p.update(@world, 0.02, 0.0, 0.0, true, false, false) }
    up = (p.y - y - 2.35).abs < 0.05
    h = p.y
    50.times { p.update(@world, 0.02, 0.0, 0.0, false, true, false) }
    held = (p.y - h).abs < 0.05
    25.times { p.update(@world, 0.02, 0.0, 0.0, false, false, false) }
    slid = (h - p.y - 1.5).abs < 0.05
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
    check("a ladder climbs at 2.35 m/s on jump, holds on Shift, and slides down at 3 m/s", up && held && slid)
    check("forward on a ladder climbs onto the block at its top", top)
  end

  # A ladder hangs only on the side of a solid block, as a thin board on
  # that side, and it falls with the block.
  def test_ladder_wall
    x = @spawn_x.floor + 44
    z = @spawn_z.floor - 40
    g = @world.height_at(x, z) + 3
    [-2, -1, 0, 1].each do |dx|
      set_block(x + dx, g - 1, z, Block::STONE)
      set_block(x + dx, g, z, Block::AIR)
      set_block(x + dx, g + 1, z, Block::AIR)
    end
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
    @player.raycast(@world)
    place
    hung = @world.get(x, g, z) == Block.facing_id(Block::LADDER, 1)
    # A view ray across the middle of the cell misses the board.
    @player.x = x + 0.5
    @player.z = z - 1.5
    @player.yaw = Math::PI
    @player.raycast(@world)
    thin = !(@player.hit && @player.hx == x && @player.hy == g && @player.hz == z)
    set_block(x + 1, g, z, Block::AIR)
    fell = @world.get(x, g, z) == Block::AIR
    # On the top of a block, a ladder does not hang.
    @player.x = x - 1.5
    @player.z = z + 0.5
    @player.yaw = Math::PI / 2.0
    @player.pitch = -1.2
    @player.raycast(@world)
    place
    floor = @player.hy == g - 1 && @world.get(x - 1, g, z) == Block::AIR && @inv.count(0) == 1
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
    [0, 1, 2].each do |dx|
      set_block(x + dx, g - 1, z, Block::STONE)
      set_block(x + dx, g, z, Block::AIR)
      set_block(x + dx, g + 1, z, Block::AIR)
      set_block(x + dx, g + 2, z, Block::AIR)
    end
    set_block(x, g, z, Block.bed_id(0, true))
    set_block(x + 2, g, z, Block.facing_id(Block::CHEST, 3))
    p = Player.new(x + 0.5, g + 1.5, z + 0.5)
    60.times { p.update(@world, 1.0 / 60.0, 0.0, 0.0, false, false, false) }
    bed = (p.y - (g + 0.5625)).abs < 0.001 && p.on_ground
    p = Player.new(x + 2.5, g + 1.5, z + 0.5)
    60.times { p.update(@world, 1.0 / 60.0, 0.0, 0.0, false, false, false) }
    chest = (p.y - (g + 0.875)).abs < 0.001
    m = Mob.new(Mob::PIG, x + 0.5, g + 1.5, z + 0.5, 1)
    m.move(@world, 0.0, -1.0, 0.0)
    pig = (m.y - (g + 0.5625)).abs < 0.001
    set_block(x, g, z, Block::AIR)
    set_block(x + 2, g, z, Block::AIR)
    check("the player and a mob land on the top of a bed and of a chest", bed && chest && pig)
  end

  # Water spreads 7 blocks over a floor and drains without its source.
  def test_water
    wx = @spawn_x.floor
    wz = @spawn_z.floor + 3
    i = -10
    while i <= 10
      set_block(wx + i, SKY_Y - 5, wz, Block::STONE)
      set_block(wx + i, SKY_Y - 4, wz, Block::AIR)
      i += 1
    end
    @flow_queue.clear
    set_block(wx, SKY_Y - 4, wz, Block::WATER)
    40.times { update_water }
    check("water spreads 7 blocks over a floor", Block::WATER_LEVEL[@world.get(wx + 7, SKY_Y - 4, wz)] == 1 && @world.get(wx + 8, SKY_Y - 4, wz) == Block::AIR && Block::WATER_LEVEL[@world.get(wx - 3, SKY_Y - 4, wz)] == 5)
    set_block(wx, SKY_Y - 4, wz, Block::AIR)
    40.times { update_water }
    check("water drains when its source is gone", @world.get(wx + 3, SKY_Y - 4, wz) == Block::AIR && @world.get(wx - 6, SKY_Y - 4, wz) == Block::AIR)
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
    @inv.add(Block::DIAMOND)
    @hotbar[0] = Block::GLASS
    new_world
    h = @world.height_at(@player.x.floor, @player.z.floor)
    check("a new world has a new seed and the player stands on it", @seed != old_seed && h > 0 && (@player.y - h).abs < 1.5 && @mobs.size > 0)
    check("a new world starts with an empty inventory", @inv.room_for(Block::DIRT) == INV * Slots::STACK && @hotbar == HOTBAR_START)
  end
end
