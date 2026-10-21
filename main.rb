# Game setup, spawn and respawn, the update step, and the game loop.
require_relative "game/gfx"
require_relative "game/log"
require_relative "game/rng"
require_relative "game/textures"
require_relative "game/block"
require_relative "game/biome"
require_relative "game/noise"
require_relative "game/world"
require_relative "game/terrain"
require_relative "game/trees"
require_relative "game/light"
require_relative "game/mesher"
require_relative "game/tint"
require_relative "game/ray"
require_relative "game/player"
require_relative "game/vitals"
require_relative "game/camera"
require_relative "game/ui"
require_relative "game/mesh3"
require_relative "game/mobs"
require_relative "game/natural_spawner"
require_relative "game/plants"
require_relative "game/flow_queue"
require_relative "game/fluids"
require_relative "game/arrow"
require_relative "game/egg"
require_relative "game/item"
require_relative "game/falling_block"
require_relative "game/boat"
require_relative "game/sounds"
require_relative "game/music"
require_relative "game/clouds"
require_relative "game/lod"
require_relative "game/far_terrain"
require_relative "game/chunk_meshes"
require_relative "game/constants"
require_relative "game/save"
require_relative "game/block_changes"
require_relative "game/slots"
require_relative "game/chest"
require_relative "game/chests"
require_relative "game/furnace"
require_relative "game/recipe"
require_relative "game/recipe_book"
require_relative "game/inventory"
require_relative "game/items"
require_relative "game/boats"
require_relative "game/hand"
require_relative "game/particles"
require_relative "game/weather"
require_relative "game/clock"
require_relative "game/sky"
require_relative "game/actions"
require_relative "game/combat"
require_relative "game/render"
require_relative "game/hud"
require_relative "game/options"
require_relative "game/menu"
require_relative "game/command"
require_relative "game/chat"
require_relative "game/commands"
require_relative "game/testing"

