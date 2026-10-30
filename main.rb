# Game setup, spawn and respawn, the update step, and the game loop.
require_relative "game/gfx"
require_relative "game/log"
require_relative "game/time_histogram"
require_relative "game/frame_stats"
require_relative "game/line_limit"
require_relative "game/perf_log"
require_relative "game/rng"
require_relative "game/textures"
require_relative "game/block"
require_relative "game/biome"
require_relative "game/noise"
require_relative "game/world"
require_relative "game/terrain"
require_relative "game/trees"
require_relative "game/ores"
require_relative "game/treasure_map"
require_relative "game/caves"
require_relative "game/chunk_generator"
require_relative "game/light"
require_relative "game/graphics_mode"
require_relative "game/mesher"
require_relative "game/tint"
require_relative "game/ray"
require_relative "game/controls"
require_relative "game/player"
require_relative "game/voxel_walk"
require_relative "game/block_target"
require_relative "game/vitals"
require_relative "game/game_mode"
require_relative "game/melee_attack"
require_relative "game/screen"
require_relative "game/camera"
require_relative "game/color"
require_relative "game/ui"
require_relative "game/mesh3"
require_relative "game/sounds"
require_relative "game/love"
require_relative "game/mobs"
require_relative "game/animal"
require_relative "game/monster"
require_relative "game/natural_spawner"
require_relative "game/breeding"
require_relative "game/plants"
require_relative "game/flow_queue"
require_relative "game/fluids"
require_relative "game/arrow"
require_relative "game/egg"
require_relative "game/item"
require_relative "game/falling_block"
require_relative "game/boat"
require_relative "game/music"
require_relative "game/clouds"
require_relative "game/lod"
require_relative "game/far_terrain"
require_relative "game/chunk_meshes"
require_relative "game/block_sound"
require_relative "game/constants"
require_relative "game/save_file"
require_relative "game/save"
require_relative "game/block_changes"
require_relative "game/slots"
require_relative "game/armor"
require_relative "game/icon_row"
require_relative "game/effect_icon"
require_relative "game/chest"
require_relative "game/chests"
require_relative "game/loot_pool"
require_relative "game/treasure"
require_relative "game/furnace"
require_relative "game/furnaces"
require_relative "game/recipe"
require_relative "game/recipe_book"
require_relative "game/inventory"
require_relative "game/items"
require_relative "game/boats"
require_relative "game/held_item"
require_relative "game/particles"
require_relative "game/spell"
require_relative "game/weather"
require_relative "game/lightning"
require_relative "game/storm"
require_relative "game/clock"
require_relative "game/sky"
require_relative "game/bed"
require_relative "game/actions"
require_relative "game/combat"
require_relative "game/render"
require_relative "game/hud"
require_relative "game/options"
require_relative "game/menu"
require_relative "game/command"
require_relative "game/chat"
require_relative "game/console"
require_relative "game/testing"
require_relative "game/house"
require_relative "game/demo"

