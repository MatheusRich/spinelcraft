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
  DOOR_OPEN = 46
  SAPLING = 47
  APPLE = 48
  WOOD_SWORD = 49
  STONE_SWORD = 50
  IRON_SWORD = 51
  DIAMOND_SWORD = 52
  IRON_INGOT = 53
  FURNACE = 54
  COOKED_PORKCHOP = 55
  WOOD_AXE = 56
  STONE_AXE = 57
  IRON_AXE = 58
  DIAMOND_AXE = 59
  WOOD_SHOVEL = 60
  STONE_SHOVEL = 61
  IRON_SHOVEL = 62
  DIAMOND_SHOVEL = 63
  # Crops: seeds grow through two stages into ripe wheat.
  SEEDS = 64
  WHEAT_1 = 65
  WHEAT_2 = 66
  WHEAT_RIPE = 67
  WHEAT = 68
  BREAD = 69
  CRAFTING_TABLE = 70
  LADDER = 71
  BUCKET = 72
  WATER_BUCKET = 73
  LAVA_BUCKET = 74
  # The half of a bed with the pillow. BED is the other half.
  BED_HEAD = 75
  # A torch on the side of a block: the first of 4, one for each wall
  # direction in WALL_DX and WALL_DZ. A torch item places one of them.
  WALL_TORCH = 76
  COUNT = 80
  # The step from a wall torch to the block that holds it.
  WALL_DX = [1, -1, 0, 0]
  WALL_DZ = [0, 0, 1, -1]
  # A wall torch sits this much higher than a torch on the floor.
  WALL_LIFT = 0.2

  NAMES = ["AIR", "GRASS", "DIRT", "STONE", "SAND", "WATER", "LOG", "LEAVES", "PLANKS", "COBBLESTONE",
           "GLASS", "SNOWY GRASS", "BEDROCK", "BRICKS", "COAL ORE", "IRON ORE", "GRAVEL", "DIAMOND ORE",
           "CACTUS", "SNOW", "TALL GRASS", "ROSE", "DANDELION", "TORCH", "PORKCHOP", "WOODEN PICKAXE", "STONE PICKAXE", "IRON PICKAXE", "DIAMOND PICKAXE", "WATER", "WATER", "WATER", "WATER", "WATER", "WATER", "WATER", "BOW", "ARROW", "LAVA", "LAVA", "LAVA", "LAVA", "WOOL", "BED", "CHEST", "DOOR", "DOOR", "SAPLING", "APPLE", "WOODEN SWORD", "STONE SWORD", "IRON SWORD", "DIAMOND SWORD", "IRON INGOT", "FURNACE", "COOKED PORKCHOP", "WOODEN AXE", "STONE AXE", "IRON AXE", "DIAMOND AXE", "WOODEN SHOVEL", "STONE SHOVEL", "IRON SHOVEL", "DIAMOND SHOVEL", "SEEDS", "WHEAT", "WHEAT", "WHEAT", "WHEAT", "BREAD", "CRAFTING TABLE", "LADDER", "BUCKET", "WATER BUCKET", "LAVA BUCKET", "BED", "TORCH", "TORCH", "TORCH", "TORCH"]
  TOP = [0, Tex::GRASS_TOP, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_TOP, Tex::LEAVES,
         Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON,
         Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_TOP, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_TOP, Tex::CHEST_TOP, Tex::PLANKS, Tex::DOOR_OPEN, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::COBBLE, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::CRAFT_TOP, Tex::CLEAR, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::BED_HEAD_TOP, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH]
  SIDE = [0, Tex::GRASS_SIDE, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_SIDE, Tex::LEAVES,
          Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::SNOW_SIDE, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON,
          Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_SIDE, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::BED_SIDE, Tex::CHEST_SIDE, Tex::DOOR, Tex::DOOR_OPEN, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::FURNACE, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::CRAFT_SIDE, Tex::LADDER, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::BED_SIDE, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH]
  BOTTOM = [0, Tex::DIRT, Tex::DIRT, Tex::STONE, Tex::SAND, Tex::WATER, Tex::LOG_TOP, Tex::LEAVES,
            Tex::PLANKS, Tex::COBBLE, Tex::GLASS, Tex::DIRT, Tex::BEDROCK, Tex::BRICK, Tex::COAL, Tex::IRON,
            Tex::GRAVEL, Tex::DIAMOND, Tex::CACTUS_TOP, Tex::SNOW, Tex::TALL_GRASS, Tex::ROSE, Tex::DANDELION, Tex::TORCH, Tex::PORKCHOP, Tex::WOOD_PICK, Tex::STONE_PICK, Tex::IRON_PICK, Tex::DIAMOND_PICK, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::WATER, Tex::BOW, Tex::ARROW, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::LAVA, Tex::WOOL, Tex::PLANKS, Tex::CHEST_TOP, Tex::PLANKS, Tex::DOOR_OPEN, Tex::SAPLING, Tex::APPLE, Tex::WOOD_SWORD, Tex::STONE_SWORD, Tex::IRON_SWORD, Tex::DIAMOND_SWORD, Tex::IRON_INGOT, Tex::COBBLE, Tex::COOKED_PORKCHOP, Tex::WOOD_AXE, Tex::STONE_AXE, Tex::IRON_AXE, Tex::DIAMOND_AXE, Tex::WOOD_SHOVEL, Tex::STONE_SHOVEL, Tex::IRON_SHOVEL, Tex::DIAMOND_SHOVEL, Tex::SEEDS, Tex::WHEAT_1, Tex::WHEAT_2, Tex::WHEAT_RIPE, Tex::WHEAT, Tex::BREAD, Tex::PLANKS, Tex::CLEAR, Tex::BUCKET, Tex::WATER_BUCKET, Tex::LAVA_BUCKET, Tex::PLANKS, Tex::TORCH, Tex::TORCH, Tex::TORCH, Tex::TORCH]
  # Integer 0/1 tables: Spinel keeps Integer arrays unboxed.
  # Hides the faces behind it.
  OPAQUE = [0, 1, 1, 1, 1, 0, 1, 0, 1, 1,
            0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Darkens ambient occlusion corners.
  OCCLUDES = [0, 1, 1, 1, 1, 0, 1, 1, 1, 1,
              0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0]
  # Stops the player.
  SOLID = [0, 1, 1, 1, 1, 0, 1, 1, 1, 1,
           1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0]
  # Drawn as two crossed quads instead of a cube.
  PLANT = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1]
  # The hardness of each block, as in Minecraft; negative never breaks.
  # Game#mine turns it into seconds. minecraft.wiki/w/Breaking, and
  # /w/Leaves, /w/Snow_Block and /w/Bed for those blocks.
  HARDNESS = [0.0, 0.6, 0.5, 1.5, 0.5, -1.0, 2.0, 0.2, 2.0, 2.0, 0.3, 0.6, -1.0, 2.0, 3.0, 3.0, 0.6, 3.0, 0.4, 0.2, 0.0, 0.0, 0.0, 0.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 0.8, 0.2, 2.5, 3.0, 3.0, 0.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 3.5, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, 0.0, 0.0, 0.0, 0.0, -1.0, -1.0, 2.5, 0.4, -1.0, -1.0, -1.0, 0.2, 0.0, 0.0, 0.0, 0.0]
  # What breaking the block gives in survival.
  DROPS = [0, DIRT, DIRT, COBBLE, SAND, 0, LOG, 0, PLANKS, COBBLE, 0, DIRT, 0, BRICK, COAL, IRON, GRAVEL, DIAMOND, CACTUS, SNOW, 0, ROSE, DANDELION, TORCH, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, WOOL, BED, CHEST, DOOR, DOOR, SAPLING, 0, 0, 0, 0, 0, 0, FURNACE, 0, 0, 0, 0, 0, 0, 0, 0, 0, SEEDS, SEEDS, SEEDS, WHEAT, 0, 0, CRAFTING_TABLE, LADDER, 0, 0, 0, BED, TORCH, TORCH, TORCH, TORCH]
  # Pickaxe tier a block needs to drop anything: 1 wood, 2 stone, 3 iron.
  NEEDS_PICK = [0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 2, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # The tool that digs the block fast: 1 a pickaxe, 2 an axe, 3 a shovel.
  DIG_KIND = [0, 3, 3, 1, 3, 0, 2, 0, 2, 1, 0, 3, 0, 1, 1, 1, 3, 1, 0, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 2, 0, 0, 0, 0]
  # Pickaxe tier of an item (0 for everything that is not a pickaxe).
  PICK_TIER = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  # Water level: 8 for a source, 1..7 for flowing water, 0 for anything else.
  WATER_LEVEL = [0, 0, 0, 0, 0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  def self.blocks_light(b) = b != AIR && b != GLASS && b != DOOR_OPEN && b != LADDER && !plant?(b)
  def self.solid?(b) = SOLID[b] == 1
  def self.plant?(b) = PLANT[b] == 1
  def self.water?(b) = WATER_LEVEL[b] > 0
  # Things that live in the inventory but are never placed.
  def self.item?(b) = (b >= PORKCHOP && b <= DIAMOND_PICK) || b == BOW || b == ARROW || (b >= APPLE && b <= IRON_INGOT) ||
    (b >= COOKED_PORKCHOP && b <= DIAMOND_SHOVEL) || b == WHEAT || b == BREAD || bucket?(b)
  def self.bucket?(b) = b >= BUCKET && b <= LAVA_BUCKET
  # Items and plants are flat pictures; the other blocks are cubes.
  def self.flat?(b) = item?(b) || plant?(b)
  def self.door?(b) = b == DOOR || b == DOOR_OPEN
  def self.torch?(b) = b == TORCH || wall_torch?(b)
  def self.wall_torch?(b) = b >= WALL_TORCH && b < WALL_TORCH + 4
  def self.bed?(b) = b == BED || b == BED_HEAD
  # The box of a block in its cell: half its width around the center, and
  # its height. A plant is smaller than its cell, and a torch is thin.
  def self.box_half(b) = torch?(b) ? 0.1 : (plant?(b) ? 0.3 : 0.5)
  def self.box_top(b) = torch?(b) ? 0.6 : (plant?(b) ? 0.8 : 1.0)
  # A wall torch leans out of its wall. This is how far the point at height
  # h of the torch moves toward the wall. vchunk in gfx.rb draws the same lean.
  def self.wall_lean(h) = 0.42 - 0.4 * h
  # The move of the box of b from the middle of its cell, and up from the floor.
  def self.box_dx(b) = wall_torch?(b) ? WALL_DX[b - WALL_TORCH] * wall_lean(0.3) : 0.0
  def self.box_dz(b) = wall_torch?(b) ? WALL_DZ[b - WALL_TORCH] * wall_lean(0.3) : 0.0
  def self.box_dy(b) = wall_torch?(b) ? WALL_LIFT : 0.0
  # Hunger points that eating b gives back; 0 for what is not food.
  # minecraft.wiki/w/Apple, /w/Bread, /w/Raw_Porkchop, /w/Food
  def self.food(b) = b == COOKED_PORKCHOP ? 8 : (b == BREAD ? 5 : (b == APPLE ? 4 : (b == PORKCHOP ? 3 : 0)))
  # Saturation points that eating b gives back.
  def self.saturation(b) = b == COOKED_PORKCHOP ? 12.8 : (b == BREAD ? 6.0 : (b == APPLE ? 2.4 : (b == PORKCHOP ? 1.8 : 0.0)))
  # A crop that has not ripened yet.
  def self.growing?(b) = b >= SEEDS && b < WHEAT_RIPE
  def self.sword?(b) = b >= WOOD_SWORD && b <= DIAMOND_SWORD
  # The damage of a hit with b, as in Minecraft 1.8, which has no attack
  # cooldown: a hand does 1, and a wooden tool does 1 more than the hand
  # with a shovel, 2 with a pickaxe, 3 with an axe and 4 with a sword. Each
  # tier above wood adds 1. NOT CONFIRMED on the wiki: minecraft.wiki/w/Melee_attack
  # gives only the values after 1.9, which has an attack cooldown.
  def self.damage(b)
    return 5 + b - WOOD_SWORD if sword?(b)
    tool_kind(b) > 0 ? TOOL_DAMAGE[tool_kind(b)] + tool_tier(b) - 1 : 1
  end
  # The damage of a wooden tool by the kind in DIG_KIND.
  TOOL_DAMAGE = [1, 3, 4, 2]
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
