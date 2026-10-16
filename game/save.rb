# Save and load: the world.sav format.
class Game
  # Field positions in the first line of a save. Field 0 is the format.
  # save writes the fields in this order.
  F_SEED = 1
  F_PLAYER = 2 # x, y, z, yaw, pitch
  F_TIME = 7
  F_DAY = 8
  F_SURVIVAL = 9
  F_HEALTH = 10
  F_ALIVE = 11 # the seconds since the last respawn
  F_SPAWN = 12 # x, z
  F_INV = 14 # INV blocks, then INV counts
  F_HOTBAR = F_INV + INV * 2
  F_HUNGER = F_HOTBAR + HOTBAR # hunger, saturation, exhaustion
  F_WEATHER = F_HUNGER + 3 # raining (1 or 0), seconds to the next change
  # The chest count, then the key and the contents of each chest. Then the
  # item count and ITEM_FIELDS for each item on the ground. Then the count
  # of seen blocks, and their ids. Then the count of furnaces that are not
  # idle, and FURNACE_FIELDS for each. Then the boat count, BOAT_FIELDS for
  # each boat, and the index of the boat that the player rides (or -1).
  F_CHESTS = F_WEATHER + 2
  ITEM_FIELDS = 6 # block, count, x, y, z, age
  FURNACE_FIELDS = 12 # x, y, z, burn, burn total, progress, then the slots (Slots#to_a)
  BOAT_FIELDS = 5 # item, x, y, z, yaw

  def save
    header = [@seed, @player.x, @player.y, @player.z, @player.yaw, @player.pitch,
              @time_of_day, @day, @survival ? 1 : 0, @vitals.health, @alive_time, @spawn_x, @spawn_z].map(&:to_s).join(" ")
    return_held
    close_chest
    land_falling
    chest_fields = [@chests.size]
    @chests.each do |key, chest|
      chest_fields << key
      chest_fields.concat(chest.to_a)
    end
    seen = []
    b = 0
    while b < Block::COUNT
      seen << b if @seen[b] == 1
      b += 1
    end
    furnace_fields = []
    @furnaces.each do |key, f|
      furnace_fields.concat([f.x, f.y, f.z, f.burn, f.burn_total, f.progress] + f.slots.to_a) unless f.idle?
    end
    furnace_fields = [furnace_fields.size / FURNACE_FIELDS] + furnace_fields
    boat_fields = [@boats.size]
    @boats.each { |boat| boat_fields.concat([boat.item, boat.x, boat.y, boat.z, boat.yaw]) }
    boat_fields << @riding
    item_fields = [@items.size]
    @items.each { |item| item_fields.concat([item.block, item.count, item.x, item.y, item.z, item.age]) }
    t0 = Gfx.gfx_ns
    chunks = @world.edited_chunks
    keys = chunks.keys
    chunk_fields = [keys.size] + keys
    inv = (@inv.to_a + @hotbar + [@vitals.hunger, @vitals.saturation, @vitals.exhaustion, @weather.raining? ? 1 : 0, @weather.timer] + chest_fields +
           item_fields + [seen.size] + seen + furnace_fields + boat_fields + chunk_fields).map(&:to_s).join(" ")
    line = "#{SAVE_VERSION} #{header} #{inv}\n"
    File.open(@save_path, "wb") do |f|
      f.write(line)
      keys.each { |k| f.write(chunks[k]) }
    end
    @changed = false
    say("WORLD SAVED")
    puts "saved #{@save_path} in #{((Gfx.gfx_ns - t0) / 1.0e6).round} ms"
    Log.debug(Log::SAVE) do
      "#{line.bytesize + keys.size * CHUNK_BYTES} bytes: #{keys.size} edited chunks, #{@chests.size} chests, #{@items.size} items, " \
        "#{furnace_fields[0]} furnaces, #{@boats.size} boats"
    end
  end

  # Returns true when a saved world was loaded. A save keeps only the chunks
  # that differ from the generator. When a save does not load, @load_error
  # gives the reason.
  def load
    return false unless File.exist?(@save_path)
    data = File.binread(@save_path)
    nl = data.index("\n")
    return load_failed("it has no first line") if nl.nil?
    f = data[0, nl].split(" ")
    return load_failed("its first line has #{f.size} fields, and a save has more than #{F_CHESTS}") if f.size <= F_CHESTS
    return load_failed("its format is #{f[0]}, not #{SAVE_VERSION}") unless f[0] == SAVE_VERSION
    at = F_CHESTS
    at += 1 + f[at].to_i * (1 + CHEST_SLOTS * 2)
    at += 1 + f[at].to_i * ITEM_FIELDS
    at += 1 + f[at].to_i
    at += 1 + f[at].to_i * FURNACE_FIELDS
    at += 1 + f[at].to_i * BOAT_FIELDS + 1
    n = f[at].to_i
    chunk_bytes = data.bytesize - nl - 1
    return load_failed("it has #{chunk_bytes} bytes of chunks, not #{n} * #{CHUNK_BYTES}") if chunk_bytes != n * CHUNK_BYTES
    @seed = f[F_SEED].to_i
    reset_world
    store = @world.store
    k = 0
    while k < n
      store[f[at + 1 + k].to_i] = data.byteslice(nl + 1 + k * CHUNK_BYTES, CHUNK_BYTES)
      k += 1
    end
    @loaded = f
    Log.debug(Log::SAVE) { "loaded #{@save_path}: #{data.bytesize} bytes, seed #{@seed}, #{n} edited chunks" }
    true
  end

  # Keeps the reason that the save did not load, and returns false.
  def load_failed(reason)
    @load_error = reason
    Log.debug(Log::SAVE) { "#{@save_path} did not load: #{reason}" }
    false
  end

  # Moves a save that exists but did not load to @bad_save_path. Otherwise the
  # next save writes the new world over it.
  def keep_bad_save
    return unless File.exist?(@save_path)
    File.rename(@save_path, @bad_save_path)
    puts "#{@save_path} did not load (#{@load_error}), so the game moved it to #{@bad_save_path}"
  end

  # An empty world for @seed; stream_around fills it.
  def reset_world
    Log.debug(Log::WORLD) { "an empty world for seed #{@seed}" }
    @world = World.new(@seed)
    @mesher = Mesher.new(@world)
    @tint = Tint.new(@world)
    @tint.write_uniforms(@uniforms, TINT_UNIFORMS)
    @lods = Array.new(LEVELS) { |l| Lod.new(@world, l) }
    @lod_tx.fill(World::NONE)
    @meshed.fill(0)
    @stream_cx = World::NONE
    @dirty_list.each { |i| @dirty[i] = false }
    @dirty_list.clear
    @later_list.each { |i| @later[i] = false }
    @later_list.clear
    @flow_queue.clear
    @falling.clear
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
    @day = f[F_DAY].to_i
    @survival = f[F_SURVIVAL] == "1"
    @vitals.health = f[F_HEALTH].to_f
    @alive_time = f[F_ALIVE].to_f
    @spawn_x = f[F_SPAWN].to_f
    @spawn_z = f[F_SPAWN + 1].to_f
    @inv.load(f, F_INV)
    i = 0
    while i < HOTBAR
      @hotbar[i] = f[F_HOTBAR + i].to_i
      i += 1
    end
    @vitals.hunger = f[F_HUNGER].to_i
    @vitals.saturation = f[F_HUNGER + 1].to_f
    @vitals.exhaustion = f[F_HUNGER + 2].to_f
    @weather.set_now(f[F_WEATHER] == "1")
    @weather.timer = f[F_WEATHER + 1].to_f
    @chests = {}
    at = F_CHESTS
    chests = f[at].to_i
    at += 1
    c = 0
    while c < chests
      chest = Slots.new(CHEST_SLOTS)
      chest.load(f, at + 1)
      @chests[f[at].to_i] = chest
      at += 1 + CHEST_SLOTS * 2
      c += 1
    end
    @items.clear
    items = f[at].to_i
    at += 1
    c = 0
    while c < items
      @items << Item.new(f[at].to_i, f[at + 1].to_i, f[at + 2].to_f, f[at + 3].to_f, f[at + 4].to_f, 0.0, 0.0, 0.0, PICKUP_WAIT, f[at + 5].to_f)
      at += ITEM_FIELDS
      c += 1
    end
    @seen.fill(0)
    seen = f[at].to_i
    c = 0
    while c < seen
      @seen[f[at + 1 + c].to_i] = 1
      c += 1
    end
    at += 1 + seen
    @furnaces = {}
    furnaces = f[at].to_i
    at += 1
    c = 0
    while c < furnaces
      x = f[at].to_i
      y = f[at + 1].to_i
      z = f[at + 2].to_i
      furnace = Furnace.new(x, y, z)
      furnace.burn = f[at + 3].to_i
      furnace.burn_total = f[at + 4].to_i
      furnace.progress = f[at + 5].to_i
      furnace.slots.load(f, at + 6)
      @furnaces[World.key(x, y, z)] = furnace
      at += FURNACE_FIELDS
      c += 1
    end
    @boats.clear
    boats = f[at].to_i
    at += 1
    c = 0
    while c < boats
      @boats << Boat.new(f[at].to_i, f[at + 1].to_f, f[at + 2].to_f, f[at + 3].to_f, f[at + 4].to_f)
      at += BOAT_FIELDS
      c += 1
    end
    @riding = f[at].to_i
    stream_around(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    respawn if @vitals.dead?
  end
end