class Game
  # What Console reads and changes. A new world replaces some of it.
  attr_reader :player, :treasure, :seed, :chunk_meshes, :game_mode, :inv, :hotbar, :slot, :mobs, :rng

  def initialize # rubocop:todo Metrics/MethodLength
    Log.setup(ENV["LOG"] || "")
    @seed = (ENV["SEED"] || "1337").to_i
    @max_frames = (ENV["FRAMES"] || "0").to_i
    @demo = !ENV["DEMO"].nil?
    # The state of the demo reel (game/demo.rb).
    @demo_time = 0.0
    @demo_scene = -1
    @demo_left = false
    @demo_house = nil
    @demo_build = []
    @demo_built = 0
    @demo_animals = []
    @demo_monsters = []
    # A run with FRAMES or DEMO set ignores the mouse and the keys, so the
    # person at the computer does not move the camera in a screenshot, a
    # benchmark or the demo reel.
    @scripted = @max_frames > 0 || @demo
    # RECORD=path writes each frame to path. Each frame then moves the game
    # on by 1 / RECORD_FPS seconds, however long it takes to draw and save.
    @record = ENV["RECORD"] || ""
    @autopilot = !ENV["AUTOPILOT"].nil?
    # BEACONS=1 draws a beam of light over each treasure chest that is not
    # looted (Game#draw_beacons), to find them in a playtest.
    @beacons = !ENV["BEACONS"].nil?
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
    @armor = Armor.new
    @heart_row = IconRow.new(@ui, Tex::HEART, Tex::HEART_EMPTY)
    @armor_row = IconRow.new(@ui, Tex::ARMOR, Tex::ARMOR_EMPTY)
    @fire_resistance_icon = EffectIcon.new(@ui, Tex::FIRE_RESISTANCE)
    @recipe_book = RecipeBook.new
    @furnaces = Furnaces.new
    # The station whose screen is open (BY_HAND, AT_TABLE or AT_FURNACE of Recipe),
    # and its cell.
    @station = Recipe::BY_HAND
    @station_x = 0
    @station_y = 0
    @station_z = 0
    # The cell that fluid_in_view found, and its walk along the view.
    @fluid_x = 0
    @fluid_y = 0
    @fluid_z = 0
    @fluid_walk = VoxelWalk.new
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
    # When jump was last pressed, for a double press that starts or stops
    # flying (FLY_TAP).
    @last_jump = -1.0
    @slot = 0
    # The screen that the player sees (game/screen.rb).
    @screen = Screen.new(Screen::PAUSED)
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
    @fps_frames = 0
    @fps_time = 0.0
    @cpu_sum = 0.0
    @total_cpu = 0.0
    @max_cpu = 0.0
    @max_frame = 0.0
    @slow_frames = 0
    @stamps = Array.new(STAMP_COUNT, 0)
    # The stamps and the wait for the swapchain of the last frame, which the
    # perf log reads one frame later.
    @previous_stamps = Array.new(STAMP_COUNT, 0)
    @previous_wait_ns = 0
    @faces_drawn = 0
    @game_mode = ENV["MODE"] == "survival" ? GameMode::SURVIVAL : GameMode::CREATIVE
    @loaded = SaveFile.new
    @load_error = ""
    @changed = false
    # A scripted run (FRAMES or DEMO) does not change the save or the options.
    @save_on_quit = !@scripted || !ENV["SAVE"].nil?
    prefix = file_prefix
    @save_path = prefix + SAVE_PATH
    @bad_save_path = prefix + BAD_SAVE_PATH
    @options = Options.new(prefix + OPTIONS_PATH)
    @perf_log = PerfLog.new(prefix + PERF_LOG_PATH)
    @options.read_file if @save_on_quit
    read_option_overrides
    @sound = false
    @clouds = Clouds.new(@seed)
    @cloud_drift = 0.0
    @bob = 0.0
    # The half angle of the view in radians. It follows the option and widens in a sprint.
    @fov = @options.half_fov
    @step_dist = 0.0
    @was_swimming = false
    @sfx = Sfx.new
    @particles = Particles.new(@seed)
    @arrows = []
    @eggs = []
    @items = []
    @falling = []
    @boats = []
    # The index in @boats of the boat that the player rides, or -1.
    @riding = -1
    # The boat in the crosshair (Game#find_targets), or -1.
    @target_boat = -1
    @draw_time = -1.0
    @eat_time = -1.0
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
    @weather = Weather.new(@seed * 3 + 2)
    @console = Console.new(self, @chat, @clock, @weather)
    start_weather_switch
    # STRIKE=1 makes lightning strike in front of the player near the last frame.
    @strike_shot = !ENV["STRIKE"].nil?
    @sky = Sky.new(@clock, @weather, @camera)
    @target_mob = -1
    @swing = 0.0
    @held_item = HeldItem.new
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

  def setup
    init_graphics
    @perf_log.start(perf_log_header) unless @scripted
    init_audio
    start_world
    show_debug_scenes
    @spawner.spawn_animals(@mobs, @player)
    open_first_screen
    say("#{game_mode.name} MODE")
  end

  # VIEW and GRAPHICS give the options of this run, over the options file.
  def read_option_overrides
    @options.read_option("view", ENV["VIEW"]) if ENV["VIEW"]
    @options.read_option("graphics", ENV["GRAPHICS"]) if ENV["GRAPHICS"]
  end

  def init_graphics
    vsync = ENV["NOVSYNC"] ? 0 : 1
    Gfx.gfx_shader_defines(Mesher.shader_defines + Lod.shader_defines + Block.shader_defines + Clouds.shader_defines)
    abort "graphics init failed" unless Gfx.gfx_init(1280, 720, vsync, @scripted ? 1 : 0)
    check_gfx_limits
    abort "cannot record to #{@record}" if @record != "" && !Gfx.gfx_record(@record)
    Gfx.gfx_fullscreen(1) if @options.fullscreen
    px = Tex.build
    abort "texture upload failed" unless Gfx.gfx_textures(px, Tex::LAYERS)
    @dyn.opaque = Tex.opaque(px)
    abort "skin upload failed" unless Gfx.gfx_skins(Tex.skins, Tex::SKIN_FILES.size)
    upload_clouds
  end

  def init_audio
    # RECORD_SOUND=file writes the sounds to file as a WAV, in step with
    # the frames of RECORD, and plays none. The music stays out of it.
    sound_path = ENV["RECORD_SOUND"] || ""
    abort "cannot record the sound to #{sound_path}" if sound_path != "" && !Gfx.au_record(sound_path)
    @sound = ENV["MUTE"].nil? && Sfx.init
    puts "audio #{@sound ? "on" : "off"}"
  end

  def start_world
    began = Gfx.gfx_ns
    loaded = enter_world
    apply_cam
    @chunk_meshes.stream(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    ended = Gfx.gfx_ns
    # Collect the world generation garbage now, not in the first minute of play.
    GC.start
    puts "world: #{loaded ? "load" : "generate"} and mesh the nearest #{(SYNC_R * 2 + 1) * (SYNC_R * 2 + 1)} chunks in #{((ended - began) / 1.0e6).round} ms"
  end

  # Loads the saved world, or makes a new one. Returns true when it loads
  # the save.
  def enter_world
    # The demo reel always plays in a new world, so each run looks the same.
    fresh = !ENV["NEW"].nil? || @demo
    loaded = !fresh && load
    keep_bad_save if !loaded && !fresh
    reset_world unless loaded
    perf_event(loaded ? "world loaded, seed #{@seed}" : "new world, seed #{@seed}")
    if loaded
      apply_loaded
    else
      spawn
    end
    loaded
  end

  def show_debug_scenes
    show_mobs if ENV["SHOWMOBS"]
    show_items if ENV["SHOWITEMS"]
    show_boats if ENV["SHOWBOATS"]
  end

  def open_first_screen
    # A screenshot, a benchmark or the self-test starts in the world.
    if !@scripted && !@autopilot && ENV["SELFTEST"].nil?
      open_title
    else
      Gfx.in_capture(1) unless @scripted
      show_screen(Screen::PLAYING)
      show_screen(Screen::INVENTORY) if ENV["INVENTORY"]
    end
  end

  # A seed from the clock, for a new world.
  def clock_seed = (Gfx.gfx_ns / 1000) % 1000000

  # NEW WORLD on the title screen: a fresh world from seed, same game mode.
  # The player starts again with an empty inventory.
  def new_world(seed)
    @seed = seed
    reset_world
    perf_event("new world, seed #{@seed}")
    @inv.clear
    @armor.slots.clear
    @hotbar = HOTBAR_START.dup
    @chests.clear
    @recipe_book = RecipeBook.new
    @furnaces.clear
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
  # can be at sea, so the noise first finds land. Then the loaded blocks give
  # dry land near that point.
  def spawn
    land_x, land_z = @world.terrain.land_near_origin
    @chunk_meshes.stream(land_x >> 4, land_z >> 4, -1, SYNC_R)
    start_x, start_z = @world.dry_spot_near(land_x, land_z, (SYNC_R - 1) * CHUNK)
    ground = @world.height_at(start_x, start_z)
    @spawn_x = start_x + 0.5
    @spawn_z = start_z + 0.5
    @player = Player.new(@spawn_x, ground + 0.01, @spawn_z)
    # A new player has no block in the crosshair yet.
    @target_block = BlockTarget.new
    Log.debug(Log::WORLD) { "spawn at #{start_x} #{ground} #{start_z}#{@world.dry_spot?(start_x, start_z) ? "" : ", but no dry land was near"}" }
  end

  def respawn
    Log.measure(Log::WORLD, "mesh the nearest chunks for the respawn") do
      @chunk_meshes.stream(@spawn_x.floor >> 4, @spawn_z.floor >> 4, -1, SYNC_R)
    end
    h = @world.height_at(@spawn_x.floor, @spawn_z.floor)
    @player.move_to(@spawn_x, h + 0.01, @spawn_z)
    @player.revive
    Log.debug(Log::WORLD) { "respawn at #{@spawn_x.floor} #{h} #{@spawn_z.floor}" }
    @alive_time = 0.0
    @riding = -1
  end

  # Moves the player to the spawn point. The chunks there load first, as in
  # respawn: before they load, height_at reads the chunk that fills their
  # slot of the ring.
  def teleport_to_spawn
    @chunk_meshes.stream(@spawn_x.floor >> 4, @spawn_z.floor >> 4, -1, SYNC_R)
    @player.move_to(@spawn_x, @world.height_at(@spawn_x.floor, @spawn_z.floor) + 0.01, @spawn_z)
  end

  # Plays the sounds that @sfx queued, at the volume of the options, and
  # empties the queue. Without sound, it only empties the queue.
  def send_sounds
    if @sound
      ids = @sfx.ids
      volumes = @sfx.volumes
      pans = @sfx.pans
      ids.size.times { |sound| Gfx.au_play(ids[sound], volumes[sound] * @options.volume, pans[sound]) }
    end
    @sfx.clear
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
    track = @music.next_track(dt, Gfx.au_music_playing, underground?, @clock.time_of_day >= 0.5)
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
  def update_game(dt)
    # to_f: Spinel cannot type the position of the player.
    @sfx.listen(@player.x.to_f, @player.eye_y.to_f, @player.z.to_f, @player.yaw.to_f)
    current = current_screen
    turn_title(dt) if current.title?
    return if current.stops_world?

    read_move_keys
    fly_autopilot(dt) if @autopilot
    move_player(dt)
    update_boats(dt)
    @target_block.trace(@world, @player)
    play_move_sounds(dt)
    update_surroundings(dt)
    update_weather_effects(dt)
    update_storm(dt)
    update_timers(dt)
    update_hand(dt)
    update_cave_sound(dt)
    update_block_sounds(dt)
    update_survival(dt)
    update_mobs(dt)
    update_fluids(dt)
    find_targets
  end

  def turn_title(dt)
    @player.yaw += TITLE_TURN * dt
    @confirm_wait -= dt
  end

  def fly_autopilot(dt)
    @player.flying = true
    @player.yaw += dt * 0.25 unless @autopilot_far
    @player.pitch = -0.25
    @player.controls.cruise
    @player.y = 72.0
  end

  def move_player(dt)
    @player.slowed = using_item?
    # Shift gets out of a boat. minecraft.wiki/w/Boat
    leave_boat if riding? && @player.controls.sneak
    remaining = riding? ? 0.0 : dt
    while remaining > 0.0
      step = remaining > 0.02 ? 0.02 : remaining
      fell = @player.update(@world, step)
      hurt((fell - 3.0).ceil.to_f, Sfx::FALL) if fell > 3.5
      if game_mode.survival?
        moved = @player.speed * step
        @player.vitals.move(moved, @player.controls.sprint && @player.on_ground, @player.in_water, @player.jumped)
      end
      remaining -= step
    end
    # A flying player who comes down onto a block stops flying, as in Java
    # Edition. minecraft.wiki/w/Flying
    @player.flying = false if @player.on_ground && !@autopilot
  end

  def play_move_sounds(dt)
    # Water splashes and swishes, but lava makes no sound when the player
    # enters it or moves in it. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
    swimming = @player.in_water && !@player.in_lava
    if (@player.on_ground || swimming) && !@player.in_lava && !@player.flying
      @step_dist += @player.speed * dt
      if @step_dist > Player::STEP
        @step_dist = 0.0
        ground = BlockSound.footstep(@world.get(@player.x.floor, (@player.y - 0.1).floor, @player.z.floor))
        @sfx.play(swimming ? Sfx::STEP_WATER : ground, 0.35)
      end
    end
    @sfx.play(Sfx::SPLASH, 0.6) if swimming && !@was_swimming && !@player.flying
    @was_swimming = swimming
  end

  def update_surroundings(dt)
    @particles.update(@world, dt)
    @particles.sample_fire(@world, @player.x, @player.y, @player.z, dt)
    grow_plants(dt)
    decay_leaves(dt)
    spread_grass(dt)
    kill_covered_grass(dt)
    update_furnaces(dt)
    update_items(dt)
    update_falling(dt)
    note_seen if game_mode.survival?
  end

  def update_weather_effects(dt)
    @weather.update_weather(dt)
    @weather.splash(@particles, @world, @player, dt)
    Gfx.au_loop(Sfx::RAIN, @weather.sound(@world, @player) * @options.volume) if @sound
    Gfx.gfx_rain(@weather.mesh.v, @weather.mesh.count) if @weather.build_quads(@world, @player, dt)
  end

  # The strikes of a thunderstorm, and the thunder that reaches the player.
  def update_storm(dt)
    lightning_hit_player if @storm.advance(dt, @player, @particles)
    return unless @storm.lightning.thunder_arrived?(dt)

    lightning = @storm.lightning
    @sfx.play_at(Sfx::THUNDER + (@rng.rand01 * Sfx::THUNDERS).to_i, lightning.heard_x, lightning.heard_y, lightning.heard_z, 1.0)
  end

  def lightning_hit_player
    return unless game_mode.survival?

    @player.vitals.ignite(Storm::STRIKE_FIRE)
    # Armor lowers a strike. minecraft.wiki/w/Armor (Damage sources)
    armored_hurt(Storm::STRIKE_DAMAGE, Sfx::HURT)
  end

  def update_timers(dt)
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
    @player.melee_attack.advance(dt)
  end

  # The movement keys of this frame, in the controls of the player. No key
  # counts when the mouse is free, the player is dead or the chat is open.
  def read_move_keys
    controls = @player.controls
    unless current_screen.playing?
      controls.release_keys
      return
    end
    controls.tap_forward(@anim_time) if Gfx.in_key_pressed(Key::W)
    controls.release_forward unless Gfx.in_key(Key::W)
    tap_to_fly if Gfx.in_key_pressed(Key::SPACE)
    sprint = (Gfx.in_key(Key::LCTRL) || controls.tap_sprint?) && may_sprint?
    controls.hold(key_axis(Key::W, Key::S), key_axis(Key::D, Key::A),
                  jump: Gfx.in_key(Key::SPACE), sneak: Gfx.in_key(Key::LSHIFT), sprint: sprint)
  end

  # 1.0 while the key plus is down, -1.0 while the key minus is down, and
  # 0.0 for both or none.
  def key_axis(plus, minus) = (Gfx.in_key(plus) ? 1.0 : 0.0) - (Gfx.in_key(minus) ? 1.0 : 0.0)

  # A hungry player cannot sprint in survival, nor a player who eats or
  # draws the bow.
  def may_sprint? = (game_mode.creative? || @player.vitals.can_sprint?) && !using_item?

  # A second press of jump within FLY_TAP starts or stops flying in
  # creative, as in Minecraft. A third press starts a new double press.
  def tap_to_fly
    if game_mode.creative? && @anim_time - @last_jump < FLY_TAP && @anim_time > @last_jump
      @player.flying = !@player.flying
      @last_jump = -1.0
    else
      @last_jump = @anim_time
    end
    nil
  end

  def update_survival(dt)
    return unless game_mode.survival? && !@player.vitals.dead?

    @alive_time += dt
    p = @player
    feet = @world.get(p.x.floor, (p.y + 0.2).floor, p.z.floor)
    eyes = p.at_eyes(@world)
    in_lava = Block.lava?(feet) || Block.lava?(eyes)
    under_water = Block.water?(eyes)
    # Water and rain put the fire out.
    if !in_lava && @player.vitals.burning? && (under_water || Block.water?(feet) || (@weather.wet? && @world.under_sky?(p.x, p.eye_y, p.z)))
      @player.vitals.douse
      @sfx.play(Sfx::FIZZ, 0.6)
    end
    on_cactus = @world.cactus_in_box?(p.x, p.y, p.z, Player::HALF, Player::TALL)
    hurt_by_fire_or_water = @player.vitals.update_vitals(dt, in_lava, on_cactus, under_water)
    armorable = @player.vitals.take_armorable_damage
    # One hurt sound for each frame. A hit that armor lowers plays it, and
    # so does a hit that kills.
    if armorable > 0.0 && !@player.vitals.dead?
      armored_hurt(armorable, Sfx::HURT)
    elsif hurt_by_fire_or_water
      felt_hurt(Sfx::HURT)
    end
    @particles.hunger(p.x, p.eye_y, p.z, p.yaw, dt) if @player.vitals.hunger_effect?
  end

  # The screen that the player sees now.
  def current_screen = @screen

  def show_screen(id)
    @screen = Screen.new(id)
  end

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

    sky = @sky.light
    light = @light.level(x, y, z, sky, @light.lamp_near?(x, y, z), sky)
    light = 15 if light < 0
    @cave_fear += 3.0 * (15 - light) / 15.0
    return if @cave_fear < 300.0

    @cave_fear = 0.0
    @sfx.play(Sfx::CAVE + (@rng.rand01 * Sfx::CAVES).to_i, 0.6)
  end

  # Looks at random blocks near the player, and plays the sound of each one
  # that makes a sound, at its AMBIENT_CHANCE. As in Minecraft, each offset
  # from the player is the difference of two random numbers below
  # Sfx::RANGE, so a block near the player sounds more often. Each sound
  # waits for its last clip to end, so the long clips do not take all the
  # voices.
  def update_block_sounds(dt)
    AMBIENT.size.times { |i| @ambient_wait[i] -= dt }
    px = @player.x.floor
    py = @player.y.floor
    pz = @player.z.floor
    (dt * AMBIENT_SAMPLES + @rng.rand01).to_i.times do
      x = px + sound_offset
      y = py + sound_offset
      z = pz + sound_offset
      k = block_sound(x, y, z)
      next if k < 0 || @ambient_wait[k] > 0.0 || @rng.rand01 >= AMBIENT_CHANCE[k] * MC_AMBIENT_SAMPLES / AMBIENT_SAMPLES

      @ambient_wait[k] = Gfx.au_seconds(AMBIENT[k])
      @sfx.play_at(AMBIENT[k], x + 0.5, y + 0.5, z + 0.5, AMBIENT_VOLUME[k])
    end
  end

  # A random offset from the player along one axis for update_block_sounds,
  # from 1 - Sfx::RANGE to Sfx::RANGE - 1. An offset near 0 comes more
  # often than one far from it.
  def sound_offset = (@rng.rand01 * Sfx::RANGE).to_i - (@rng.rand01 * Sfx::RANGE).to_i

  # The index in AMBIENT of the sound that block x, y, z makes, or -1.
  def block_sound(x, y, z)
    block = @world.get(x, y, z)
    return 0 if Block.lava?(block) && @world.get(x, y + 1, z) == Block::AIR
    return 1 if Block.water?(block) && block != Block::WATER
    return 2 if Block.furnace_lit?(block)

    -1
  end

  # True while the player eats or draws the bow.
  def using_item? = @eat_time >= 0.0 || @draw_time >= 0.0

  # A new item in the hand starts a new attack cooldown and ends a meal. The
  # sway of the held item follows the walk speed.
  def update_hand(dt)
    if @held_item.change(current_block.to_i)
      @player.melee_attack.restart
      @eat_time = -1.0
    end
    p = @player
    walk = p.on_ground && !p.flying ? (Math.sqrt(p.vx * p.vx + p.vz * p.vz) / 4.3).clamp(0.0, 1.0) : 0.0
    @held_item.ease(dt, walk, @bob)
  end

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

  def run
    setup
    return run_selftest if ENV["SELFTEST"]

    last = Gfx.gfx_ns
    started = last
    frames = 0
    until Gfx.in_poll || @quit
      now = Gfx.gfx_ns
      interval_ms = (now - last) / 1.0e6
      dt = interval_ms / 1000.0
      dt = 0.05 if dt > 0.05
      dt = 1.0 / RECORD_FPS if @record != ""
      last = now
      cpu = frame(dt, now, frames)
      record_frame(frames, dt, cpu)
      write_perf_log(interval_ms) if frames > WARMUP_FRAMES && !@scripted
      remember_frame unless @scripted
      frames += 1
      Gfx.gfx_screenshot(@shot) if @shot != "" && frames == @max_frames - 1
      break if @max_frames > 0 && frames >= @max_frames
    end
    shutdown(started, frames)
  end

  def run_selftest
    ok = self_test
    Gfx.gfx_quit
    exit(1) unless ok
  end

  # One frame of the game. Returns the milliseconds of CPU that it took.
  def frame(dt, now, frames)
    @stamps[STAMP_BEGIN] = now
    strike_ahead if @strike_shot && frames == @max_frames - 3
    advance(dt)
    stamp(STAMP_STREAM)
    @chunk_meshes.stream(@player.x.floor >> 4, @player.z.floor >> 4, STREAM_BUDGET_NS, view_radius)
    stamp(STAMP_FAR)
    build_far_tiles
    stamp(STAMP_FLUSH)
    @chunk_meshes.flush
    stamp(STAMP_RENDER)
    render
    cpu = cpu_ms(@stamps)
    log_slow_frame(frames, cpu) if cpu > Log::SLOW_MS
    cpu
  end

  def advance(dt)
    handle_input(dt) unless @scripted
    demo(dt) if @demo
    stamp(STAMP_GAME)
    update_game(dt)
    stamp(STAMP_SOUND)
    send_sounds
    Gfx.au_record_mix(dt)
    update_music(dt)
  end

  # The far tiles use the part of the time budget that the chunks left.
  def build_far_tiles
    left = STREAM_BUDGET_NS - (@stamps[STAMP_FAR] - @stamps[STAMP_STREAM])
    @far.build_tiles(@player.x.floor.to_i, @player.z.floor.to_i, @options.view, left > 500_000 ? left : 500_000)
  end

  # Writes the time of this moment in the frame, in nanoseconds, for the
  # frame topic of the log.
  def stamp(index)
    @stamps[index] = Gfx.gfx_ns
  end

  def log_slow_frame(frames, cpu)
    Log.debug(Log::FRAME) { "frame #{frames}: #{cpu.round(2)} ms of CPU. #{frame_steps(@stamps)}" }
  end

  def frame_steps(stamps)
    "input #{step_ms(stamps[STAMP_BEGIN], stamps[STAMP_GAME])}, game #{step_ms(stamps[STAMP_GAME], stamps[STAMP_SOUND])}, " \
      "sound #{step_ms(stamps[STAMP_SOUND], stamps[STAMP_STREAM])}, " \
      "chunks #{step_ms(stamps[STAMP_STREAM], stamps[STAMP_FAR])}, far tiles #{step_ms(stamps[STAMP_FAR], stamps[STAMP_FLUSH])}, " \
      "remesh #{step_ms(stamps[STAMP_FLUSH], stamps[STAMP_RENDER])}, render #{step_ms(stamps[STAMP_RENDER], stamps[STAMP_END])}"
  end

  def step_ms(from, to) = ((to - from) / 1.0e6).round(2)

  def cpu_ms(stamps) = (stamps[STAMP_END] - stamps[STAMP_BEGIN]) / 1.0e6

  # The first frames are not counted in the maximum values: they load the
  # world.
  def record_frame(frames, dt, cpu)
    warm = frames > WARMUP_FRAMES
    @max_cpu = cpu if cpu > @max_cpu && warm
    frame_ms = dt * 1000.0
    @max_frame = frame_ms if frame_ms > @max_frame && warm
    @slow_frames += 1 if frame_ms > 12.0 && warm
    @cpu_sum += cpu
    @total_cpu += cpu
    @fps_frames += 1
    @fps_time += dt
    update_fps if @fps_time >= 0.5
  end

  # The interval is the time from the start of the last frame to the start of
  # this one, with no limit. It belongs to the last frame, so it goes with the
  # CPU time, the wait for the swapchain and the steps of the last frame.
  def write_perf_log(interval_ms)
    previous_cpu = cpu_ms(@previous_stamps)
    @perf_log.add(interval_ms, previous_cpu)
    @perf_log.write_stutter(interval_ms, stutter_detail(interval_ms, previous_cpu)) if @perf_log.stutter?(interval_ms)
    write_window_events
    @perf_log.write_stretch(perf_state) if @perf_log.due?
  end

  # Keeps this frame for the perf log of the next one. The stamps of the last
  # frame are the old ones, which the next frame writes again.
  def remember_frame
    @previous_wait_ns = Gfx.gfx_wait_ns
    @stamps, @previous_stamps = @previous_stamps, @stamps
  end

  # The wait is the time that the swapchain made the frame wait, which is the
  # display when it is most of the wait. The rest is the event poll, the
  # present call and the system.
  def stutter_detail(interval_ms, previous_cpu)
    "#{previous_cpu.round(1)} ms of CPU, #{(interval_ms - previous_cpu).round(1)} ms of wait " \
      "(#{(@previous_wait_ns / 1.0e6).round(1)} ms for the swapchain). #{frame_steps(@previous_stamps)}"
  end

  def write_window_events
    Gfx.in_window_event_count.times { |index| @perf_log.write_window_event(Gfx.in_window_event(index)) }
  end

  def perf_event(text)
    @perf_log.write_event(text) unless @scripted
  end

  # What the game knows at the end of a stretch of play, for the perf log.
  def perf_state
    "window #{Gfx.gfx_width}x#{Gfx.gfx_height}, memory #{Gfx.gfx_footprint_mb} MB, #{@world.loaded_chunk_count} chunks, #{@mobs.size} mobs, " \
      "#{@options.graphics.name}, #{underground? ? "underground" : "above ground"}, time of day #{@clock.time_of_day.round(2)}, " \
      "at x #{@player.x.round}, eye y #{@player.eye_y.round}, z #{@player.z.round}"
  end

  def underground? = @player.eye_y < SEA && !@world.under_sky?(@player.x, @player.eye_y, @player.z)

  def perf_log_header
    started = Time.now
    "session #{started.strftime("%Y-%m-%d %H:%M:%S")}\n" \
      "machine #{Gfx.gfx_machine(2)}, #{Gfx.gfx_machine(1)}, macOS #{Gfx.gfx_machine(3)}, GPU #{Gfx.gfx_machine(0)}\n" \
      "settings view #{@options.view.round}, fov #{@options.fov_degrees.round}, graphics #{@options.graphics.name}\n" \
      "display #{Gfx.gfx_refresh_hz.round(1)} Hz, present #{Gfx.gfx_present_mode}"
  end

  # The fps and the CPU time that the HUD shows are the mean of the last
  # half second.
  def update_fps
    @fps = @fps_frames / @fps_time
    @cpu_ms = @cpu_sum / @fps_frames
    @fps_frames = 0
    @fps_time = 0.0
    @cpu_sum = 0.0
  end

  def shutdown(started, frames)
    if @save_on_quit
      save
      @options.write_file
    end
    @perf_log.write_stretch(perf_state) unless @scripted
    elapsed = (Gfx.gfx_ns - started) / 1.0e9
    puts "gpu_wait_ms=#{Gfx.gfx_gpu_ms.round(2)}" if ENV["GPUTIME"]
    puts "size=#{Gfx.gfx_width}x#{Gfx.gfx_height} frames=#{frames} avg_fps=#{(frames / elapsed).round(1)} avg_cpu_ms=#{(@total_cpu / frames).round(3)} max_cpu_ms=#{@max_cpu.round(2)} max_frame_ms=#{@max_frame.round(1)} slow_frames=#{@slow_frames} health=#{@player.vitals.health} dead=#{@player.vitals.dead?} mobs=#{@mobs.size}"
    Gfx.gfx_quit
  end
end

Game.new.run
