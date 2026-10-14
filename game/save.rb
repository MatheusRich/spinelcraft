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
  F_HUNGER = F_HOTBAR + HOTBAR # hunger, saturation, exhaustion
  F_WEATHER = F_HUNGER + 3 # raining (1 or 0), seconds to the next change
  # The chest count, then the key and the contents of each chest. Then the
  # item count and ITEM_FIELDS for each item on the ground. Then the count
  # of seen blocks, and their ids. Then the count of furnaces that are not
  # idle, and FURNACE_FIELDS for each.
  F_CHESTS = F_WEATHER + 2
  ITEM_FIELDS = 6 # block, count, x, y, z, age
  FURNACE_FIELDS = 12 # x, y, z, burn, burn total, progress, then the slots (Slots#to_a)

  def save
    header = [WX, WY, WZ, @seed, @player.x, @player.y, @player.z, @player.yaw, @player.pitch,
              @time_of_day, @survival ? 1 : 0, @vitals.health, @spawn_x, @spawn_z].map(&:to_s).join(" ")
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
    item_fields = [@items.size]
    @items.each { |item| item_fields.concat([item.block, item.count, item.x, item.y, item.z, item.age]) }
    t0 = Gfx.gfx_ns
    chunks = @world.edited_chunks
    keys = chunks.keys
    chunk_fields = [keys.size] + keys
    inv = (@inv.to_a + @hotbar + [@vitals.hunger, @vitals.saturation, @vitals.exhaustion, @weather.raining? ? 1 : 0, @weather.timer] + chest_fields +
           item_fields + [seen.size] + seen + furnace_fields + chunk_fields).map(&:to_s).join(" ")
    File.open(SAVE_PATH, "wb") do |f|
      f.write("#{SAVE_VERSION} #{header} #{inv}\n")
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
    return false unless f[0] == SAVE_VERSION
    at = F_CHESTS
    at += 1 + f[at].to_i * (1 + CHEST_SLOTS * 2)
    at += 1 + f[at].to_i * ITEM_FIELDS
    at += 1 + f[at].to_i
    at += 1 + f[at].to_i * FURNACE_FIELDS
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
    @survival = f[F_SURVIVAL] == "1"
    @vitals.health = f[F_HEALTH].to_i
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
    stream_around(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    respawn if @vitals.dead?
  end
end
