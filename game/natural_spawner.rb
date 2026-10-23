# Natural spawning as in Minecraft: monsters in the dark and animals on
# grass, near the player. Breeding, a thrown egg and /summon make mobs in
# other ways. minecraft.wiki/w/Mob_spawning
class NaturalSpawner
  # A monster spawns only in block light 0 and when the light is at most a
  # random number from 0 to this. minecraft.wiki/w/Mob_spawning
  SPAWN_LIGHT = 7
  # The cap for the 17 x 17 chunks around the player. The game always loads
  # all of them, so the cap does not get smaller as in Minecraft.
  # Minecraft's cap is 70, but its world is 384 blocks tall. This world is
  # 96 blocks tall, so it has less cave room. With a cap of 70, 33 to 44
  # monsters came to the surface at night, with 35, 14 to 20, and with 25,
  # about 10 to 14. This is not a Minecraft value.
  MONSTER_CAP = 25
  # Chunks on each side of the player's chunk where monsters spawn.
  SPAWN_CHUNKS = 8
  # Pack centers each second: one for each of the 17 x 17 chunks each tick.
  PACK_CENTERS = 289 * 20
  # Packs for each center, and monsters for each center at most.
  PACKS = 3
  PACK_SIZE = 4
  # Monsters spawn at least SPAWN_NEAR blocks from the player, and no
  # farther than where they despawn (Monster::DESPAWN_FAR).
  SPAWN_NEAR = 24.0
  # The monster kinds and their spawn weights. minecraft.wiki/w/Plains
  MONSTER_KINDS = [Mob::ZOMBIE, Mob::SKELETON, Mob::CREEPER]
  MONSTER_WEIGHTS = [95.0, 100.0, 100.0]

  # The animals that spawn on grass, and the weight of each, as in the
  # plains biome. minecraft.wiki/w/Plains
  ANIMAL_KINDS = [Mob::PIG, Mob::SHEEP, Mob::COW, Mob::CHICKEN]
  ANIMAL_WEIGHTS = [10.0, 12.0, 8.0, 10.0]
  # The animals that spawn around the player in a new world. Each
  # REFILL_TIME seconds, one more animal spawns while fewer than half of
  # them are left. These are not Minecraft values.
  ANIMALS = 24
  REFILL_TIME = 2.0

  # The guards of a treasure chest: a pack of GUARDS monsters in the
  # cells up to GUARD_RANGE blocks from the chest on x and z and 1 block
  # on y, as a monster spawner spawns 4 mobs in the 9 x 3 x 9 blocks
  # around it (minecraft.wiki/w/Monster_Spawner). A spawner makes 4 tries
  # each time. The pack tries up to GUARD_TRIES cells, so that it nearly
  # always has all its monsters; this is not a Minecraft value.
  GUARDS = 4
  GUARD_RANGE = 4
  GUARD_TRIES = 40

  # On Halloween, a zombie or a skeleton wears a carved pumpkin 22.5% of
  # the time and a jack o'lantern 2.5% of the time. minecraft.wiki/w/Halloween
  HALLOWEEN_CARVED = 0.225
  HALLOWEEN_JACK = 0.025

  def initialize(world, seed, halloween)
    @world = world
    @light = Light.new(world)
    @rng = Rng.new(seed)
    @halloween = halloween
    # Seconds to the next refill_animals.
    @refill = 0.0
    nil
  end

  # The pack centers of dt seconds around player, until the monsters in
  # mobs reach the cap. sky is the sky light under the open sky now.
  def spawn_monsters(mobs, player, sky, dt)
    monsters = 0
    mobs.size.times { |i| monsters += 1 unless mobs[i].passive? }
    centers = (dt * PACK_CENTERS + @rng.rand01).to_i
    while centers > 0 && monsters < MONSTER_CAP
      monsters += spawn_packs(mobs, player, sky, MONSTER_CAP - monsters)
      centers -= 1
    end
    nil
  end

  # Picks a pack center in a random cell of a random chunk near the player,
  # at a random height up to the cell above the top of its column. Most
  # centers are in the ground, so most monsters spawn in caves. Then PACKS
  # packs walk from the center with steps of up to 5 on x and z, and each
  # step can spawn a monster of the pack's kind. Returns how many spawned,
  # room at most.
  def spawn_packs(mobs, player, sky, room)
    span = SPAWN_CHUNKS * 2 + 1
    x0 = ((player.x.floor >> 4) - SPAWN_CHUNKS + (@rng.rand01 * span).to_i) * 16 + (@rng.rand01 * 16.0).to_i
    z0 = ((player.z.floor >> 4) - SPAWN_CHUNKS + (@rng.rand01 * span).to_i) * 16 + (@rng.rand01 * 16.0).to_i
    return 0 unless @world.loaded?(x0, z0)

    y = (@rng.rand01 * (@world.height_at(x0, z0) + 1)).to_i
    return 0 if Block::OPAQUE[@world.get(x0, y, z0)] == 1

    room = PACK_SIZE if room > PACK_SIZE
    spawned = 0
    pack = 0
    while pack < PACKS
      kind = pick_kind(MONSTER_KINDS, MONSTER_WEIGHTS)
      x = x0
      z = z0
      PACK_SIZE.times do
        x += (@rng.rand01 * 6.0).to_i - (@rng.rand01 * 6.0).to_i
        z += (@rng.rand01 * 6.0).to_i - (@rng.rand01 * 6.0).to_i
        if monster_fits?(player, x, y, z, sky)
          add_monster(mobs, kind, x, y, z)
          spawned += 1
          return spawned if spawned >= room
        end
      end
      pack += 1
    end
    spawned
  end

  # True when a monster can spawn in the cell x, y, z: a dark cell with
  # room for it (room?), between SPAWN_NEAR and Monster::DESPAWN_FAR
  # blocks from player.
  def monster_fits?(player, x, y, z, sky)
    return false unless room?(x, y, z)

    dx = x + 0.5 - player.x
    dy = y - player.y
    dz = z + 0.5 - player.z
    distance2 = dx * dx + dy * dy + dz * dz
    return false if distance2 < SPAWN_NEAR * SPAWN_NEAR || distance2 > Monster::DESPAWN_FAR * Monster::DESPAWN_FAR

    dark?(x, y, z, sky)
  end

  # True when the cell x, y, z is loaded and has room for the body of a
  # monster: a solid floor that is not leaves, and two cells of air.
  def room?(x, y, z)
    return false if y < 1 || !@world.loaded?(x, z)

    ground = @world.get(x, y - 1, z)
    Block.solid?(ground) && !Block.leaves?(ground) && @world.get(x, y, z) == Block::AIR && @world.get(x, y + 1, z) == Block::AIR
  end

  # The guards of the treasure chest at x, y, z: a pack of GUARDS monsters
  # of random kinds, by MONSTER_WEIGHTS, in the cells around the chest
  # that have room for them. Light does not stop them. Returns how many
  # spawned.
  def spawn_guards(mobs, x, y, z)
    spawned = 0
    tries = 0
    while spawned < GUARDS && tries < GUARD_TRIES
      tries += 1
      cell_x = x + @rng.between(-GUARD_RANGE, GUARD_RANGE)
      cell_y = y + @rng.between(-1, 1)
      cell_z = z + @rng.between(-GUARD_RANGE, GUARD_RANGE)
      if room?(cell_x, cell_y, cell_z)
        add_monster(mobs, pick_kind(MONSTER_KINDS, MONSTER_WEIGHTS), cell_x, cell_y, cell_z).guard = true
        spawned += 1
      end
    end
    spawned
  end

  # Adds a new monster of kind at the cell x, y, z to mobs, and gives it.
  def add_monster(mobs, kind, x, y, z)
    monster = Monster.new(kind, x + 0.5, y + 0.01, z + 0.5, (@rng.rand01 * 100000.0).to_i)
    monster.head = halloween_head(kind)
    mobs << monster
    Log.debug(Log::MOBS) { "#{Mob::NAMES[kind]} spawns at #{x} #{y} #{z}, #{mobs.size} mobs" }
    monster
  end

  # True when a monster can spawn in the cell x, y, z by its light, sky
  # being the sky light under the open sky now. No torch or lava may light
  # the cell, and its light must be at most a random number from 0 to
  # SPAWN_LIGHT.
  def dark?(x, y, z, sky)
    # The random number comes first. A cell under the open sky that is
    # sky - most steps away or farther cannot make the light more than most,
    # so the search stops before those steps.
    most = (@rng.rand01 * (SPAWN_LIGHT + 1)).to_i
    light = @light.level(x, y, z, sky, @light.lamp_near?(x, y, z), sky - most)
    light >= 0 && light <= most
  end

  # What a new monster of kind wears on its head, or 0 for nothing.
  def halloween_head(kind)
    return 0 unless @halloween && (kind == Mob::ZOMBIE || kind == Mob::SKELETON)

    roll = @rng.rand01
    return Block::JACK_O_LANTERN if roll < HALLOWEEN_JACK
    return Block::CARVED_PUMPKIN if roll < HALLOWEEN_JACK + HALLOWEEN_CARVED

    0
  end

  # ANIMALS animals around player in a new world.
  def spawn_animals(mobs, player)
    ANIMALS.times { spawn_animal(mobs, player, 10.0, 120.0) }
    nil
  end

  # One more animal each REFILL_TIME seconds while mobs has fewer than half
  # of ANIMALS animals.
  def refill_animals(mobs, player, dt)
    @refill -= dt
    return nil if @refill > 0.0

    @refill = REFILL_TIME
    animals = 0
    mobs.size.times { |i| animals += 1 if mobs[i].passive? }
    spawn_animal(mobs, player, 40.0, 90.0) if animals < ANIMALS / 2
    nil
  end

  # Puts an animal on grass at a random distance from player in [near,
  # far). After 20 tries with no room on grass, no animal spawns.
  def spawn_animal(mobs, player, near, far)
    kind = pick_kind(ANIMAL_KINDS, ANIMAL_WEIGHTS)
    tries = 0
    while tries < 20
      tries += 1
      angle = @rng.rand01 * 6.283
      distance = near + @rng.rand01 * (far - near)
      x = (player.x + Math.cos(angle) * distance).floor
      z = (player.z + Math.sin(angle) * distance).floor
      next unless @world.loaded?(x, z)

      h = @world.height_at(x, z)
      ground = @world.get(x, h - 1, z)
      next unless ground == Block::GRASS || ground == Block::SNOW_GRASS
      next if @world.get(x, h, z) != Block::AIR || @world.get(x, h + 1, z) != Block::AIR

      mobs << Animal.new(kind, x + 0.5, h + 0.01, z + 0.5, (@rng.rand01 * 100000.0).to_i)
      Log.debug(Log::MOBS) { "#{Mob::NAMES[kind]} spawns at #{x} #{h} #{z}, #{mobs.size} mobs" }
      return nil
    end
    nil
  end

  # A kind from kinds, picked at random by weights.
  def pick_kind(kinds, weights)
    roll = @rng.rand01 * weights.sum
    i = 0
    while i < kinds.size - 1
      roll -= weights[i]
      return kinds[i] if roll < 0.0

      i += 1
    end
    kinds[i]
  end
end
