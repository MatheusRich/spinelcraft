# Sound effects: OGG files in assets/sounds, from VoxeLibre (see
# assets/sounds/CREDITS.md).
module Sfx
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
           "mobs_mc_chicken_child"]
  # The gain of each file in dB, in the order of the ids above. It sets the
  # RMS of the loudest 0.1 seconds of each sound to -20 dBFS (-12 dBFS for
  # the explosion), so that all sounds are equally loud.
  GAINS = [-4.1, 3.7, 0.0, 0.5, 2.4, 9.2, 3.3, 2.6,
           3.1, -1.2, -2.0, -4.4, -2.8, -9.0, 19.8, 1.1,
           7.4, 2.5, -6.1, -9.5, -4.3, 21.2, -11.5, -10.0,
           -2.4, -5.7, -9.8, 1.2, -1.6, -5.3, -11.6, -9.5,
           -10.0, -15.4, 1.0, -6.0, -5.4, -2.0, -8.0, -6.1,
           -1.5, 1.8, -0.6, 6.8, 2.7, -6.0, -1.3, -9.5,
           -10.4, -9.6, -15.5, 6.8, -8.5, 10.6, -6.0, 3.3, -9.7, 2.7,
           -11.4, -8.4, -1.9, -0.6, 9.6, -2.7, -5.4, -2.7]

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
