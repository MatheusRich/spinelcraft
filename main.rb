# Game setup, spawn and respawn, the update step, and the game loop.
require_relative "game/gfx"
require_relative "game/rng"
require_relative "game/textures"
require_relative "game/block"
require_relative "game/biome"
require_relative "game/noise"
require_relative "game/world"
require_relative "game/mesher"
require_relative "game/ray"
require_relative "game/player"
require_relative "game/vitals"
require_relative "game/camera"
require_relative "game/ui"
require_relative "game/mesh3"
require_relative "game/mobs"
require_relative "game/arrow"
require_relative "game/item"
require_relative "game/falling_block"
require_relative "game/sounds"
require_relative "game/clouds"
require_relative "game/lod"
require_relative "game/constants"
require_relative "game/save"
require_relative "game/streaming"
require_relative "game/block_changes"
require_relative "game/slots"
require_relative "game/furnace"
require_relative "game/inventory"
require_relative "game/items"
require_relative "game/hand"
require_relative "game/particles"
require_relative "game/weather"
require_relative "game/actions"
require_relative "game/combat"
require_relative "game/render"
require_relative "game/hud"
require_relative "game/menu"
require_relative "game/testing"

class Game
  def initialize
    @seed = (ENV["SEED"] || "1337").to_i
    @max_frames = (ENV["FRAMES"] || "0").to_i
    # A run with FRAMES set ignores the mouse and the keys, so the person at
    # the computer does not move the camera in a screenshot or a benchmark.
    @scripted = @max_frames > 0
    @autopilot = !ENV["AUTOPILOT"].nil?
    # AUTOPILOT=far flies in a straight line, so new chunks stream in.
    @autopilot_far = ENV["AUTOPILOT"] == "far"
    @shot = ENV["SHOT"] || ""
    @world = World.new(@seed)
    @mesher = Mesher.new(@world)
    @lods = Array.new(LEVELS) { |l| Lod.new(@world, l) }
    @lod_visible = Array.new(0, 0)
    # Per level: the tile the ring walk is centered on, and how far it got.
    @lod_tx = Array.new(LEVELS, World::NONE)
    @lod_tz = Array.new(LEVELS, World::NONE)
    @lod_at = Array.new(LEVELS, 0)
    make_lod_ring
    @camera = Camera.new
    @ui = Ui.new
    @dyn = Mesh3.new
    @uniforms = Array.new(UNIFORMS, 0.0)
    @visible = []
    @water_visible = []
    # Sort keys of the visible chunks with water: distance * LOD_SLOT0 + slot.
    @water_keys = Array.new(0, 0)
    # 1 when a slot's chunk has a current mesh on the GPU.
    @meshed = Array.new(CX * CZ, 0)
    # 1 when the chunk's mesh has water faces.
    @has_water = Array.new(CX * CZ, 0)
    @stream_cx = World::NONE
    @stream_cz = World::NONE
    @load_at = 0
    @mesh_at = 0
    make_ring
    @dirty = Array.new(CX * CZ, false)
    @dirty_list = []
    # Chunks that can wait a few frames: torch light and flowing water.
    @later = Array.new(CX * CZ, false)
    @later_list = []
    @defer = false
    @hotbar = HOTBAR_START.dup
    @inv = Slots.new(INV)
    @seen = Array.new(Block::COUNT, 0)
    @recipe_new = Array.new(RECIPES.size, 0)
    # The first recipe row in view, and the wheel steps not used yet.
    @recipe_top = 0
    @recipe_wheel = 0.0
    # The furnaces, by World.key, and the time not yet ticked.
    @furnaces = {}
    @furnace_clock = 0.0
    # The station whose screen is open (BY_HAND, AT_TABLE or AT_FURNACE),
    # and its cell.
    @station = BY_HAND
    @station_x = 0
    @station_y = 0
    @station_z = 0
    # The cell that fluid_in_view found.
    @fluid_x = 0
    @fluid_y = 0
    @fluid_z = 0
    @held_block = 0
    @held_count = 0
    @chests = {}
    # The open chest, and its World.key; -1 when no chest is open.
    @chest = Slots.new(CHEST_SLOTS)
    @chest_key = -1
    @sky = Ui.new
    make_stars
    @flow_queue = []
    @flow_timer = 0.0
    @alive_time = 0.0
    @anim_time = 0.0
    @fullscreen = false
    @fog_end = FOG_END.to_f
    # The options of the pause menu (game/menu.rb), from 0 to 1. Brightness 0
    # is the light without a lift. The volume starts at half.
    @brightness = 0.0
    @volume = 0.5
    # The slider that the mouse drags, or -1.
    @menu_drag = -1
    # True after one click on New world.
    @menu_confirm = false
    @quit = false
    @last_w = -1.0
    @w_sprint = false
    @slot = 0
    @captured = false
    @time_of_day = (ENV["TIME"] || "0.3").to_f
    @action_cooldown = 0.0
    @message = ""
    @message_time = 0.0
    @fps = 0.0
    @cpu_ms = 0.0
    @mesh_ms = 0.0
    @faces_drawn = 0
    @show_debug = true
    @cpu_end = 0
    @survival = ENV["MODE"] == "survival"
    @loaded = [""]
    @changed = false
    # A scripted run (FRAMES) does not change the save or the options.
    @save_on_quit = ENV["FRAMES"].nil? || !ENV["SAVE"].nil?
    load_options if @save_on_quit
    @fog_end = ENV["VIEW"].to_f if ENV["VIEW"]
    @sound = false
    @demo = !ENV["DEMO"].nil?
    @clouds = Clouds.new(@seed)
    @cloud_drift = 0.0
    @bob = 0.0
    @fov = 0.6
    @inventory_open = !ENV["INVENTORY"].nil?
    @step_dist = 0.0
    @was_swimming = false
    @particles = Particles.new(@seed)
    @arrows = []
    @items = []
    @falling = []
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
    # The light search of Game#spawn_light: a stamp for each cell of its
    # cube that it has seen, and its queue of cells and steps.
    @light_seen = Array.new(LIGHT_SIDE * LIGHT_SIDE * LIGHT_SIDE, 0)
    @light_stamp = 0
    @light_queue = []
    @spawn_timer = 0.0
    # The cave sounds (update_cave_sound): seconds to the next check, and
    # the fear that the darkness built up.
    @cave_timer = 0.0
    @cave_fear = 0.0
    @ambient_wait = [0.0, 0.0, 0.0]
    @rng = Rng.new(@seed * 7 + 1)
    @weather = Weather.new(@seed * 3 + 2, !ENV["RAIN"].nil?)
    @target_mob = -1
    @swing = 0.0
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
    abort "gfx.rb LEVELS is not #{LEVELS}" if Gfx.gfx_limit(0) != LEVELS
    abort "gfx.rb COLUMNS is not #{Mesher::COLUMNS}" if Gfx.gfx_limit(1) != Mesher::COLUMNS
    abort "the world ring is not Mesher::COLUMNS wide" if WX != Mesher::COLUMNS || Lod::TRING * Lod::CELLS != Mesher::COLUMNS
    abort "gfx.rb MAX_SLOTS is too small" if Gfx.gfx_limit(2) < LOD_SLOT0 + LEVELS * TILE_SLOTS
    abort "gfx.rb UNIFORMS is not #{UNIFORMS}" if Gfx.gfx_limit(3) != UNIFORMS
  end

  def setup
    vsync = ENV["NOVSYNC"] ? 0 : 1
    abort "graphics init failed" unless Gfx.gfx_init(1280, 720, vsync, @scripted ? 1 : 0)
    check_gfx_limits
    Gfx.gfx_fullscreen(1) if @fullscreen
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
    if loaded
      @player = Player.new(0.5, 80.0, 0.5)
      apply_loaded
    else
      spawn
    end
    apply_cam
    stream_around(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    t1 = Gfx.gfx_ns
    # Collect the world generation garbage now, not in the first minute of play.
    GC.start
    puts "world: #{loaded ? "load" : "generate"} and mesh the nearest #{(SYNC_R * 2 + 1) * (SYNC_R * 2 + 1)} chunks in #{((t1 - t0) / 1.0e6).round} ms"
    show_mobs if ENV["SHOWMOBS"]
    show_items if ENV["SHOWITEMS"]
    spawn_animals
    Gfx.in_capture(1) unless @scripted
    @captured = true
    say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
  end

  # New world on the pause menu: a fresh world from a new seed, same game mode.
  # The player starts again with an empty inventory.
  def new_world
    @seed = (Gfx.gfx_ns / 1000) % 1000000
    reset_world
    @inv.clear
    @hotbar = HOTBAR_START.dup
    @chests = {}
    @seen.fill(0)
    @recipe_new.fill(0)
    @furnaces = {}
    @mobs.clear
    @arrows.clear
    @items.clear
    @clouds = Clouds.new(@seed)
    upload_clouds
    spawn
    respawn
    spawn_animals
    @changed = true
    say("NEW WORLD  SEED #{@seed}")
  end

  # Finds dry land near x = z = 0 and puts a new player there. The origin
  # can be at sea, so the noise first finds land on squares around it, 64
  # blocks apart. Then the loaded blocks give dry land near that point.
  def spawn
    ox = 0
    oz = 0
    r = 0
    while !land?(ox, oz) && r < 4096
      r += 64
      k = -r
      while k <= r && !land?(ox, oz)
        if land?(k, -r)
          ox = k
          oz = -r
        elsif land?(k, r)
          ox = k
          oz = r
        elsif land?(-r, k)
          ox = -r
          oz = k
        elsif land?(r, k)
          ox = r
          oz = k
        end
        k += 64
      end
    end
    stream_around(ox >> 4, oz >> 4, -1, SYNC_R)
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
          if dry_land?(x, z) && dry_land?(x + 3, z) && dry_land?(x - 3, z) && dry_land?(x, z + 3) && dry_land?(x, z - 3)
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
  end

  # Land well above the sea, from the noise alone.
  def land?(x, z) = @world.surface_height(x, z) > SEA + 4

  # Ground above the beach with no tree or water on top.
  def dry_land?(x, z)
    h = @world.height_at(x, z)
    b = @world.get(x, h - 1, z)
    h > SEA + 2 && b != Block::LEAVES && !Block.water?(b)
  end

  def respawn
    stream_around(@spawn_x.floor >> 4, @spawn_z.floor >> 4, -1, SYNC_R)
    h = @world.height_at(@spawn_x.floor, @spawn_z.floor)
    @player.x = @spawn_x
    @player.y = h + 0.01
    @player.z = @spawn_z
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    @player.fall_start = @player.y
    @vitals = Vitals.new
    @alive_time = 0.0
  end

  def play(id, volume)
    Gfx.au_play(id, volume * @volume, 0.0) if @sound
  end

  # Plays a sound that comes from x, y, z and reaches range blocks.
  def play_at(id, x, y, z, gain, range)
    Gfx.au_play(id, near_volume(x, y, z, gain, range) * @volume, pan_to(x, y, z)) if @sound
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

  def say(text)
    @message = text
    @message_time = 2.0
  end

  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_game(dt)
    fwd = 0.0
    strafe = 0.0
    jump = false
    down = false
    sprint = false
    if @captured && !@vitals.dead?
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
    remaining = dt
    while remaining > 0.0
      step = remaining > 0.02 ? 0.02 : remaining
      fell = @player.update(@world, step, fwd, strafe, jump, down, sprint)
      hurt((fell - 3.0).ceil, Sfx::FALL) if fell > 3.5
      if @survival
        moved = Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz) * step
        @vitals.move(moved, sprint && @player.on_ground, @player.in_water, @player.jumped)
      end
      remaining -= step
    end
    @player.raycast(@world)
    # Water splashes and swishes, but lava makes no sound when the player
    # enters it or moves in it. minecraft.wiki/w/Water, minecraft.wiki/w/Lava
    swimming = @player.in_water && !@player.in_lava
    if (@player.on_ground || swimming) && !@player.in_lava && !@player.flying
      @step_dist += Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz) * dt
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
    update_furnaces(dt)
    update_items(dt)
    update_falling(dt)
    note_seen if @survival
    @weather.update_weather(dt)
    if @weather.rain > 0.0
      @weather.splash(@particles, @world, @player, dt)
      volume = @weather.sound(@world, @player, dt)
      play(Sfx::RAIN, volume) if volume > 0.0
    end
    Gfx.gfx_rain(@weather.mesh.v, @weather.mesh.count) if @weather.build_quads(@world, @player, dt)
    @cloud_drift = (@cloud_drift + dt * 1.2) % Clouds::PERIOD
    @anim_time = (@anim_time + dt) % 1000.0
    speed = Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz)
    @bob += speed * dt * 2.6
    target_fov = speed > 5.0 ? 0.66 : 0.6
    @fov += (target_fov - @fov) * (6.0 * dt).clamp(0.0, 1.0)
    @time_of_day = (@time_of_day + dt / DAY_SECONDS) % 1.0
    @message_time -= dt
    @damage_flash -= dt
    @swing -= dt
    @attack_time += dt
    update_hand(dt)
    update_cave_sound(dt)
    update_block_sounds(dt)
    update_survival(dt)
    update_mobs(dt)
    @flow_timer -= dt
    if @flow_timer <= 0.0
      @flow_timer = 0.15
      update_water unless @flow_queue.empty?
    end
    find_target_mob
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
    if !in_lava && @vitals.burning? && (under_water || Block.water?(feet) || (@weather.rain > 0.5 && @world.under_sky?(p.x, p.eye_y, p.z)))
      @vitals.douse
      play(Sfx::FIZZ, 0.6)
    end
    felt_hurt(Sfx::HURT) if @vitals.update_vitals(dt, in_lava, under_water)
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
    sky = sky_light
    light = spawn_light(x, y, z, sky, lamp_near?(x, y, z), sky)
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
    i = 0
    while i < AMBIENT.size
      @ambient_wait[i] -= dt
      i += 1
    end
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

  def daylight
    s = Math.sin(@time_of_day * Math::PI * 2.0)
    (0.5 + s * 0.9).clamp(0.12, 1.0)
  end

  def run
    setup
    if ENV["SELFTEST"]
      self_test
      Gfx.gfx_quit
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
      update_game(dt) unless paused?
      t_stream = Gfx.gfx_ns
      stream_around(@player.x.floor >> 4, @player.z.floor >> 4, STREAM_BUDGET_NS, view_radius)
      left = STREAM_BUDGET_NS - (Gfx.gfx_ns - t_stream)
      stream_lod(left > 500_000 ? left : 500_000)
      flush_dirty unless @dirty_list.empty? && @later_list.empty?
      render
      cpu = (@cpu_end - now) / 1.0e6
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
      save_options
    end
    elapsed = (Gfx.gfx_ns - started) / 1.0e9
    puts "gpu_wait_ms=#{Gfx.gfx_gpu_ms.round(2)}" if ENV["GPUTIME"]
    puts "size=#{Gfx.gfx_width}x#{Gfx.gfx_height} frames=#{frames} avg_fps=#{(frames / elapsed).round(1)} avg_cpu_ms=#{(total_cpu / frames).round(3)} max_cpu_ms=#{max_cpu.round(2)} max_frame_ms=#{max_frame.round(1)} slow_frames=#{slow_frames} health=#{@vitals.health} dead=#{@vitals.dead?} mobs=#{@mobs.size}"
    Gfx.gfx_quit
  end
end

Game.new.run
