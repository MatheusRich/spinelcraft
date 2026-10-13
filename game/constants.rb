# Game constants that more than one file uses. main.rb requires this file
# first, so each constant has its value before any method reads it.
class Game
  HOTBAR_START = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::PLANKS,
                  Block::LOG, Block::GLASS, Block::BRICK, Block::TORCH]
  PLACEABLE = [Block::GRASS, Block::DIRT, Block::STONE, Block::COBBLE, Block::PLANKS, Block::LOG,
               Block::LEAVES, Block::GLASS, Block::BRICK, Block::SAND, Block::GRAVEL, Block::SNOW,
               Block::SNOW_GRASS, Block::CACTUS, Block::COAL, Block::IRON, Block::DIAMOND, Block::WATER,
               Block::BEDROCK, Block::TALL_GRASS, Block::ROSE, Block::DANDELION, Block::TORCH,
               Block::BOW, Block::ARROW, Block::LAVA, Block::WOOL, Block::BED, Block::CHEST]
  FOG_END = 1600.0
  # F4 view distances, in blocks.
  VIEWS = [200.0, 800.0, 1600.0, 5000.0]
  # Full-detail chunks reach this far at most; far terrain (lod.rb) draws the rest.
  DETAIL_VIEW = 400.0
  # Far terrain levels: level L has cells of 4 << L blocks and reaches
  # LOD_REACH << L blocks, so each level has about the same number of tiles.
  LEVELS = 4
  LOD_REACH = 640
  # Floats that render passes to the shaders: 28, one square for each level,
  # 8 for the far cloud layer, then 4 for the rain.
  CLOUD_UNIFORMS = 28 + 4 * LEVELS
  RAIN_UNIFORMS = CLOUD_UNIFORMS + 8
  UNIFORMS = RAIN_UNIFORMS + 4
  DAY_SECONDS = 600.0
  MAX_HEALTH = 20
  MAX_HUNGER = 20
  MAX_ZOMBIES = 12
  PIGS = 24
  STACK = 64
  # Survival inventory: slots 0..8 are the hotbar, 9..35 the backpack.
  INV = 36
  HOTBAR = 9
  # Seconds of air under water.
  MAX_AIR = 10.0
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
  RECIPES = [[Block::LOG, 1, Block::PLANKS, 4], [Block::COAL, 1, Block::TORCH, 4],
             [Block::SAND, 1, Block::GLASS, 1], [Block::GRAVEL, 1, Block::ARROW, 4],
             [Block::PLANKS, 3, Block::WOOD_PICK, 1], [Block::COBBLE, 3, Block::STONE_PICK, 1],
             [Block::IRON, 3, Block::IRON_PICK, 1], [Block::DIAMOND, 3, Block::DIAMOND_PICK, 1],
             [Block::STONE, 2, Block::BRICK, 1], [Block::WOOL, 3, Block::BED, 1], [Block::PLANKS, 5, Block::BOW, 1],
             [Block::PLANKS, 8, Block::CHEST, 1]]

  INV_COLS = 8

  SAVE_PATH = "world.sav"
  # Where a save that does not load goes, so that the next save does not replace it.
  BAD_SAVE_PATH = "world-bad.sav"
end
