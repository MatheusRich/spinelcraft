# Game constants that more than one file uses. main.rb requires this file
# first, so each constant has its value before any method reads it.
class Game
  HOTBAR_START = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::PLANKS,
                  Block::LOG, Block::GLASS, Block::BRICK, Block::TORCH]
  # The creative inventory screen: the blocks, then the items.
  CREATIVE_ITEMS = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::PLANKS, Block::LOG,
                    Block::LEAVES, Block::GLASS, Block::BRICK, Block::SAND, Block::GRAVEL, Block::SNOW,
                    Block::SNOW_GRASS, Block::CACTUS, Block::COAL, Block::IRON, Block::DIAMOND, Block::WATER,
                    Block::BEDROCK, Block::TALL_GRASS, Block::ROSE, Block::DANDELION, Block::TORCH,
                    Block::LAVA, Block::WOOL, Block::BED, Block::CHEST, Block::DOOR, Block::SAPLING,
                    Block::FURNACE, Block::SEEDS, Block::CRAFTING_TABLE, Block::LADDER,
                    Block::WOOD_SWORD, Block::STONE_SWORD, Block::IRON_SWORD, Block::DIAMOND_SWORD,
                    Block::WOOD_PICK, Block::STONE_PICK, Block::IRON_PICK, Block::DIAMOND_PICK,
                    Block::WOOD_AXE, Block::STONE_AXE, Block::IRON_AXE, Block::DIAMOND_AXE,
                    Block::WOOD_SHOVEL, Block::STONE_SHOVEL, Block::IRON_SHOVEL, Block::DIAMOND_SHOVEL,
                    Block::BOW, Block::ARROW, Block::BUCKET, Block::WATER_BUCKET, Block::LAVA_BUCKET,
                    Block::IRON_INGOT, Block::WHEAT, Block::APPLE, Block::BREAD, Block::PORKCHOP,
                    Block::COOKED_PORKCHOP, Block::ROTTEN_FLESH]
  FOG_END = 1600.0
  # The range of the render distance slider, in blocks.
  VIEW_MIN = 200.0
  VIEW_MAX = 5000.0
  # Full-detail chunks reach this far at most; far terrain (lod.rb) draws the rest.
  DETAIL_VIEW = 400.0
  # Far terrain levels: level L has cells of 4 << L blocks and reaches
  # LOD_REACH << L blocks, so each level has about the same number of tiles.
  LEVELS = 4
  LOD_REACH = 640
  # Floats that render passes to the shaders: 28, one square for each level,
  # 8 for the far cloud layer, 4 for the rain, then 4 for the options.
  CLOUD_UNIFORMS = 28 + 4 * LEVELS
  RAIN_UNIFORMS = CLOUD_UNIFORMS + 8
  OPTION_UNIFORMS = RAIN_UNIFORMS + 4
  UNIFORMS = OPTION_UNIFORMS + 4
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
  # A bite plays each 4 ticks after the first 7 ticks of eating, as in
  # Minecraft (LivingEntity.shouldTriggerItemUseEffects, not on the wiki).
  CHEW_START = 0.35
  CHEW_EVERY = 0.2
  # A sound from a point fades to silence at this distance, in blocks.
  # minecraft.wiki/w/Sound
  SOUND_RANGE = 16.0
  # The wiki gives 64 blocks for TNT. It does not say if a creeper
  # explosion carries as far. minecraft.wiki/w/Sound
  EXPLOSION_RANGE = 64.0
  # Blocks near the player make these sounds now and then (Game#block_sound):
  # lava under air, flowing water, and a lit furnace. The wiki says only
  # that they play at random (minecraft.wiki/w/Lava, minecraft.wiki/w/Water,
  # minecraft.wiki/w/Furnace). It does not give the rates, so these are a
  # guess, as sounds for each block in each second.
  AMBIENT = [Sfx::LAVA, Sfx::FLOWING, Sfx::CRACKLE]
  AMBIENT_RATE = [1.0 / 150.0, 1.0 / 150.0, 1.0 / 25.0]
  AMBIENT_VOLUME = [0.4, 0.3, 0.5]
  # Each second, Game#update_block_sounds looks at this many random blocks
  # within SOUND_RANGE of the player.
  AMBIENT_SAMPLES = 3000.0
  # A day and a night last 20 minutes, as in Minecraft.
  # minecraft.wiki/w/Daylight_cycle
  DAY_SECONDS = 1200.0
  PIGS = 24
  # Survival inventory: slots 0..8 are the hotbar, 9..35 the backpack.
  INV = 36
  HOTBAR = 9
  CHEST_SLOTS = 27

  # Chunks within LOAD_R of the player's chunk are loaded, and those within
  # MESH_R are meshed. MESH_R is one less, so a chunk to mesh has its neighbors.
  LOAD_R = RING / 2 - 1
  MESH_R = LOAD_R - 1
  # Loads that must finish before play goes on (start, respawn) stop at SYNC_R;
  # the rest stream in.
  SYNC_R = 8
  STREAM_BUDGET_NS = 2_500_000

  # GPU slots after the chunks' opaque and water slots, TILE_SLOTS per level.
  LOD_SLOT0 = CX * CZ * 2
  TILE_SLOTS = Lod::TRING * Lod::TRING

  # Survival crafting: turns the selected stack into something else.
  # Where a recipe works: by hand (the E screen), on a crafting table, or in
  # a furnace (the screen that a right-click on one opens).
  BY_HAND = 0
  AT_TABLE = 1
  AT_FURNACE = 2
  # Each recipe: the ingredient, how many, the result, how many, and where.
  # The recipe list shows two recipes to a row. The tools come first, in
  # pairs of one material, so that each kind of tool is a column: the
  # pickaxes and then the axes at the left, the swords and then the
  # shovels at the right.
  RECIPES = [[Block::PLANKS, 3, Block::WOOD_PICK, 1, AT_TABLE], [Block::PLANKS, 2, Block::WOOD_SWORD, 1, AT_TABLE],
             [Block::COBBLE, 3, Block::STONE_PICK, 1, AT_TABLE], [Block::COBBLE, 2, Block::STONE_SWORD, 1, AT_TABLE],
             [Block::IRON_INGOT, 3, Block::IRON_PICK, 1, AT_TABLE], [Block::IRON_INGOT, 2, Block::IRON_SWORD, 1, AT_TABLE],
             [Block::DIAMOND, 3, Block::DIAMOND_PICK, 1, AT_TABLE], [Block::DIAMOND, 2, Block::DIAMOND_SWORD, 1, AT_TABLE],
             [Block::PLANKS, 3, Block::WOOD_AXE, 1, AT_TABLE], [Block::PLANKS, 1, Block::WOOD_SHOVEL, 1, AT_TABLE],
             [Block::COBBLE, 3, Block::STONE_AXE, 1, AT_TABLE], [Block::COBBLE, 1, Block::STONE_SHOVEL, 1, AT_TABLE],
             [Block::IRON_INGOT, 3, Block::IRON_AXE, 1, AT_TABLE], [Block::IRON_INGOT, 1, Block::IRON_SHOVEL, 1, AT_TABLE],
             [Block::DIAMOND, 3, Block::DIAMOND_AXE, 1, AT_TABLE], [Block::DIAMOND, 1, Block::DIAMOND_SHOVEL, 1, AT_TABLE],
             [Block::LOG, 1, Block::PLANKS, 4, BY_HAND], [Block::COAL, 1, Block::TORCH, 4, BY_HAND],
             [Block::PLANKS, 4, Block::CRAFTING_TABLE, 1, BY_HAND], [Block::GRAVEL, 1, Block::ARROW, 4, AT_TABLE],
             [Block::STONE, 2, Block::BRICK, 1, AT_TABLE], [Block::WOOL, 3, Block::BED, 1, AT_TABLE],
             [Block::PLANKS, 5, Block::BOW, 1, AT_TABLE], [Block::PLANKS, 8, Block::CHEST, 1, AT_TABLE],
             [Block::PLANKS, 6, Block::DOOR, 3, AT_TABLE], [Block::PLANKS, 3, Block::LADDER, 4, AT_TABLE],
             [Block::WHEAT, 3, Block::BREAD, 1, AT_TABLE], [Block::IRON_INGOT, 3, Block::BUCKET, 1, AT_TABLE],
             [Block::COBBLE, 8, Block::FURNACE, 1, AT_TABLE],
             [Block::IRON, 1, Block::IRON_INGOT, 1, AT_FURNACE], [Block::PORKCHOP, 1, Block::COOKED_PORKCHOP, 1, AT_FURNACE],
             [Block::SAND, 1, Block::GLASS, 1, AT_FURNACE], [Block::COBBLE, 1, Block::STONE, 1, AT_FURNACE]]

  INV_COLS = 8

  SAVE_PATH = "world.sav"
  # The first word of a save. A save with another version does not load.
  SAVE_VERSION = "SPINELCRAFT13"
  # The options of the pause menu (see Game#save_options).
  OPTIONS_PATH = "options.txt"
  # Where a save that does not load goes, so that the next save does not replace it.
  BAD_SAVE_PATH = "world-bad.sav"
end
