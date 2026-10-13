# Save and load: the world.sav format and the importer for format 3 saves.
class Game
  # Layout of a format 3 save: 384 columns and one padding column on each side.
  OLD_P = 386
  OLD_PY = 98

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
end
