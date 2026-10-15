# Procedural 16x16 textures, all generated at start-up into one texture array.
module Tex
  WHITE = 0
  GRASS_TOP = 1
  GRASS_SIDE = 2
  DIRT = 3
  STONE = 4
  SAND = 5
  WATER = 6
  OAK_LOG_SIDE = 7
  OAK_LOG_TOP = 8
  OAK_LEAVES = 9
  OAK_PLANKS = 10
  COBBLE = 11
  GLASS = 12
  SNOW = 13
  SNOW_SIDE = 14
  BEDROCK = 15
  BRICK = 16
  COAL_ORE = 17
  IRON = 18
  GRAVEL = 19
  DIAMOND = 20
  CACTUS_SIDE = 21
  CACTUS_TOP = 22
  HEART = 23
  HEART_EMPTY = 24
  COAL = 25
  CRACK = 26
  CRACK_STAGES = 8
  TALL_GRASS = 34
  ROSE = 35
  DANDELION = 36
  TORCH = 37
  PORKCHOP = 38
  WOOD_PICK = 39
  STONE_PICK = 40
  IRON_PICK = 41
  DIAMOND_PICK = 42
  BOW = 43
  ARROW = 44
  LAVA = 45
  WOOL = 46
  BED_TOP = 47
  BED_SIDE = 48
  CHEST_TOP = 49
  CHEST_SIDE = 50
  # Flame tongues, and a round puff for smoke.
  FIRE = 51
  PUFF = 52
  # Streaks of rain on a clear background.
  RAIN = 53
  DOOR_LOWER = 54
  DOOR_UPPER = 55
  OAK_SAPLING = 56
  APPLE = 57
  WOOD_SWORD = 58
  STONE_SWORD = 59
  IRON_SWORD = 60
  DIAMOND_SWORD = 61
  IRON_INGOT = 62
  FURNACE = 63
  COOKED_PORKCHOP = 64
  WOOD_AXE = 65
  STONE_AXE = 66
  IRON_AXE = 67
  DIAMOND_AXE = 68
  WOOD_SHOVEL = 69
  STONE_SHOVEL = 70
  IRON_SHOVEL = 71
  DIAMOND_SHOVEL = 72
  SEEDS = 73
  WHEAT_1 = 74
  WHEAT_2 = 75
  WHEAT_RIPE = 76
  WHEAT = 77
  BREAD = 78
  CRAFT_TOP = 79
  CRAFT_SIDE = 80
  LADDER = 81
  # Nothing paints this layer, so it is fully transparent.
  CLEAR = 82
  BUCKET = 83
  WATER_BUCKET = 84
  LAVA_BUCKET = 85
  BED_HEAD_TOP = 86
  FURNACE_SIDE = 87
  FURNACE_TOP = 88
  DOOR_ITEM = 89
  CHEST_FRONT = 90
  BED_HEAD_SIDE = 91
  # The ends of a bed: the foot of the foot half, and the head of the head half.
  BED_FOOT_END = 92
  BED_HEAD_END = 93
  BED_ITEM = 94
  FURNACE_LIT = 95
  ROTTEN_FLESH = 96
  SPRUCE_LOG_SIDE = 97
  SPRUCE_LOG_TOP = 98
  SPRUCE_LEAVES = 99
  SPRUCE_PLANKS = 100
  SPRUCE_SAPLING = 101
  BIRCH_LOG_SIDE = 102
  BIRCH_LOG_TOP = 103
  BIRCH_LEAVES = 104
  BIRCH_PLANKS = 105
  BIRCH_SAPLING = 106
  # The moon in each phase: MOON + 0 is the full moon, in the order of
  # MOON_LIT.
  MOON = 107
  MUTTON = 115
  COOKED_MUTTON = 116
  # The full and the empty food icon of the HUD, and the full icon while
  # the Hunger effect lasts (see ICON_LAYERS).
  HUNGER = 117
  HUNGER_EMPTY = 118
  HUNGER_EFFECT = 119
  OAK_BOAT = 120
  SPRUCE_BOAT = 121
  BIRCH_BOAT = 122
  PUMPKIN_SIDE = 123
  PUMPKIN_TOP = 124
  # The carved face of a pumpkin, and of a jack o'lantern with its light.
  PUMPKIN_FACE = 125
  JACK_FACE = 126
  SHEARS = 127
  PUMPKIN_SEEDS = 128
  # A young stem is green, and a ripe stem yellow.
  PUMPKIN_STEM = 129
  PUMPKIN_STEM_RIPE = 130
  FONT = 131
  CHARS = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:/-+%()!?,'<>=_"
  LAYERS = FONT + CHARS.size

  # How a layer's texture scrolls: 0 not at all, 1 like water, 2 like lava.
  # The mesher puts it in bits 23-24 of a face record for the shader.
  def self.scroll(layer) = layer == WATER ? 1 : (layer == LAVA ? 2 : 0)

  # The biome color that a layer takes in the world: 0 none, 1 the grass
  # color, 2 the foliage color (Tint). The images have the plains colors,
  # so items show the plains colors. A pixel with alpha 254 keeps its
  # color: the dirt of GRASS_SIDE.
  def self.tint(layer)
    return 2 if layer == OAK_LEAVES
    layer == GRASS_TOP || layer == GRASS_SIDE || layer == TALL_GRASS ? 1 : 0
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
    "..# .#. #.. .#. ..#", "#.. .#. ..# .#. #..", "... ### ... ### ...", "... ... ... ... ###"
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

  # The layers that come from the images in assets/pixel-perfection, and the
  # name of each image, in the same order.
  IMAGE_LAYERS = [GRASS_TOP, GRASS_SIDE, DIRT, STONE, SAND, WATER, OAK_LOG_SIDE, OAK_LOG_TOP, OAK_LEAVES, OAK_PLANKS, COBBLE, GLASS,
                  SNOW, SNOW_SIDE, BEDROCK, BRICK, COAL_ORE, IRON, GRAVEL, DIAMOND, CACTUS_SIDE, CACTUS_TOP, TALL_GRASS,
                  ROSE, DANDELION, TORCH, PORKCHOP, WOOD_PICK, STONE_PICK, IRON_PICK, DIAMOND_PICK, BOW, ARROW, LAVA,
                  WOOL, FIRE, OAK_SAPLING, APPLE, WOOD_SWORD, STONE_SWORD, IRON_SWORD, DIAMOND_SWORD, IRON_INGOT, FURNACE,
                  COOKED_PORKCHOP, WOOD_AXE, STONE_AXE, IRON_AXE, DIAMOND_AXE, WOOD_SHOVEL, STONE_SHOVEL, IRON_SHOVEL,
                  DIAMOND_SHOVEL, SEEDS, WHEAT_1, WHEAT_2, WHEAT_RIPE, WHEAT, BREAD, CRAFT_TOP, CRAFT_SIDE, LADDER,
                  BUCKET, WATER_BUCKET, LAVA_BUCKET, FURNACE_SIDE, FURNACE_TOP,
                  DOOR_LOWER, DOOR_UPPER, DOOR_ITEM, CHEST_TOP, CHEST_SIDE, CHEST_FRONT, BED_TOP, BED_HEAD_TOP,
                  BED_SIDE, BED_HEAD_SIDE, BED_FOOT_END, BED_HEAD_END, BED_ITEM, FURNACE_LIT, ROTTEN_FLESH,
                  SPRUCE_LOG_SIDE, SPRUCE_LOG_TOP, SPRUCE_LEAVES, SPRUCE_PLANKS, SPRUCE_SAPLING, BIRCH_LOG_SIDE,
                  BIRCH_LOG_TOP, BIRCH_LEAVES, BIRCH_PLANKS, BIRCH_SAPLING, MOON, MOON + 1, MOON + 2, MOON + 3,
                  MOON + 4, MOON + 5, MOON + 6, MOON + 7, MUTTON, COOKED_MUTTON, COAL, OAK_BOAT, SPRUCE_BOAT,
                  BIRCH_BOAT, PUMPKIN_SIDE, PUMPKIN_TOP, PUMPKIN_FACE, JACK_FACE, SHEARS, PUMPKIN_SEEDS, PUMPKIN_STEM,
                  PUMPKIN_STEM_RIPE]
  IMAGE_FILES = %w[grass_top grass_side dirt stone sand water oak_log_side oak_log_top oak_leaves oak_planks cobble glass snow
                   snow_side bedrock brick coal_ore iron gravel diamond cactus_side cactus_top tall_grass rose dandelion
                   torch porkchop wood_pick stone_pick iron_pick diamond_pick bow arrow lava wool fire oak_sapling apple
                   wood_sword stone_sword iron_sword diamond_sword iron_ingot furnace cooked_porkchop wood_axe
                   stone_axe iron_axe diamond_axe wood_shovel stone_shovel iron_shovel diamond_shovel seeds wheat_1
                   wheat_2 wheat_ripe wheat bread craft_top craft_side ladder bucket water_bucket lava_bucket
                   furnace_side furnace_top door_lower door_upper door_item chest_top chest_side chest_front bed_top
                   bed_head_top bed_side bed_head_side bed_foot_end bed_head_end bed_item furnace_lit rotten_flesh
                   spruce_log_side spruce_log_top spruce_leaves spruce_planks spruce_sapling birch_log_side
                   birch_log_top birch_leaves birch_planks birch_sapling moon_0 moon_1 moon_2 moon_3 moon_4 moon_5
                   moon_6 moon_7 mutton cooked_mutton coal oak_boat spruce_boat birch_boat pumpkin_side pumpkin_top
                   pumpkin_face jack_face shears pumpkin_seeds pumpkin_stem pumpkin_stem_ripe]

  # The HUD icons are 9 x 9 images, as in Minecraft. Each one fills the top
  # left corner of its layer, so the HUD draws ICON_PART of the layer.
  ICON_LAYERS = [HUNGER, HUNGER_EMPTY, HUNGER_EFFECT, HEART, HEART_EMPTY]
  ICON_FILES = %w[hunger hunger_empty hunger_effect heart heart_empty]
  ICON_SIZE = 9
  ICON_PART = ICON_SIZE / 16.0

  def self.images(px)
    s = 0
    while s < IMAGE_LAYERS.size
      path = "assets/pixel-perfection/#{IMAGE_FILES[s]}.png"
      abort "#{path} did not load" unless Gfx.gfx_png(path, 16, 16)
      i = 0
      while i < 256
        px[IMAGE_LAYERS[s] * 256 + i] = Gfx.gfx_png_pixel(i)
        i += 1
      end
      s += 1
    end
    s = 0
    while s < ICON_LAYERS.size
      path = "assets/pixel-perfection/#{ICON_FILES[s]}.png"
      abort "#{path} did not load" unless Gfx.gfx_png(path, ICON_SIZE, ICON_SIZE)
      i = 0
      while i < ICON_SIZE * ICON_SIZE
        px[ICON_LAYERS[s] * 256 + i / ICON_SIZE * 16 + i % ICON_SIZE] = Gfx.gfx_png_pixel(i)
        i += 1
      end
      s += 1
    end
  end

  # The mob skins: a second texture array of 64 x 64 layers. A dynamic
  # vertex with layer SKINS + k takes layer k of it (fdyn in gfx.rb). Layer k
  # is the skin of the mob kind k (Mob::PIG and the others). Then come the
  # fur of a sheep and the skin of the player, whose arm the view shows. A
  # skin of 64 x 32 fills the top half of its layer.
  SKINS = 256
  SKIN_FUR = 5
  SKIN_PLAYER = 6
  SKIN_FILES = %w[skin_pig skin_zombie skin_skeleton skin_sheep skin_creeper skin_sheep_fur skin_player]
  SKIN_HEIGHTS = [32, 64, 32, 32, 32, 32, 32]

  def self.skins
    px = Array.new(SKIN_FILES.size * 4096, 0)
    s = 0
    while s < SKIN_FILES.size
      path = "assets/pixel-perfection/#{SKIN_FILES[s]}.png"
      abort "#{path} did not load" unless Gfx.gfx_png(path, 64, SKIN_HEIGHTS[s])
      i = 0
      while i < 64 * SKIN_HEIGHTS[s]
        px[s * 4096 + i] = Gfx.gfx_png_pixel(i)
        i += 1
      end
      s += 1
    end
    px
  end

  def self.build
    px = Array.new(LAYERS * 256, 0)
    i = 0
    while i < 256
      px[i] = rgba(255, 255, 255, 255)
      i += 1
    end
    puff(px)
    rain(px)
    font(px)
    cracks(px)
    images(px)
    bleed(px, OAK_LEAVES)
    bleed(px, SPRUCE_LEAVES)
    bleed(px, BIRCH_LEAVES)
    bleed(px, GLASS)
    bleed(px, TALL_GRASS)
    bleed(px, ROSE)
    bleed(px, DANDELION)
    bleed(px, FIRE)
    bleed(px, PUFF)
    bleed(px, RAIN)
    bleed(px, OAK_SAPLING)
    bleed(px, SPRUCE_SAPLING)
    bleed(px, BIRCH_SAPLING)
    bleed(px, SEEDS)
    bleed(px, WHEAT_1)
    bleed(px, WHEAT_2)
    bleed(px, WHEAT_RIPE)
    bleed(px, PUMPKIN_STEM)
    bleed(px, PUMPKIN_STEM_RIPE)
    bleed(px, CHEST_TOP)
    bleed(px, CHEST_SIDE)
    bleed(px, CHEST_FRONT)
    bleed(px, BED_SIDE)
    bleed(px, BED_HEAD_SIDE)
    bleed(px, BED_FOOT_END)
    bleed(px, BED_HEAD_END)
    px
  end


  # A few streaks in each column of pixels that has rain.
  def self.rain(px)
    x = 1
    while x < 16
      start = rnd(x, 0, 85) % 16
      len = 3 + rnd(x, 1, 86) % 4
      k = 0
      while k < len
        set(px, RAIN, x, (start + k) % 16, 255, 255, 255, 200)
        k += 1
      end
      x += 3 + rnd(x, 2, 87) % 2
    end
  end

  # A white disk with a rough edge.
  def self.puff(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        dx = x - 7.5
        dy = y - 7.5
        r = 6.0 + rnd(x, y, 83) / 128.0
        v = 225 + rnd(x, y, 84) / 9
        set(px, PUFF, x, y, v, v, v, 255) if dx * dx + dy * dy < r * r
        x += 1
      end
      y += 1
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
    line = 0
    while line < 8
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
      line += 1
    end
    s = 0
    while s < CRACK_STAGES
      i = 0
      while i < 256
        px[(CRACK + s) * 256 + i] = reveal[i] <= s ? rgba(20, 16, 12, 215) : 0
        i += 1
      end
      s += 1
    end
  end

  # Gives clear texels the layer's average opaque color so mipmaps do not darken.
  def self.bleed(px, layer)
    r = 0
    g = 0
    b = 0
    n = 0
    i = 0
    while i < 256
      c = px[layer * 256 + i]
      if (c >> 24) & 255 > 0
        r += c & 255
        g += (c >> 8) & 255
        b += (c >> 16) & 255
        n += 1
      end
      i += 1
    end
    return if n == 0
    i = 0
    while i < 256
      px[layer * 256 + i] = rgba(r / n, g / n, b / n, 0) if (px[layer * 256 + i] >> 24) & 255 == 0
      i += 1
    end
  end

  # The opaque pixels of each layer as bit masks, for the edges of an item
  # (see Mesh3#item_edges). At layer * 32 + y is the row y, with bit x for
  # the pixel x. At layer * 32 + 16 + x is the column x, with bit y for the
  # pixel y. A pixel is opaque where fdyn in gfx.rb draws it.
  def self.opaque(px)
    masks = Array.new(LAYERS * 32, 0)
    i = 0
    while i < LAYERS * 256
      if (px[i] >> 24) & 255 >= 128
        k = i / 256 * 32
        x = i % 16
        y = i / 16 % 16
        masks[k + y] = masks[k + y] | (1 << x)
        masks[k + 16 + x] = masks[k + 16 + x] | (1 << y)
      end
      i += 1
    end
    masks
  end

  # Each glyph is 3 x 5 cells of 3 x 3 pixels, so it fills a 9 x 15 corner of its layer.
  def self.font(px)
    g = 0
    while g < GLYPHS.size
      rows = GLYPHS[g].split(" ")
      layer = FONT + g
      ry = 0
      while ry < 5
        rx = 0
        while rx < 3
          if rows[ry][rx] == "#"
            y = ry * 3
            while y < ry * 3 + 3
              x = rx * 3
              while x < rx * 3 + 3
                set(px, layer, x, y, 255, 255, 255, 255)
                x += 1
              end
              y += 1
            end
          end
          rx += 1
        end
        ry += 1
      end
      g += 1
    end
  end

  def self.glyph(ch)
    i = CHARS.index(ch)
    i.nil? ? FONT : FONT + i
  end
end