class Game
  def initialize # rubocop:todo Metrics/MethodLength
    Log.setup(ENV["LOG"] || "")
    @seed = (ENV["SEED"] || "1337").to_i
    @max_frames = (ENV["FRAMES"] || "0").to_i
    # A run with FRAMES set ignores the mouse and the keys, so the person at
    # the computer does not move the camera in a screenshot or a benchmark.
    @scripted = @max_frames > 0
    @autopilot = !ENV["AUTOPILOT"].nil?
    # AUTOPILOT=far flies in a straight line, so new chunks stream in.
    @autopilot_far = ENV["AUTOPILOT"] == "far"
    @shot = ENV["SHOT"] || ""
    # setup builds the World (reset_world) once it knows the seed: that of
    # the save, or @seed for a new world.
    @camera = Camera.new
    @ui = Ui.new
    @dyn = Mesh3.new
    @uniforms = Array.new(UNIFORMS, 0.0)
    @hotbar = HOTBAR_START.dup
    @inv = Slots.new(INV)
    @recipe_book = RecipeBook.new
    # The furnaces, by World.key, and the time not yet ticked.
    @furnaces = {}
    @furnace_clock = 0.0
    # The station whose screen is open (BY_HAND, AT_TABLE or AT_FURNACE of Recipe),
    # and its cell.
    @station = Recipe::BY_HAND
    @station_x = 0
    @station_y = 0
    @station_z = 0
    # The cell that fluid_in_view found.
    @fluid_x = 0
    @fluid_y = 0
    @fluid_z = 0
    # The stack in the hand while the inventory is open.
    @held = Slots.new(1)
    @chests = Chests.new
    # The block changes of Plants: x, y, z and the block, for each one.
    @changes = Array.new(0, 0)
    @alive_time = 0.0
    @anim_time = 0.0
    # The slider that the mouse drags, or -1.
    @menu_drag = -1
    # True after one click on NEW WORLD of the title screen.
    @menu_confirm = false
    # Seconds until a second click on NEW WORLD counts.
    @confirm_wait = 0.0
    @quit = false
    # The title screen is open (game/menu.rb).
    @title_open = false
    @last_w = -1.0
    @w_sprint = false
    # When jump was last pressed, for a double press that starts or stops
    # flying (FLY_TAP).
    @last_jump = -1.0
    @slot = 0
    @captured = false
    @clock = Clock.new((ENV["TIME"] || "0.3").to_f, (ENV["DAY"] || "0").to_i)
    now = Time.now
    @halloween = ENV["HALLOWEEN"] == "1" || (now.month == 10 && now.day == 31)
    @action_cooldown = 0.0
    # True from a click that goes back to the game until the player lets
    # the mouse buttons go (Game#resume).
    @wait_for_release = false
    @message = ""
    @message_time = 0.0
    @chat = Chat.new
    @fps = 0.0
    @cpu_ms = 0.0
    @faces_drawn = 0
    @cpu_end = 0
    @survival = ENV["MODE"] == "survival"
    @loaded = [""]
    @load_error = ""
    @changed = false
    # A scripted run (FRAMES) does not change the save or the options.
    @save_on_quit = ENV["FRAMES"].nil? || !ENV["SAVE"].nil?
    prefix = file_prefix
    @save_path = prefix + SAVE_PATH
    @bad_save_path = prefix + BAD_SAVE_PATH
    @options = Options.new(prefix + OPTIONS_PATH)
    @options.read_file if @save_on_quit
    @options.read_option("view", ENV["VIEW"]) if ENV["VIEW"]
    @sound = false
    @demo = !ENV["DEMO"].nil?
    @clouds = Clouds.new(@seed)
    @cloud_drift = 0.0
    @bob = 0.0
    # The half angle of the view in radians. It follows the option and widens in a sprint.
    @fov = @options.half_fov
    @inventory_open = !ENV["INVENTORY"].nil?
    @step_dist = 0.0
    @was_swimming = false
    @last_sound = -1
    @particles = Particles.new(@seed)
    @arrows = []
    @eggs = []
    @items = []
    @falling = []
    @boats = []
    # The index in @boats of the boat that the player rides, or -1.
    @riding = -1
    # The boat in the crosshair (Game#find_target_boat), or -1, and its distance.
    @target_boat = -1
    @target_boat_t = 0.0
    @draw_time = -1.0
    @eat_time = -1.0
    @vitals = Vitals.new
    @damage_flash = 0.0
    @mining = false
    @mine_x = 0
    @mine_y = 0
    @mine_z = 0
    @mine_progress = 0.0
    @dig_wait = 0.0
    @mine_delay = 0.0
    @mobs = []
    # The cave sounds (update_cave_sound): seconds to the next check, and
    # the fear that the darkness built up.
    @cave_timer = 0.0
    @cave_fear = 0.0
    @ambient_wait = [0.0, 0.0, 0.0]
    @rng = Rng.new(@seed * 7 + 1)
    # The clock seeds the music, so each session plays its own order, as
    # in Minecraft. Near seeds give near first numbers in Rng, so a hash
    # mixes the seconds first.
    @music = Music.new(Noise.hash3(Time.now.to_i, 0, 0, 60))
    @weather = Weather.new(@seed * 3 + 2, !ENV["RAIN"].nil?)
    @sky = Sky.new(@clock, @weather, @camera)
    @target_mob = -1
    @swing = 0.0
    # The axes and the move of the held model (see turn_hand).
    @hand_frame = Array.new(12, 0.0)
    # Seconds since the last attack, broken block or new item in the hand
    # (see attack_charge).
    @attack_time = 0.0
    # The block in the hand model, and how far down the model still is after
    # the selection changed (1 to 0).
    @hand_block = 0
    @equip = 0.0
    # The sway of the held item while the player walks (game/hand.rb).
    @hand_dx = 0.0
    @hand_dy = 0.0
    @hand_walk = 0.0
    # Where the held model starts in @dyn (see gfx_dyn).
    @hand_at = 0
  end

  # CAM=x,y,z,yaw,pitch puts a flying camera somewhere, for screenshots.
  def apply_cam
    cam = ENV["CAM"]
    if cam
      parts = cam.split(",")
      @player.x = parts[0].to_f
      @player.y = parts[1].to_f
      @player.z = parts[2].to_f
      @player.yaw = parts[3].to_f
      @player.pitch = parts[4].to_f
      @player.flying = true
    end
  end

  # The C layer in gfx.rb has fixed sizes. Stop at start if one no longer
  # matches the Ruby constants, not later with a wrong picture.
  def check_gfx_limits
    abort "gfx.rb LEVELS is not #{FarTerrain::LEVELS}" if Gfx.gfx_limit(0) != FarTerrain::LEVELS
    abort "gfx.rb COLUMNS is not #{Mesher::COLUMNS}" if Gfx.gfx_limit(1) != Mesher::COLUMNS
    abort "the world ring is not Mesher::COLUMNS wide" if WX != Mesher::COLUMNS || Lod::TRING * Lod::CELLS != Mesher::COLUMNS
    abort "gfx.rb MAX_SLOTS is too small" if Gfx.gfx_limit(2) < LOD_SLOT0 + FarTerrain::LEVELS * FarTerrain::TILE_SLOTS
    abort "gfx.rb UNIFORMS is not #{UNIFORMS}" if Gfx.gfx_limit(3) != UNIFORMS
    abort "gfx.rb TINT_SIZE is not #{Tint::SIZE}" if Gfx.gfx_limit(4) != Tint::SIZE
    abort "gfx.rb SOUNDS is too small" if Gfx.gfx_limit(5) < Sfx::FILES.size
    # The fields of a face record must fit in its two 32-bit words, and the
    # y field must hold every y of the world.
    abort "a face record is wider than 32 bits" if Mesher::FACE_AT + Mesher::FACE_BITS > 32 ||
                                                   Mesher::TINT_AT + Mesher::TINT_BITS > 32 || Lod::BIOME_AT + Lod::BIOME_BITS > 32
    abort "Mesher::Y_BITS is too narrow for WY" if WY > 1 << Mesher::Y_BITS
    abort "Mesher::SHAPE_BITS is too narrow for Block::SHAPE_BOX" if Block::SHAPE_BOX.size / 6 > Mesher::TORCH_SHAPE
  end

  def setup # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    vsync = ENV["NOVSYNC"] ? 0 : 1
    Gfx.gfx_shader_defines(Mesher.shader_defines + Lod.shader_defines + Block.shader_defines + Clouds.shader_defines)
    abort "graphics init failed" unless Gfx.gfx_init(1280, 720, vsync, @scripted ? 1 : 0)
    check_gfx_limits
    Gfx.gfx_fullscreen(1) if @options.fullscreen
    px = Tex.build
    abort "texture upload failed" unless Gfx.gfx_textures(px, Tex::LAYERS)
    @dyn.opaque = Tex.opaque(px)
    abort "skin upload failed" unless Gfx.gfx_skins(Tex.skins, Tex::SKIN_FILES.size)
    upload_clouds
    @sound = ENV["MUTE"].nil? && Sfx.init
    puts "audio #{@sound ? "on" : "off"}"
    t0 = Gfx.gfx_ns
    loaded = ENV["NEW"].nil? && load
    keep_bad_save if !loaded && ENV["NEW"].nil?
    reset_world unless loaded
    if loaded
      @player = Player.new(0.5, 80.0, 0.5)
      apply_loaded
    else
      spawn
    end
    apply_cam
    @chunk_meshes.stream(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    t1 = Gfx.gfx_ns
    # Collect the world generation garbage now, not in the first minute of play.
    GC.start
    puts "world: #{loaded ? "load" : "generate"} and mesh the nearest #{(SYNC_R * 2 + 1) * (SYNC_R * 2 + 1)} chunks in #{((t1 - t0) / 1.0e6).round} ms"
    show_mobs if ENV["SHOWMOBS"]
    show_items if ENV["SHOWITEMS"]
    show_boats if ENV["SHOWBOATS"]
    @spawner.spawn_animals(@mobs, @player)
    # A screenshot, a benchmark or the self-test starts in the world.
    if !@scripted && !@autopilot && ENV["SELFTEST"].nil?
      open_title
    else
      Gfx.in_capture(1) unless @scripted
      @captured = true
    end
    say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
  end

  # NEW WORLD on the title screen: a fresh world from a new seed, same game mode.
  # The player starts again with an empty inventory.
  def new_world
    @seed = (Gfx.gfx_ns / 1000) % 1000000
    reset_world
    @inv.clear
    @hotbar = HOTBAR_START.dup
    @chests.clear
    @recipe_book = RecipeBook.new
    @furnaces = {}
    @mobs.clear
    @arrows.clear
    @eggs.clear
    @items.clear
    @boats.clear
    @riding = -1
    @clouds = Clouds.new(@seed)
    upload_clouds
    @clock.day = 0
    spawn
    respawn
    @spawner.spawn_animals(@mobs, @player)
    @changed = true
    say("NEW WORLD: SEED #{@seed}")
  end

  # Finds dry land near x = z = 0 and puts a new player there. The origin
  # can be at sea, so the noise first finds land on squares around it, 64
  # blocks apart. Then the loaded blocks give dry land near that point.
  def spawn # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    ox = 0
    oz = 0
    r = 0
    terrain = @world.terrain
    while !terrain.land?(ox, oz) && r < 4096
      r += 64
      k = -r
      while k <= r && !terrain.land?(ox, oz)
        if terrain.land?(k, -r)
          ox = k
          oz = -r
        elsif terrain.land?(k, r)
          ox = k
          oz = r
        elsif terrain.land?(-r, k)
          ox = -r
          oz = k
        elsif terrain.land?(r, k)
          ox = r
          oz = k
        end
        k += 64
      end
    end
    @chunk_meshes.stream(ox >> 4, oz >> 4, -1, SYNC_R)
    best_x = ox
    best_z = oz
    r = 0
    found = false
    while r < (SYNC_R - 1) * CHUNK && !found
      dx = -r
      while dx <= r && !found
        dz = -r
        while dz <= r && !found
          x = ox + dx
          z = oz + dz
          if @world.dry_land?(x, z) && @world.dry_land?(x + 3, z) && @world.dry_land?(x - 3, z) && @world.dry_land?(x, z + 3) && @world.dry_land?(x, z - 3)
            best_x = x
            best_z = z
            found = true
          end
          dz += 1
        end
        dx += 1
      end
      r += 1
    end
    h = @world.height_at(best_x, best_z)
    @spawn_x = best_x + 0.5
    @spawn_z = best_z + 0.5
    @player = Player.new(@spawn_x, h + 0.01, @spawn_z)
    Log.debug(Log::WORLD) { "spawn at #{best_x} #{h} #{best_z}#{found ? "" : ", but no dry land was near"}" }
  end

  def respawn
    @chunk_meshes.stream(@spawn_x.floor >> 4, @spawn_z.floor >> 4, -1, SYNC_R)
    h = @world.height_at(@spawn_x.floor, @spawn_z.floor)
    @player.move_to(@spawn_x, h + 0.01, @spawn_z)
    Log.debug(Log::WORLD) { "respawn at #{@spawn_x.floor} #{h} #{@spawn_z.floor}" }
    @vitals = Vitals.new
    @alive_time = 0.0
    @riding = -1
  end

  # The self-test runs with no sound, so it reads @last_sound.
  def play(id, volume)
    @last_sound = id
    Gfx.au_play(id, volume * @options.volume, 0.0) if @sound
  end

  # Plays a sound that comes from x, y, z and reaches range blocks.
  def play_at(id, x, y, z, gain, range)
    Gfx.au_play(id, near_volume(x, y, z, gain, range) * @options.volume, pan_to(x, y, z)) if @sound
  end

  # Volume for a sound at x, y, z: fades to silence at range blocks.
  def near_volume(x, y, z, gain, range)
    dx = x - @player.x
    dy = y - @player.eye_y
    dz = z - @player.z
    v = 1.0 - Math.sqrt(dx * dx + dy * dy + dz * dz) / range
    v > 0.0 ? v * gain : 0.0
  end

  # Pan for a sound at x, y, z: -1.0 is to the left of the player, 1.0 is
  # to the right, and 0.0 is ahead, behind, above or below.
  def pan_to(x, y, z)
    dx = x - @player.x
    dy = y - @player.eye_y
    dz = z - @player.z
    dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
    return 0.0 if dist < 0.001
    (dx * Math.cos(@player.yaw) + dz * Math.sin(@player.yaw)) / dist
  end

  # Starts a track when Music says so, and feeds the track that plays. The
  # music goes on in the pause menu, as in Minecraft. At a volume of 0 the
  # track stops.
  def update_music(dt)
    return unless @sound
    volume = @options.volume * @options.music
    if volume <= 0.0
      Gfx.au_music_stop
      return
    end
    y = @player.eye_y
    underground = y < SEA && !@world.under_sky?(@player.x, y, @player.z)
    track = @music.next_track(dt, Gfx.au_music_playing, underground, @clock.time_of_day >= 0.5)
    Music.start(track) if track >= 0
    Gfx.au_music_feed(volume)
  end

  def say(text)
    @message = text
    @message_time = 2.0
  end

  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_game(dt) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    if @title_open
      @player.yaw += TITLE_TURN * dt
      @confirm_wait -= dt
    end
    return if paused?

    fwd = 0.0
    strafe = 0.0
    jump = false
    down = false
    sprint = false
    if @captured && !@vitals.dead? && !@chat.open?
      fwd += 1.0 if Gfx.in_key(Key::W)
      fwd -= 1.0 if Gfx.in_key(Key::S)
      strafe += 1.0 if Gfx.in_key(Key::D)
      strafe -= 1.0 if Gfx.in_key(Key::A)
      jump = Gfx.in_key(Key::SPACE)
      down = Gfx.in_key(Key::LSHIFT)
      # Double-tap W to sprint until W is released.
      if Gfx.in_key_pressed(Key::W)
        @w_sprint = @anim_time - @last_w < 0.3 && @anim_time > @last_w
        @last_w = @anim_time
      end
      @w_sprint = false unless Gfx.in_key(Key::W)
      tap_to_fly if Gfx.in_key_pressed(Key::SPACE)
      sprint = Gfx.in_key(Key::LCTRL) || @w_sprint
      # The player sprints only forward. The wiki does not confirm this.
      sprint = false if fwd <= 0.0 || (@survival && !@vitals.can_sprint?) || using_item?
    end
    if @autopilot
      @player.flying = true
      @player.yaw += dt * 0.25 unless @autopilot_far
      @player.pitch = -0.25
      fwd = 1.0
      sprint = true
      @player.y = 72.0
    end
    @player.slowed = using_item?
    # Shift gets out of a boat. minecraft.wiki/w/Boat
    leave_boat if riding? && down
    remaining = riding? ? 0.0 : dt
    while remaining > 0.0
      step = remaining > 0.02 ? 0.02 : remaining
      fell = @player.update(@world, step, fwd, strafe, jump, down, sprint)
      hurt((fell - 3.0).ceil, Sfx::FALL) if fell > 3.5
      if @survival
        moved = @player.speed * step
        @vitals.move(moved, sprint && @player.on_ground, @player.in_water, @player.jumped)
      end
      remaining -= step
    end
    # A flying player who comes down onto a block stops flying, as in Java
    # Edition. minecraft.wiki/w/Flying
    @player.flying = false if @player.on_ground && !@autopilot
    update_boats(dt, fwd, strafe)
    @player.raycast(@world)
    # Water splashes and swishes, but lava makes no sound when the player
    # enters it or moves in it. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
    swimming = @player.in_water && !@player.in_lava
    if (@player.on_ground || swimming) && !@player.in_lava && !@player.flying
      @step_dist += @player.speed * dt
      if @step_dist > Player::STEP
        @step_dist = 0.0
        ground = MATERIAL_STEP[material(@world.get(@player.x.floor, (@player.y - 0.1).floor, @player.z.floor))]
        play(swimming ? Sfx::STEP_WATER : ground, 0.35)
      end
    end
    play(Sfx::SPLASH, 0.6) if swimming && !@was_swimming && !@player.flying
    @was_swimming = swimming
    @particles.update(@world, dt)
    @particles.sample_fire(@world, @player.x, @player.y, @player.z, dt)
    grow_plants(dt)
    decay_leaves(dt)
    spread_grass(dt)
    kill_covered_grass(dt)
    update_furnaces(dt)
    update_items(dt)
    update_falling(dt)
    note_seen if @survival
    @weather.update_weather(dt)
    @weather.splash(@particles, @world, @player, dt) if @weather.rain > 0.0
    Gfx.au_loop(Sfx::RAIN, @weather.sound(@world, @player) * @options.volume) if @sound
    Gfx.gfx_rain(@weather.mesh.v, @weather.mesh.count) if @weather.build_quads(@world, @player, dt)
    @cloud_drift = (@cloud_drift + dt * 1.2) % Clouds::PERIOD
    @anim_time = (@anim_time + dt) % 1000.0
    speed = @player.speed
    @bob += speed * dt * 2.6
    target_fov = @options.half_fov * (speed > 5.0 ? 1.1 : 1.0)
    @fov += (target_fov - @fov) * (6.0 * dt).clamp(0.0, 1.0)
    @clock.advance(dt)
    @message_time -= dt
    @chat.age(dt)
    @damage_flash -= dt
    @swing -= dt
    @attack_time += dt
    update_hand(dt)
    update_cave_sound(dt)
    update_block_sounds(dt)
    update_survival(dt)
    update_mobs(dt)
    update_fluids(dt)
    find_target_boat
    find_target_mob
  end

  # A second press of jump within FLY_TAP starts or stops flying in
  # creative, as in Minecraft. A third press starts a new double press.
  def tap_to_fly
    if !@survival && @anim_time - @last_jump < FLY_TAP && @anim_time > @last_jump
      @player.flying = !@player.flying
      @last_jump = -1.0
    else
      @last_jump = @anim_time
    end
    nil
  end

  def update_survival(dt)
    return unless @survival && !@vitals.dead?
    @alive_time += dt
    p = @player
    feet = @world.get(p.x.floor, (p.y + 0.2).floor, p.z.floor)
    eyes = @world.get(p.x.floor, p.eye_y.floor, p.z.floor)
    in_lava = Block.lava?(feet) || Block.lava?(eyes)
    under_water = Block.water?(eyes)
    # Water and rain put the fire out.
    if !in_lava && @vitals.burning? && (under_water || Block.water?(feet) || (@weather.wet? && @world.under_sky?(p.x, p.eye_y, p.z)))
      @vitals.douse
      play(Sfx::FIZZ, 0.6)
    end
    on_cactus = @world.cactus_in_box?(p.x, p.y, p.z, Player::HALF, Player::TALL)
    felt_hurt(Sfx::HURT) if @vitals.update_vitals(dt, in_lava, on_cactus, under_water)
    @particles.hunger(p.x, p.eye_y, p.z, p.yaw, dt) if @vitals.hunger_effect?
  end

  # The pause screen is open. The world stops, as in Minecraft, but not on
  # the death screen or in the inventory.
  def paused? = !@captured && !@inventory_open && !@vitals.dead?

  # A cave sound now and then below the sea level, as in VoxeLibre
  # (vl_cavesounds). Each 3 seconds the fear grows by 3 * (15 - light) / 15,
  # so after 5 minutes of full darkness a random cave sound plays.
  def update_cave_sound(dt)
    @cave_timer -= dt
    return if @cave_timer > 0.0
    @cave_timer = 3.0
    x = @player.x.floor
    y = @player.eye_y.floor
    z = @player.z.floor
    return if y >= SEA || !@world.inside?(x, y, z)
    sky = Light.sky(@clock.ticks, raining: @weather.raining?)
    light = @light.level(x, y, z, sky, @light.lamp_near?(x, y, z), sky)
    light = 15 if light < 0
    @cave_fear += 3.0 * (15 - light) / 15.0
    return if @cave_fear < 300.0
    @cave_fear = 0.0
    play(Sfx::CAVE + (@rng.rand01 * Sfx::CAVES).to_i, 0.6)
  end

  # Looks at random blocks near the player, and plays the sound of each one
  # that makes a sound, at its AMBIENT_RATE. Each sound waits for its last
  # clip to end, so the long clips do not take all the voices.
  def update_block_sounds(dt)
    AMBIENT.size.times { |i| @ambient_wait[i] -= dt }
    r = SOUND_RANGE.to_i
    span = r * 2 + 1
    blocks = (span * span * span).to_f
    sx = @player.x.floor - r
    sy = @player.y.floor - r
    sz = @player.z.floor - r
    (dt * AMBIENT_SAMPLES + @rng.rand01).to_i.times do
      x = sx + (@rng.rand01 * span).to_i
      y = sy + (@rng.rand01 * span).to_i
      z = sz + (@rng.rand01 * span).to_i
      k = block_sound(x, y, z)
      next if k < 0 || @ambient_wait[k] > 0.0 || @rng.rand01 >= AMBIENT_RATE[k] * blocks / AMBIENT_SAMPLES
      @ambient_wait[k] = Gfx.au_seconds(AMBIENT[k])
      play_at(AMBIENT[k], x + 0.5, y + 0.5, z + 0.5, AMBIENT_VOLUME[k], SOUND_RANGE)
    end
  end

  # The index in AMBIENT of the sound that block x, y, z makes, or -1.
  def block_sound(x, y, z)
    b = @world.get(x, y, z)
    return 0 if Block.lava?(b) && @world.get(x, y + 1, z) == Block::AIR
    return 1 if Block.water?(b) && b != Block::WATER
    return 2 if Block.furnace_lit?(b)
    -1
  end

  # True while the player eats or draws the bow.
  def using_item? = @eat_time >= 0.0 || @draw_time >= 0.0

  # The self-test writes and deletes its files in the temporary folder, so
  # that it never changes the save or the options of the player.
  def file_prefix
    return "" unless ENV["SELFTEST"]
    dir = ENV["TMPDIR"] || "/tmp"
    dir += "/" unless dir.end_with?("/")
    "#{dir}spinelcraft-selftest-"
  end

  # Chunks to load around the player for the view distance: the meshed ones
  # (one ring less) then reach past the fog.
  def view_radius = (((detail_view + 20.0) / CHUNK).ceil + 1).clamp(SYNC_R, ChunkMeshes::LOAD_R)

  def detail_view = @options.view < FarTerrain::DETAIL_VIEW ? @options.view : FarTerrain::DETAIL_VIEW

  def run # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    setup
    if ENV["SELFTEST"]
      ok = self_test
      Gfx.gfx_quit
      exit(1) unless ok
      return
    end
    last = Gfx.gfx_ns
    frames = 0
    fps_frames = 0
    fps_time = 0.0
    cpu_sum = 0.0
    total_cpu = 0.0
    max_cpu = 0.0
    max_frame = 0.0
    slow_frames = 0
    started = last
    until Gfx.in_poll || @quit
      now = Gfx.gfx_ns
      dt = (now - last) / 1.0e9
      dt = 0.05 if dt > 0.05
      last = now
      handle_input(dt) unless @scripted
      demo(frames) if @demo
      update_game(dt)
      update_music(dt)
      t_stream = Gfx.gfx_ns
      @chunk_meshes.stream(@player.x.floor >> 4, @player.z.floor >> 4, STREAM_BUDGET_NS, view_radius)
      t_lod = Gfx.gfx_ns
      left = STREAM_BUDGET_NS - (t_lod - t_stream)
      @far.build_tiles(@player.x.floor.to_i, @player.z.floor.to_i, @options.view, left > 500_000 ? left : 500_000)
      t_flush = Gfx.gfx_ns
      @chunk_meshes.flush
      t_render = Gfx.gfx_ns
      render
      cpu = (@cpu_end - now) / 1.0e6
      if cpu > Log::SLOW_MS
        Log.debug(Log::FRAME) do
          "frame #{frames}: #{cpu.round(2)} ms of CPU. update #{((t_stream - now) / 1.0e6).round(2)}, chunks #{((t_lod - t_stream) / 1.0e6).round(2)}, " \
            "far tiles #{((t_flush - t_lod) / 1.0e6).round(2)}, remesh #{((t_render - t_flush) / 1.0e6).round(2)}, render #{((@cpu_end - t_render) / 1.0e6).round(2)}"
        end
      end
      max_cpu = cpu if cpu > max_cpu && frames > 10
      frame_ms = dt * 1000.0
      max_frame = frame_ms if frame_ms > max_frame && frames > 10
      slow_frames += 1 if frame_ms > 12.0 && frames > 10
      cpu_sum += cpu
      total_cpu += cpu
      fps_frames += 1
      fps_time += dt
      if fps_time >= 0.5
        @fps = fps_frames / fps_time
        @cpu_ms = cpu_sum / fps_frames
        fps_frames = 0
        fps_time = 0.0
        cpu_sum = 0.0
      end
      frames += 1
      Gfx.gfx_screenshot(@shot) if @shot != "" && frames == @max_frames - 1
      break if @max_frames > 0 && frames >= @max_frames
    end
    if @save_on_quit
      save
      @options.write_file
    end
    elapsed = (Gfx.gfx_ns - started) / 1.0e9
    puts "gpu_wait_ms=#{Gfx.gfx_gpu_ms.round(2)}" if ENV["GPUTIME"]
    puts "size=#{Gfx.gfx_width}x#{Gfx.gfx_height} frames=#{frames} avg_fps=#{(frames / elapsed).round(1)} avg_cpu_ms=#{(total_cpu / frames).round(3)} max_cpu_ms=#{max_cpu.round(2)} max_frame_ms=#{max_frame.round(1)} slow_frames=#{slow_frames} health=#{@vitals.health} dead=#{@vitals.dead?} mobs=#{@mobs.size}"
    Gfx.gfx_quit
  end
end

Game.new.run
