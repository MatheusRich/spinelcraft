require_relative "game/gfx"
require_relative "game/textures"
require_relative "game/world"
require_relative "game/mesher"
require_relative "game/player"
require_relative "game/camera"
require_relative "game/draw"
require_relative "game/mobs"
require_relative "game/sounds"
require_relative "game/clouds"
require_relative "game/lod"
require_relative "game/constants"
require_relative "game/save"
require_relative "game/streaming"
require_relative "game/block_changes"
require_relative "game/inventory"
require_relative "game/items"
require_relative "game/actions"
require_relative "game/combat"
require_relative "game/render"
require_relative "game/hud"
require_relative "game/testing"

class Game
  def initialize
    @seed = (ENV["SEED"] || "1337").to_i
    @max_frames = (ENV["FRAMES"] || "0").to_i
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
    @inv_block = Array.new(INV, 0)
    @inv_count = Array.new(INV, 0)
    @held_block = 0
    @held_count = 0
    @chests = {}
    @chest_key = -1
    @chest_block = Array.new(CHEST_SLOTS, 0)
    @chest_count = Array.new(CHEST_SLOTS, 0)
    @sky = Ui.new
    make_stars
    @flow_queue = []
    @flow_timer = 0.0
    @lava_timer = 0.0
    @alive_time = 0.0
    @anim_time = 0.0
    @fullscreen = false
    @fog_end = (ENV["VIEW"] || FOG_END.to_s).to_f
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
    @save_on_quit = ENV["FRAMES"].nil? || !ENV["SAVE"].nil?
    @sound = false
    @demo = !ENV["DEMO"].nil?
    @clouds = Clouds.new(@seed)
    @cloud_drift = 0.0
    @bob = 0.0
    @fov = 0.6
    @inventory_open = !ENV["INVENTORY"].nil?
    @step_dist = 0.0
    @was_in_water = false
    # Particles: position, velocity, life and texture layer, in parallel arrays.
    @pt_x = []
    @pt_y = []
    @pt_z = []
    @pt_vx = []
    @pt_vy = []
    @pt_vz = []
    @pt_life = []
    @pt_layer = []
    # Arrows: position, velocity and time left; a stuck arrow has stopped.
    @ar_x = []
    @ar_y = []
    @ar_z = []
    @ar_vx = []
    @ar_vy = []
    @ar_vz = []
    @ar_life = []
    @ar_stuck = []
    # 0 for a skeleton's arrow; otherwise the damage of the player's arrow.
    @ar_damage = []
    # Items on the ground (game/items.rb): the block, the count, the position,
    # the velocity, the age, and the seconds until the player can pick it up.
    @it_block = []
    @it_count = []
    @it_x = []
    @it_y = []
    @it_z = []
    @it_vx = []
    @it_vy = []
    @it_vz = []
    @it_age = []
    @it_wait = []
    @draw_time = -1.0
    @health = MAX_HEALTH
    @hunger = MAX_HUNGER
    @hunger_timer = 0.0
    @air = MAX_AIR
    @regen = 0.0
    @since_damage = 0.0
    @damage_flash = 0.0
    @dead = false
    @mining = false
    @mine_x = 0
    @mine_y = 0
    @mine_z = 0
    @mine_progress = 0.0
    @dig_wait = 0.0
    @mobs = []
    @spawn_timer = 0.0
    @rng = @seed * 7 + 1
    @target_mob = -1
    @swing = 0.0
  end

  def rand01
    @rng = (@rng * 1103515245 + 12345) & 0x7fffffff
    (@rng >> 8) / 8388608.0
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
    abort "graphics init failed" unless Gfx.gfx_init(1280, 720, vsync)
    check_gfx_limits
    abort "texture upload failed" unless Gfx.gfx_textures(Tex.build, Tex::LAYERS)
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
    Gfx.in_capture(1)
    @captured = true
    say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
  end

  # N on the pause screen: a fresh world from a new seed, same game mode.
  def new_world
    @seed = (Gfx.gfx_ns / 1000) % 1000000
    reset_world
    @chests = {}
    @mobs.clear
    clear_arrows
    clear_items
    @clouds = Clouds.new(@seed)
    upload_clouds
    spawn
    respawn
    spawn_animals
    @changed = true
    say("NEW WORLD  SEED #{@seed}")
  end

  # Finds dry land near x = z = 0 and puts a new player there.
  def spawn
    stream_around(0, 0, -1, SYNC_R)
    best_x = 0
    best_z = 0
    r = 0
    found = false
    while r < (SYNC_R - 1) * CHUNK && !found
      dx = -r
      while dx <= r && !found
        dz = -r
        while dz <= r && !found
          x = dx
          z = dz
          h = @world.height_at(x, z)
          b = @world.get(x, h - 1, z)
          if h > SEA + 2 && b != Block::LEAVES && !Block.water?(b)
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
    @health = MAX_HEALTH
    @hunger = MAX_HUNGER
    @air = MAX_AIR
    @dead = false
    @alive_time = 0.0
  end

  def play(id, volume)
    Gfx.au_play(id, volume) if @sound
  end

  # Volume for a sound at x, z: fades to silence at 24 blocks.
  def near_volume(x, z, gain)
    dx = x - @player.x
    dz = z - @player.z
    v = 1.0 - Math.sqrt(dx * dx + dz * dz) / 24.0
    v > 0.0 ? v * gain : 0.0
  end

  def burst_particles(x, y, z, b)
    layer = Block::SIDE[b]
    i = 0
    while i < 12
      @pt_x << x + 0.2 + rand01 * 0.6
      @pt_y << y + 0.2 + rand01 * 0.6
      @pt_z << z + 0.2 + rand01 * 0.6
      @pt_vx << (rand01 - 0.5) * 4.0
      @pt_vy << rand01 * 4.0 + 1.0
      @pt_vz << (rand01 - 0.5) * 4.0
      @pt_life << 0.5 + rand01 * 0.4
      @pt_layer << layer
      i += 1
    end
  end

  def update_particles(dt)
    i = 0
    while i < @pt_life.size
      @pt_life[i] -= dt
      @pt_vy[i] -= 18.0 * dt
      nx = @pt_x[i] + @pt_vx[i] * dt
      ny = @pt_y[i] + @pt_vy[i] * dt
      nz = @pt_z[i] + @pt_vz[i] * dt
      if Block.solid?(@world.get(nx.floor, ny.floor, nz.floor))
        @pt_vx[i] *= 0.3
        @pt_vz[i] *= 0.3
        @pt_vy[i] = 0.0
      else
        @pt_x[i] = nx
        @pt_y[i] = ny
        @pt_z[i] = nz
      end
      i += 1
    end
    # Drop the dead ones from the front (they are the oldest).
    while !@pt_life.empty? && @pt_life[0] <= 0.0
      @pt_x.shift
      @pt_y.shift
      @pt_z.shift
      @pt_vx.shift
      @pt_vy.shift
      @pt_vz.shift
      @pt_life.shift
      @pt_layer.shift
    end
  end

  def say(text)
    @message = text
    @message_time = 2.0
  end

  def update(dt)
    fwd = 0.0
    strafe = 0.0
    jump = false
    down = false
    sprint = false
    if @captured && !@dead
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
    end
    if @autopilot
      @player.flying = true
      @player.yaw += dt * 0.25 unless @autopilot_far
      @player.pitch = -0.25
      fwd = 1.0
      sprint = true
      @player.y = 72.0
    end
    remaining = dt
    while remaining > 0.0
      step = remaining > 0.02 ? 0.02 : remaining
      fell = @player.update(@world, step, fwd, strafe, jump, down, sprint)
      hurt((fell - 3.0).ceil) if fell > 3.5
      remaining -= step
    end
    @player.raycast(@world)
    if @player.on_ground && !@player.flying
      @step_dist += Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz) * dt
      if @step_dist > 2.1
        @step_dist = 0.0
        play(Sfx::STEP, 0.35)
      end
    end
    play(Sfx::SPLASH, 0.6) if @player.in_water && !@was_in_water && !@player.flying
    @was_in_water = @player.in_water
    update_particles(dt)
    update_items(dt)
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
    return unless @survival && !@dead
    @alive_time += dt
    feet = @world.get(@player.x.floor, (@player.y + 0.2).floor, @player.z.floor)
    if Block.lava?(feet) || Block.lava?(@world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor))
      @lava_timer -= dt
      if @lava_timer <= 0.0
        @lava_timer = 0.5
        hurt(4)
      end
    end
    head = Block.water?(@world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor))
    if head
      @air -= dt
      if @air < 0.0
        @air += 1.0
        hurt(2)
      end
    else
      @air = MAX_AIR
    end
    @since_damage += dt
    speed = Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz)
    @hunger_timer += dt * (speed > 5.0 ? 2.5 : 1.0)
    if @hunger_timer > 25.0
      @hunger_timer = 0.0
      @hunger -= 1 if @hunger > 0
    end
    @regen += dt
    if @regen > 4.0
      @regen = 0.0
      if @hunger >= 15 && @health < MAX_HEALTH && @since_damage > 5.0
        @health += 1
      elsif @hunger == 0 && @health > 1
        hurt(1)
      end
    end
  end

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
    until Gfx.in_poll
      now = Gfx.gfx_ns
      dt = (now - last) / 1.0e9
      dt = 0.05 if dt > 0.05
      last = now
      handle_input(dt)
      demo(frames) if @demo
      update(dt)
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
    save if @save_on_quit
    elapsed = (Gfx.gfx_ns - started) / 1.0e9
    puts "gpu_wait_ms=#{Gfx.gfx_gpu_ms.round(2)}" if ENV["GPUTIME"]
    puts "size=#{Gfx.gfx_width}x#{Gfx.gfx_height} frames=#{frames} avg_fps=#{(frames / elapsed).round(1)} avg_cpu_ms=#{(total_cpu / frames).round(3)} max_cpu_ms=#{max_cpu.round(2)} max_frame_ms=#{max_frame.round(1)} slow_frames=#{slow_frames} health=#{@health} dead=#{@dead} mobs=#{@mobs.size}"
    Gfx.gfx_quit
  end
end

Game.new.run
