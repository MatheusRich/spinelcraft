# Sound effects: OGG files in assets/sounds, from VoxeLibre (see
# assets/sounds/CREDITS.md). An Sfx is the listener: it gives the volume
# and the pan of a sound from where the player hears it, and it queues
# the sounds of a frame. Game sends the queue to Gfx (Game#send_sounds).
class Sfx
  BREAK = 0
  PLACE = 1
  PLACE_HARD = 2
  HURT = 3
  STEP_GRASS = 4
  STEP_DIRT = 5
  STEP_HARD = 6
  STEP_WOOD = 7
  DIG_STONE = 8
  DIG_WOOD = 9
  DIG_SOFT = 10
  TOOL_BREAK = 11
  OINK = 12
  GROAN = 13
  RATTLE = 14
  CREEPER_HURT = 15
  SHOOT = 16
  HIT = 17
  SPLASH = 18
  FIZZ = 19
  EXPLODE = 20
  RAIN = 21
  POP = 22
  PIG_DEATH = 23
  BAA = 24
  ZOMBIE_HURT = 25
  ZOMBIE_DEATH = 26
  SKELETON_HURT = 27
  SKELETON_DEATH = 28
  CREEPER_DEATH = 29
  EAT = 30
  FALL = 31
  DOOR_OPEN = 32
  DOOR_CLOSE = 33
  CHEST_OPEN = 34
  CHEST_CLOSE = 35
  WATER_TAKE = 36
  WATER_POUR = 37
  LAVA_POUR = 38
  BREAK_GLASS = 39
  STEP_GLASS = 40
  DIG_LEAVES = 41
  DIG_GRAVEL = 42
  BREAK_GRAVEL = 43
  STEP_GRAVEL = 44
  STEP_SAND = 45
  STEP_WATER = 46
  # The cave sounds are CAVE to CAVE + CAVES - 1.
  CAVE = 47
  CAVES = 4
  FUSE = 51
  CLOTH = 52
  SNOW = 53
  LAVA = 54
  FLOWING = 55
  CRACKLE = 56
  CLICK = 57
  MOO = 58
  COW_HURT = 59
  MILK = 60
  DRINK = 61
  CLUCK = 62
  CHICKEN_HURT = 63
  LAY_EGG = 64
  CHICK = 65
  # The thunder sounds are THUNDER to THUNDER + THUNDERS - 1.
  THUNDER = 66
  THUNDERS = 3
  ARMOR_IRON = 69
  ARMOR_DIAMOND = 70
  IGNITE = 71
  # A sound from a point fades to silence at RANGE blocks, and an
  # explosion at EXPLOSION_RANGE. The wiki gives 64 blocks for TNT. It does
  # not say if a creeper explosion carries as far. minecraft.wiki/w/Sound
  RANGE = 16.0
  # The slot of each loop (Gfx.au_loop): the rain and the fire.
  RAIN_LOOP = 0
  FIRE_LOOP = 1
  EXPLOSION_RANGE = 64.0
  # Thunder carries over the 17 x 17 chunks where lightning strikes. Minecraft
  # plays thunder at full volume in the whole dimension, so this range is not
  # a Minecraft value.
  THUNDER_RANGE = 192.0
  # The file of each sound and its gain in dB. The gain sets the RMS of the
  # loudest 0.1 seconds of each sound to -20 dBFS (-12 dBFS for the
  # explosion and the thunder), so that all sounds are equally loud.
  # Sfx.define_sound fills them, one call for each id, in the order of the ids.
  FILES = []
  GAINS = []

  def self.define_sound(id, file, gain)
    abort "Sfx.define_sound: id #{id} comes out of order" if id != FILES.size
    FILES << file
    GAINS << gain
    nil
  end

  define_sound BREAK, "default_dug_node.1", -4.1
  define_sound PLACE, "default_place_node.1", 3.7
  define_sound PLACE_HARD, "default_place_node_hard.1", 0.0
  define_sound HURT, "player_damage", 0.5
  define_sound STEP_GRASS, "default_grass_footstep.1", 2.4
  define_sound STEP_DIRT, "default_dirt_footstep.1", 9.2
  define_sound STEP_HARD, "default_hard_footstep.1", 3.3
  define_sound STEP_WOOD, "default_wood_footstep.1", 2.6
  define_sound DIG_STONE, "default_dig_cracky.1", 3.1
  define_sound DIG_WOOD, "default_dig_choppy.1", -1.2
  define_sound DIG_SOFT, "default_dig_crumbly", -2.0
  define_sound TOOL_BREAK, "default_tool_breaks", -4.4
  define_sound OINK, "mobs_pig", -2.8
  define_sound GROAN, "mobs_mc_zombie_growl", -9.0
  define_sound RATTLE, "mobs_mc_skeleton_random.1", 19.8
  define_sound CREEPER_HURT, "mobs_mc_creeper_hurt", 1.1
  define_sound SHOOT, "mcl_bows_bow_shoot", 7.4
  define_sound HIT, "mcl_bows_hit_other", 2.5
  define_sound SPLASH, "watersplash", -6.1
  define_sound FIZZ, "fire_extinguish_flame.1", -9.5
  define_sound EXPLODE, "tnt_explode", -4.3
  define_sound RAIN, "weather_rain", 21.2
  define_sound POP, "item_drop_pickup", -11.5
  define_sound PIG_DEATH, "mobs_pig_angry", -10.0
  define_sound BAA, "mobs_sheep", -2.4
  define_sound ZOMBIE_HURT, "mobs_mc_zombie_hurt", -5.7
  define_sound ZOMBIE_DEATH, "mobs_mc_zombie_death", -9.8
  define_sound SKELETON_HURT, "mobs_mc_skeleton_hurt", 1.2
  define_sound SKELETON_DEATH, "mobs_mc_skeleton_death", -1.6
  define_sound CREEPER_DEATH, "mobs_mc_creeper_death", -5.3
  define_sound EAT, "mcl_hunger_bite.1", -11.6
  define_sound FALL, "player_falling_damage", -9.5
  define_sound DOOR_OPEN, "doors_door_open", -10.0
  define_sound DOOR_CLOSE, "doors_door_close", -15.4
  define_sound CHEST_OPEN, "default_chest_open", 1.0
  define_sound CHEST_CLOSE, "default_chest_close", -6.0
  define_sound WATER_TAKE, "mcl_sounds_dug_water", -5.4
  define_sound WATER_POUR, "mcl_sounds_place_node_water", -2.0
  define_sound LAVA_POUR, "default_place_node_lava", -8.0
  define_sound BREAK_GLASS, "default_break_glass.1", -6.1
  define_sound STEP_GLASS, "default_glass_footstep", -1.5
  define_sound DIG_LEAVES, "default_dig_snappy", 1.8
  define_sound DIG_GRAVEL, "default_gravel_dig.1", -0.6
  define_sound BREAK_GRAVEL, "default_gravel_dug.1", 6.8
  define_sound STEP_GRAVEL, "default_gravel_footstep.1", 2.7
  define_sound STEP_SAND, "default_sand_footstep.1", -6.0
  define_sound STEP_WATER, "default_water_footstep.1", -1.3
  define_sound CAVE, "cave1", -9.5
  define_sound CAVE + 1, "cave2", -10.4
  define_sound CAVE + 2, "cave4", -9.6
  define_sound CAVE + 3, "cave5", -15.5
  define_sound FUSE, "tnt_ignite", 6.8
  define_sound CLOTH, "mcl_sounds_cloth.1", -8.5
  define_sound SNOW, "pedology_snow_soft_footstep.1", 10.6
  define_sound LAVA, "env_sounds_lava.1", -6.0
  define_sound FLOWING, "env_sounds_water.1", 3.3
  define_sound CRACKLE, "fire_fire.1", -9.7
  define_sound CLICK, "mesecons_button_push", 2.7
  define_sound MOO, "mobs_mc_cow", -11.4
  define_sound COW_HURT, "mobs_mc_cow_hurt", -8.4
  define_sound MILK, "mobs_mc_cow_milk", -1.9
  define_sound DRINK, "mcl_potions_drinking", -0.6
  define_sound CLUCK, "mobs_mc_chicken_buck.1", 9.6
  define_sound CHICKEN_HURT, "mobs_mc_chicken_hurt", -2.7
  define_sound LAY_EGG, "mobs_mc_chicken_lay_egg", -5.4
  define_sound CHICK, "mobs_mc_chicken_child", -2.7
  define_sound THUNDER, "lightning_thunder.1", -5.6
  define_sound THUNDER + 1, "lightning_thunder.2", -2.7
  define_sound THUNDER + 2, "lightning_thunder.3", -0.5
  define_sound ARMOR_IRON, "mcl_armor_equip_iron", -1.1
  define_sound ARMOR_DIAMOND, "mcl_armor_equip_diamond", -2.4
  define_sound IGNITE, "fire_flint_and_steel", -2.2

  # The distance in blocks at which each sound from a point fades to
  # silence, in the order of the ids above.
  RANGES = Array.new(FILES.size, RANGE)
  RANGES[EXPLODE] = EXPLOSION_RANGE
  THUNDERS.times { |index| RANGES[THUNDER + index] = THUNDER_RANGE }

  # The queue: the id, the volume and the pan of each sound to play.
  attr_reader :ids, :volumes, :pans

  # Loads each sound file. Returns how many loaded.
  def self.load_files
    loaded = 0
    FILES.each_with_index do |name, id|
      loaded += 1 if Gfx.au_load_ogg(id, "assets/sounds/#{name}.ogg", GAINS[id]) == 0
    end
    loaded
  end

  def self.init
    return false unless Gfx.au_init

    load_files
    true
  end

  def initialize
    @x = 0.0
    @y = 0.0
    @z = 0.0
    @yaw = 0.0
    @ids = Array.new(0, 0)
    @volumes = Array.new(0, 0.0)
    @pans = Array.new(0, 0.0)
  end

  # Queues sound id at volume, with no place, so it plays in the middle.
  def play(id, volume)
    queue(id, volume, 0.0)
  end

  # Queues sound id from x, y, z at gain, and gives true. It fades to
  # silence at RANGES[id] blocks, and a sound out of range is not queued
  # and gives false.
  def play_at(id, x, y, z, gain)
    # to_f: Spinel cannot type the positions of the mobs and the items.
    volume = near_volume(x.to_f, y.to_f, z.to_f, gain, RANGES[id])
    return false if volume <= 0.0

    queue(id, volume, pan_to(x.to_f, y.to_f, z.to_f))
    true
  end

  def queue(id, volume, pan)
    @ids << id
    @volumes << volume
    @pans << pan
    nil
  end

  # Empties the queue.
  def clear
    @ids.clear
    @volumes.clear
    @pans.clear
    nil
  end

  # The listener hears from x, y, z (the eyes of the player) and faces
  # yaw. Game sets it once each frame.
  def listen(x, y, z, yaw)
    @x = x
    @y = y
    @z = z
    @yaw = yaw
    nil
  end

  # Volume for a sound at x, y, z: fades to silence at range blocks.
  def near_volume(x, y, z, gain, range)
    dx = x - @x
    dy = y - @y
    dz = z - @z
    volume = 1.0 - Math.sqrt(dx * dx + dy * dy + dz * dz) / range
    volume > 0.0 ? volume * gain : 0.0
  end

  # Pan for a sound at x, y, z: -1.0 is to the left of the listener, 1.0 is
  # to the right, and 0.0 is ahead, behind, above or below.
  def pan_to(x, y, z)
    dx = x - @x
    dy = y - @y
    dz = z - @z
    dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
    return 0.0 if dist < 0.001

    (dx * Math.cos(@yaw) + dz * Math.sin(@yaw)) / dist
  end
end
