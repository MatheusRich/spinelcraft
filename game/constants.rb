# Game constants that more than one file uses. main.rb requires this file
# first, so each constant has its value before any method reads it.
class Game
  HOTBAR_START = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::OAK_PLANKS,
                  Block::OAK_LOG, Block::GLASS, Block::BRICK, Block::TORCH]
  # The creative inventory screen: the blocks, then the items.
  CREATIVE_ITEMS = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::OAK_PLANKS, Block::OAK_LOG,
                    Block::OAK_LEAVES, Block::SPRUCE_PLANKS, Block::SPRUCE_LOG, Block::SPRUCE_LEAVES,
                    Block::BIRCH_PLANKS, Block::BIRCH_LOG, Block::BIRCH_LEAVES, Block::GLASS, Block::BRICK, Block::SAND, Block::SANDSTONE,
                    Block::GRAVEL, Block::SNOW,
                    Block::SNOW_GRASS, Block::CACTUS, Block::COAL_ORE, Block::IRON, Block::DIAMOND, Block::SPINEL_ORE, Block::WATER,
                    Block::BEDROCK, Block::TALL_GRASS, Block::DRY_GRASS, Block::ROSE, Block::DANDELION, Block::TORCH,
                    Block::LAVA, Block::WOOL, Block::BED, Block::CHEST, Block::DOOR, Block::OAK_SAPLING,
                    Block::SPRUCE_SAPLING, Block::BIRCH_SAPLING,
                    Block::FURNACE, Block::SEEDS, Block::CRAFTING_TABLE, Block::LADDER,
                    Block::WOOD_SWORD, Block::STONE_SWORD, Block::IRON_SWORD, Block::DIAMOND_SWORD,
                    Block::WOOD_PICK, Block::STONE_PICK, Block::IRON_PICK, Block::DIAMOND_PICK,
                    Block::WOOD_AXE, Block::STONE_AXE, Block::IRON_AXE, Block::DIAMOND_AXE,
                    Block::WOOD_SHOVEL, Block::STONE_SHOVEL, Block::IRON_SHOVEL, Block::DIAMOND_SHOVEL, Block::SPINEL_MATTOCK,
                    Block::BOW, Block::ARROW, Block::BUCKET, Block::WATER_BUCKET, Block::LAVA_BUCKET,
                    Block::COAL, Block::IRON_INGOT, Block::SPINEL, Block::WHEAT, Block::APPLE, Block::BREAD, Block::PORKCHOP,
                    Block::COOKED_PORKCHOP, Block::MUTTON, Block::COOKED_MUTTON, Block::BEEF, Block::STEAK,
                    Block::RAW_CHICKEN, Block::COOKED_CHICKEN, Block::ROTTEN_FLESH, Block::LEATHER, Block::MILK_BUCKET,
                    Block::FEATHER, Block::EGG,
                    Block::OAK_BOAT, Block::SPRUCE_BOAT, Block::BIRCH_BOAT,
                    Block::PUMPKIN, Block::CARVED_PUMPKIN, Block::JACK_O_LANTERN, Block::PUMPKIN_SEEDS, Block::PUMPKIN_PIE, Block::SHEARS,
                    Block::BONE, Block::BONE_MEAL]
  # The 6 floats of the colors of the sky and of the fog, the daylight and
  # the fog range (Sky#write_uniforms).
  SKY_UNIFORMS = 20
  # Floats that render passes to the shaders: 28, one square for each level,
  # 8 for the far cloud layer, 4 for the rain, 4 for the options, then 8
  # for each biome: its grass and foliage ratios for far terrain (Tint).
  CLOUD_UNIFORMS = 28 + 4 * FarTerrain::LEVELS
  RAIN_UNIFORMS = CLOUD_UNIFORMS + 8
  OPTION_UNIFORMS = RAIN_UNIFORMS + 4
  TINT_UNIFORMS = OPTION_UNIFORMS + 4
  UNIFORMS = TINT_UNIFORMS + 8 * Biome::ALL.size
  # The materials of blocks for their sounds (Game#material), and the sound
  # of each material when the player digs it, breaks it, steps on it and
  # places it. They follow VoxeLibre (mcl_sounds), but stone, wood and dirt
  # break with one sound.
  M_STONE = 0
  M_WOOD = 1
  M_DIRT = 2
  M_GRASS = 3
  M_SAND = 4
  M_GRAVEL = 5
  M_GLASS = 6
  M_LEAVES = 7
  M_CLOTH = 8
  M_SNOW = 9
  MATERIAL_DIG = [Sfx::DIG_STONE, Sfx::DIG_WOOD, Sfx::DIG_SOFT, Sfx::DIG_SOFT, Sfx::DIG_SOFT, Sfx::DIG_GRAVEL, Sfx::DIG_STONE, Sfx::DIG_LEAVES,
                  Sfx::CLOTH, Sfx::SNOW]
  MATERIAL_BREAK = [Sfx::BREAK, Sfx::BREAK, Sfx::BREAK, Sfx::BREAK, Sfx::STEP_SAND, Sfx::BREAK_GRAVEL, Sfx::BREAK_GLASS, Sfx::STEP_GRASS,
                    Sfx::CLOTH, Sfx::SNOW]
  MATERIAL_STEP = [Sfx::STEP_HARD, Sfx::STEP_WOOD, Sfx::STEP_DIRT, Sfx::STEP_GRASS, Sfx::STEP_SAND, Sfx::STEP_GRAVEL, Sfx::STEP_GLASS, Sfx::STEP_GRASS,
                   Sfx::CLOTH, Sfx::SNOW]
  MATERIAL_PLACE = [Sfx::PLACE_HARD, Sfx::PLACE_HARD, Sfx::PLACE, Sfx::PLACE, Sfx::PLACE, Sfx::PLACE, Sfx::PLACE_HARD, Sfx::PLACE,
                    Sfx::CLOTH, Sfx::PLACE]
  # Eating takes 32 ticks. minecraft.wiki/w/Food
  EAT_TIME = 1.6
  # Two presses of jump this close start or stop flying in creative. The
  # wiki says only "double-tapping" (minecraft.wiki/w/Flying). The 7 ticks
  # come from the game code (LocalPlayer.aiStep, jumpTriggerTime).
  FLY_TAP = 0.35
  # A bite plays each 4 ticks after the first 7 ticks of eating, as in
  # Minecraft (LivingEntity.shouldTriggerItemUseEffects, not on the wiki).
  CHEW_START = 0.35
  CHEW_EVERY = 0.2
  # Blocks near the player make these sounds now and then (Game#block_sound):
  # lava under air, flowing water, and a lit furnace. The wiki says only
  # that they play at random (minecraft.wiki/w/Lava, minecraft.wiki/w/Water,
  # minecraft.wiki/w/Furnace). It does not confirm the chances. They are
  # those of the code of Java Edition: each time that Minecraft looks at a
  # block, lava plays its sound at a chance of 1 in 200, flowing water 1 in
  # 64, and a lit furnace 1 in 10.
  AMBIENT = [Sfx::LAVA, Sfx::FLOWING, Sfx::CRACKLE]
  AMBIENT_CHANCE = [1.0 / 200.0, 1.0 / 64.0, 0.1]
  AMBIENT_VOLUME = [0.4, 0.3, 0.5]
  # Each second, Game#update_block_sounds looks at this many random blocks
  # near the player. Minecraft looks at MC_AMBIENT_SAMPLES of them (667 in
  # each tick), so the chances grow to make up the difference. The wiki
  # does not confirm the count.
  AMBIENT_SAMPLES = 3000.0
  MC_AMBIENT_SAMPLES = 667.0 * 20.0
  # Survival inventory: slots 0..8 are the hotbar, 9..35 the backpack.
  INV = 36
  HOTBAR = 9

  # Loads that must finish before play goes on (start, respawn) stop at SYNC_R;
  # the rest stream in.
  SYNC_R = 8
  STREAM_BUDGET_NS = 2_500_000
  # The frame rate of a recording (RECORD).
  RECORD_FPS = 30

  # GPU slots after the chunks' opaque and water slots, FarTerrain::TILE_SLOTS
  # per level.
  LOD_SLOT0 = ChunkMeshes::GPU_SLOTS

  INV_COLS = 8

  # The files of the game. Game#initialize puts Game#file_prefix in front
  # of each name.
  SAVE_PATH = "world.sav"
  # The first word of a save. A save with another version does not load.
  SAVE_VERSION = "SPINELCRAFT21"
  # The options of the pause menu (see Options#write_file).
  OPTIONS_PATH = "options.txt"
  # Where a save that does not load goes, so that the next save does not replace it.
  BAD_SAVE_PATH = "world-bad.sav"
end
