# Save and load: the world.sav format.
class Game
  # Field positions in the first line of a save. Field 0 is the format and
  # fields 1-3 are the world size. save writes the fields in this order.
  F_SEED = 4
  F_PLAYER = 5 # x, y, z, yaw, pitch
  F_TIME = 10
  F_SURVIVAL = 11
  F_HEALTH = 12
  F_SPAWN = 13 # x, z
  F_INV = 15 # INV blocks, then INV counts
  F_HOTBAR = F_INV + INV * 2
  F_HUNGER = F_HOTBAR + HOTBAR
  # The chest count, then the key and the contents of each chest.
  F_CHESTS = F_HUNGER + 1

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
  # that differ from the generator.
  def load
    return false unless File.exist?(SAVE_PATH)
    data = File.binread(SAVE_PATH)
    nl = data.index("\n")
    return false if nl.nil?
    f = data[0, nl].split(" ")
    return false if f.size <= F_CHESTS
    return false unless f[0] == "SPINELCRAFT4"
    at = F_CHESTS
    at += 1 + f[at].to_i * (1 + CHEST_SLOTS * 2)
    n = f[at].to_i
    return false if data.bytesize - nl - 1 != n * CHUNK_BYTES
    @seed = f[F_SEED].to_i
    reset_world
    store = @world.store
    k = 0
    while k < n
      store[f[at + 1 + k].to_i] = data.byteslice(nl + 1 + k * CHUNK_BYTES, CHUNK_BYTES)
      k += 1
    end
    @loaded = f
    true
  end

  # Moves a save that exists but did not load to BAD_SAVE_PATH. Otherwise the
  # next save writes the new world over it.
  def keep_bad_save
    return unless File.exist?(SAVE_PATH)
    File.rename(SAVE_PATH, BAD_SAVE_PATH)
    puts "#{SAVE_PATH} did not load, so the game moved it to #{BAD_SAVE_PATH}"
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

  def apply_loaded
    f = @loaded
    @player.x = f[F_PLAYER].to_f
    @player.y = f[F_PLAYER + 1].to_f
    @player.z = f[F_PLAYER + 2].to_f
    @player.yaw = f[F_PLAYER + 3].to_f
    @player.pitch = f[F_PLAYER + 4].to_f
    @player.fall_start = @player.y
    @time_of_day = f[F_TIME].to_f
    @survival = f[F_SURVIVAL] == "1"
    @health = f[F_HEALTH].to_i
    @spawn_x = f[F_SPAWN].to_f
    @spawn_z = f[F_SPAWN + 1].to_f
    i = 0
    while i < INV
      @inv_block[i] = f[F_INV + i].to_i
      @inv_count[i] = f[F_INV + INV + i].to_i
      i += 1
    end
    i = 0
    while i < HOTBAR
      @hotbar[i] = f[F_HOTBAR + i].to_i
      i += 1
    end
    @hunger = f[F_HUNGER].to_i
    @chests = {}
    at = F_CHESTS
    chests = f[at].to_i
    at += 1
    c = 0
    while c < chests
      key = f[at].to_i
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
end
