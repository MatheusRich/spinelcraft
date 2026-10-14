# Each block and item type: its name, textures and what it does.
module Block
  AIR = 0
  GRASS = 1
  DIRT = 2
  STONE = 3
  SAND = 4
  WATER = 5
  LOG = 6
  LEAVES = 7
  PLANKS = 8
  COBBLE = 9
  GLASS = 10
  SNOW_GRASS = 11
  BEDROCK = 12
  BRICK = 13
  COAL = 14
  IRON = 15
  GRAVEL = 16
  DIAMOND = 17
  CACTUS = 18
  SNOW = 19
  TALL_GRASS = 20
  ROSE = 21
  DANDELION = 22
  TORCH = 23
  PORKCHOP = 24
  WOOD_PICK = 25
  STONE_PICK = 26
  IRON_PICK = 27
  DIAMOND_PICK = 28
  # Flowing water: FLOW + level - 1 for levels 1..7 (a source is level 8).
  FLOW = 29
  BOW = 36
  ARROW = 37
  # Lava: a source is level 4; LAVA_FLOW + level - 1 for flowing levels 1..3.
  LAVA = 38
  LAVA_FLOW = 39
  WOOL = 42
  BED = 43
  CHEST = 44
  DOOR = 45
  SAPLING = 46
  APPLE = 47
  WOOD_SWORD = 48
  STONE_SWORD = 49
  IRON_SWORD = 50
  DIAMOND_SWORD = 51
  IRON_INGOT = 52
  FURNACE = 53
  COOKED_PORKCHOP = 54
  WOOD_AXE = 55
  STONE_AXE = 56
  IRON_AXE = 57
  DIAMOND_AXE = 58
  WOOD_SHOVEL = 59
  STONE_SHOVEL = 60
  IRON_SHOVEL = 61
  DIAMOND_SHOVEL = 62
  # Crops: seeds grow through two stages into ripe wheat.
  SEEDS = 63
  WHEAT_1 = 64
  WHEAT_2 = 65
  WHEAT_RIPE = 66
  WHEAT = 67
  BREAD = 68
  CRAFTING_TABLE = 69
  LADDER = 70
  BUCKET = 71
  WATER_BUCKET = 72
  LAVA_BUCKET = 73
  # The half of a bed with the pillow. BED is the other half.
  BED_HEAD = 74
  # A torch on the side of a block: the first of 4, one for each facing.
  # A torch item places one of them (see facing_id).
  WALL_TORCH = 75
  # 79-81 are furnaces that face the directions 1-3. FURNACE faces
  # direction 0.
  # The first of 16 door blocks: DOOR_BLOCK + open * 8 + upper * 4 + facing.
  # A closed door stands on the edge of its cell that it faces, and an open
  # door on the edge that DOOR_TURN gives. DOOR is the item.
  DOOR_BLOCK = 82
  COUNT = 98
  # The step in each of the 4 directions on the ground: +x, -x, +z and -z.
  # The opposite of direction d is d ^ 1.
  DIR_DX = [1, -1, 0, 0]
  DIR_DZ = [0, 0, 1, -1]
  # The face of a cube (in the face order of Mesher and Mesh3) that looks
  # in each direction.
  DIR_FACE = [0, 1, 4, 5]
  # A wall torch sits this much higher than a torch on the floor.
  WALL_LIFT = 0.2
  # The thickness of a door, as in Minecraft (3 of 16 pixels).
  DOOR_THICK = 3.0 / 16.0
  # The edge that an open door moves to from the edge of its closed door.
  # It is a quarter turn, so DOOR_TURN of d is never d or d ^ 1.
  DOOR_TURN = [2, 3, 1, 0]

  NAMES = ["AIR", "GRASS", "DIRT", "STONE", "SAND", "WATER", "LOG", "LEAVES", "PLANKS", "COBBLESTONE", "GLASS", "SNOWY GRASS", "BEDROCK", "BRICKS", "COAL ORE", "IRON ORE", "GRAVEL", "DIAMOND ORE", "CACTUS", "SNOW", "TALL GRASS", "ROSE", "DANDELION", "TORCH", "PORKCHOP", "WOODEN PICKAXE", "STONE PICKAXE", "IRON PICKAXE", "DIAMOND PICKAXE", "WATER", "WATER", "WATER", "WATER", "WATER", "WATER", "WATER", "BOW", "ARROW", "LAVA", "LAVA", "LAVA", "LAVA", "WOOL", "BED", "CHEST", "DOOR", "SAPLING", "APPLE", "WOODEN SWORD", "STONE SWORD", "IRON SWORD", "DIAMOND SWORD", "IRON INGOT", "FURNACE", "COOKED PORKCHOP", "WOODEN AXE", "STONE AXE", "IRON AXE", "DIAMOND AXE", "WOODEN SHOVEL", "STONE SHOVEL", "IRON SHOVEL", "DIAMOND SHOVEL", "SEEDS", "WHEAT", "WHEAT", "WHEAT", "WHEAT", "BREAD", "CRAFTING TABLE", "LADDER", "BUCKET", "WATER BUCKET", "LAVA BUCKET", "BED", "TORCH", "TORCH", "TORCH", "TORCH", "FURNACE", "FURNACE", "FURNACE", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR", "DOOR"]
  TOP = [0, Tex::GRASS_TOP, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_TOP, Tex::LEAVES, Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON, Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_TOP, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_TOP, Tex::CHEST_TOP, Tex::DOOR_ITEM, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::FURNACE_TOP, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::CRAFT_TOP, Tex::CLEAR, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::BED_HEAD_TOP, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::FURNACE_TOP, Tex::FURNACE_TOP, Tex::FURNACE_TOP, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER]
  SIDE = [0, Tex::GRASS_SIDE, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_SIDE, Tex::LEAVES, Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW_SIDE, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON, Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_SIDE, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_SIDE, Tex::CHEST_SIDE, Tex::DOOR_ITEM, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::FURNACE_SIDE, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::CRAFT_SIDE, Tex::LADDER, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::BED_SIDE, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::FURNACE_SIDE, Tex::FURNACE_SIDE, Tex::FURNACE_SIDE, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER]
  BOTTOM = [0, Tex::DIRT, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_TOP, Tex::LEAVES, Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::DIRT, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON, Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_TOP, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::PLANKS, Tex::CHEST_TOP, Tex::DOOR_ITEM, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::FURNACE_TOP, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::PLANKS, Tex::CLEAR, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::PLANKS, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::FURNACE_TOP, Tex::FURNACE_TOP, Tex::FURNACE_TOP, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER]
  # The texture on the front face of a block that has a facing, and the
  # icon of the block in the inventory.
  FRONT = [0, Tex::GRASS_SIDE, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_SIDE, Tex::LEAVES, Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW_SIDE, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON, Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_SIDE, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_SIDE, Tex::CHEST_SIDE, Tex::DOOR_ITEM, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::FURNACE, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::CRAFT_SIDE, Tex::LADDER, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::BED_SIDE, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::FURNACE, Tex::FURNACE, Tex::FURNACE, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_LOWER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER, Tex::DOOR_UPPER]
  # The direction that the front of each block faces (see DIR_DX and DIR_DZ),
  # or -1 for a block without a front. A wall torch faces away from its wall.
  FACING = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 0, 1, 2, 3, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]
  # The kind of each block: what the inventory holds for it. The blocks of
  # one kind differ only in their facing, or in a part of the same thing
  # (an open door, the head of a bed).
  BASE = [AIR, GRASS, DIRT, STONE, SAND, WATER, LOG, LEAVES, PLANKS, COBBLE, GLASS, SNOW_GRASS, BEDROCK, BRICK, COAL, IRON, GRAVEL, DIAMOND, CACTUS, SNOW, TALL_GRASS, ROSE, DANDELION, TORCH, PORKCHOP, WOOD_PICK, STONE_PICK, IRON_PICK, DIAMOND_PICK, FLOW, 30, 31, 32, 33, 34, 35, BOW, ARROW, LAVA, LAVA_FLOW, 40, 41, WOOL, BED, CHEST, DOOR, SAPLING, APPLE, WOOD_SWORD, STONE_SWORD, IRON_SWORD, DIAMOND_SWORD, IRON_INGOT, FURNACE, COOKED_PORKCHOP, WOOD_AXE, STONE_AXE, IRON_AXE, DIAMOND_AXE, WOOD_SHOVEL, STONE_SHOVEL, IRON_SHOVEL, DIAMOND_SHOVEL, SEEDS, 64, 65, WHEAT_RIPE, WHEAT, BREAD, CRAFTING_TABLE, LADDER, BUCKET, WATER_BUCKET, LAVA_BUCKET, BED, TORCH, TORCH, TORCH, TORCH, FURNACE, FURNACE, FURNACE, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR]

  # Integer 0/1 tables: Spinel keeps Integer arrays unboxed.
  # Hides the faces behind it.
  OPAQUE = [0, 1, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Darkens ambient occlusion corners.
  OCCLUDES = [0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Stops the player.
  SOLID = [0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  # Drawn as two crossed quads instead of a cube.
  PLANT = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # The hardness of each block, as in Minecraft; negative never breaks.
  # Game#mine turns it into seconds. minecraft.wiki/w/Breaking, and
  # /w/Leaves, /w/Snow_Block and /w/Bed for those blocks.
  HARDNESS = [0.0, 0.6, 0.5, 1.5, 0.5, -1.0, 2.0, 0.2, 2.0, 2.0, 0.3, 0.6, -1.0, 2.0, 3.0, 3.0, 0.6, 3.0, 0.4, 0.2, 0.0, 0.0, 0.0, 0.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 0.8, 0.2, 2.5, 3.0, 0.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 3.5, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 0.0, 0.0, 0.0, 0.0, -1.0, -1.0, 2.5, 0.4, -1.0, -1.0, -1.0, 0.2, 0.0, 0.0, 0.0, 0.0, 3.5, 3.5, 3.5, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0]
  # What breaking the block gives in survival.
  DROPS = [0, DIRT, DIRT, COBBLE, SAND, 0, LOG, 0, PLANKS, COBBLE, 0, DIRT, 0, BRICK, COAL, IRON, GRAVEL, DIAMOND, CACTUS, SNOW, 0, ROSE, DANDELION, TORCH, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, WOOL, BED, CHEST, DOOR, SAPLING, 0, 0, 0, 0, 0, 0, FURNACE, 0, 0, 0, 0, 0, 0, 0, 0, 0, SEEDS, SEEDS, SEEDS, WHEAT, 0, 0, CRAFTING_TABLE, LADDER, 0, 0, 0, BED, TORCH, TORCH, TORCH, TORCH, FURNACE, FURNACE, FURNACE, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR, DOOR]
  # Pickaxe tier a block needs to drop anything: 1 wood, 2 stone, 3 iron.
  NEEDS_PICK = [0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # The tool that digs the block fast: 1 a pickaxe, 2 an axe, 3 a shovel.
  DIG_KIND = [0, 3, 3, 1, 3, 0, 2, 0, 2, 1, 0, 3, 0, 1, 1, 1, 3, 1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 2, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2]
  # Pickaxe tier of an item (0 for everything that is not a pickaxe).
  PICK_TIER = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Water level: 8 for a source, 1..7 for flowing water, 0 for anything else.
  WATER_LEVEL = [0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  def self.blocks_light(b) = b != AIR && b != GLASS && !door?(b) && b != LADDER && !plant?(b)
  def self.solid?(b) = SOLID[b] == 1
  def self.plant?(b) = PLANT[b] == 1
  def self.water?(b) = WATER_LEVEL[b] > 0
  # Things that live in the inventory but are never placed.
  def self.item?(b) = (b >= PORKCHOP && b <= DIAMOND_PICK) || b == BOW || b == ARROW || (b >= APPLE && b <= IRON_INGOT) ||
    (b >= COOKED_PORKCHOP && b <= DIAMOND_SHOVEL) || b == WHEAT || b == BREAD || bucket?(b)
  def self.bucket?(b) = b >= BUCKET && b <= LAVA_BUCKET
  # Items, plants and the door item are flat pictures; the other blocks are cubes.
  def self.flat?(b) = item?(b) || plant?(b) || b == DOOR
  def self.door?(b) = b >= DOOR_BLOCK && b < DOOR_BLOCK + 16
  def self.door_open?(b) = door?(b) && b >= DOOR_BLOCK + 8
  def self.door_upper?(b) = door?(b) && (b - DOOR_BLOCK) % 8 >= 4
  def self.door_id(facing, upper, open) = DOOR_BLOCK + (open ? 8 : 0) + (upper ? 4 : 0) + facing
  # The same door half, opened or closed.
  def self.door_toggled(b) = door_open?(b) ? b - 8 : b + 8
  # The edge of its cell that a door stands on, as a direction, or -1 for
  # a block that is not a door.
  def self.door_edge(b) = door?(b) ? (door_open?(b) ? DOOR_TURN[FACING[b]] : FACING[b]) : -1
  def self.torch?(b) = BASE[b] == TORCH
  def self.wall_torch?(b) = torch?(b) && FACING[b] >= 0
  def self.bed?(b) = b == BED || b == BED_HEAD
  # The block of kind base that faces direction d; base when the kind has
  # no block for that direction.
  def self.facing_id(base, d)
    b = 0
    while b < COUNT
      return b if BASE[b] == base && FACING[b] == d
      b += 1
    end
    base
  end
  # The box of a block in its cell: half its size on x and z around the
  # center, and its height. A plant is smaller than its cell, a torch is
  # thin, and a door is a thin board on one edge.
  def self.box_half(b) = torch?(b) ? 0.1 : (plant?(b) ? 0.3 : 0.5)
  def self.box_hx(b) = door?(b) && DIR_DX[door_edge(b)] != 0 ? DOOR_THICK / 2.0 : box_half(b)
  def self.box_hz(b) = door?(b) && DIR_DZ[door_edge(b)] != 0 ? DOOR_THICK / 2.0 : box_half(b)
  def self.box_top(b) = torch?(b) ? 0.6 : (plant?(b) ? 0.8 : 1.0)
  # A wall torch leans out of its wall. This is how far the point at height
  # h of the torch moves toward the wall. vchunk in gfx.rb draws the same lean.
  def self.wall_lean(h) = 0.42 - 0.4 * h
  # The move of the box of b from the middle of its cell, and up from the floor.
  def self.box_dx(b)
    return -DIR_DX[FACING[b]] * wall_lean(0.3) if wall_torch?(b)
    door?(b) ? DIR_DX[door_edge(b)] * (0.5 - DOOR_THICK / 2.0) : 0.0
  end
  def self.box_dz(b)
    return -DIR_DZ[FACING[b]] * wall_lean(0.3) if wall_torch?(b)
    door?(b) ? DIR_DZ[door_edge(b)] * (0.5 - DOOR_THICK / 2.0) : 0.0
  end
  def self.box_dy(b) = wall_torch?(b) ? WALL_LIFT : 0.0
  # Hunger points that eating b gives back; 0 for what is not food.
  # minecraft.wiki/w/Apple, /w/Bread, /w/Raw_Porkchop, /w/Food
  def self.food(b) = b == COOKED_PORKCHOP ? 8 : (b == BREAD ? 5 : (b == APPLE ? 4 : (b == PORKCHOP ? 3 : 0)))
  # Saturation points that eating b gives back.
  def self.saturation(b) = b == COOKED_PORKCHOP ? 12.8 : (b == BREAD ? 6.0 : (b == APPLE ? 2.4 : (b == PORKCHOP ? 1.8 : 0.0)))
  # A crop that has not ripened yet.
  def self.growing?(b) = b >= SEEDS && b < WHEAT_RIPE
  def self.sword?(b) = b >= WOOD_SWORD && b <= DIAMOND_SWORD
  # The damage of a hit with b when the attack cooldown is full. A hand and
  # what is not a weapon or a tool do 1. minecraft.wiki/w/Sword, /w/Axe,
  # /w/Pickaxe, /w/Shovel and /w/Melee_attack
  def self.damage(b)
    return SWORD_DAMAGE[b - WOOD_SWORD] if sword?(b)
    kind = tool_kind(b)
    return 1.0 if kind == 0
    tier = tool_tier(b)
    kind == 1 ? tier + 1.0 : (kind == 2 ? AXE_DAMAGE[tier - 1] : tier + 1.5)
  end
  SWORD_DAMAGE = [4.0, 5.0, 6.0, 7.0]
  AXE_DAMAGE = [7.0, 9.0, 9.0, 9.0]
  # Attacks each second with b: the attack cooldown is 1 / speed seconds.
  # minecraft.wiki/w/Sword, /w/Axe, /w/Pickaxe, /w/Shovel and
  # /w/Melee_attack
  def self.attack_speed(b)
    return 1.6 if sword?(b)
    kind = tool_kind(b)
    return 4.0 if kind == 0
    kind == 1 ? 1.2 : (kind == 2 ? AXE_SPEED[tool_tier(b) - 1] : 1.0)
  end
  AXE_SPEED = [0.8, 0.8, 0.9, 1.0]
  # The uses that one hit (attack true) or one broken block takes from b:
  # a sword is for hits and a digging tool for blocks, and each loses 2 for
  # the other job. minecraft.wiki/w/Item_durability
  def self.wear(b, attack)
    return attack ? 1 : 2 if sword?(b)
    return attack ? 2 : 1 if tool_kind(b) > 0
    0
  end
  # Uses before a wooden, stone, iron or diamond tool breaks, and a bow.
  # minecraft.wiki/w/Item_durability
  TOOL_USES = [59, 131, 250, 1561]
  # The uses of a new tool b; 0 for what is not a tool. A tool never
  # stacks: the count of its stack is the uses that it has left.
  def self.uses(b)
    return TOOL_USES[tool_tier(b) - 1] if tool_tier(b) > 0
    return TOOL_USES[b - WOOD_SWORD] if sword?(b)
    b == BOW ? 384 : 0
  end
  # The kind of a digging tool, as in DIG_KIND; 0 for anything else.
  def self.tool_kind(b) = PICK_TIER[b] > 0 ? 1 : (b >= WOOD_AXE && b <= DIAMOND_AXE ? 2 : (b >= WOOD_SHOVEL && b <= DIAMOND_SHOVEL ? 3 : 0))
  # The tier of a digging tool: 1 wood, 2 stone, 3 iron, 4 diamond; 0 for anything else.
  def self.tool_tier(b)
    return PICK_TIER[b] if PICK_TIER[b] > 0
    return b - WOOD_AXE + 1 if b >= WOOD_AXE && b <= DIAMOND_AXE
    b >= WOOD_SHOVEL && b <= DIAMOND_SHOVEL ? b - WOOD_SHOVEL + 1 : 0
  end
  def self.tool?(b) = uses(b) > 0
  def self.lava?(b) = b >= LAVA && b < LAVA_FLOW + 3
  def self.lava_level(b) = b == LAVA ? 4 : (lava?(b) ? b - LAVA_FLOW + 1 : 0)
  # Torches and lava sources light their surroundings.
  def self.emits?(b) = torch?(b) || b == LAVA
end
