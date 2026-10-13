require_relative "gfx"
require_relative "textures"
require_relative "world"
require_relative "mesher"
require_relative "player"
require_relative "draw"
require_relative "mobs"
require_relative "sounds"
require_relative "clouds"
require_relative "lod"

class Game
  HOTBAR_START = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::PLANKS,
                  Block::LOG, Block::GLASS, Block::BRICK, Block::TORCH]
  PLACEABLE = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::PLANKS, Block::LOG,
               Block::LEAVES, Block::GLASS, Block::BRICK, Block::SAND, Block::GRAVEL, Block::SNOW,
               Block::SNOW_GRASS, Block::CACTUS, Block::COAL, Block::IRON, Block::DIAMOND, Block::WATER,
               Block::BEDROCK, Block::TALL_GRASS, Block::ROSE, Block::DANDELION, Block::TORCH,
               Block::BOW, Block::ARROW, Block::LAVA, Block::WOOL, Block::BED, Block::CHEST]
  FOG_END = 1600.0
  # F4 view distances, in blocks.
  VIEWS = [200.0, 800.0, 1600.0, 5000.0]
  # Full-detail chunks reach this far at most; far terrain (lod.rb) draws the rest.
  DETAIL_VIEW = 400.0
  # Far terrain levels: level L has cells of 4 << L blocks and reaches
  # LOD_REACH << L blocks, so each level has about the same number of tiles.
  LEVELS = 4
  LOD_REACH = 640
  DAY_SECONDS = 600.0
  MAX_HEALTH = 20
  MAX_HUNGER = 20
  MAX_ZOMBIES = 12
  PIGS = 24
  STACK = 64
  # Survival inventory: slots 0..8 are the hotbar, 9..35 the backpack.
  INV = 36
  CHEST_SLOTS = 27

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
    @uniforms = Array.new(44, 0.0)
    @visible = []
    @water_visible = []
    @water_order = []
    @water_dist = []
    # 1 when a slot's chunk has a current mesh on the GPU.
    @meshed = Array.new(CX * CZ, 0)
    @stream_cx = World::NONE
    @stream_cz = World::NONE
    @load_at = 0
    @mesh_at = 0
    @old_keys = false
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
    @draw_time = -1.0
    @health = MAX_HEALTH
    @hunger = MAX_HUNGER
    @hunger_timer = 0.0
    @air = 10.0
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

  SAVE_PATH = "world.sav"

  def save
    header = [WX, WY, WZ, @seed, @player.x, @player.y, @player.z, @player.yaw, @player.pitch,
              @time_of_day, @survival ? 1 : 0, @health, @spawn_x, @spawn_z].map(&:to_s).join(" ")
    return_held
    close_chest
    chest_fields = [@chests.size]
    @chests.each do |key, stored|
      chest_fields << key
      chest_fields.concat(stored)
    end
    t0 = Gfx.gfx_ns
    chunks = @world.edited_chunks
    keys = chunks.keys
    chunk_fields = [keys.size] + keys
    inv = (@inv_block + @inv_count + @hotbar + [@hunger] + chest_fields + chunk_fields).map(&:to_s).join(" ")
    File.open(SAVE_PATH, "wb") do |f|
      f.write("SPINELCRAFT4 #{header} #{inv}\n")
      keys.each { |k| f.write(chunks[k]) }
    end
    @changed = false
    say("WORLD SAVED")
    puts "saved #{SAVE_PATH} in #{((Gfx.gfx_ns - t0) / 1.0e6).round} ms"
  end

  # Returns true when a saved world was loaded. A save keeps only the chunks
  # that differ from the generator. A format 3 save (the old 384 x 384 world)
  # becomes edited chunks 0..23 on both axes.
  def load
    return false unless File.exist?(SAVE_PATH)
    data = File.binread(SAVE_PATH)
    nl = data.index("\n")
    return false if nl.nil?
    f = data[0, nl].split(" ")
    return false if f.size < 15 + INV * 2 + 10
    v3 = f[0] == "SPINELCRAFT3" && f[1] == "384" && f[2] == "96" && f[3] == "384"
    return false unless f[0] == "SPINELCRAFT4" || v3
    at = 15 + INV * 2 + 10
    at += 1 + f[at].to_i * (1 + CHEST_SLOTS * 2)
    n = v3 ? 0 : f[at].to_i
    return false if !v3 && data.bytesize - nl - 1 != n * CHUNK_BYTES
    return false if v3 && data.bytesize - nl - 1 != OLD_P * OLD_PY * OLD_P
    @seed = f[4].to_i
    reset_world
    store = @world.store
    if v3
      import_v3(data, nl + 1)
    else
      k = 0
      while k < n
        store[f[at + 1 + k].to_i] = data.byteslice(nl + 1 + k * CHUNK_BYTES, CHUNK_BYTES)
        k += 1
      end
    end
    @old_keys = v3
    @loaded = f
    true
  end

  # An empty world for @seed; stream_around fills it.
  def reset_world
    @world = World.new(@seed)
    @mesher = Mesher.new(@world)
    @lods = Array.new(LEVELS) { |l| Lod.new(@world, l) }
    @lod_tx.fill(World::NONE)
    @meshed.fill(0)
    @stream_cx = World::NONE
    @dirty_list.each { |i| @dirty[i] = false }
    @dirty_list.clear
    @later_list.each { |i| @later[i] = false }
    @later_list.clear
    @flow_queue.clear
  end

  # Layout of a format 3 save: 384 columns and one padding column on each side.
  OLD_P = 386
  OLD_PY = 98

  def import_v3(data, off)
    cx = 0
    while cx < 24
      cz = 0
      while cz < 24
        parts = []
        x = cx * CHUNK
        while x < cx * CHUNK + CHUNK
          z = cz * CHUNK
          while z < cz * CHUNK + CHUNK
            parts << data.byteslice(off + ((x + 1) * OLD_P + z + 1) * OLD_PY + 1, WY)
            z += 1
          end
          x += 1
        end
        @world.store[World.chunk_key(cx, cz)] = parts.join
        cz += 1
      end
      cx += 1
    end
  end

  # A format 3 chest key was a block index; this gives the world key.
  def old_chest_key(i)
    t = i / OLD_PY
    World.key(t / OLD_P - 1, i % OLD_PY - 1, t % OLD_P - 1)
  end

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

  def apply_loaded
    f = @loaded
    @player.x = f[5].to_f
    @player.y = f[6].to_f
    @player.z = f[7].to_f
    @player.yaw = f[8].to_f
    @player.pitch = f[9].to_f
    @player.fall_start = @player.y
    @time_of_day = f[10].to_f
    @survival = f[11] == "1"
    @health = f[12].to_i
    @spawn_x = f[13].to_f
    @spawn_z = f[14].to_f
    i = 0
    while i < INV
      @inv_block[i] = f[15 + i].to_i
      @inv_count[i] = f[15 + INV + i].to_i
      i += 1
    end
    i = 0
    while i < 9
      @hotbar[i] = f[15 + INV * 2 + i].to_i
      i += 1
    end
    @hunger = f[15 + INV * 2 + 9].to_i
    @chests = {}
    at = 15 + INV * 2 + 10
    chests = at < f.size ? f[at].to_i : 0
    at += 1
    c = 0
    while c < chests
      key = f[at].to_i
      key = old_chest_key(key) if @old_keys
      stored = Array.new(CHEST_SLOTS * 2, 0)
      k = 0
      while k < CHEST_SLOTS * 2
        stored[k] = f[at + 1 + k].to_i
        k += 1
      end
      @chests[key] = stored
      at += 1 + CHEST_SLOTS * 2
      c += 1
    end
    stream_around(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    respawn if @health <= 0
  end

  def setup
    vsync = ENV["NOVSYNC"] ? 0 : 1
    abort "graphics init failed" if Gfx.gfx_init(1280, 720, vsync) != 0
    abort "texture upload failed" if Gfx.gfx_textures(Tex.build, Tex::LAYERS) != 0
    @sound = ENV["MUTE"].nil? && Sfx.init
    puts "audio #{@sound ? "on" : "off"}"
    t0 = Gfx.gfx_ns
    loaded = ENV["NEW"].nil? && load
    if loaded
      @player = Player.new(0.5, 80.0, 0.5)
      apply_loaded
      stream_around(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
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
    i = 0
    while i < PIGS
      spawn_mob(i % 2 == 0 ? Mob::PIG : Mob::SHEEP, 10.0, 120.0)
      i += 1
    end
    Gfx.in_capture(1)
    @captured = true
    say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
  end

  # Chunks within LOAD_R of the player's chunk are loaded, and those within
  # MESH_R are meshed. MESH_R is one less, so a chunk to mesh has its neighbors.
  LOAD_R = RING / 2 - 1
  MESH_R = LOAD_R - 1
  # Loads that must finish before play goes on (start, respawn) stop at SYNC_R;
  # the rest stream in.
  SYNC_R = 8
  STREAM_BUDGET_NS = 2_500_000

  # Chunk offsets in rings around the player, nearest ring first.
  def make_ring
    @ring_dx = Array.new(0, 0)
    @ring_dz = Array.new(0, 0)
    r = 0
    while r <= LOAD_R
      dx = -r
      while dx <= r
        dz = -r
        while dz <= r
          if dx.abs == r || dz.abs == r
            @ring_dx << dx
            @ring_dz << dz
          end
          dz += 1
        end
        dx += 1
      end
      r += 1
    end
  end

  # Loads and meshes the chunks within radius of chunk (pcx, pcz), nearest
  # first, until budget_ns has passed (a negative budget does all of them).
  # A chunk is meshed once its ring of neighbors has loaded.
  def stream_around(pcx, pcz, budget_ns, radius)
    t0 = Gfx.gfx_ns
    if pcx != @stream_cx || pcz != @stream_cz
      @stream_cx = pcx
      @stream_cz = pcz
      @load_at = 0
      @mesh_at = 0
    end
    load_count = (radius * 2 + 1) * (radius * 2 + 1)
    mesh_count = (radius * 2 - 1) * (radius * 2 - 1)
    while budget_ns < 0 || Gfx.gfx_ns - t0 < budget_ns
      if @mesh_at < mesh_count
        cx = pcx + @ring_dx[@mesh_at]
        cz = pcz + @ring_dz[@mesh_at]
        if @meshed[World.slot(cx, cz)] == 1 && @world.chunk_loaded?(cx, cz)
          @mesh_at += 1
          next
        end
        if meshable?(cx, cz)
          remesh(cx, cz)
          @mesh_at += 1
          next
        end
      end
      break if @load_at >= load_count
      cx = pcx + @ring_dx[@load_at]
      cz = pcz + @ring_dz[@load_at]
      @load_at += 1
      next if @world.chunk_loaded?(cx, cz)
      @meshed[World.slot(cx, cz)] = 0
      @world.load_chunk(cx, cz)
    end
  end

  # Chunks to load around the player for the view distance: the meshed ones
  # (one ring less) then reach past the fog.
  def view_radius = (((detail_view + 20.0) / CHUNK).ceil + 1).clamp(SYNC_R, LOAD_R)

  def detail_view = @fog_end < DETAIL_VIEW ? @fog_end : DETAIL_VIEW
  def far_terrain? = @fog_end > DETAIL_VIEW

  # The widest square ring of chunks around the stream center that is all meshed.
  def detail_rings = ((Math.sqrt(@mesh_at.to_f).to_i - 1) / 2)

  # The first distance a level draws: where the next finer one stops.
  def lod_start(level) = level == 0 ? DETAIL_VIEW : (LOD_REACH << (level - 1)).to_f

  # Tile rings a level builds for the current view.
  def lod_rings(level)
    reach = (LOD_REACH << level).to_f
    reach = @fog_end if @fog_end < reach
    (reach / @lods[level].tile).ceil + 1
  end

  # Far tile offsets in rings, nearest first.
  def make_lod_ring
    @lod_dx = Array.new(0, 0)
    @lod_dz = Array.new(0, 0)
    max = LOD_REACH / 64 + 1
    r = 0
    while r <= max
      dx = -r
      while dx <= r
        dz = -r
        while dz <= r
          if dx.abs == r || dz.abs == r
            @lod_dx << dx
            @lod_dz << dz
          end
          dz += 1
        end
        dx += 1
      end
      r += 1
    end
  end

  # Builds the far tiles within the view, finest level and nearest first,
  # until budget_ns has passed.
  def stream_lod(budget_ns)
    t0 = Gfx.gfx_ns
    level = 0
    while level < LEVELS && @fog_end > lod_start(level)
      lod = @lods[level]
      ptx = @player.x.floor >> lod.tile_shift
      ptz = @player.z.floor >> lod.tile_shift
      if ptx != @lod_tx[level] || ptz != @lod_tz[level]
        @lod_tx[level] = ptx
        @lod_tz[level] = ptz
        @lod_at[level] = 0
      end
      r = lod_rings(level)
      count = (r * 2 + 1) * (r * 2 + 1)
      while @lod_at[level] < count
        return if Gfx.gfx_ns - t0 >= budget_ns
        at = @lod_at[level]
        tx = ptx + @lod_dx[at]
        tz = ptz + @lod_dz[at]
        @lod_at[level] = at + 1
        next if lod.ready?(tx, tz)
        slot = lod.build(tx, tz)
        Gfx.gfx_mesh(LOD_SLOT0 + level * TILE_SLOTS + slot, lod.faces, lod.faces.size / 2, lod.offsets)
      end
      level += 1
    end
  end

  # The square a level covers with complete rings of tiles, into uniforms
  # at (the coarser level's discard square).
  def lod_square(level, at)
    lod = @lods[level]
    rc = (Math.sqrt(@lod_at[level].to_f).to_i - 1) / 2
    r = lod_rings(level)
    rc = r if rc > r
    @uniforms[at] = ((@lod_tx[level] - rc) * lod.tile).to_f
    @uniforms[at + 1] = ((@lod_tz[level] - rc) * lod.tile).to_f
    @uniforms[at + 2] = ((@lod_tx[level] + rc + 1) * lod.tile).to_f
    @uniforms[at + 3] = ((@lod_tz[level] + rc + 1) * lod.tile).to_f
  end

  # GPU slots after the chunks' opaque and water slots, TILE_SLOTS per level.
  LOD_SLOT0 = CX * CZ * 2
  TILE_SLOTS = Lod::TRING * Lod::TRING

  def meshable?(cx, cz)
    w = @world
    w.chunk_loaded?(cx - 1, cz - 1) && w.chunk_loaded?(cx, cz - 1) && w.chunk_loaded?(cx + 1, cz - 1) &&
      w.chunk_loaded?(cx - 1, cz) && w.chunk_loaded?(cx, cz) && w.chunk_loaded?(cx + 1, cz) &&
      w.chunk_loaded?(cx - 1, cz + 1) && w.chunk_loaded?(cx, cz + 1) && w.chunk_loaded?(cx + 1, cz + 1)
  end

  # N on the pause screen: a fresh world from a new seed, same game mode.
  def new_world
    @seed = (Gfx.gfx_ns / 1000) % 1000000
    reset_world
    @chests = {}
    @mobs.clear
    clear_arrows
    @clouds = Clouds.new(@seed)
    spawn
    respawn
    i = 0
    while i < PIGS
      spawn_mob(i % 2 == 0 ? Mob::PIG : Mob::SHEEP, 10.0, 120.0)
      i += 1
    end
    @changed = true
    say("NEW WORLD  SEED #{@seed}")
  end

  def clear_arrows
    @ar_x.clear
    @ar_y.clear
    @ar_z.clear
    @ar_vx.clear
    @ar_vy.clear
    @ar_vz.clear
    @ar_life.clear
    @ar_stuck.clear
    @ar_damage.clear
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
    @air = 10.0
    @dead = false
    @alive_time = 0.0
  end

  # Puts a mob on a surface block at a random distance from the player in [near, far).
  def spawn_mob(kind, near, far)
    tries = 0
    while tries < 20
      tries += 1
      ang = rand01 * 6.283
      dist = near + rand01 * (far - near)
      x = (@player.x + Math.cos(ang) * dist).floor
      z = (@player.z + Math.sin(ang) * dist).floor
      next unless @world.loaded?(x, z)
      h = @world.height_at(x, z)
      ground = @world.get(x, h - 1, z)
      next unless ground == Block::GRASS || ground == Block::SNOW_GRASS || (kind == Mob::ZOMBIE && ground == Block::SAND)
      next if @world.get(x, h, z) != Block::AIR || @world.get(x, h + 1, z) != Block::AIR
      @mobs << Mob.new(kind, x + 0.5, h + 0.01, z + 0.5, (rand01 * 100000.0).to_i)
      return
    end
  end

  def remesh(cx, cz)
    return unless meshable?(cx, cz)
    @mesher.build(cx, cz)
    s = World.slot(cx, cz)
    Gfx.gfx_mesh(s * 2, @mesher.opaque, @mesher.opaque.size / 2, @mesher.offsets)
    Gfx.gfx_mesh(s * 2 + 1, @mesher.water, @mesher.water.size / 2, @mesher.water_offsets)
    @meshed[s] = 1
  end

  # Marks the chunk of a block, and the chunks it touches across an edge.
  def mark_dirty(x, z)
    cx = x >> 4
    cz = z >> 4
    ex = (x & 15) == 0 ? -1 : ((x & 15) == 15 ? 1 : 0)
    ez = (z & 15) == 0 ? -1 : ((z & 15) == 15 ? 1 : 0)
    mark_chunk(cx, cz)
    mark_chunk(cx + ex, cz) if ex != 0
    mark_chunk(cx, cz + ez) if ez != 0
    mark_chunk(cx + ex, cz + ez) if ex != 0 && ez != 0
  end

  # A chunk without a mesh gets one from stream_around, so only meshed ones queue.
  def mark_chunk(cx, cz)
    return unless @world.chunk_loaded?(cx, cz)
    i = World.slot(cx, cz)
    return if @meshed[i] == 0
    if @defer
      return if @dirty[i] || @later[i]
      @later[i] = true
      @later_list << i
      return
    end
    return if @dirty[i]
    @dirty[i] = true
    @dirty_list << i
  end

  MESH_BUDGET_NS = 1_000_000

  # Remeshes every chunk that an edit changed. Then it remeshes deferred
  # chunks until the frame has used MESH_BUDGET_NS.
  def flush_dirty
    t0 = Gfx.gfx_ns
    @dirty_list.each do |i|
      @dirty[i] = false
      @later[i] = false
      remesh(@world.slot_cx[i], @world.slot_cz[i]) if @meshed[i] == 1
    end
    @dirty_list.clear
    while !@later_list.empty? && Gfx.gfx_ns - t0 < MESH_BUDGET_NS
      i = @later_list.shift
      next unless @later[i]
      @later[i] = false
      remesh(@world.slot_cx[i], @world.slot_cz[i]) if @meshed[i] == 1
    end
    @mesh_ms = (Gfx.gfx_ns - t0) / 1.0e6
  end

  def set_block(x, y, z, b)
    @changed = true
    drop_chest(x, y, z) if b != Block::CHEST && @world.get(x, y, z) == Block::CHEST
    old = @world.get(x, y, z)
    if Block.emits?(b) || Block.emits?(old) || (Block::OPAQUE[b] == 0 && near_lava?(x, y, z))
      deferred = @defer
      @defer = true
      cx = (x - 14) / CHUNK
      while cx <= (x + 14) / CHUNK
        cz = (z - 14) / CHUNK
        while cz <= (z + 14) / CHUNK
          mark_chunk(cx, cz)
          cz += 1
        end
        cx += 1
      end
      @defer = deferred
    end
    @world.set(x, y, z, b)
    mark_dirty(x, z)
    set_block(x, y + 1, z, Block::AIR) if b == Block::AIR && Block::PLANT[@world.get(x, y + 1, z)] == 1
    settle_column(x, z)
    wake_water(x, y, z)
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

  # The level a cell should have: 7 under falling water, else one less than the
  # best neighbor that spreads sideways (a source, or water resting on a solid block).
  def flow_target(x, y, z)
    return 7 if Block.water?(@world.get(x, y + 1, z))
    best = 0
    d = 0
    while d < 4
      nx = x + (d == 0 ? 1 : (d == 1 ? -1 : 0))
      nz = z + (d == 2 ? 1 : (d == 3 ? -1 : 0))
      level = Block::WATER_LEVEL[@world.get(nx, y, nz)]
      if level > 0 && (level == 8 || Block::SOLID[@world.get(nx, y - 1, nz)] == 1)
        best = level - 1 if level - 1 > best
      end
      d += 1
    end
    best
  end

  # Lava's version of flow_target: it spreads 3 blocks.
  def lava_target(x, y, z)
    return 3 if Block.lava?(@world.get(x, y + 1, z))
    best = 0
    d = 0
    while d < 4
      nx = x + (d == 0 ? 1 : (d == 1 ? -1 : 0))
      nz = z + (d == 2 ? 1 : (d == 3 ? -1 : 0))
      level = Block.lava_level(@world.get(nx, y, nz))
      if level > 0 && (level == 4 || Block::SOLID[@world.get(nx, y - 1, nz)] == 1)
        best = level - 1 if level - 1 > best
      end
      d += 1
    end
    best
  end

  def touches_water?(x, y, z)
    Block.water?(@world.get(x + 1, y, z)) || Block.water?(@world.get(x - 1, y, z)) ||
      Block.water?(@world.get(x, y + 1, z)) || Block.water?(@world.get(x, y, z + 1)) || Block.water?(@world.get(x, y, z - 1))
  end

  def update_water
    batch = @flow_queue
    @flow_queue = []
    @defer = true
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
        next
      end
      level = Block::WATER_LEVEL[b]
      lava = Block.lava_level(b)
      next if level == 8 || lava == 4
      next unless b == Block::AIR || level > 0 || lava > 0 || Block::PLANT[b] == 1
      target = flow_target(x, y, z)
      lava_to = lava_target(x, y, z)
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
    @defer = false
  end

  def falls?(b) = b == Block::SAND || b == Block::GRAVEL

  # Sand and gravel drop onto the first block below that holds them.
  def settle_column(x, z)
    moved = false
    y = 1
    while y < WY
      b = @world.get(x, y, z)
      if falls?(b)
        below = @world.get(x, y - 1, z)
        if below == Block::AIR || Block.water?(below) || Block::PLANT[below] == 1
          ty = y - 1
          while ty > 0
            under = @world.get(x, ty - 1, z)
            break unless under == Block::AIR || Block.water?(under) || Block::PLANT[under] == 1
            ty -= 1
          end
          @world.set(x, y, z, Block::AIR)
          @world.set(x, ty, z, b)
          wake_water(x, y, z)
          wake_water(x, ty, z)
          moved = true
        end
      end
      y += 1
    end
    mark_dirty(x, z) if moved
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
      if Block::SOLID[@world.get(nx.floor, ny.floor, nz.floor)] == 1
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

  def current_block
    @survival ? @inv_block[@slot] : @hotbar[@slot]
  end

  # How many of b still fit in the inventory.
  def room_for(b)
    room = 0
    i = 0
    while i < INV
      room += STACK - @inv_count[i] if @inv_block[i] == b || @inv_count[i] == 0
      i += 1
    end
    room
  end

  # Adds one b; false when it does not fit.
  def give(b)
    return true if b == Block::AIR
    i = 0
    while i < INV
      if @inv_block[i] == b && @inv_count[i] < STACK
        @inv_count[i] += 1
        return true
      end
      i += 1
    end
    i = 0
    while i < INV
      if @inv_count[i] == 0
        @inv_block[i] = b
        @inv_count[i] = 1
        return true
      end
      i += 1
    end
    false
  end

  # True when every stack of a chest's contents would fit in the inventory.
  def chest_fits?(stored)
    blocks = @inv_block.dup
    counts = @inv_count.dup
    k = 0
    while k < CHEST_SLOTS
      b = stored[k]
      n = stored[CHEST_SLOTS + k]
      i = 0
      while n > 0 && i < INV
        if counts[i] == 0 || blocks[i] == b
          take = STACK - counts[i] < n ? STACK - counts[i] : n
          blocks[i] = b
          counts[i] += take
          n -= take
        end
        i += 1
      end
      return false if n > 0
      k += 1
    end
    true
  end

  # Survival crafting: turns the selected stack into something else.
  RECIPES = [[Block::LOG, 1, Block::PLANKS, 4], [Block::COAL, 1, Block::TORCH, 4],
             [Block::SAND, 1, Block::GLASS, 1], [Block::GRAVEL, 1, Block::ARROW, 4],
             [Block::PLANKS, 3, Block::WOOD_PICK, 1], [Block::COBBLE, 3, Block::STONE_PICK, 1],
             [Block::IRON, 3, Block::IRON_PICK, 1], [Block::DIAMOND, 3, Block::DIAMOND_PICK, 1],
             [Block::STONE, 2, Block::BRICK, 1], [Block::WOOL, 3, Block::BED, 1], [Block::PLANKS, 5, Block::BOW, 1],
             [Block::PLANKS, 8, Block::CHEST, 1]]

  def count_items(b)
    n = 0
    i = 0
    while i < INV
      n += @inv_count[i] if @inv_block[i] == b
      i += 1
    end
    n
  end

  def remove_items(b, n)
    i = INV - 1
    while i >= 0 && n > 0
      if @inv_block[i] == b && @inv_count[i] > 0
        take = @inv_count[i] < n ? @inv_count[i] : n
        @inv_count[i] -= take
        n -= take
        @inv_block[i] = Block::AIR if @inv_count[i] == 0
      end
      i -= 1
    end
  end

  # Crafts recipe k from items anywhere in the inventory.
  def craft_recipe(k)
    r = RECIPES[k]
    if count_items(r[0]) < r[1]
      say("NEED #{r[1]} #{Block::NAMES[r[0]]}")
      return
    end
    if room_for(r[2]) < r[3]
      say("INVENTORY FULL")
      return
    end
    remove_items(r[0], r[1])
    r[3].times { give(r[2]) }
    say("CRAFTED #{r[3]} #{Block::NAMES[r[2]]}")
    play(Sfx::PLACE, 0.6)
  end

  def craft
    b = @inv_block[@slot]
    RECIPES.each do |r|
      next if r[0] != b || @inv_count[@slot] < r[1]
      freed = @inv_count[@slot] == r[1] ? STACK : 0
      if room_for(r[2]) + freed < r[3]
        say("INVENTORY FULL")
        return
      end
      @inv_count[@slot] -= r[1]
      @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
      n = 0
      while n < r[3]
        give(r[2])
        n += 1
      end
      say("CRAFTED #{r[3]} #{Block::NAMES[r[2]]}")
      play(Sfx::PLACE, 0.6)
      return
    end
    say("NOTHING TO CRAFT FROM #{Block::NAMES[b]}") if b != Block::AIR
  end

  def hurt(amount)
    return if !@survival || @dead || amount <= 0
    @health -= amount
    play(Sfx::HURT, 0.8)
    @since_damage = 0.0
    @damage_flash = 0.35
    if @health <= 0
      @health = 0
      @dead = true
      @captured = false
      Gfx.in_capture(0)
    end
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

  INV_COLS = 8

  # Pixel rectangle of inventory cell i: x, y, size.
  def inventory_cell(i, w, h, s)
    size = 56.0 * s
    gap = 8.0 * s
    cols = INV_COLS
    rows = (PLACEABLE.size + cols - 1) / cols
    x0 = (w - (cols * size + (cols - 1) * gap)) / 2.0
    y0 = (h - (rows * size + (rows - 1) * gap)) / 2.0
    [x0 + (i % cols) * (size + gap), y0 + (i / cols) * (size + gap), size]
  end

  def inventory_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    i = 0
    while i < PLACEABLE.size
      c = inventory_cell(i, w, h, s)
      return i if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[2]
      i += 1
    end
    -1
  end

  def ui_scale(h)
    s = (h / 720.0).round.to_f
    s < 1.0 ? 1.0 : s
  end

  # Survival inventory cell i: backpack rows on top, the hotbar row below.
  def pack_cell(i, w, h, s)
    size = 52.0 * s
    gap = 6.0 * s
    row = i < 9 ? 3 : (i - 9) / 9
    col = i < 9 ? i : (i - 9) % 9
    x0 = (w - (9 * size + 8 * gap) - RECIPE_W * s - 60.0 * s) / 2.0
    y0 = (h - (4 * size + 3 * gap + 14.0 * s)) / 2.0
    [x0 + col * (size + gap), y0 + row * (size + gap) + (row == 3 ? 14.0 * s : 0.0), size]
  end

  RECIPE_W = 300.0

  # Recipe row k beside the grid: x, y, width, height.
  def recipe_cell(k, w, h, s)
    last = pack_cell(INV - 1, w, h, s)
    top = pack_cell(9, w, h, s)
    [last[0] + last[2] + 60.0 * s, top[1] + k * 30.0 * s, RECIPE_W * s, 26.0 * s]
  end

  def recipe_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    k = 0
    while k < RECIPES.size
      c = recipe_cell(k, w, h, s)
      return k if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[3]
      k += 1
    end
    -1
  end

  def pack_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    i = 0
    while i < INV
      c = pack_cell(i, w, h, s)
      return i if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[2]
      i += 1
    end
    -1
  end

  def click_slot(i) = click_cell(@inv_block, @inv_count, i)

  # A click picks up a stack, puts it down, merges it, or swaps it.
  def click_cell(blocks, counts, i)
    b = blocks[i]
    n = counts[i]
    if @held_count == 0
      return if n == 0
      @held_block = b
      @held_count = n
      blocks[i] = Block::AIR
      counts[i] = 0
    elsif n == 0
      blocks[i] = @held_block
      counts[i] = @held_count
      @held_count = 0
      @held_block = Block::AIR
    elsif b == @held_block
      moved = [STACK - n, @held_count].min
      counts[i] += moved
      @held_count -= moved
      @held_block = Block::AIR if @held_count == 0
    else
      blocks[i] = @held_block
      counts[i] = @held_count
      @held_block = b
      @held_count = n
    end
  end

  # Chest cell k, in the place of the recipe list: x, y, size.
  def chest_cell(k, w, h, s)
    first = recipe_cell(0, w, h, s)
    size = 31.0 * s
    [first[0] + (k % 9) * (size + 2.0 * s), first[1] + (k / 9) * (size + 2.0 * s), size]
  end

  def chest_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    k = 0
    while k < CHEST_SLOTS
      c = chest_cell(k, w, h, s)
      return k if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[2]
      k += 1
    end
    -1
  end

  def open_chest(x, y, z)
    @chest_key = World.key(x, y, z)
    stored = @chests[@chest_key]
    k = 0
    while k < CHEST_SLOTS
      @chest_block[k] = stored.nil? ? 0 : stored[k]
      @chest_count[k] = stored.nil? ? 0 : stored[CHEST_SLOTS + k]
      k += 1
    end
    toggle_inventory
  end

  def close_chest
    return if @chest_key < 0
    @chests[@chest_key] = @chest_block + @chest_count
    @chest_key = -1
  end

  # Breaking a chest gives back what it held (in survival).
  def drop_chest(x, y, z)
    key = World.key(x, y, z)
    if key == @chest_key
      return_held
      close_chest
      @inventory_open = false
      @captured = true
      Gfx.in_capture(1)
    end
    stored = @chests[key]
    return if stored.nil?
    if @survival
      k = 0
      while k < CHEST_SLOTS
        stored[CHEST_SLOTS + k].times { give(stored[k]) }
        k += 1
      end
    end
    @chests.delete(key)
  end

  def return_held
    while @held_count > 0 && give(@held_block)
      @held_count -= 1
    end
    if @held_count > 0 && @chest_key >= 0
      k = 0
      while k < CHEST_SLOTS && @held_count > 0
        if @chest_count[k] == 0 || @chest_block[k] == @held_block
          take = STACK - @chest_count[k] < @held_count ? STACK - @chest_count[k] : @held_count
          @chest_block[k] = @held_block
          @chest_count[k] += take
          @held_count -= take
        end
        k += 1
      end
    end
    @held_block = Block::AIR if @held_count == 0
  end

  def toggle_inventory
    if @inventory_open
      return_held
      if @held_count > 0
        say("NO ROOM FOR THE HELD STACK")
        return
      end
    end
    close_chest if @inventory_open
    @inventory_open = !@inventory_open
    @captured = !@inventory_open
    Gfx.in_capture(@inventory_open ? 0 : 1)
  end

  def handle_inventory
    if Gfx.in_key_pressed(Key::E) != 0 || Gfx.in_key_pressed(Key::ESCAPE) != 0
      toggle_inventory
      return
    end
    i = 0
    while i < 9
      @slot = i if Gfx.in_key_pressed(Key::N1 + i) != 0
      i += 1
    end
    craft if @survival && Gfx.in_key_pressed(Key::C) != 0
    if @survival && Gfx.in_button_pressed(1) != 0
      w = Gfx.gfx_width.to_f
      h = Gfx.gfx_height.to_f
      hover = pack_hover(w, h, ui_scale(h))
      click_slot(hover) if hover >= 0
      if @chest_key >= 0
        cell = chest_hover(w, h, ui_scale(h))
        click_cell(@chest_block, @chest_count, cell) if cell >= 0
      else
        recipe = recipe_hover(w, h, ui_scale(h))
        craft_recipe(recipe) if recipe >= 0 && @held_count == 0
      end
    elsif Gfx.in_button_pressed(1) != 0
      w = Gfx.gfx_width.to_f
      h = Gfx.gfx_height.to_f
      hover = inventory_hover(w, h, ui_scale(h))
      if hover >= 0
        @hotbar[@slot] = PLACEABLE[hover]
        say(Block::NAMES[PLACEABLE[hover]])
        play(Sfx::PLACE, 0.4)
      end
    end
  end

  def handle_input(dt)
    if @inventory_open
      handle_inventory
      return
    end
    if Gfx.in_key_pressed(Key::ESCAPE) != 0 || Gfx.in_focus_lost != 0
      # Saving takes tens of milliseconds, so it happens when the game pauses, not mid-play.
      save if @captured && @changed && @save_on_quit
      @captured = false
      Gfx.in_capture(0)
    end
    if @dead
      if Gfx.in_button_pressed(1) != 0 || Gfx.in_key_pressed(Key::R) != 0
        respawn
        @captured = true
        Gfx.in_capture(1)
      end
      return
    end
    if !@captured
      new_world if Gfx.in_key_pressed(Key::N) != 0
      if Gfx.in_button_pressed(1) != 0
        @captured = true
        Gfx.in_capture(1)
      end
      return
    end
    @player.look(Gfx.in_mouse_dx, Gfx.in_mouse_dy)
    i = 0
    while i < 9
      @slot = i if Gfx.in_key_pressed(Key::N1 + i) != 0
      i += 1
    end
    wheel = Gfx.in_wheel
    @slot = (@slot + 1) % 9 if wheel < 0.0
    @slot = (@slot + 8) % 9 if wheel > 0.0
    if Gfx.in_key_pressed(Key::E) != 0
      toggle_inventory
      return
    end
    if !@survival && Gfx.in_key_pressed(Key::Q) != 0
      at = PLACEABLE.index(@hotbar[@slot]) || 0
      @hotbar[@slot] = PLACEABLE[(at + 1) % PLACEABLE.size]
      say(Block::NAMES[@hotbar[@slot]])
    end
    if Gfx.in_key_pressed(Key::G) != 0
      @survival = !@survival
      @player.flying = false if @survival
      say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
    end
    if Gfx.in_key_pressed(Key::F) != 0 && !@survival
      @player.flying = !@player.flying
      say(@player.flying ? "FLYING" : "WALKING")
    end
    @show_debug = !@show_debug if Gfx.in_key_pressed(Key::F3) != 0
    save if Gfx.in_key_pressed(Key::F5) != 0
    if Gfx.in_key_pressed(Key::F4) != 0
      i = VIEWS.index { |v| v > @fog_end }
      @fog_end = i.nil? ? VIEWS[0] : VIEWS[i]
      say("VIEW DISTANCE #{@fog_end.to_i}")
    end
    if Gfx.in_key_pressed(Key::F11) != 0
      @fullscreen = !@fullscreen
      Gfx.gfx_fullscreen(@fullscreen ? 1 : 0)
    end
    craft if @survival && Gfx.in_key_pressed(Key::C) != 0
    @time_of_day += 0.25 if Gfx.in_key_pressed(Key::T) != 0

    @action_cooldown -= dt
    left = Gfx.in_button(1) != 0
    right = Gfx.in_button(3) != 0
    left_pressed = Gfx.in_button_pressed(1) != 0
    @action_cooldown = 0.0 if left_pressed || Gfx.in_button_pressed(3) != 0
    if Gfx.in_button_pressed(2) != 0 && @player.hit && !@survival
      picked = @world.get(@player.hx, @player.hy, @player.hz)
      @hotbar[@slot] = picked if picked != Block::BEDROCK
      say(Block::NAMES[@hotbar[@slot]])
    end

    if left && @target_mob >= 0
      if left_pressed
        mob = @mobs[@target_mob]
        mob.hit(@survival ? 4 : 10, @player.x, @player.z)
        mob.by_player = true
        play(Sfx::HIT, 0.8)
        @swing = 0.25
      end
      left = false
    end
    if left && @player.hit
      if @survival
        mine(dt)
      elsif @action_cooldown <= 0.0
        broken = @world.get(@player.hx, @player.hy, @player.hz)
        burst_particles(@player.hx, @player.hy, @player.hz, broken)
        play(Sfx::BREAK, 0.7)
        set_block(@player.hx, @player.hy, @player.hz, Block::AIR)
        @action_cooldown = 0.22
        @swing = 0.25
      end
    else
      @mining = false
    end
    target = @player.hit ? @world.get(@player.hx, @player.hy, @player.hz) : Block::AIR
    if current_block == Block::BOW && target != Block::CHEST && target != Block::BED
      if right
        @draw_time = 0.0 if @draw_time < 0.0
        @draw_time += dt
      elsif @draw_time >= 0.0
        shoot_bow(@draw_time)
        @draw_time = -1.0
      end
      return
    end
    @draw_time = -1.0
    if right && @action_cooldown <= 0.0
      if @survival && @player.hit && @world.get(@player.hx, @player.hy, @player.hz) == Block::CHEST
        open_chest(@player.hx, @player.hy, @player.hz)
        return
      elsif @player.hit && @world.get(@player.hx, @player.hy, @player.hz) == Block::BED
        use_bed(@player.hx, @player.hy, @player.hz)
      elsif current_block == Block::PORKCHOP
        eat
      elsif @player.hit
        place
      end
      @action_cooldown = 0.22
    end
  end

  def mine(dt)
    x = @player.hx
    y = @player.hy
    z = @player.hz
    if !@mining || x != @mine_x || y != @mine_y || z != @mine_z
      @mining = true
      @mine_x = x
      @mine_y = y
      @mine_z = z
      @mine_progress = 0.0
      @dig_wait = 0.0
    end
    b = @world.get(x, y, z)
    hardness = Block::HARDNESS[b]
    return if hardness < 0.0
    @dig_wait -= dt
    if @dig_wait <= 0.0 && hardness > 0.0
      play(dig_sound(b), 0.55)
      @dig_wait = 0.25
    end
    @swing = 0.25
    tier = Block::PICK_TIER[current_block]
    need = Block::NEEDS_PICK[b]
    # A good enough pickaxe speeds up stone; without one, stone is slow.
    speed = need == 0 ? 1.0 : (tier >= need ? 1.0 + tier * 1.2 : 0.3)
    @mine_progress += hardness == 0.0 ? 1.0 : dt * speed / hardness
    if @mine_progress >= 1.0 && b == Block::CHEST
      stored = @chests[World.key(x, y, z)]
      unless stored.nil? || chest_fits?(stored)
        say("EMPTY THE CHEST FIRST  INVENTORY FULL")
        @mine_progress = 0.0
        return
      end
    end
    if @mine_progress >= 1.0
      drop = tier >= need ? Block::DROPS[b] : Block::AIR
      if drop != Block::AIR && room_for(drop) == 0
        say("INVENTORY FULL")
        @mine_progress = 0.0
        return
      end
      burst_particles(x, y, z, b)
      play(Sfx::BREAK, 0.7)
      set_block(x, y, z, Block::AIR)
      give(drop)
      @mining = false
    end
  end

  def dig_sound(b)
    return Sfx::DIG_STONE if Block::NEEDS_PICK[b] > 0 || b == Block::GLASS || b == Block::BEDROCK
    return Sfx::DIG_WOOD if b == Block::LOG || b == Block::PLANKS || b == Block::CHEST || b == Block::BED
    Sfx::DIG_SOFT
  end

  # A bed sets the spawn point; at night with no monster close by, it skips to morning.
  def use_bed(x, y, z)
    @spawn_x = x + 0.5
    @spawn_z = z + 0.5
    if daylight > 0.35
      say("SPAWN SET  YOU CAN ONLY SLEEP AT NIGHT")
      return
    end
    near = @mobs.count { |m| m.kind != Mob::PIG && m.kind != Mob::SHEEP && (m.x - x) ** 2 + (m.z - z) ** 2 < 100.0 }
    if near > 0
      say("YOU CANNOT SLEEP NOW  MONSTERS ARE NEARBY")
      return
    end
    @time_of_day = 0.02
    say("GOOD MORNING")
  end

  def eat
    return unless @survival && @inv_count[@slot] > 0 && @hunger < MAX_HUNGER
    @hunger = [@hunger + 8, MAX_HUNGER].min
    @inv_count[@slot] -= 1
    @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
    play(Sfx::PLACE, 0.5)
    say("YUM")
  end

  def place
    b = current_block
    return if b == Block::AIR || Block.item?(b)
    return if @survival && @inv_count[@slot] <= 0
    x = @player.px
    y = @player.py
    z = @player.pz
    return unless @world.inside?(x, y, z)
    return if Block::SOLID[b] == 1 && @player.overlaps?(x, y, z)
    return if Block::PLANT[b] == 1 && (Block::SOLID[@world.get(x, y - 1, z)] == 0 || Block.water?(@world.get(x, y, z)))
    if Block::SOLID[b] == 1
      @mobs.each do |m|
        return if x + 1 > m.x - m.half && x < m.x + m.half && y + 1 > m.y && y < m.y + m.tall && z + 1 > m.z - m.half && z < m.z + m.half
      end
    end
    current = @world.get(x, y, z)
    return unless current == Block::AIR || Block.water?(current) || Block::PLANT[current] == 1
    set_block(x, y, z, b)
    play(Sfx::PLACE, 0.7)
    @swing = 0.25
    if @survival
      @inv_count[@slot] -= 1
      @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
    end
  end

  def update(dt)
    fwd = 0.0
    strafe = 0.0
    jump = false
    down = false
    sprint = false
    if @captured && !@dead
      fwd += 1.0 if Gfx.in_key(Key::W) != 0
      fwd -= 1.0 if Gfx.in_key(Key::S) != 0
      strafe += 1.0 if Gfx.in_key(Key::D) != 0
      strafe -= 1.0 if Gfx.in_key(Key::A) != 0
      jump = Gfx.in_key(Key::SPACE) != 0
      down = Gfx.in_key(Key::LSHIFT) != 0
      # Double-tap W to sprint until W is released.
      if Gfx.in_key_pressed(Key::W) != 0
        @w_sprint = @anim_time - @last_w < 0.3 && @anim_time > @last_w
        @last_w = @anim_time
      end
      @w_sprint = false if Gfx.in_key(Key::W) == 0
      sprint = Gfx.in_key(Key::LCTRL) != 0 || @w_sprint
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
    @cloud_drift += dt * 1.2
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
      @air = 10.0
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

  def update_mobs(dt)
    day = daylight
    @spawn_timer -= dt
    if @spawn_timer <= 0.0
      @spawn_timer = 2.0
      zombies = 0
      pigs = 0
      @mobs.each { |m| m.kind == Mob::PIG || m.kind == Mob::SHEEP ? pigs += 1 : zombies += 1 }
      roll = rand01
      spawn_mob(roll < 0.3 ? Mob::SKELETON : (roll < 0.55 ? Mob::CREEPER : Mob::ZOMBIE), 18.0, 40.0) if day < 0.35 && zombies < MAX_ZOMBIES
      spawn_mob(rand01 < 0.5 ? Mob::PIG : Mob::SHEEP, 40.0, 90.0) if pigs < PIGS / 2
    end
    @mobs.each do |m|
      if rand01 < dt * 0.08
        play(m.kind == Mob::PIG ? Sfx::OINK : (m.kind == Mob::ZOMBIE ? Sfx::GROAN : (m.kind == Mob::SHEEP ? Sfx::OINK : (m.kind == Mob::CREEPER ? Sfx::SPLASH : Sfx::STEP))), near_volume(m.x, m.z, 0.8))
      end
      if m.shoot
        m.shoot = false
        shoot_arrow(m)
      end
      if m.explode
        m.explode = false
        m.alive = false
        explode(m.x, m.y + 0.8, m.z)
      end
      steps = dt > 0.025 ? 2 : 1
      sdt = dt / steps
      k = 0
      while k < steps
        damage = m.update(@world, sdt, @player, day)
        if damage > 0
          hurt(damage)
          if @survival
            dx = @player.x - m.x
            dz = @player.z - m.z
            len = Math.sqrt(dx * dx + dz * dz)
            len = 1.0 if len < 0.001
            @player.vx = dx / len * 8.0
            @player.vz = dz / len * 8.0
            @player.vy = 5.0
          end
        end
        k += 1
      end
    end
    if @survival
      @mobs.each do |m|
        next unless !m.alive && m.kind == Mob::SKELETON && m.hp <= 0 && m.by_player
        n = 1 + (rand01 * 3.0).to_i
        n.times { give(Block::ARROW) }
        give(Block::BOW) if rand01 < 0.3
        say("+#{n} ARROWS")
      end
    end
    sheared = @mobs.count { |m| !m.alive && m.kind == Mob::SHEEP && m.hp <= 0 && m.by_player }
    if sheared > 0 && @survival
      (sheared * 2).times { give(Block::WOOL) }
      say("+#{sheared * 2} WOOL")
    end
    killed = @mobs.count { |m| !m.alive && m.kind == Mob::PIG && m.hp <= 0 && m.by_player }
    if killed > 0 && @survival
      killed.times { give(Block::PORKCHOP) }
      say("+#{killed} PORKCHOP  RIGHT CLICK TO EAT")
    end
    steps = (dt * 180.0).ceil
    steps = 1 if steps < 1
    steps.times { update_arrows(dt / steps) }
    @mobs.reject! do |m|
      d2 = (m.x - @player.x) ** 2 + (m.z - @player.z) ** 2
      !m.alive || !@world.loaded?(m.x.floor, m.z.floor) || d2 > 160.0 * 160.0 ||
        (m.kind != Mob::PIG && m.kind != Mob::SHEEP && d2 > 64.0 * 64.0)
    end
  end

  # Draw time (seconds) sets speed and damage; a full draw takes one second.
  def shoot_bow(held)
    pull = held > 1.0 ? 1.0 : held
    return if pull < 0.1
    if @survival
      slot = -1
      i = 0
      while i < INV
        slot = i if slot < 0 && @inv_block[i] == Block::ARROW && @inv_count[i] > 0
        i += 1
      end
      if slot < 0
        say("NO ARROWS")
        return
      end
      @inv_count[slot] -= 1
      @inv_block[slot] = Block::AIR if @inv_count[slot] == 0
    end
    speed = 12.0 + pull * 30.0
    @ar_x << @player.x
    @ar_y << @player.eye_y - 0.1
    @ar_z << @player.z
    @ar_vx << @player.fx * speed
    @ar_vy << @player.fy * speed
    @ar_vz << @player.fz * speed
    @ar_life << 5.0
    @ar_stuck << false
    @ar_damage << 2 + (pull * 7.0).to_i
    @swing = 0.25
    play(Sfx::SHOOT, 0.8)
  end

  # Removes blocks within the radius and hurts what is near, less with distance.
  def explode(cx, cy, cz)
    r = 3
    x = cx.floor - r
    while x <= cx.floor + r
      y = cy.floor - r
      while y <= cy.floor + r
        z = cz.floor - r
        while z <= cz.floor + r
          dx = x + 0.5 - cx
          dy = y + 0.5 - cy
          dz = z + 0.5 - cz
          b = @world.get(x, y, z)
          if dx * dx + dy * dy + dz * dz < 9.5 - rand01 * 2.5 && b != Block::AIR && b != Block::BEDROCK && !Block.water?(b) && !Block.lava?(b)
            burst_particles(x, y, z, b) if rand01 < 0.15
            set_block(x, y, z, Block::AIR)
          end
          z += 1
        end
        y += 1
      end
      x += 1
    end
    play(Sfx::BREAK, 1.0)
    play(Sfx::HIT, 1.0)
    pdx = @player.x - cx
    pdy = @player.y + 0.9 - cy
    pdz = @player.z - cz
    dist = Math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz)
    if dist < 7.0
      hurt(((7.0 - dist) * 3.2).to_i)
      len = dist < 0.1 ? 1.0 : dist
      @player.vx += pdx / len * (7.0 - dist) * 2.0
      @player.vz += pdz / len * (7.0 - dist) * 2.0
      @player.vy += 4.0 + (7.0 - dist)
    end
    @mobs.each do |m|
      next unless m.alive
      mdx = m.x - cx
      mdz = m.z - cz
      d = Math.sqrt(mdx * mdx + mdz * mdz)
      m.hit(((7.0 - d) * 3.0).to_i, cx, cz) if d < 7.0
    end
  end

  def shoot_arrow(m)
    sx = m.x
    sy = m.y + 1.5
    sz = m.z
    dx = @player.x - sx
    dy = @player.y + 1.2 - sy
    dz = @player.z - sz
    dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
    return if dist < 0.5
    speed = 22.0
    t = dist / speed
    @ar_x << sx
    @ar_y << sy
    @ar_z << sz
    @ar_vx << dx / t
    @ar_vy << dy / t + 9.0 * t
    @ar_vz << dz / t
    @ar_life << 4.0
    @ar_stuck << false
    @ar_damage << 0
    play(Sfx::SHOOT, near_volume(sx, sz, 0.9))
  end

  def update_arrows(dt)
    i = 0
    while i < @ar_life.size
      @ar_life[i] -= dt
      unless @ar_stuck[i]
        @ar_vy[i] -= 18.0 * dt
        nx = @ar_x[i] + @ar_vx[i] * dt
        ny = @ar_y[i] + @ar_vy[i] * dt
        nz = @ar_z[i] + @ar_vz[i] * dt
        if Block::SOLID[@world.get(nx.floor, ny.floor, nz.floor)] == 1
          @ar_stuck[i] = true
          @ar_life[i] = 3.0 if @ar_life[i] > 3.0
        else
          @ar_x[i] = nx
          @ar_y[i] = ny
          @ar_z[i] = nz
          p = @player
          if @ar_damage[i] > 0
            k = 0
            while k < @mobs.size
              m = @mobs[k]
              if nx > m.x - m.half && nx < m.x + m.half && ny > m.y && ny < m.y + m.tall && nz > m.z - m.half && nz < m.z + m.half
                m.hit(@ar_damage[i], nx - @ar_vx[i], nz - @ar_vz[i])
                m.by_player = true
                play(Sfx::HIT, near_volume(nx, nz, 0.8))
                @ar_life[i] = 0.0
                break
              end
              k += 1
            end
          elsif nx > p.x - Player::HALF && nx < p.x + Player::HALF && ny > p.y && ny < p.y + Player::TALL && nz > p.z - Player::HALF && nz < p.z + Player::HALF
            hurt(3)
            if @survival
              len = Math.sqrt(@ar_vx[i] * @ar_vx[i] + @ar_vz[i] * @ar_vz[i])
              len = 1.0 if len < 0.001
              @player.vx += @ar_vx[i] / len * 5.0
              @player.vz += @ar_vz[i] / len * 5.0
            end
            @ar_life[i] = 0.0
          end
        end
      end
      i += 1
    end
    i = @ar_life.size - 1
    while i >= 0
      if @ar_life[i] <= 0.0
        @ar_x.delete_at(i)
        @ar_y.delete_at(i)
        @ar_z.delete_at(i)
        @ar_vx.delete_at(i)
        @ar_vy.delete_at(i)
        @ar_vz.delete_at(i)
        @ar_life.delete_at(i)
        @ar_stuck.delete_at(i)
        @ar_damage.delete_at(i)
      end
      i -= 1
    end
  end

  def draw_arrows
    i = 0
    while i < @ar_life.size
      vx = @ar_vx[i]
      vy = @ar_vy[i]
      vz = @ar_vz[i]
      yaw = Math.atan2(-vx, vz)
      pitch = -Math.atan2(vy, Math.sqrt(vx * vx + vz * vz))
      @dyn.box(@ar_x[i], @ar_y[i], @ar_z[i], yaw, 0.0, 0.0, pitch, -0.03, -0.03, -0.6, 0.03, 0.03, 0.0, Tex::WHITE, 0.45, 0.32, 0.18, 1.0)
      @dyn.box(@ar_x[i], @ar_y[i], @ar_z[i], yaw, 0.0, 0.0, pitch, -0.05, -0.05, -0.62, 0.05, 0.05, -0.5, Tex::WHITE, 0.9, 0.9, 0.9, 1.0)
      i += 1
    end
  end

  def find_target_mob
    @target_mob = -1
    return if @mobs.empty?
    best = @player.hit ? @player.hit_t : 3.5
    best = 3.5 if best > 3.5
    ox = @player.x
    oy = @player.eye_y
    oz = @player.z
    dx = @player.fx
    dy = @player.fy
    dz = @player.fz
    i = 0
    while i < @mobs.size
      m = @mobs[i]
      # Mob#ray allocates; skip the mobs that are out of reach.
      if (m.x - ox) ** 2 + (m.z - oz) ** 2 < 25.0
        t = m.ray(ox, oy, oz, dx, dy, dz)
        if t >= 0.0 && t < best
          best = t
          @target_mob = i
        end
      end
      i += 1
    end
  end

  def daylight
    s = Math.sin(@time_of_day * Math::PI * 2.0)
    (0.5 + s * 0.9).clamp(0.12, 1.0)
  end

  def render
    w = Gfx.gfx_width.to_f
    h = Gfx.gfx_height.to_f
    ex = @player.x
    ey = @player.eye_y
    ez = @player.z
    walking = @player.on_ground && !@player.flying
    speed = Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz)
    ey += Math.sin(@bob) * 0.05 * (speed / 4.3).clamp(0.0, 1.0) if walking
    @camera.update(ex, ey, ez, @player.yaw, @player.pitch, w / h, @fog_end + 40.0, @fov)
    @camera.write_column_major(@uniforms)
    day = daylight
    under = Block.water?(@world.get(ex.floor, ey.floor, ez.floor))
    sky_r = 0.03 + 0.50 * day
    sky_g = 0.04 + 0.68 * day
    sky_b = 0.10 + 0.88 * day
    dusk = 1.0 - Math.sin(@time_of_day * Math::PI * 2.0).abs * 4.0
    if dusk > 0.0
      dusk *= 0.75
      sky_r += (1.0 - sky_r) * dusk
      sky_g += (0.55 - sky_g) * dusk
      sky_b += (0.25 - sky_b) * dusk
    end
    @uniforms[16] = ex
    @uniforms[17] = ey
    @uniforms[18] = ez
    # Seconds for texture animation; wraps before float precision suffers.
    @uniforms[19] = @anim_time
    @uniforms[20] = under ? 0.05 : sky_r
    @uniforms[21] = under ? 0.15 : sky_g
    @uniforms[22] = under ? 0.35 : sky_b
    @uniforms[23] = under ? 24.0 : @fog_end
    @uniforms[24] = day
    # Fog at the view's end starts 65 blocks before it, or a quarter of the
    # view before it for long views, so it blends with the haze.
    @uniforms[25] = under ? 2.0 : @fog_end - (@fog_end * 0.25 > 65.0 ? @fog_end * 0.25 : 65.0)
    @uniforms[26] = w
    @uniforms[27] = h

    @visible.clear
    @water_visible.clear
    @water_order.clear
    reach = @fog_end + 4.0
    # With far terrain on, full detail stops at the last complete ring, and
    # the far terrain shader skips the square those rings cover.
    rings = far_terrain? ? detail_rings : LOAD_R
    @uniforms[28] = ((@stream_cx - rings) * CHUNK).to_f
    @uniforms[29] = ((@stream_cz - rings) * CHUNK).to_f
    @uniforms[30] = ((@stream_cx + rings + 1) * CHUNK).to_f
    @uniforms[31] = ((@stream_cz + rings + 1) * CHUNK).to_f
    s = 0
    while s < CX * CZ
      if @meshed[s] == 1 && (@world.slot_cx[s] - @stream_cx).abs <= rings && (@world.slot_cz[s] - @stream_cz).abs <= rings
        x0 = (@world.slot_cx[s] * CHUNK).to_f
        z0 = (@world.slot_cz[s] * CHUNK).to_f
        dx = (x0 + 8.0 - ex).abs - 8.0
        dz = (z0 + 8.0 - ez).abs - 8.0
        dx = 0.0 if dx < 0.0
        dz = 0.0 if dz < 0.0
        d2 = dx * dx + dz * dz
        if d2 < reach * reach && @camera.box_visible?(x0, 0.0, z0, x0 + 16.0, WY.to_f, z0 + 16.0)
          slot = s * 2
          # Only directions that can face the camera.
          mask = 4 | 8 | 64
          mask |= 1 if ex > x0
          mask |= 2 if ex < x0 + 16.0
          mask |= 16 if ez > z0
          mask |= 32 if ez < z0 + 16.0
          @visible << slot << mask
          @water_order << slot + 1
          @water_dist << -d2
        end
      end
      s += 1
    end
    @lod_visible.clear
    level = 0
    while level < LEVELS && @fog_end > lod_start(level)
      # Uniforms 28 + 4 * L hold the square level L skips: full detail for
      # level 0, the complete rings of level L - 1 for the others.
      at = 28 + level * 4
      lod_square(level - 1, at) if level > 0
      lod = @lods[level]
      size = lod.tile.to_f
      s = 0
      while s < TILE_SLOTS
        if lod.built[s] == 1
          x0 = lod.tile_x[s] * size
          z0 = lod.tile_z[s] * size
          x1 = x0 + size
          z1 = z0 + size
          dx = (x0 + size / 2.0 - ex).abs - size / 2.0
          dz = (z0 + size / 2.0 - ez).abs - size / 2.0
          dx = 0.0 if dx < 0.0
          dz = 0.0 if dz < 0.0
          inside = x0 >= @uniforms[at] && z0 >= @uniforms[at + 1] && x1 <= @uniforms[at + 2] && z1 <= @uniforms[at + 3]
          if !inside && dx * dx + dz * dz < reach * reach && @camera.box_visible?(x0, 0.0, z0, x1, WY.to_f + 8.0, z1)
            mask = 4
            mask |= 1 if ex > x0
            mask |= 2 if ex < x1
            mask |= 16 if ez > z0
            mask |= 32 if ez < z1
            @lod_visible << LOD_SLOT0 + level * TILE_SLOTS + s << mask
          end
        end
        s += 1
      end
      level += 1
    end
    # Water blends, so draw the far chunks first.
    order = (0...@water_order.size).sort_by { |i| @water_dist[i] }
    order.each { |i| @water_visible << @water_order[i] << 127 }
    @water_dist.clear

    @dyn.clear
    @mobs.each do |m|
      ddx = m.x - ex
      ddz = m.z - ez
      next if ddx * ddx + ddz * ddz > reach * reach
      next unless @camera.box_visible?(m.x - 1.0, m.y, m.z - 1.0, m.x + 1.0, m.y + 2.0, m.z + 1.0)
      m.draw(@dyn)
    end
    @clouds.draw(@dyn, ex, ez, @cloud_drift)
    draw_arrows
    i = 0
    while i < @pt_life.size
      x = @pt_x[i]
      y = @pt_y[i]
      z = @pt_z[i]
      @dyn.aabb(x - 0.06, y - 0.06, z - 0.06, x + 0.06, y + 0.06, z + 0.06, @pt_layer[i], 1.0, 1.0, 1.0, 1.0)
      i += 1
    end
    if @player.hit && @captured && @target_mob < 0
      @dyn.outline(@player.hx, @player.hy, @player.hz)
      if @mining && @mine_progress > 0.0
        e = 0.003
        x = @mine_x.to_f
        y = @mine_y.to_f
        z = @mine_z.to_f
        stage = (@mine_progress * Tex::CRACK_STAGES).to_i
        stage = Tex::CRACK_STAGES - 1 if stage >= Tex::CRACK_STAGES
        @dyn.aabb(x - e, y - e, z - e, x + 1.0 + e, y + 1.0 + e, z + 1.0 + e, Tex::CRACK + stage, 1.0, 1.0, 1.0, 1.0)
      end
    end
    Gfx.gfx_dyn(@dyn.v, @dyn.count)
    build_ui(w, h)
    Gfx.gfx_ui(@ui.v, @ui.v.size)
    build_sky(w, h, ui_scale(h))
    Gfx.gfx_sky(@sky.v, @sky.v.size)
    @cpu_end = Gfx.gfx_ns
    if Gfx.gfx_begin(@uniforms) == 0
      @faces_drawn = Gfx.gfx_chunks(@visible, @visible.size / 2, 0)
      @faces_drawn += Gfx.gfx_chunks(@lod_visible, @lod_visible.size / 2, 2)
      Gfx.gfx_draw_dyn
      @faces_drawn += Gfx.gfx_chunks(@water_visible, @water_visible.size / 2, 1)
    end
    Gfx.gfx_end
  end

  STARS = 260

  # Star directions on the upper sphere, fixed for the world.
  def make_stars
    @stars = []
    rng = 977
    i = 0
    while i < STARS
      rng = (rng * 1103515245 + 12345) & 0x7fffffff
      u = (rng % 10000) / 10000.0
      rng = (rng * 1103515245 + 12345) & 0x7fffffff
      v = (rng % 10000) / 10000.0
      rng = (rng * 1103515245 + 12345) & 0x7fffffff
      bright = 0.4 + (rng % 600) / 1000.0
      theta = u * 6.283185
      y = v * 1.6 - 0.6
      r = Math.sqrt(1.0 - y * y)
      @stars << r * Math.cos(theta) << y << r * Math.sin(theta) << bright
      i += 1
    end
  end

  # Sky layer: drawn before the world, so terrain and clouds cover it.
  def build_sky(w, h, s)
    @sky.clear
    draw_sky_body(w, h, s, 1.0, 1.0, 0.95, 0.75, 70.0)
    draw_sky_body(w, h, s, -1.0, 0.85, 0.88, 0.95, 46.0)
    night = (0.55 - daylight) * 2.5
    return if night <= 0.0
    night = 1.0 if night > 1.0
    a = @time_of_day * Math::PI * 2.0
    ca = Math.cos(a)
    sa = Math.sin(a)
    ex = @player.x
    ey = @player.eye_y
    ez = @player.z
    i = 0
    while i < @stars.size
      # The stars turn with the sun around the z axis.
      sx = @stars[i]
      sy = @stars[i + 1]
      rx = sx * ca - sy * sa
      ry = sx * sa + sy * ca
      if ry > -0.05
        if @camera.project(ex + rx * 100.0, ey + ry * 100.0, ez + @stars[i + 2] * 100.0, w, h)
          size = 2.0 * s
          c = @stars[i + 3]
          @sky.rect(@camera.sx, @camera.sy, size, size, c, c, c * 1.05, night)
        end
      end
      i += 4
    end
  end

  # The sun (side 1) or the moon (side -1).
  def draw_sky_body(w, h, s, side, r, g, b, size)
    a = @time_of_day * Math::PI * 2.0
    dx = Math.cos(a) * side
    dy = Math.sin(a) * side
    dz = 0.25
    return if dy < -0.15
    ex = @player.x
    ey = @player.eye_y
    ez = @player.z
    return unless @camera.project(ex + dx * 100.0, ey + dy * 100.0, ez + dz * 100.0, w, h)
    half = size * s / 2.0
    sx = @camera.sx
    sy = @camera.sy
    @sky.rect(sx - half * 1.4, sy - half * 1.4, half * 2.8, half * 2.8, r, g, b, 0.18)
    @sky.rect(sx - half, sy - half, half * 2.0, half * 2.0, r, g, b, 1.0)
  end

  def build_ui(w, h)
    @ui.clear
    s = (h / 720.0).round.to_f
    s = 1.0 if s < 1.0
    eye_block = @world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor)
    if Block.water?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.1, 0.25, 0.6, 0.25)
    elsif Block.lava?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.9, 0.3, 0.05, 0.75)
    end
    if @damage_flash > 0.0
      @ui.rect(0.0, 0.0, w, h, 0.8, 0.0, 0.0, @damage_flash)
    end
    # crosshair
    @ui.rect(w / 2.0 - 9.0 * s, h / 2.0 - 1.0 * s, 18.0 * s, 2.0 * s, 1.0, 1.0, 1.0, 0.8)
    @ui.rect(w / 2.0 - 1.0 * s, h / 2.0 - 9.0 * s, 2.0 * s, 18.0 * s, 1.0, 1.0, 1.0, 0.8)
    if @draw_time >= 0.0
      pull = @draw_time > 1.0 ? 1.0 : @draw_time
      @ui.rect(w / 2.0 - 20.0 * s, h / 2.0 + 16.0 * s, 40.0 * s, 4.0 * s, 0.0, 0.0, 0.0, 0.5)
      @ui.rect(w / 2.0 - 20.0 * s, h / 2.0 + 16.0 * s, 40.0 * s * pull, 4.0 * s, 1.0, pull, 0.2, 0.9)
    end
    # hand: the selected block, bobbing when used
    b = current_block
    if b != Block::AIR && @captured
      bob = @swing > 0.0 ? @swing * 120.0 * s : 0.0
      hs = 150.0 * s
      @ui.icon(w - hs - 90.0 * s - bob * 0.5, h - hs + 30.0 * s + bob, hs, Block::SIDE[b], 0.85)
    end
    # hotbar
    size = 44.0 * s
    gap = 4.0 * s
    total = size * 9.0 + gap * 8.0
    x0 = (w - total) / 2.0
    y0 = h - size - 12.0 * s
    @ui.rect(x0 - gap, y0 - gap, total + gap * 2.0, size + gap * 2.0, 0.0, 0.0, 0.0, 0.45)
    i = 0
    while i < 9
      x = x0 + i * (size + gap)
      if i == @slot
        @ui.rect(x - 3.0 * s, y0 - 3.0 * s, size + 6.0 * s, size + 6.0 * s, 1.0, 1.0, 1.0, 0.95)
      end
      @ui.rect(x, y0, size, size, 0.25, 0.25, 0.25, 0.9)
      slot_block = @survival ? @inv_block[i] : @hotbar[i]
      if slot_block != Block::AIR
        @ui.icon(x + 5.0 * s, y0 + 5.0 * s, size - 10.0 * s, Block::SIDE[slot_block], 1.0)
        if @survival
          n = @inv_count[i].to_s
          @ui.text(x + size - @ui.text_width(n, 2.0 * s) - 1.0 * s, y0 + size - 12.0 * s, n, 2.0 * s, 1.0, 1.0, 1.0, 1.0)
        end
      end
      i += 1
    end
    if @survival
      hy = y0 - 26.0 * s
      i = 0
      while i < 10
        hx = x0 + i * 20.0 * s
        @ui.icon(hx, hy, 18.0 * s, Tex::HEART_EMPTY, 1.0)
        hp = @health - i * 2
        if hp >= 2
          @ui.icon(hx, hy, 18.0 * s, Tex::HEART, 1.0)
        elsif hp == 1
          @ui.quad(hx, hy, 9.0 * s, 18.0 * s, Tex::HEART, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0)
        end
        i += 1
      end
      i = 0
      while i < 10
        fx = x0 + total - (i + 1) * 20.0 * s
        full = @hunger - i * 2 >= 1
        @ui.icon(fx, hy, 18.0 * s, Tex::PORKCHOP, full ? 1.0 : 0.22)
        i += 1
      end
      if @air < 10.0
        bubbles = @air.ceil
        i = 0
        while i < bubbles
          bx = x0 + total - (i + 1) * 20.0 * s
          @ui.rect(bx + 3.0 * s, hy - 22.0 * s + 3.0 * s, 13.0 * s, 13.0 * s, 0.6, 0.85, 1.0, 0.9)
          i += 1
        end
      end
    end
    if @survival && !@dead && !@inventory_open && room_for(Block::DIRT) == INV * STACK
      hint = "HOLD LEFT CLICK ON A TREE FOR LOGS, THEN PRESS C TO CRAFT PLANKS"
      @ui.text((w - @ui.text_width(hint, 2.0 * s)) / 2.0, y0 - 92.0 * s, hint, 2.0 * s, 1.0, 1.0, 0.7, 0.9)
    end
    if @message_time > 0.0
      tw = @ui.text_width(@message, 3.0 * s)
      @ui.text((w - tw) / 2.0, y0 - 64.0 * s, @message, 3.0 * s, 1.0, 1.0, 1.0, @message_time > 1.0 ? 1.0 : @message_time)
    end
    if @show_debug
      ts = 2.0 * s
      @ui.text(8.0 * s, 8.0 * s, "FPS #{@fps.round}  CPU #{@cpu_ms.round(2)}MS", ts, 1.0, 1.0, 1.0, 1.0)
      @ui.text(8.0 * s, 22.0 * s, "XYZ #{@player.x.floor} #{@player.y.floor} #{@player.z.floor}  FACES #{@faces_drawn}", ts, 1.0, 1.0, 1.0, 1.0)
      @ui.text(8.0 * s, 36.0 * s, "CHUNKS #{@visible.size / 2}  REMESH #{@mesh_ms.round(2)}MS  MOBS #{@mobs.size}", ts, 1.0, 1.0, 1.0, 1.0)
      clock = ((@time_of_day * 24.0 + 6.0) % 24.0).floor
      mode = @survival ? "SURVIVAL  DAY #{(@alive_time / DAY_SECONDS).floor + 1}" : "CREATIVE"
      @ui.text(8.0 * s, 50.0 * s, "TIME #{clock}:00  #{mode}", ts, 1.0, 1.0, 1.0, 1.0)
    end
    if @dead
      @ui.rect(0.0, 0.0, w, h, 0.5, 0.0, 0.0, 0.5)
      msg = "YOU DIED"
      @ui.text((w - @ui.text_width(msg, 8.0 * s)) / 2.0, h / 2.0 - 60.0 * s, msg, 8.0 * s, 1.0, 1.0, 1.0, 1.0)
      days = (@alive_time / DAY_SECONDS).floor
      lasted = "YOU LASTED #{days} #{days == 1 ? "DAY" : "DAYS"}"
      @ui.text((w - @ui.text_width(lasted, 3.0 * s)) / 2.0, h / 2.0 + 50.0 * s, lasted, 3.0 * s, 1.0, 0.85, 0.6, 1.0)
      sub = "CLICK OR PRESS R TO RESPAWN"
      @ui.text((w - @ui.text_width(sub, 3.0 * s)) / 2.0, h / 2.0 + 10.0 * s, sub, 3.0 * s, 1.0, 1.0, 1.0, 1.0)
    elsif @inventory_open && @survival
      @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.55)
      top = pack_cell(9, w, h, s)
      bottom = pack_cell(8, w, h, s)
      pad = 18.0 * s
      @ui.rect(top[0] - pad, top[1] - pad - 40.0 * s, bottom[0] + bottom[2] - top[0] + pad * 2.0, bottom[1] + bottom[2] - top[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
      @ui.text(top[0], top[1] - 36.0 * s, "INVENTORY", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
      hover = pack_hover(w, h, s)
      i = 0
      while i < INV
        c = pack_cell(i, w, h, s)
        if i == @slot
          @ui.rect(c[0] - 3.0 * s, c[1] - 3.0 * s, c[2] + 6.0 * s, c[2] + 6.0 * s, 1.0, 1.0, 1.0, 0.9)
        end
        shade = i == hover ? 0.55 : 0.32
        @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
        if @inv_count[i] > 0
          @ui.icon(c[0] + 6.0 * s, c[1] + 6.0 * s, c[2] - 12.0 * s, Block::SIDE[@inv_block[i]], 1.0)
          n = @inv_count[i].to_s
          @ui.text(c[0] + c[2] - @ui.text_width(n, 2.0 * s) - 1.0 * s, c[1] + c[2] - 12.0 * s, n, 2.0 * s, 1.0, 1.0, 1.0, 1.0)
        end
        i += 1
      end
      first = recipe_cell(0, w, h, s)
      last_r = recipe_cell(RECIPES.size - 1, w, h, s)
      if @chest_key >= 0
        last_c = chest_cell(CHEST_SLOTS - 1, w, h, s)
        @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, first[2] + pad * 2.0, last_c[1] + last_c[2] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
        @ui.text(first[0], first[1] - 36.0 * s, "CHEST", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
        chover = chest_hover(w, h, s)
        k = 0
        while k < CHEST_SLOTS
          c = chest_cell(k, w, h, s)
          shade = k == chover ? 0.55 : 0.32
          @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
          if @chest_count[k] > 0
            @ui.icon(c[0] + 3.0 * s, c[1] + 3.0 * s, c[2] - 6.0 * s, Block::SIDE[@chest_block[k]], 1.0)
            n = @chest_count[k].to_s
            @ui.text(c[0] + c[2] - @ui.text_width(n, 1.5 * s), c[1] + c[2] - 8.0 * s, n, 1.5 * s, 1.0, 1.0, 1.0, 1.0)
          end
          k += 1
        end
      else
      @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, first[2] + pad * 2.0, last_r[1] + last_r[3] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
      @ui.text(first[0], first[1] - 36.0 * s, "CRAFTING", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
      rhover = recipe_hover(w, h, s)
      k = 0
      while k < RECIPES.size
        r = RECIPES[k]
        c = recipe_cell(k, w, h, s)
        can = count_items(r[0]) >= r[1]
        shade = k == rhover ? 0.5 : 0.28
        @ui.rect(c[0], c[1], c[2], c[3], shade, shade, shade, 1.0)
        @ui.icon(c[0] + 2.0 * s, c[1] + 2.0 * s, 22.0 * s, Block::SIDE[r[2]], can ? 1.0 : 0.35)
        bright = can ? 1.0 : 0.45
        @ui.text(c[0] + 30.0 * s, c[1] + 4.0 * s, "#{r[3]} #{Block::NAMES[r[2]]}", 2.0 * s, bright, bright, bright, 1.0)
        need = "#{r[1]} #{Block::NAMES[r[0]]}"
        @ui.text(c[0] + c[2] - @ui.text_width(need, 1.5 * s) - 4.0 * s, c[1] + 15.0 * s, need, 1.5 * s, bright * 0.95, bright * 0.85, bright * 0.55, 1.0)
        k += 1
      end
      end
      tip = @chest_key >= 0 ? "CLICK TO MOVE STACKS BETWEEN THE CHEST AND YOUR INVENTORY" : "CLICK TO MOVE STACKS  CLICK A RECIPE TO CRAFT IT"
      label = hover >= 0 && @inv_count[hover] > 0 ? Block::NAMES[@inv_block[hover]] : tip
      mid = (top[0] + bottom[0] + bottom[2]) / 2.0
      @ui.text(mid - @ui.text_width(label, 2.0 * s) / 2.0, bottom[1] + bottom[2] + pad + 12.0 * s, label, 2.0 * s, 1.0, 1.0, 0.8, 1.0)
      if @held_count > 0
        mx = Gfx.in_mouse_x
        my = Gfx.in_mouse_y
        @ui.icon(mx - 20.0 * s, my - 20.0 * s, 40.0 * s, Block::SIDE[@held_block], 1.0)
        n = @held_count.to_s
        @ui.text(mx + 20.0 * s - @ui.text_width(n, 2.0 * s), my + 8.0 * s, n, 2.0 * s, 1.0, 1.0, 1.0, 1.0)
      end
    elsif @inventory_open
      @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.55)
      first = inventory_cell(0, w, h, s)
      last = inventory_cell(PLACEABLE.size - 1, w, h, s)
      pad = 18.0 * s
      right = inventory_cell(INV_COLS - 1, w, h, s)
      @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, right[0] + right[2] - first[0] + pad * 2.0, last[1] + last[2] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
      @ui.text(first[0], first[1] - 36.0 * s, "BLOCKS", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
      hover = inventory_hover(w, h, s)
      i = 0
      while i < PLACEABLE.size
        c = inventory_cell(i, w, h, s)
        shade = i == hover ? 0.55 : 0.32
        @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
        @ui.icon(c[0] + 6.0 * s, c[1] + 6.0 * s, c[2] - 12.0 * s, Block::SIDE[PLACEABLE[i]], 1.0)
        i += 1
      end
      label = hover >= 0 ? Block::NAMES[PLACEABLE[hover]] : "CLICK A BLOCK TO PUT IT IN THE SELECTED SLOT"
      @ui.text((w - @ui.text_width(label, 2.0 * s)) / 2.0, last[1] + last[2] + pad + 12.0 * s, label, 2.0 * s, 1.0, 1.0, 0.8, 1.0)
    elsif !@captured
      @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.45)
      msg = "PAUSED - CLICK TO PLAY  N NEW WORLD"
      @ui.text((w - @ui.text_width(msg, 4.0 * s)) / 2.0, h / 2.0 - 60.0 * s, msg, 4.0 * s, 1.0, 1.0, 1.0, 1.0)
      lines = ["WASD MOVE  SPACE JUMP  CTRL SPRINT  SHIFT DOWN",
               "LEFT CLICK BREAK/ATTACK  RIGHT CLICK PLACE  MIDDLE PICK",
               "1-9 SLOT  E INVENTORY  Q NEXT BLOCK  F FLY  G GAME MODE  T TIME  F3 DEBUG  F4 VIEW  F5 SAVE  F11 FULLSCREEN",
               "SURVIVAL: C CRAFTS THE SELECTED STACK  LOG>PLANKS  COAL>TORCHES  SAND>GLASS",
               "3 PLANKS/COBBLE/IRON/DIAMOND > PICKAXE  STONE NEEDS A PICKAXE TO DROP"]
      i = 0
      while i < lines.size
        line = lines[i]
        @ui.text((w - @ui.text_width(line, 2.0 * s)) / 2.0, h / 2.0 + (i * 18.0) * s, line, 2.0 * s, 0.9, 0.9, 0.9, 1.0)
        i += 1
      end
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
    check("walls stop torch light", inside == 14 && outside == 0)
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
    @survival = true
    @inv_block.fill(0)
    @inv_count.fill(0)
    3.times { give(Block::LOG) }
    @slot = 0
    craft
    check("craft log into planks", @inv_block[0] == Block::LOG && @inv_count[0] == 2 && @inv_block[1] == Block::PLANKS && @inv_count[1] == 4)
    70.times { give(Block::DIRT) }
    check("stacks split at 64", @inv_count[2] == 64 && @inv_block[3] == Block::DIRT && @inv_count[3] == 6)
    @health = MAX_HEALTH
    hurt(5)
    check("hurt lowers health", @health == 15 && !@dead)
    hurt(30)
    check("death at zero health", @health == 0 && @dead)
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
    check("stone without a pickaxe drops nothing", @world.get(x, ground + 1, z) == Block::AIR && room_for(Block::COBBLE) == INV * STACK)
    3.times { give(Block::PLANKS) }
    craft
    check("3 planks craft a wooden pickaxe", @inv_block[0] == Block::WOOD_PICK)
    set_block(x, ground + 1, z, Block::STONE)
    mining_frames = 0
    while mining_frames < 200 && @world.get(x, ground + 1, z) == Block::STONE
      @player.raycast(@world)
      mine(0.05)
      mining_frames += 1
    end
    check("a pickaxe mines stone faster and it drops cobblestone", mining_frames < n && @inv_block[1] == Block::COBBLE)
    @inv_block[5] = Block::PORKCHOP
    @inv_count[5] = 2
    @slot = 5
    @hunger = 5
    eat
    check("eating restores hunger", @hunger == 13 && @inv_count[5] == 1)
    # A skeleton on a sky platform at night shoots the player.
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
    frames = 0
    while frames < 300 && @world.get(px + 2, 88, pz) == Block::STONE
      update_mobs(1.0 / 60.0)
      frames += 1
    end
    check("a creeper explodes, breaks blocks and hurts", @world.get(px + 2, 88, pz) == Block::AIR && @health < MAX_HEALTH && frames > 60)
    @mobs.clear
    @time_of_day = 0.3
    @health = MAX_HEALTH
    old = @world.get(x, ground + 1, z)
    kept_block = @inv_block[1]
    kept_count = @inv_count[1]
    save
    @world.set(x, ground + 1, z, Block::GLASS)
    @health = 3
    @inv_count[1] = 0
    ok = load
    apply_loaded if ok
    check("save and load round trip", ok && @world.get(x, ground + 1, z) == old && @health == MAX_HEALTH && @inv_block[1] == kept_block && @inv_count[1] == kept_count && kept_count > 0 && @survival)
    @health = 0
    @dead = true
    save
    ok = load
    apply_loaded if ok
    check("loading a save made while dead respawns", ok && @health == MAX_HEALTH && !@dead)
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
    craft
    check("crafting refuses when the result does not fit", @inv_count[0] == 5 && @inv_count[1] == 62)
    @inv_block.fill(0)
    @inv_count.fill(0)
    @inv_block[3] = Block::PLANKS
    @inv_count[3] = 2
    @inv_block[20] = Block::PLANKS
    @inv_count[20] = 4
    craft_recipe(RECIPES.index { |r| r[2] == Block::BOW })
    check("a recipe takes ingredients from several stacks", count_items(Block::PLANKS) == 1 && count_items(Block::BOW) == 1)
    cx = @spawn_x.floor + 4
    cz = @spawn_z.floor + 4
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
    check("breaking a chest gives its contents back", count_items(Block::DIAMOND) == 7 && @chests.empty?)
    # An open chest destroyed by a blast never duplicates its contents.
    @inv_block.fill(0)
    @inv_count.fill(0)
    set_block(cx, 90, cz, Block::CHEST)
    open_chest(cx, 90, cz)
    @chest_block[0] = Block::DIAMOND
    @chest_count[0] = 7
    set_block(cx, 90, cz, Block::AIR)
    check("a chest destroyed while open does not duplicate items", count_items(Block::DIAMOND) == 7 && !@inventory_open && @chest_count[0] == 7 && @chests.empty?)
    # Mobs that die without the player's help drop nothing.
    @inv_block.fill(0)
    @inv_count.fill(0)
    far = Mob.new(Mob::PIG, @spawn_x + 30.0, 90.0, @spawn_z, 5)
    far.hp = 0
    far.alive = false
    @mobs.clear
    @mobs << far
    update_mobs(1.0 / 60.0)
    check("a pig that dies on its own drops nothing", count_items(Block::PORKCHOP) == 0)
    # Wool is not a light source.
    set_block(cx, 90, cz, Block::WOOL)
    @mesher.build(cx / CHUNK, cz / CHUNK)
    glow = false
    k = 0
    while k < @mesher.opaque.size
      w0 = @mesher.opaque[k]
      w1 = @mesher.opaque[k + 1]
      if (w0 & 511) == cx && ((w0 >> 9) & 255) == 90 && ((w0 >> 17) & 511) == cz
        glow = true if ((w1 >> 19) & 15) == 14
      end
      k += 2
    end
    check("wool does not glow", !glow)
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
    @mobs.clear
    bx = @spawn_x.floor
    bz = @spawn_z.floor
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
    File.delete(SAVE_PATH) if File.exist?(SAVE_PATH)
    puts @failures == 0 ? "ALL PASS" : "#{@failures} FAILED"
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
    while Gfx.in_poll == 0
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
