# The 16x16 textures, all loaded or drawn at start-up into one texture array.
module Tex
  # The image in assets/pixel-perfection of each layer, or "" for a layer
  # that the code draws. Each layer below takes the next free number.
  LAYER_FILES = []
  # 1 for a layer with clear pixels: Tex.bleed gives them a color.
  BLEED = []
  # The HUD icons (see ICON_SIZE), and the image of each.
  ICON_LAYERS = []
  ICON_FILES = []

  def self.add_layer(file, bleed)
    LAYER_FILES << file
    BLEED << bleed
    LAYER_FILES.size - 1
  end

  # A layer from an image; it gives the number of the layer.
  def self.image(file, bleed: 0) = add_layer(file, bleed)

  # A layer from each image, in a row; it gives the number of the first.
  def self.image_series(files)
    first = LAYER_FILES.size
    files.each { |file| add_layer(file, 0) }
    first
  end

  # n layers that the code draws; it gives the number of the first.
  def self.drawn(n, bleed: 0)
    first = LAYER_FILES.size
    n.times { add_layer("", bleed) }
    first
  end

  # A HUD icon from an image (see ICON_SIZE).
  def self.hud_icon(file)
    ICON_LAYERS << LAYER_FILES.size
    ICON_FILES << file
    add_layer("", 0)
  end

  WHITE = drawn(1)
  GRASS_TOP = image("grass_top")
  GRASS_SIDE = image("grass_side")
  DIRT = image("dirt")
  STONE = image("stone")
  SAND = image("sand")
  WATER = image("water")
  OAK_LOG_SIDE = image("oak_log_side")
  OAK_LOG_TOP = image("oak_log_top")
  OAK_LEAVES = image("oak_leaves", bleed: 1)
  OAK_PLANKS = image("oak_planks")
  COBBLE = image("cobble")
  GLASS = image("glass", bleed: 1)
  SNOW = image("snow")
  SNOW_SIDE = image("snow_side")
  BEDROCK = image("bedrock")
  BRICK = image("brick")
  COAL_ORE = image("coal_ore")
  IRON = image("iron")
  GRAVEL = image("gravel")
  DIAMOND = image("diamond")
  CACTUS_SIDE = image("cactus_side")
  CACTUS_TOP = image("cactus_top")
  HEART = hud_icon("heart")
  HEART_EMPTY = hud_icon("heart_empty")
  COAL = image("coal")
  CRACK_STAGES = 8
  CRACK = drawn(CRACK_STAGES)
  TALL_GRASS = image("tall_grass", bleed: 1)
  ROSE = image("rose", bleed: 1)
  DANDELION = image("dandelion", bleed: 1)
  TORCH = image("torch")
  PORKCHOP = image("porkchop")
  WOOD_PICK = image("wood_pick")
  STONE_PICK = image("stone_pick")
  IRON_PICK = image("iron_pick")
  DIAMOND_PICK = image("diamond_pick")
  BOW = image("bow")
  # The bow at three stages of the draw (see Game#draw_hand).
  BOW_PULLING = image_series(%w[bow_pulling_0 bow_pulling_1 bow_pulling_2])
  ARROW = image("arrow")
  LAVA = image("lava")
  WOOL = image("wool")
  BED_TOP = image("bed_top")
  BED_SIDE = image("bed_side", bleed: 1)
  CHEST_TOP = image("chest_top", bleed: 1)
  CHEST_SIDE = image("chest_side", bleed: 1)
  # Flame tongues, and a round puff for smoke.
  FIRE = image("fire", bleed: 1)
  PUFF = drawn(1, bleed: 1)
  # Streaks of rain on a clear background.
  RAIN = drawn(1, bleed: 1)
  DOOR_LOWER = image("door_lower")
  DOOR_UPPER = image("door_upper")
  OAK_SAPLING = image("oak_sapling", bleed: 1)
  APPLE = image("apple")
  WOOD_SWORD = image("wood_sword")
  STONE_SWORD = image("stone_sword")
  IRON_SWORD = image("iron_sword")
  DIAMOND_SWORD = image("diamond_sword")
  IRON_INGOT = image("iron_ingot")
  FURNACE = image("furnace")
  COOKED_PORKCHOP = image("cooked_porkchop")
  WOOD_AXE = image("wood_axe")
  STONE_AXE = image("stone_axe")
  IRON_AXE = image("iron_axe")
  DIAMOND_AXE = image("diamond_axe")
  WOOD_SHOVEL = image("wood_shovel")
  STONE_SHOVEL = image("stone_shovel")
  IRON_SHOVEL = image("iron_shovel")
  DIAMOND_SHOVEL = image("diamond_shovel")
  SEEDS = image("seeds", bleed: 1)
  WHEAT_1 = image("wheat_1", bleed: 1)
  WHEAT_2 = image("wheat_2", bleed: 1)
  WHEAT_RIPE = image("wheat_ripe", bleed: 1)
  WHEAT = image("wheat")
  BREAD = image("bread")
  CRAFT_TOP = image("craft_top")
  CRAFT_SIDE = image("craft_side")
  LADDER = image("ladder")
  # Nothing paints this layer, so it is fully transparent.
  CLEAR = drawn(1)
  BUCKET = image("bucket")
  WATER_BUCKET = image("water_bucket")
  LAVA_BUCKET = image("lava_bucket")
  BED_HEAD_TOP = image("bed_head_top")
  FURNACE_SIDE = image("furnace_side")
  FURNACE_TOP = image("furnace_top")
  DOOR_ITEM = image("door_item")
  CHEST_FRONT = image("chest_front", bleed: 1)
  # The halves of a large chest.
  CHEST_LEFT_FRONT = image("chest_left_front", bleed: 1)
  CHEST_RIGHT_FRONT = image("chest_right_front", bleed: 1)
  CHEST_LEFT_TOP = image("chest_left_top", bleed: 1)
  CHEST_RIGHT_TOP = image("chest_right_top", bleed: 1)
  BED_HEAD_SIDE = image("bed_head_side", bleed: 1)
  # The ends of a bed: the foot of the foot half, and the head of the head half.
  BED_FOOT_END = image("bed_foot_end", bleed: 1)
  BED_HEAD_END = image("bed_head_end", bleed: 1)
  BED_ITEM = image("bed_item")
  FURNACE_LIT = image("furnace_lit")
  ROTTEN_FLESH = image("rotten_flesh")
  SPRUCE_LOG_SIDE = image("spruce_log_side")
  SPRUCE_LOG_TOP = image("spruce_log_top")
  SPRUCE_LEAVES = image("spruce_leaves", bleed: 1)
  SPRUCE_PLANKS = image("spruce_planks")
  SPRUCE_SAPLING = image("spruce_sapling", bleed: 1)
  BIRCH_LOG_SIDE = image("birch_log_side")
  BIRCH_LOG_TOP = image("birch_log_top")
  BIRCH_LEAVES = image("birch_leaves", bleed: 1)
  BIRCH_PLANKS = image("birch_planks")
  BIRCH_SAPLING = image("birch_sapling", bleed: 1)
  # The moon in each phase: MOON + 0 is the full moon, in the order of
  # Clock::MOON_LIT.
  MOON = image_series(%w[moon_0 moon_1 moon_2 moon_3 moon_4 moon_5 moon_6 moon_7])
  MUTTON = image("mutton")
  COOKED_MUTTON = image("cooked_mutton")
  # The full and the empty food icon of the HUD, and the full icon while
  # the Hunger effect lasts (see ICON_LAYERS).
  HUNGER = hud_icon("hunger")
  HUNGER_EMPTY = hud_icon("hunger_empty")
  HUNGER_EFFECT = hud_icon("hunger_effect")
  OAK_BOAT = image("oak_boat")
  SPRUCE_BOAT = image("spruce_boat")
  BIRCH_BOAT = image("birch_boat")
  PUMPKIN_SIDE = image("pumpkin_side")
  PUMPKIN_TOP = image("pumpkin_top")
  # The carved face of a pumpkin, and of a jack o'lantern with its light.
  PUMPKIN_FACE = image("pumpkin_face")
  JACK_FACE = image("jack_face")
  SHEARS = image("shears")
  PUMPKIN_SEEDS = image("pumpkin_seeds")
  PUMPKIN_PIE = image("pumpkin_pie")
  # A young stem is green, and a ripe stem yellow.
  PUMPKIN_STEM = image("pumpkin_stem", bleed: 1)
  PUMPKIN_STEM_RIPE = image("pumpkin_stem_ripe", bleed: 1)
  BONE = image("bone")
  BONE_MEAL = image("bone_meal")
  SANDSTONE_SIDE = image("sandstone_side")
  SANDSTONE_TOP = image("sandstone_top")
  SANDSTONE_BOTTOM = image("sandstone_bottom")
  DRY_GRASS = image("dry_grass", bleed: 1)
  BEEF = image("beef")
  STEAK = image("steak")
  LEATHER = image("leather")
  MILK_BUCKET = image("milk_bucket")
  RAW_CHICKEN = image("raw_chicken")
  COOKED_CHICKEN = image("cooked_chicken")
  FEATHER = image("feather")
  EGG = image("egg")
  SPINEL_ORE = image("spinel_ore")
  SPINEL = image("spinel")
  SPINEL_MATTOCK = image("spinel_mattock")
  # The armor pieces, in the order of the Block ids from IRON_HELMET.
  IRON_HELMET = image("iron_helmet")
  IRON_CHESTPLATE = image("iron_chestplate")
  IRON_LEGGINGS = image("iron_leggings")
  IRON_BOOTS = image("iron_boots")
  DIAMOND_HELMET = image("diamond_helmet")
  DIAMOND_CHESTPLATE = image("diamond_chestplate")
  DIAMOND_LEGGINGS = image("diamond_leggings")
  DIAMOND_BOOTS = image("diamond_boots")
  ARMOR = hud_icon("armor")
  ARMOR_EMPTY = hud_icon("armor_empty")
  # The red blocks of SPINEL in the title (tools/logo.rb).
  SPINEL_BLOCK = image("spinel_block")
  # The leaves with no clear pixel, for FAST graphics (Tex.solid_leaves).
  OAK_LEAVES_SOLID = drawn(1)
  SPRUCE_LEAVES_SOLID = drawn(1)
  BIRCH_LEAVES_SOLID = drawn(1)
  CHARS = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:/-+%()!?,'<>=_~@[]#*;\"|"
  FONT = drawn(CHARS.size)
  LAYERS = LAYER_FILES.size

  # How a layer's texture scrolls: 0 not at all, 1 like water, 2 like lava.
  # The mesher puts it in bits 23-24 of a face record for the shader.
  def self.scroll(layer) = layer == WATER ? 1 : (layer == LAVA ? 2 : 0)

  # The biome color that a layer takes in the world: 0 none, 1 the grass
  # color, 2 the foliage color (Tint). The images have the plains colors,
  # so items show the plains colors. A pixel with alpha 254 keeps its
  # color: the dirt of GRASS_SIDE.
  def self.tint(layer)
    return 2 if layer == OAK_LEAVES || layer == OAK_LEAVES_SOLID

    layer == GRASS_TOP || layer == GRASS_SIDE || layer == TALL_GRASS ? 1 : 0
  end

  # The layer that FAST graphics draws in place of a layer of leaves.
  def self.solid(layer)
    return OAK_LEAVES_SOLID if layer == OAK_LEAVES
    return SPRUCE_LEAVES_SOLID if layer == SPRUCE_LEAVES
    return BIRCH_LEAVES_SOLID if layer == BIRCH_LEAVES

    layer
  end

  GLYPHS = [
    "... ... ... ... ...",
    "### #.# #.# #.# ###", ".#. ##. .#. .#. ###", "### ..# ### #.. ###", "### ..# ### ..# ###",
    "#.# #.# ### ..# ..#", "### #.. ### ..# ###", "### #.. ### #.# ###", "### ..# ..# .#. .#.",
    "### #.# ### #.# ###", "### #.# ### ..# ###",
    ".#. #.# ### #.# #.#", "##. #.# ##. #.# ##.", ".## #.. #.. #.. .##", "##. #.# #.# #.# ##.",
    "### #.. ##. #.. ###", "### #.. ##. #.. #..", ".## #.. #.# #.# .##", "#.# #.# ### #.# #.#",
    "### .#. .#. .#. ###", "..# ..# ..# #.# .#.", "#.# #.# ##. #.# #.#", "#.. #.. #.. #.. ###",
    "#.# ### ### #.# #.#", "##. #.# #.# #.# #.#", ".#. #.# #.# #.# .#.", "##. #.# ##. #.. #..",
    ".#. #.# #.# ##. .##", "##. #.# ##. #.# #.#", ".## #.. .#. ..# ##.", "### .#. .#. .#. .#.",
    "#.# #.# #.# #.# ###", "#.# #.# #.# #.# .#.", "#.# #.# ### ### #.#", "#.# #.# .#. #.# #.#",
    "#.# #.# .#. .#. .#.", "### ..# .#. #.. ###",
    "... ... ... ... .#.", "... .#. ... .#. ...", "..# ..# .#. #.. #..", "... ... ### ... ...",
    "... .#. ### .#. ...", "#.# ..# .#. #.. #.#", "..# .#. .#. .#. ..#", "#.. .#. .#. .#. #..",
    ".#. .#. .#. ... .#.", "##. ..# .#. ... .#.", "... ... ... .#. #..", ".#. .#. ... ... ...",
    "..# .#. #.. .#. ..#", "#.. .#. ..# .#. #..", "... ### ... ### ...", "... ... ... ... ###",
    "... ##. .## ... ...", ".#. #.# ### #.. .##", "##. #.. #.. #.. ##.", ".## ..# ..# ..# .##",
    "#.# ### #.# ### #.#", "... #.# .#. #.# ...", "... .#. ... .#. #..", "#.# #.# ... ... ...",
    ".#. .#. .#. .#. .#."
  ]

  def self.rgba(r, g, b, a)
    r.clamp(0, 255) | (g.clamp(0, 255) << 8) | (b.clamp(0, 255) << 16) | (a.clamp(0, 255) << 24)
  end

  def self.rnd(x, y, salt)
    h = (x * 374761393 + y * 668265263 + salt * 2246822519) & 0xffffffff
    h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
    (h ^ (h >> 16)) & 255
  end

  def self.set(px, layer, x, y, r, g, b, a)
    px[layer * 256 + y * 16 + x] = rgba(r, g, b, a)
  end

  # The HUD icons are 9 x 9 images, as in Minecraft. Each one fills the top
  # left corner of its layer, so the HUD draws ICON_PART of the layer.
  ICON_SIZE = 9
  ICON_PART = ICON_SIZE / 16.0

  def self.images(px)
    s = 0
    while s < LAYER_FILES.size
      if LAYER_FILES[s] != ""
        path = "assets/pixel-perfection/#{LAYER_FILES[s]}.png"
        abort "#{path} did not load" unless Gfx.gfx_png(path, 16, 16)
        256.times { |i| px[s * 256 + i] = Gfx.gfx_png_pixel(i) }
      end
      s += 1
    end
    ICON_LAYERS.size.times do |s|
      path = "assets/pixel-perfection/#{ICON_FILES[s]}.png"
      abort "#{path} did not load" unless Gfx.gfx_png(path, ICON_SIZE, ICON_SIZE)
      (ICON_SIZE * ICON_SIZE).times do |i|
        px[ICON_LAYERS[s] * 256 + i / ICON_SIZE * 16 + i % ICON_SIZE] = Gfx.gfx_png_pixel(i)
      end
    end
  end

  # The mob skins: a second texture array of 64 x 64 layers. A dynamic
  # vertex with layer SKINS + k takes layer k of it (fdyn in gfx.rb). Layer k
  # is the skin of the mob kind k (Mob::PIG and the others). Then come the
  # fur of a sheep and the skin of the player, whose arm the view shows. A
  # skin of 64 x 32 fills the top half of its layer.
  SKINS = 256
  SKIN_FUR = 7
  SKIN_PLAYER = 8
  SKIN_FILES = %w[skin_pig skin_zombie skin_skeleton skin_sheep skin_creeper skin_cow skin_chicken skin_sheep_fur skin_player]
  SKIN_HEIGHTS = [32, 64, 32, 32, 32, 32, 32, 32, 32]

  def self.skins
    px = Array.new(SKIN_FILES.size * 4096, 0)
    SKIN_FILES.size.times do |s|
      path = "assets/pixel-perfection/#{SKIN_FILES[s]}.png"
      abort "#{path} did not load" unless Gfx.gfx_png(path, 64, SKIN_HEIGHTS[s])
      (64 * SKIN_HEIGHTS[s]).times { |i| px[s * 4096 + i] = Gfx.gfx_png_pixel(i) }
    end
    px
  end

  def self.build
    px = Array.new(LAYERS * 256, 0)
    256.times { |i| px[i] = rgba(255, 255, 255, 255) }
    puff(px)
    rain(px)
    font(px)
    cracks(px)
    images(px)
    LAYERS.times { |layer| bleed(px, layer) if BLEED[layer] == 1 }
    solid_leaves(px)
    px
  end

  # The share of the color of a clear pixel of leaves that its solid layer
  # keeps: the dark of the leaves behind the first ones.
  SOLID_SHADE_PERCENT = 55

  # Fills the solid layer of each layer of leaves: the opaque pixels stay,
  # and each clear pixel takes the color that bleed gave it, darker. It runs
  # after bleed.
  def self.solid_leaves(px)
    [OAK_LEAVES, SPRUCE_LEAVES, BIRCH_LEAVES].each do |layer|
      solid = Tex.solid(layer)
      256.times do |pixel|
        color = px[layer * 256 + pixel]
        shade = (color >> 24) & 255 >= 128 ? 100 : SOLID_SHADE_PERCENT
        px[solid * 256 + pixel] = rgba((color & 255) * shade / 100, ((color >> 8) & 255) * shade / 100, ((color >> 16) & 255) * shade / 100, 255)
      end
    end
  end


  # A few streaks in each column of pixels that has rain.
  def self.rain(px)
    x = 1
    while x < 16
      start = rnd(x, 0, 85) % 16
      len = 3 + rnd(x, 1, 86) % 4
      len.times { |k| set(px, RAIN, x, (start + k) % 16, 255, 255, 255, 200) }
      x += 3 + rnd(x, 2, 87) % 2
    end
  end

  # A white disk with a rough edge.
  def self.puff(px)
    16.times do |y|
      16.times do |x|
        dx = x - 7.5
        dy = y - 7.5
        r = 6.0 + rnd(x, y, 83) / 128.0
        v = 225 + rnd(x, y, 84) / 9
        set(px, PUFF, x, y, v, v, v, 255) if dx * dx + dy * dy < r * r
      end
    end
  end

  # Mining cracks, one layer per stage. Each stage keeps the cracks of the
  # stages before it and grows them out from the middle of the face.
  def self.cracks(px)
    reveal = Array.new(256, CRACK_STAGES)
    dx = [1, 1, 0, -1, -1, -1, 0, 1]
    dy = [0, 1, 1, 1, 0, -1, -1, -1]
    ox = [3, 12, 4, 11]
    oy = [4, 3, 12, 11]
    8.times do |line|
      # Four cracks start at the middle; four shorter ones start later, nearer the edges.
      x = line < 4 ? 7 + line % 2 : ox[line - 4]
      y = line < 4 ? 7 + line / 2 % 2 : oy[line - 4]
      dir = line < 4 ? line * 2 + 1 : (line * 2) % 8
      start = line < 4 ? 0 : line - 1
      step = 0
      while x >= 0 && x < 16 && y >= 0 && y < 16 && (line < 4 || step < 6)
        stage = start + step / 2
        reveal[y * 16 + x] = stage if stage < reveal[y * 16 + x]
        turn = rnd(line, step, 61)
        dir = (dir + 7) % 8 if turn < 40
        dir = (dir + 1) % 8 if turn > 215
        x += dx[dir]
        y += dy[dir]
        step += 1
      end
    end
    CRACK_STAGES.times { |s| 256.times { |i| px[(CRACK + s) * 256 + i] = reveal[i] <= s ? rgba(20, 16, 12, 215) : 0 } }
  end

  # Gives clear texels the layer's average opaque color so mipmaps do not darken.
  def self.bleed(px, layer)
    r = 0
    g = 0
    b = 0
    n = 0
    256.times do |i|
      c = px[layer * 256 + i]
      if (c >> 24) & 255 > 0
        r += c & 255
        g += (c >> 8) & 255
        b += (c >> 16) & 255
        n += 1
      end
    end
    return if n == 0

    256.times { |i| px[layer * 256 + i] = rgba(r / n, g / n, b / n, 0) if (px[layer * 256 + i] >> 24) & 255 == 0 }
  end

  # The opaque pixels of each layer as bit masks, for the edges of an item
  # (see Mesh3#item_edges). At layer * 32 + y is the row y, with bit x for
  # the pixel x. At layer * 32 + 16 + x is the column x, with bit y for the
  # pixel y. A pixel is opaque where fdyn in gfx.rb draws it.
  def self.opaque(px)
    masks = Array.new(LAYERS * 32, 0)
    (LAYERS * 256).times do |i|
      if (px[i] >> 24) & 255 >= 128
        k = i / 256 * 32
        x = i % 16
        y = i / 16 % 16
        masks[k + y] = masks[k + y] | (1 << x)
        masks[k + 16 + x] = masks[k + 16 + x] | (1 << y)
      end
    end
    masks
  end

  # Each glyph is 3 x 5 cells of 3 x 3 pixels, so it fills a 9 x 15 corner of its layer.
  def self.font(px)
    GLYPHS.each_with_index do |glyph, g|
      rows = glyph.split(" ")
      layer = FONT + g
      5.times do |ry|
        3.times do |rx|
          if rows[ry][rx] == "#"
            (ry * 3...ry * 3 + 3).each do |y|
              (rx * 3...rx * 3 + 3).each { |x| set(px, layer, x, y, 255, 255, 255, 255) }
            end
          end
        end
      end
    end
  end

  def self.glyph(ch)
    i = CHARS.index(ch)
    i.nil? ? FONT : FONT + i
  end
end
