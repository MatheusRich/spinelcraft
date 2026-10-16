# Each block and item type: its name, textures and what it does.
module Block
  AIR = 0
  GRASS = 1
  DIRT = 2
  STONE = 3
  SAND = 4
  WATER = 5
  OAK_LOG = 6
  OAK_LEAVES = 7
  OAK_PLANKS = 8
  COBBLE = 9
  GLASS = 10
  SNOW_GRASS = 11
  BEDROCK = 12
  BRICK = 13
  COAL_ORE = 14
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
  OAK_SAPLING = 46
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
  # A torch on the side of a block: the first of 4, one for each facing.
  # A torch item places one of them (see facing_id).
  WALL_TORCH = 74
  # The first of 3 furnaces that face the directions 1-3. FURNACE faces
  # direction 0.
  FURNACE_TURNS = 78
  # The first of 16 door blocks: DOOR_BLOCK + open * 8 + upper * 4 + facing.
  # A closed door stands on the edge of its cell that it faces, and an open
  # door on the edge a quarter turn from it (see SHAPE_BOX). DOOR is the item.
  DOOR_BLOCK = 81
  # The first of 3 ladders and the first of 3 chests that face the
  # directions 1-3. LADDER and CHEST face direction 0. A ladder faces
  # away from its wall.
  LADDER_TURNS = 97
  CHEST_TURNS = 100
  # A furnace with heat: FURNACE_LIT + facing.
  FURNACE_LIT = 103
  # The first of 8 bed blocks: BED_BLOCK + head * 4 + facing. Each half
  # faces away from the other half. BED is the item.
  BED_BLOCK = 107
  ROTTEN_FLESH = 115
  # The spruce and the birch woods, in the order of the oak wood.
  SPRUCE_LOG = 116
  SPRUCE_LEAVES = 117
  SPRUCE_PLANKS = 118
  SPRUCE_SAPLING = 119
  BIRCH_LOG = 120
  BIRCH_LEAVES = 121
  BIRCH_PLANKS = 122
  BIRCH_SAPLING = 123
  MUTTON = 124
  COOKED_MUTTON = 125
  COAL = 126
  # Leaves that the player placed. They never decay, as the persistent
  # leaves of Minecraft.
  PLACED_OAK_LEAVES = 127
  PLACED_SPRUCE_LEAVES = 128
  PLACED_BIRCH_LEAVES = 129
  # A boat of each wood, in the order of WOODS. A boat is an item: placed
  # on water it is a Boat, not a block.
  OAK_BOAT = 130
  SPRUCE_BOAT = 131
  BIRCH_BOAT = 132
  PUMPKIN = 133
  # A carved pumpkin and a jack o'lantern face direction 0. 135-137 and
  # 139-141 face the directions 1-3.
  CARVED_PUMPKIN = 134
  JACK_O_LANTERN = 138
  SHEARS = 142
  # Pumpkin seeds grow into a stem, and a ripe stem grows pumpkins next to it.
  PUMPKIN_SEEDS = 143
  PUMPKIN_STEM = 144
  PUMPKIN_STEM_RIPE = 145
  BONE = 146
  BONE_MEAL = 147
  SANDSTONE = 148
  DRY_GRASS = 149
  BEEF = 150
  STEAK = 151
  LEATHER = 152
  MILK_BUCKET = 153
  # What a chicken drops and lays.
  RAW_CHICKEN = 154
  COOKED_CHICKEN = 155
  FEATHER = 156
  EGG = 157
  WOODS = [OAK_WOOD = 0, SPRUCE_WOOD = 1, BIRCH_WOOD = 2]
  # The blocks of each wood, one entry for each of WOODS.
  LOGS = [OAK_LOG, SPRUCE_LOG, BIRCH_LOG]
  LEAVES = [OAK_LEAVES, SPRUCE_LEAVES, BIRCH_LEAVES]
  PLACED_LEAVES = [PLACED_OAK_LEAVES, PLACED_SPRUCE_LEAVES, PLACED_BIRCH_LEAVES]
  PLANKS = [OAK_PLANKS, SPRUCE_PLANKS, BIRCH_PLANKS]
  SAPLINGS = [OAK_SAPLING, SPRUCE_SAPLING, BIRCH_SAPLING]
  # A recipe ingredient that the planks of any wood fill, as the planks tag
  # in Minecraft. It is not a block, so no table has an entry for it.
  ANY_PLANKS = 1000
  # The step in each of the 4 directions on the ground: +x, -x, +z and -z.
  # The opposite of direction d is d ^ 1.
  DIR_DX = [1, -1, 0, 0]
  DIR_DZ = [0, 0, 1, -1]
  # The face of a cube (in the face order of Mesher and Mesh3) that looks
  # in each direction.
  DIR_FACE = [0, 1, 4, 5]
  # A wall torch sits this much higher than a torch on the floor.
  WALL_LIFT = 0.2
  # The shapes of the blocks that are not a full cube, as boxes in
  # sixteenths of the cell: x0, y0, z0, x1, y1, z1. Each box is for the
  # block that faces +x (direction 0), and a block turns it to its facing.
  # The sizes are those of Minecraft: 1 a closed door, a board 3 thick on
  # the +x edge; 2 an open door, the same board on the +z edge, so that
  # both share the hinge corner; 3 a ladder, a board 1 thick on its wall;
  # 4 a chest; 5 a bed; 6 a cactus, 1 narrower on each side, so that the
  # clear edges of its texture fall outside the box. Shape 0 is the full
  # cube. Block.shader_defines gives the boxes to the chunk shader.
  SHAPE_BOX = [0, 0, 0, 16, 16, 16, 13, 0, 0, 16, 16, 16, 0, 0, 13, 16, 16, 16, 0, 0, 0, 1, 16, 16,
               1, 0, 1, 15, 14, 15, 0, 0, 0, 16, 9, 16, 1, 0, 1, 15, 16, 15]

  # The tables below have one entry for each block, at the index of its
  # id. Block.define_block fills them, and each block is one call to it, after
  # these tables. Spinel keeps Integer and Float arrays unboxed.
  NAMES = []
  # The textures of the top, the sides and the bottom of each block.
  TOP = []
  SIDE = []
  BOTTOM = []
  # The texture on the front face of a block that has a facing, and the
  # icon of the block in the inventory.
  FRONT = []
  # The direction that the front of each block faces (see DIR_DX and DIR_DZ),
  # or -1 for a block without a front. A wall torch faces away from its wall.
  FACING = []
  # The kind of each block: what the inventory holds for it. The blocks of
  # one kind differ only in their facing, or in a part of the same thing
  # (an open door, the head of a bed).
  BASE = []
  # The shape of each block in SHAPE_BOX.
  SHAPE = []
  # 1 for a block that hides the faces behind it.
  OPAQUE = []
  # 1 for a block that darkens ambient occlusion corners.
  OCCLUDES = []
  # 1 for a block that stops the player.
  SOLID = []
  # 1 for a block that draws as two crossed quads instead of a cube.
  PLANT = []
  # The hardness of each block, as in Minecraft; negative never breaks.
  # Game#mine turns it into seconds.
  HARDNESS = []
  # What breaking the block gives in survival.
  DROPS = []
  # Pickaxe tier a block needs to drop anything: 1 wood, 2 stone, 3 iron.
  NEEDS_PICK = []
  # The tool that digs the block fast: DIG_PICK, DIG_AXE, DIG_SHOVEL, or 0.
  DIG_KIND = []
  DIG_PICK = 1
  DIG_AXE = 2
  DIG_SHOVEL = 3
  # Pickaxe tier of an item (0 for everything that is not a pickaxe).
  PICK_TIER = []
  # Water level: 8 for a source, 1..7 for flowing water, 0 for anything else.
  WATER_LEVEL = []
  # 1 for a thing that lives in the inventory but is never placed.
  ITEM = []
  # Hunger points that eating the block gives back; 0 for what is not food.
  FOOD = []
  # Saturation points that eating the block gives back.
  SATURATION = []

  # Adds block id to the tables above, which name its arguments. The
  # blocks come in the order of their ids. A block is an opaque, solid
  # cube with the texture side on each face, and it drops itself, unless
  # the arguments say something else.
  def self.define_block(id, name, side, top: side, bottom: top, front: side, facing: -1, base: id, shape: 0, opaque: 1,
                        occludes: opaque, solid: 1, plant: 0, hardness: 0.0, drops: id, needs_pick: 0, dig: 0, pick_tier: 0,
                        water: 0, item: 0, food: 0, saturation: 0.0)
    abort "Block.define_block: block #{id} comes out of order" if id != NAMES.size
    NAMES << name
    TOP << top
    SIDE << side
    BOTTOM << bottom
    FRONT << front
    FACING << facing
    BASE << base
    SHAPE << shape
    OPAQUE << opaque
    OCCLUDES << occludes
    SOLID << solid
    PLANT << plant
    HARDNESS << hardness
    DROPS << drops
    NEEDS_PICK << needs_pick
    DIG_KIND << dig
    PICK_TIER << pick_tier
    WATER_LEVEL << water
    ITEM << item
    FOOD << food
    SATURATION << saturation
  end

  # A thing that lives in the inventory, but never in the world.
  def self.define_item(id, name, tex, pick_tier: 0, food: 0, saturation: 0.0) =
    define_block(id, name, tex, opaque: 0, solid: 0, hardness: -1.0, drops: AIR, pick_tier: pick_tier, item: 1, food: food,
                 saturation: saturation)

  # A plant: two crossed quads that do not stop the player and break at once.
  def self.define_plant(id, name, tex, drops: id) = define_block(id, name, tex, opaque: 0, solid: 0, plant: 1, drops: drops)

  # The blocks first, first + 1 and so on: block of turned to each direction
  # after its own facing, up to direction 3.
  def self.define_turns(first, of)
    (FACING[of] + 1...4).each do |d|
      define_block(first + d - FACING[of] - 1, NAMES[of], SIDE[of], top: TOP[of], bottom: BOTTOM[of], front: FRONT[of],
                   facing: d, base: BASE[of], shape: SHAPE[of], opaque: OPAQUE[of], occludes: OCCLUDES[of], solid: SOLID[of],
                   plant: PLANT[of], hardness: HARDNESS[of], drops: DROPS[of], needs_pick: NEEDS_PICK[of], dig: DIG_KIND[of],
                   pick_tier: PICK_TIER[of], water: WATER_LEVEL[of], item: ITEM[of], food: FOOD[of], saturation: SATURATION[of])
    end
    # A while loop gives an untyped value, so Spinel would box the return.
    nil
  end

  # Leaves let light through, but darken ambient occlusion corners. base is
  # the leaves of the tree for leaves that the player placed.
  def self.define_leaves(id, name, tex, base: id) =
    define_block(id, name, tex, base: base, opaque: 0, occludes: 1, hardness: 0.2, drops: AIR)

  # A door half (see DOOR_BLOCK) that faces +x, and its turns.
  def self.define_door(first, tex, shape)
    define_block(first, "DOOR", tex, facing: 0, base: DOOR, shape: shape, opaque: 0, hardness: 3.0, drops: DOOR, dig: DIG_AXE)
    define_turns(first + 1, first)
  end

  # The hardness values come from minecraft.wiki/w/Breaking, and /w/Leaves,
  # /w/Snow_Block, /w/Bed, /w/Pumpkin and /w/Jack_o'Lantern for those blocks.
  # The food and saturation values come from minecraft.wiki/w/Food, and
  # the page of each food.
  define_block AIR, "AIR", Tex::WHITE, opaque: 0, solid: 0
  define_block GRASS, "GRASS", Tex::GRASS_SIDE, top: Tex::GRASS_TOP, bottom: Tex::DIRT, hardness: 0.6, drops: DIRT, dig: DIG_SHOVEL
  define_block DIRT, "DIRT", Tex::DIRT, hardness: 0.5, dig: DIG_SHOVEL
  define_block STONE, "STONE", Tex::STONE, hardness: 1.5, drops: COBBLE, needs_pick: 1, dig: DIG_PICK
  define_block SAND, "SAND", Tex::SAND, hardness: 0.5, dig: DIG_SHOVEL
  define_block WATER, "WATER", Tex::WATER, opaque: 0, solid: 0, hardness: -1.0, drops: AIR, water: 8
  define_block OAK_LOG, "OAK LOG", Tex::OAK_LOG_SIDE, top: Tex::OAK_LOG_TOP, hardness: 2.0, dig: DIG_AXE
  define_leaves OAK_LEAVES, "OAK LEAVES", Tex::OAK_LEAVES
  define_block OAK_PLANKS, "OAK PLANKS", Tex::OAK_PLANKS, hardness: 2.0, dig: DIG_AXE
  define_block COBBLE, "COBBLESTONE", Tex::COBBLE, hardness: 2.0, needs_pick: 1, dig: DIG_PICK
  define_block GLASS, "GLASS", Tex::GLASS, opaque: 0, hardness: 0.3, drops: AIR
  define_block SNOW_GRASS, "SNOWY GRASS", Tex::SNOW_SIDE, top: Tex::SNOW, bottom: Tex::DIRT, hardness: 0.6, drops: DIRT, dig: DIG_SHOVEL
  define_block BEDROCK, "BEDROCK", Tex::BEDROCK, hardness: -1.0, drops: AIR
  define_block BRICK, "BRICKS", Tex::BRICK, hardness: 2.0, needs_pick: 1, dig: DIG_PICK
  define_block COAL_ORE, "COAL ORE", Tex::COAL_ORE, hardness: 3.0, drops: COAL, needs_pick: 1, dig: DIG_PICK
  define_block IRON, "IRON ORE", Tex::IRON, hardness: 3.0, needs_pick: 2, dig: DIG_PICK
  define_block GRAVEL, "GRAVEL", Tex::GRAVEL, hardness: 0.6, dig: DIG_SHOVEL
  define_block DIAMOND, "DIAMOND ORE", Tex::DIAMOND, hardness: 3.0, needs_pick: 3, dig: DIG_PICK
  define_block CACTUS, "CACTUS", Tex::CACTUS_SIDE, top: Tex::CACTUS_TOP, shape: 6, opaque: 0, hardness: 0.4
  define_block SNOW, "SNOW", Tex::SNOW, hardness: 0.2, dig: DIG_SHOVEL
  define_plant TALL_GRASS, "TALL GRASS", Tex::TALL_GRASS, drops: AIR
  define_plant ROSE, "ROSE", Tex::ROSE
  define_plant DANDELION, "DANDELION", Tex::DANDELION
  define_plant TORCH, "TORCH", Tex::TORCH
  define_item PORKCHOP, "PORKCHOP", Tex::PORKCHOP, food: 3, saturation: 1.8 # minecraft.wiki/w/Raw_Porkchop
  define_item WOOD_PICK, "WOODEN PICKAXE", Tex::WOOD_PICK, pick_tier: 1
  define_item STONE_PICK, "STONE PICKAXE", Tex::STONE_PICK, pick_tier: 2
  define_item IRON_PICK, "IRON PICKAXE", Tex::IRON_PICK, pick_tier: 3
  define_item DIAMOND_PICK, "DIAMOND PICKAXE", Tex::DIAMOND_PICK, pick_tier: 4
  (1...8).each do |level|
    define_block FLOW + level - 1, "WATER", Tex::WATER, opaque: 0, solid: 0, hardness: -1.0, drops: AIR, water: level
  end
  define_item BOW, "BOW", Tex::BOW
  define_item ARROW, "ARROW", Tex::ARROW
  define_block LAVA, "LAVA", Tex::LAVA, solid: 0, hardness: -1.0, drops: AIR
  (1...4).each { |level| define_block LAVA_FLOW + level - 1, "LAVA", Tex::LAVA, solid: 0, hardness: -1.0, drops: AIR }
  define_block WOOL, "WOOL", Tex::WOOL, hardness: 0.8
  define_block BED, "BED", Tex::BED_ITEM, opaque: 0, solid: 0, hardness: 0.2, dig: DIG_AXE
  define_block CHEST, "CHEST", Tex::CHEST_SIDE, top: Tex::CHEST_TOP, front: Tex::CHEST_FRONT, facing: 0, shape: 4, opaque: 0,
               hardness: 2.5, dig: DIG_AXE
  define_block DOOR, "DOOR", Tex::DOOR_ITEM, opaque: 0, solid: 0, hardness: 3.0, dig: DIG_AXE
  define_plant OAK_SAPLING, "OAK SAPLING", Tex::OAK_SAPLING
  define_item APPLE, "APPLE", Tex::APPLE, food: 4, saturation: 2.4 # minecraft.wiki/w/Apple
  define_item WOOD_SWORD, "WOODEN SWORD", Tex::WOOD_SWORD
  define_item STONE_SWORD, "STONE SWORD", Tex::STONE_SWORD
  define_item IRON_SWORD, "IRON SWORD", Tex::IRON_SWORD
  define_item DIAMOND_SWORD, "DIAMOND SWORD", Tex::DIAMOND_SWORD
  define_item IRON_INGOT, "IRON INGOT", Tex::IRON_INGOT
  define_block FURNACE, "FURNACE", Tex::FURNACE_SIDE, top: Tex::FURNACE_TOP, front: Tex::FURNACE, facing: 0, hardness: 3.5,
               needs_pick: 1, dig: DIG_PICK
  define_item COOKED_PORKCHOP, "COOKED PORKCHOP", Tex::COOKED_PORKCHOP, food: 8, saturation: 12.8 # minecraft.wiki/w/Cooked_Porkchop
  define_item WOOD_AXE, "WOODEN AXE", Tex::WOOD_AXE
  define_item STONE_AXE, "STONE AXE", Tex::STONE_AXE
  define_item IRON_AXE, "IRON AXE", Tex::IRON_AXE
  define_item DIAMOND_AXE, "DIAMOND AXE", Tex::DIAMOND_AXE
  define_item WOOD_SHOVEL, "WOODEN SHOVEL", Tex::WOOD_SHOVEL
  define_item STONE_SHOVEL, "STONE SHOVEL", Tex::STONE_SHOVEL
  define_item IRON_SHOVEL, "IRON SHOVEL", Tex::IRON_SHOVEL
  define_item DIAMOND_SHOVEL, "DIAMOND SHOVEL", Tex::DIAMOND_SHOVEL
  define_plant SEEDS, "SEEDS", Tex::SEEDS
  define_plant WHEAT_1, "WHEAT CROPS", Tex::WHEAT_1, drops: SEEDS
  define_plant WHEAT_2, "WHEAT CROPS", Tex::WHEAT_2, drops: SEEDS
  define_plant WHEAT_RIPE, "WHEAT CROPS", Tex::WHEAT_RIPE, drops: WHEAT
  define_item WHEAT, "WHEAT", Tex::WHEAT
  define_item BREAD, "BREAD", Tex::BREAD, food: 5, saturation: 6.0 # minecraft.wiki/w/Bread
  define_block CRAFTING_TABLE, "CRAFTING TABLE", Tex::CRAFT_SIDE, top: Tex::CRAFT_TOP, bottom: Tex::OAK_PLANKS, hardness: 2.5,
               dig: DIG_AXE
  define_block LADDER, "LADDER", Tex::LADDER, top: Tex::CLEAR, facing: 0, shape: 3, opaque: 0, solid: 0, hardness: 0.4, dig: DIG_AXE
  define_item BUCKET, "BUCKET", Tex::BUCKET
  define_item WATER_BUCKET, "WATER BUCKET", Tex::WATER_BUCKET
  define_item LAVA_BUCKET, "LAVA BUCKET", Tex::LAVA_BUCKET
  define_block WALL_TORCH, "TORCH", Tex::TORCH, facing: 0, base: TORCH, opaque: 0, solid: 0, plant: 1, drops: TORCH
  define_turns WALL_TORCH + 1, WALL_TORCH
  define_turns FURNACE_TURNS, FURNACE
  define_door DOOR_BLOCK, Tex::DOOR_LOWER, 1
  define_door DOOR_BLOCK + 4, Tex::DOOR_UPPER, 1
  define_door DOOR_BLOCK + 8, Tex::DOOR_LOWER, 2
  define_door DOOR_BLOCK + 12, Tex::DOOR_UPPER, 2
  define_turns LADDER_TURNS, LADDER
  define_turns CHEST_TURNS, CHEST
  define_block FURNACE_LIT, "FURNACE", Tex::FURNACE_SIDE, top: Tex::FURNACE_TOP, front: Tex::FURNACE_LIT, facing: 0, base: FURNACE,
               hardness: 3.5, drops: FURNACE, needs_pick: 1, dig: DIG_PICK
  define_turns FURNACE_LIT + 1, FURNACE_LIT
  define_block BED_BLOCK, "BED", Tex::BED_SIDE, top: Tex::BED_TOP, bottom: Tex::OAK_PLANKS, front: Tex::BED_FOOT_END, facing: 0,
               base: BED, shape: 5, opaque: 0, hardness: 0.2, drops: BED, dig: DIG_AXE
  define_turns BED_BLOCK + 1, BED_BLOCK
  define_block BED_BLOCK + 4, "BED", Tex::BED_HEAD_SIDE, top: Tex::BED_HEAD_TOP, bottom: Tex::OAK_PLANKS, front: Tex::BED_HEAD_END,
               facing: 0, base: BED, shape: 5, opaque: 0, hardness: 0.2, drops: BED, dig: DIG_AXE
  define_turns BED_BLOCK + 5, BED_BLOCK + 4
  define_item ROTTEN_FLESH, "ROTTEN FLESH", Tex::ROTTEN_FLESH, food: 4, saturation: 0.8 # minecraft.wiki/w/Rotten_Flesh
  define_block SPRUCE_LOG, "SPRUCE LOG", Tex::SPRUCE_LOG_SIDE, top: Tex::SPRUCE_LOG_TOP, hardness: 2.0, dig: DIG_AXE
  define_leaves SPRUCE_LEAVES, "SPRUCE LEAVES", Tex::SPRUCE_LEAVES
  define_block SPRUCE_PLANKS, "SPRUCE PLANKS", Tex::SPRUCE_PLANKS, hardness: 2.0, dig: DIG_AXE
  define_plant SPRUCE_SAPLING, "SPRUCE SAPLING", Tex::SPRUCE_SAPLING
  define_block BIRCH_LOG, "BIRCH LOG", Tex::BIRCH_LOG_SIDE, top: Tex::BIRCH_LOG_TOP, hardness: 2.0, dig: DIG_AXE
  define_leaves BIRCH_LEAVES, "BIRCH LEAVES", Tex::BIRCH_LEAVES
  define_block BIRCH_PLANKS, "BIRCH PLANKS", Tex::BIRCH_PLANKS, hardness: 2.0, dig: DIG_AXE
  define_plant BIRCH_SAPLING, "BIRCH SAPLING", Tex::BIRCH_SAPLING
  define_item MUTTON, "MUTTON", Tex::MUTTON, food: 2, saturation: 1.2 # minecraft.wiki/w/Raw_Mutton
  define_item COOKED_MUTTON, "COOKED MUTTON", Tex::COOKED_MUTTON, food: 6, saturation: 9.6 # minecraft.wiki/w/Cooked_Mutton
  define_item COAL, "COAL", Tex::COAL
  define_leaves PLACED_OAK_LEAVES, "OAK LEAVES", Tex::OAK_LEAVES, base: OAK_LEAVES
  define_leaves PLACED_SPRUCE_LEAVES, "SPRUCE LEAVES", Tex::SPRUCE_LEAVES, base: SPRUCE_LEAVES
  define_leaves PLACED_BIRCH_LEAVES, "BIRCH LEAVES", Tex::BIRCH_LEAVES, base: BIRCH_LEAVES
  define_item OAK_BOAT, "OAK BOAT", Tex::OAK_BOAT
  define_item SPRUCE_BOAT, "SPRUCE BOAT", Tex::SPRUCE_BOAT
  define_item BIRCH_BOAT, "BIRCH BOAT", Tex::BIRCH_BOAT
  define_block PUMPKIN, "PUMPKIN", Tex::PUMPKIN_SIDE, top: Tex::PUMPKIN_TOP, hardness: 1.0, dig: DIG_AXE
  define_block CARVED_PUMPKIN, "CARVED PUMPKIN", Tex::PUMPKIN_SIDE, top: Tex::PUMPKIN_TOP, front: Tex::PUMPKIN_FACE, facing: 0,
               hardness: 1.0, dig: DIG_AXE
  define_turns CARVED_PUMPKIN + 1, CARVED_PUMPKIN
  define_block JACK_O_LANTERN, "JACK O'LANTERN", Tex::PUMPKIN_SIDE, top: Tex::PUMPKIN_TOP, front: Tex::JACK_FACE, facing: 0,
               hardness: 1.0, dig: DIG_AXE
  define_turns JACK_O_LANTERN + 1, JACK_O_LANTERN
  define_item SHEARS, "SHEARS", Tex::SHEARS
  # Placed pumpkin seeds show the young stem; the icon shows the seeds.
  define_block PUMPKIN_SEEDS, "PUMPKIN SEEDS", Tex::PUMPKIN_SEEDS, top: Tex::PUMPKIN_STEM, bottom: Tex::PUMPKIN_SEEDS, opaque: 0,
               solid: 0, plant: 1
  define_plant PUMPKIN_STEM, "PUMPKIN STEM", Tex::PUMPKIN_STEM, drops: PUMPKIN_SEEDS
  define_plant PUMPKIN_STEM_RIPE, "PUMPKIN STEM", Tex::PUMPKIN_STEM_RIPE, drops: PUMPKIN_SEEDS
  define_item BONE, "BONE", Tex::BONE
  define_item BONE_MEAL, "BONE MEAL", Tex::BONE_MEAL
  # Any pickaxe mines sandstone. Without one it drops nothing. minecraft.wiki/w/Sandstone
  define_block SANDSTONE, "SANDSTONE", Tex::SANDSTONE_SIDE, top: Tex::SANDSTONE_TOP, bottom: Tex::SANDSTONE_BOTTOM, hardness: 0.8,
               needs_pick: 1, dig: DIG_PICK
  # The short dry grass of Minecraft drops nothing by hand. minecraft.wiki/w/Short_Dry_Grass
  define_plant DRY_GRASS, "DRY GRASS", Tex::DRY_GRASS, drops: AIR
  define_item BEEF, "RAW BEEF", Tex::BEEF, food: 3, saturation: 1.8 # minecraft.wiki/w/Raw_Beef
  define_item STEAK, "STEAK", Tex::STEAK, food: 8, saturation: 12.8 # minecraft.wiki/w/Steak
  define_item LEATHER, "LEATHER", Tex::LEATHER
  define_item MILK_BUCKET, "MILK BUCKET", Tex::MILK_BUCKET
  define_item RAW_CHICKEN, "RAW CHICKEN", Tex::RAW_CHICKEN, food: 2, saturation: 1.2 # minecraft.wiki/w/Raw_Chicken
  define_item COOKED_CHICKEN, "COOKED CHICKEN", Tex::COOKED_CHICKEN, food: 6, saturation: 7.2 # minecraft.wiki/w/Cooked_Chicken
  define_item FEATHER, "FEATHER", Tex::FEATHER
  define_item EGG, "EGG", Tex::EGG
  COUNT = NAMES.size

  def self.blocks_light(b) = b != AIR && b != GLASS && !door?(b) && BASE[b] != LADDER && !plant?(b)
  def self.solid?(b) = SOLID[b] == 1
  def self.plant?(b) = PLANT[b] == 1
  # A placed block takes the cell of grass, as in Minecraft.
  def self.replaceable?(b) = b == TALL_GRASS || b == DRY_GRASS
  def self.water?(b) = WATER_LEVEL[b] > 0
  def self.log?(b) = LOGS.include?(b)
  # Leaves of a tree or leaves that the player placed.
  def self.leaves?(b) = LEAVES.include?(BASE[b])
  def self.placed_leaves?(b) = PLACED_LEAVES.include?(b)
  def self.planks?(b) = PLANKS.include?(b)
  def self.sapling?(b) = SAPLINGS.include?(b)
  # The blocks that fill the recipe ingredient ing.
  def self.fillers(ing) = ing == ANY_PLANKS ? PLANKS : Array.new(1, ing.to_i)
  def self.ingredient_name(ing) = ing == ANY_PLANKS ? "PLANKS" : NAMES[ing]
  # The wood of a log, leaves, planks or sapling (Block::OAK_WOOD and so
  # on), or -1.
  def self.wood(b)
    LOGS.size.times { |w| return w if LOGS[w] == b || LEAVES[w] == BASE[b] || PLANKS[w] == b || SAPLINGS[w] == b }
    -1
  end
  # The boxes of SHAPE_BOX as #defines for the shaders: SHAPE_COUNT, and
  # SHAPE_BOXES, the boxes as an array of 6 numbers each.
  def self.shader_defines
    boxes = ""
    SHAPE_BOX.size.times do |i|
      boxes += i % 6 == 0 ? (i == 0 ? "{{" : "}, {") : ","
      boxes += SHAPE_BOX[i].to_s
    end
    "#define SHAPE_COUNT #{SHAPE_BOX.size / 6}\n#define SHAPE_BOXES #{boxes}}}\n"
  end
  # Things that live in the inventory but are never placed.
  def self.item?(b) = ITEM[b] == 1
  def self.bucket?(b) = b >= BUCKET && b <= LAVA_BUCKET
  def self.boat?(b) = b >= OAK_BOAT && b <= BIRCH_BOAT
  # The most of b that one slot holds. A boat, a bed and a full bucket do
  # not stack, and eggs and empty buckets stack to 16. minecraft.wiki/w/Boat,
  # /w/Bed, /w/Water_Bucket, /w/Lava_Bucket, /w/Milk_Bucket, /w/Egg and /w/Bucket
  def self.stack(b)
    return 1 if boat?(b) || b == BED || b == WATER_BUCKET || b == LAVA_BUCKET || b == MILK_BUCKET
    return 16 if b == EGG || b == BUCKET

    Slots::STACK
  end
  # Items, plants and the door, bed and ladder items are flat pictures; the
  # other blocks are cubes.
  def self.flat?(b) = item?(b) || plant?(b) || b == DOOR || b == BED || b == LADDER
  def self.door?(b) = b >= DOOR_BLOCK && b < DOOR_BLOCK + 16
  def self.door_open?(b) = door?(b) && b >= DOOR_BLOCK + 8
  def self.door_id(facing, upper, open) = DOOR_BLOCK + (open ? 8 : 0) + (upper ? 4 : 0) + facing
  # The same door half, opened or closed.
  def self.door_toggled(b) = door_open?(b) ? b - 8 : b + 8
  def self.torch?(b) = BASE[b] == TORCH
  def self.wall_torch?(b) = torch?(b) && FACING[b] >= 0
  def self.bed?(b) = b >= BED_BLOCK && b < BED_BLOCK + 8
  def self.bed_id(facing, head) = BED_BLOCK + (head ? 4 : 0) + facing
  def self.furnace_lit?(b) = b >= FURNACE_LIT && b < FURNACE_LIT + 4
  # The furnace that faces direction d, lit when it has heat.
  def self.furnace_id(d, lit) = lit ? FURNACE_LIT + d : facing_id(FURNACE, d)
  # The block of kind base that faces direction d; base when the kind has
  # no block for that direction. The first one wins, so a furnace is not lit.
  def self.facing_id(base, d)
    COUNT.times { |b| return b if BASE[b] == base && FACING[b] == d }
    base
  end
  # The box of a block in its cell: half its size on x and z around the
  # center, and its height. A plant is smaller than its cell, a torch is
  # thin, and a block with a shape has the box of SHAPE_BOX turned to its
  # facing.
  def self.box_half(b) = torch?(b) ? 0.1 : (plant?(b) ? 0.3 : 0.5)
  def self.box_hx(b) = SHAPE[b] > 0 ? shape_half(b, FACING[b] < 2 ? 0 : 2) : box_half(b)
  def self.box_hz(b) = SHAPE[b] > 0 ? shape_half(b, FACING[b] < 2 ? 2 : 0) : box_half(b)
  def self.box_top(b) = SHAPE[b] > 0 ? SHAPE_BOX[SHAPE[b] * 6 + 4] / 16.0 : (torch?(b) ? 0.6 : (plant?(b) ? 0.8 : 1.0))
  # Half the size of the box of shape SHAPE[b] on the axis a (0 x, 2 z) of
  # the block that faces +x, and the move of its center from the middle of
  # the cell.
  def self.shape_half(b, a) = (SHAPE_BOX[SHAPE[b] * 6 + 3 + a] - SHAPE_BOX[SHAPE[b] * 6 + a]) / 32.0
  def self.shape_mid(b, a) = (SHAPE_BOX[SHAPE[b] * 6 + 3 + a] + SHAPE_BOX[SHAPE[b] * 6 + a]) / 32.0 - 0.5
  # A wall torch leans out of its wall. This is how far the point at height
  # h of the torch moves toward the wall. vchunk in gfx.rb draws the same lean.
  def self.wall_lean(h) = 0.42 - 0.4 * h
  # The move of the box of b from the middle of its cell, and up from the
  # floor. A shape turns by a quarter turn for each step from +x to +z,
  # and so on: +x goes to the facing. A shape without a facing (a cactus)
  # sits in the middle of its cell.
  def self.box_dx(b)
    return -DIR_DX[FACING[b]] * wall_lean(0.3) if wall_torch?(b)
    return 0.0 if SHAPE[b] == 0 || FACING[b] < 0
    d = FACING[b]
    d < 2 ? DIR_DX[d] * shape_mid(b, 0) : -DIR_DZ[d] * shape_mid(b, 2)
  end
  def self.box_dz(b)
    return -DIR_DZ[FACING[b]] * wall_lean(0.3) if wall_torch?(b)
    return 0.0 if SHAPE[b] == 0 || FACING[b] < 0
    d = FACING[b]
    d < 2 ? DIR_DX[d] * shape_mid(b, 2) : DIR_DZ[d] * shape_mid(b, 0)
  end
  def self.box_dy(b) = wall_torch?(b) ? WALL_LIFT : 0.0
  # Hunger and saturation points that eating b gives back.
  def self.food(b) = FOOD[b]
  # The chance that eating b gives the Hunger effect.
  # minecraft.wiki/w/Rotten_Flesh and /w/Raw_Chicken
  def self.hunger_chance(b) = b == ROTTEN_FLESH ? 0.8 : (b == RAW_CHICKEN ? 0.3 : 0.0)
  def self.saturation(b) = SATURATION[b]
  # A crop that has not ripened yet.
  def self.growing?(b) = (b >= SEEDS && b < WHEAT_RIPE) || (b >= PUMPKIN_SEEDS && b < PUMPKIN_STEM_RIPE)
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
    return attack ? 0 : 1 if b == SHEARS
    return attack ? 2 : 1 if tool_kind(b) > 0
    0
  end
  # How fast shears dig b: 15 times on leaves and 5 times on wool. The wiki
  # gives 2 for some other blocks, but not which ones, so the others take
  # 1. minecraft.wiki/w/Shears
  def self.shear_speed(b) = leaves?(b) ? 15.0 : (b == WOOL ? 5.0 : 1.0)
  # What breaking b with shears gives: leaves and grass give themselves,
  # and the rest give what they give by hand. minecraft.wiki/w/Shears
  def self.shear_drop(b) = leaves?(b) ? BASE[b] : (replaceable?(b) ? b : DROPS[b])

  # Uses before a wooden, stone, iron or diamond tool breaks, and a bow.
  # minecraft.wiki/w/Item_durability
  TOOL_USES = [59, 131, 250, 1561]
  # The uses of a new tool b; 0 for what is not a tool. A tool never
  # stacks: the count of its stack is the uses that it has left.
  def self.uses(b)
    return TOOL_USES[tool_tier(b) - 1] if tool_tier(b) > 0
    return TOOL_USES[b - WOOD_SWORD] if sword?(b)
    # minecraft.wiki/w/Item_durability
    b == BOW ? 384 : (b == SHEARS ? 238 : 0)
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
  def self.jack_o_lantern?(b) = BASE[b] == JACK_O_LANTERN
  # A pumpkin, a carved pumpkin or a jack o'lantern.
  def self.pumpkin?(b) = b >= PUMPKIN && b < SHEARS
  # The plants that go only on soil: dirt, grass or snowy grass. In
  # Minecraft, seeds go only on farmland (minecraft.wiki/w/Pumpkin_Seeds and
  # /w/Wheat_Seeds). The game has no farmland, so dirt and grass take its
  # place. Saplings, flowers and short grass go on dirt and grass
  # (minecraft.wiki/w/Sapling, /w/Flower and /w/Short_Grass).
  SOIL_PLANTS = [PUMPKIN_SEEDS, SEEDS, OAK_SAPLING, SPRUCE_SAPLING, BIRCH_SAPLING, ROSE, DANDELION, TALL_GRASS]
  def self.soil?(b) = b == DIRT || b == GRASS || b == SNOW_GRASS
  # Torches, lava sources and jack o'lanterns light their surroundings.
  def self.emits?(b) = torch?(b) || b == LAVA || jack_o_lantern?(b)
end
