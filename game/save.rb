# Save and load: the world.sav format. SaveFile has the form of the file. The
# sections are the ones that save adds.
class Game
  ITEM_FIELDS = 6 # block, count, x, y, z, age
  BOAT_FIELDS = 5 # item, x, y, z, yaw

  def save
    return_held
    @chests.close
    land_falling
    file = Log.measure(Log::SAVE, "sections") { save_sections }
    chunks = @world.edited_chunks
    keys = chunks.keys
    head = file.head(SAVE_VERSION, keys)
    Log.measure(Log::SAVE, "write #{@save_path}") do
      File.open(@save_path, "wb") do |out|
        out.write(head)
        keys.each { |key| out.write(chunks[key]) }
      end
    end
    @changed = false
    say("WORLD SAVED")
    Log.debug(Log::SAVE) do
      "#{head.bytesize + keys.size * CHUNK_BYTES} bytes: #{keys.size} edited chunks, #{@chests.size} chests, #{@items.size} items, " \
        "#{@furnaces.size} furnaces, #{@boats.size} boats"
    end
  end

  # Returns true when a saved world was loaded. A save keeps only the chunks
  # that differ from the generator. When a save does not load, @load_error
  # gives the reason.
  def load
    return false unless File.exist?(@save_path)

    file = SaveFile.new
    read = Log.measure(Log::SAVE, "read #{@save_path}") { file.read(File.binread(@save_path), SAVE_VERSION) }
    return load_failed(file.error) unless read

    seed = file.section("seed")
    @seed = seed[0].to_i unless seed.empty?
    reset_world
    store = @world.store
    Log.measure(Log::SAVE, "store #{file.chunks.size} chunks") do
      file.chunks.each { |key, bytes| store[key] = bytes }
    end
    @loaded = file
    Log.debug(Log::SAVE) { "loaded #{@save_path}: seed #{@seed}, #{file.chunks.size} edited chunks" }
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

  # An empty world for @seed; ChunkMeshes#stream fills it.
  def reset_world
    Log.debug(Log::WORLD) { "an empty world for seed #{@seed}" }
    @world = World.new(@seed)
    @tint = Tint.new(@world.terrain)
    @tint.write_uniforms(@uniforms, TINT_UNIFORMS)
    @far = FarTerrain.new(@world.terrain, LOD_SLOT0)
    @chunk_meshes = ChunkMeshes.new(@world, @tint)
    @light = Light.new(@world)
    @storm = Storm.new(@seed * 5 + 3, @world, @weather, @mobs)
    @spawner = NaturalSpawner.new(@world, @seed * 11 + 5, @halloween)
    @plants = Plants.new(@world, @seed * 13 + 3)
    @breeding = Breeding.new(@seed * 17 + 9)
    @fluids = Fluids.new(@world)
    @treasure = Treasure.new(@world.treasure_map, @seed)
    @falling.clear
  end


  # The SaveFile with a section for each part of the game that the save keeps.
  def save_sections
    file = SaveFile.new
    vitals = @player.vitals
    file.add("seed", [@seed])
    file.add("player", [@player.x, @player.y, @player.z, @player.yaw, @player.pitch])
    file.add("clock", [@clock.time_of_day, @clock.day])
    file.add("mode", [game_mode.name])
    file.add("vitals", [vitals.health, vitals.hunger, vitals.saturation, vitals.exhaustion])
    file.add("life", [@alive_time, @spawn_x, @spawn_z]) # the seconds since the last respawn, and the spawn x and z
    file.add("inventory", @inv.to_a)
    file.add("hotbar", @hotbar)
    file.add("armor", @armor.slots.to_a)
    file.add("weather", @weather.to_a)
    file.add("chests", @chests.to_a)
    file.add("items", item_fields)
    file.add("recipes", seen_fields)
    file.add("furnaces", @furnaces.to_a)
    file.add("boats", boat_fields)
    file.add("riding", [@riding])
    file.add("treasure", @treasure.to_a)
    file
  end

  # The item count, then ITEM_FIELDS for each item on the ground.
  def item_fields
    fields = [@items.size]
    @items.each { |item| fields.concat([item.block, item.count, item.x, item.y, item.z, item.age]) }
    fields
  end

  # The count of seen blocks, then their ids.
  def seen_fields
    seen = (0...Block::COUNT).select { |block| @recipe_book.seen?(block) }
    [seen.size] + seen
  end

  # The boat count, then BOAT_FIELDS for each boat.
  def boat_fields
    fields = [@boats.size]
    @boats.each { |boat| fields.concat([boat.item, boat.x, boat.y, boat.z, boat.yaw]) }
    fields
  end

  def apply_loaded
    # A part that the save lacks keeps its value for a new world: the spawn
    # point, and the player there.
    spawn
    with_section("player") { |fields| apply_player(fields) }
    with_section("clock") { |fields| apply_clock(fields) }
    with_section("mode") { |fields| @game_mode = GameMode.parse(fields[0]) }
    with_section("vitals") { |fields| apply_vitals(fields) }
    with_section("life") { |fields| apply_life(fields) }
    with_section("inventory") { |fields| @inv.load(fields, 0) }
    with_section("armor") { |fields| @armor.slots.load(fields, 0) }
    with_section("hotbar") { |fields| HOTBAR.times { |slot| @hotbar[slot] = fields[slot].to_i } }
    with_section("weather") { |fields| @weather.load(fields, 0) }
    with_section("chests") { |fields| @chests.load(fields, 0) }
    with_section("items") { |fields| apply_items(fields) }
    with_section("recipes") { |fields| apply_recipes(fields) }
    with_section("furnaces") { |fields| @furnaces.load(fields, 0) }
    with_section("boats") { |fields| apply_boats(fields) }
    with_section("riding") { |fields| apply_riding(fields) }
    with_section("treasure") { |fields| @treasure.load(fields, 0) }
    @chunk_meshes.stream(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    respawn if @player.vitals.dead?
  end

  # Calls the block with the fields of the section name, when the loaded save
  # has that section. Otherwise the part keeps its value for a new world.
  def with_section(name)
    fields = @loaded.section(name)
    yield fields unless fields.empty?
  end

  def apply_player(fields)
    @player.x = fields[0].to_f
    @player.y = fields[1].to_f
    @player.z = fields[2].to_f
    @player.yaw = fields[3].to_f
    @player.pitch = fields[4].to_f
    @player.fall_start = @player.y
  end

  def apply_clock(fields)
    @clock.time_of_day = fields[0].to_f
    @clock.day = fields[1].to_i
  end

  def apply_vitals(fields)
    @player.vitals.health = fields[0].to_f
    @player.vitals.hunger = fields[1].to_i
    @player.vitals.saturation = fields[2].to_f
    @player.vitals.exhaustion = fields[3].to_f
  end

  def apply_life(fields)
    @alive_time = fields[0].to_f
    @spawn_x = fields[1].to_f
    @spawn_z = fields[2].to_f
  end

  # The boat that the player rides must exist.
  def apply_riding(fields)
    @riding = -1
    index = fields[0].to_i
    @riding = index if index >= 0 && index < @boats.size
  end

  def apply_items(fields)
    @items.clear
    fields[0].to_i.times do |index|
      at = 1 + index * ITEM_FIELDS
      @items << Item.new(fields[at].to_i, fields[at + 1].to_i, fields[at + 2].to_f, fields[at + 3].to_f, fields[at + 4].to_f, 0.0, 0.0, 0.0, PICKUP_WAIT, fields[at + 5].to_f)
    end
  end

  def apply_recipes(fields)
    @recipe_book = RecipeBook.new
    fields[0].to_i.times { |index| @recipe_book.learn(fields[1 + index].to_i) }
  end

  def apply_boats(fields)
    @boats.clear
    fields[0].to_i.times do |index|
      at = 1 + index * BOAT_FIELDS
      @boats << Boat.new(fields[at].to_i, fields[at + 1].to_f, fields[at + 2].to_f, fields[at + 3].to_f, fields[at + 4].to_f)
    end
  end
end
