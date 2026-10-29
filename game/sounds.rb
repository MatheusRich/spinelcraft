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
  # A sound from a point fades to silence at RANGE blocks, and an  # explosion at EXPLOSION_RANGE. The wiki gives 64 blocks for TNT. It does
  # not say if a creeper explosion carries as far. minecraft.wiki/w/Sound
  RANGE = 16.0
  EXPLOSION_RANGE = 64.0
  # Thunder carries over the 17 x 17 chunks where lightning strikes. Minecraft
  # plays thunder at full volume in the whole dimension, so this range is not
  # a Minecraft value.
  THUNDER_RANGE = 192.0
  # The file of each sound, in the order of the ids above.
  FILES = ["default_dug_node.1", "default_place_node.1", "default_place_node_hard.1", "player_damage",
           "default_grass_footstep.1", "default_dirt_footstep.1", "default_hard_footstep.1", "default_wood_footstep.1",
           "default_dig_cracky.1", "default_dig_choppy.1", "default_dig_crumbly", "default_tool_breaks",
           "mobs_pig", "mobs_mc_zombie_growl", "mobs_mc_skeleton_random.1", "mobs_mc_creeper_hurt",
           "mcl_bows_bow_shoot", "mcl_bows_hit_other", "watersplash", "fire_extinguish_flame.1",
           "tnt_explode", "weather_rain", "item_drop_pickup",
           "mobs_pig_angry", "mobs_sheep", "mobs_mc_zombie_hurt", "mobs_mc_zombie_death",
           "mobs_mc_skeleton_hurt", "mobs_mc_skeleton_death", "mobs_mc_creeper_death",
           "mcl_hunger_bite.1", "player_falling_damage",
           "doors_door_open", "doors_door_close", "default_chest_open", "default_chest_close",
           "mcl_sounds_dug_water", "mcl_sounds_place_node_water", "default_place_node_lava",
           "default_break_glass.1", "default_glass_footstep", "default_dig_snappy",
           "default_gravel_dig.1", "default_gravel_dug.1", "default_gravel_footstep.1",
           "default_sand_footstep.1", "default_water_footstep.1",
           "cave1", "cave2", "cave4", "cave5",
           "tnt_ignite", "mcl_sounds_cloth.1", "pedology_snow_soft_footstep.1",
           "env_sounds_lava.1", "env_sounds_water.1", "fire_fire.1",
           "mesecons_button_push", "mobs_mc_cow", "mobs_mc_cow_hurt", "mobs_mc_cow_milk",
           "mcl_potions_drinking", "mobs_mc_chicken_buck.1", "mobs_mc_chicken_hurt", "mobs_mc_chicken_lay_egg",
           "mobs_mc_chicken_child", "lightning_thunder.1", "lightning_thunder.2", "lightning_thunder.3",
           "mcl_armor_equip_iron", "mcl_armor_equip_diamond"]
  # The gain of each file in dB, in the order of the ids above. It sets the
  # RMS of the loudest 0.1 seconds of each sound to -20 dBFS (-12 dBFS for
  # the explosion and the thunder), so that all sounds are equally loud.
  GAINS = [-4.1, 3.7, 0.0, 0.5, 2.4, 9.2, 3.3, 2.6,
           3.1, -1.2, -2.0, -4.4, -2.8, -9.0, 19.8, 1.1,
           7.4, 2.5, -6.1, -9.5, -4.3, 21.2, -11.5, -10.0,
           -2.4, -5.7, -9.8, 1.2, -1.6, -5.3, -11.6, -9.5,
           -10.0, -15.4, 1.0, -6.0, -5.4, -2.0, -8.0, -6.1,
           -1.5, 1.8, -0.6, 6.8, 2.7, -6.0, -1.3, -9.5,
           -10.4, -9.6, -15.5, 6.8, -8.5, 10.6, -6.0, 3.3, -9.7, 2.7,
           -11.4, -8.4, -1.9, -0.6, 9.6, -2.7, -5.4, -2.7,
           -5.6, -2.7, -0.5, -1.1, -2.4]
  # The distance in blocks at which each sound from a point fades to
  # silence, in the order of the ids above.
  RANGES = Array.new(FILES.size, RANGE)
  RANGES[EXPLODE] = EXPLOSION_RANGE
  THUNDERS.times { |index| RANGES[THUNDER + index] = THUNDER_RANGE }

  # The queue: the id, the volume and the pan of each sound to play.
  attr_reader :ids, :volumes, :pans

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

  # Queues sound id from x, y, z at gain. It fades to silence at
  # RANGES[id] blocks, and a sound out of range is not queued.
  def play_at(id, x, y, z, gain)
    # to_f: Spinel cannot type the positions of the mobs and the items.
    volume = near_volume(x.to_f, y.to_f, z.to_f, gain, RANGES[id])
    queue(id, volume, pan_to(x.to_f, y.to_f, z.to_f)) if volume > 0.0
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
end
