# Procedural 16x16 textures, all generated at start-up into one texture array.
module Tex
  WHITE = 0
  GRASS_TOP = 1
  GRASS_SIDE = 2
  DIRT = 3
  STONE = 4
  SAND = 5
  WATER = 6
  LOG_SIDE = 7
  LOG_TOP = 8
  LEAVES = 9
  PLANKS = 10
  COBBLE = 11
  GLASS = 12
  SNOW = 13
  SNOW_SIDE = 14
  BEDROCK = 15
  BRICK = 16
  COAL = 17
  IRON = 18
  GRAVEL = 19
  DIAMOND = 20
  CACTUS_SIDE = 21
  CACTUS_TOP = 22
  HEART = 23
  HEART_EMPTY = 24
  SKIN = 25
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
  SAPLING = 56
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
  FONT = 90
  CHARS = " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.:/-+%()!?,'<>=_"
  LAYERS = FONT + CHARS.size

  # How a layer's texture scrolls: 0 not at all, 1 like water, 2 like lava.
  # The mesher puts it in bits 23-24 of a face record for the shader.
  def self.scroll(layer) = layer == WATER ? 1 : (layer == LAVA ? 2 : 0)

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

  def self.noisy(px, layer, r, g, b, amount, salt)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = (rnd(x, y, salt) - 128) * amount / 128
        px[layer * 256 + y * 16 + x] = rgba(r + v, g + v, b + v, 255)
        x += 1
      end
      y += 1
    end
  end

  def self.set(px, layer, x, y, r, g, b, a)
    px[layer * 256 + y * 16 + x] = rgba(r, g, b, a)
  end

  # The layers that come from the images in assets/pixel-perfection, and the
  # name of each image, in the same order.
  IMAGE_LAYERS = [GRASS_TOP, GRASS_SIDE, DIRT, STONE, SAND, WATER, LOG_SIDE, LOG_TOP, LEAVES, PLANKS, COBBLE, GLASS,
                  SNOW, SNOW_SIDE, BEDROCK, BRICK, COAL, IRON, GRAVEL, DIAMOND, CACTUS_SIDE, CACTUS_TOP, TALL_GRASS,
                  ROSE, DANDELION, TORCH, PORKCHOP, WOOD_PICK, STONE_PICK, IRON_PICK, DIAMOND_PICK, BOW, ARROW, LAVA,
                  WOOL, FIRE, SAPLING, APPLE, WOOD_SWORD, STONE_SWORD, IRON_SWORD, DIAMOND_SWORD, IRON_INGOT, FURNACE,
                  COOKED_PORKCHOP, WOOD_AXE, STONE_AXE, IRON_AXE, DIAMOND_AXE, WOOD_SHOVEL, STONE_SHOVEL, IRON_SHOVEL,
                  DIAMOND_SHOVEL, SEEDS, WHEAT_1, WHEAT_2, WHEAT_RIPE, WHEAT, BREAD, CRAFT_TOP, CRAFT_SIDE, LADDER,
                  BUCKET, WATER_BUCKET, LAVA_BUCKET, FURNACE_SIDE, FURNACE_TOP,
                  DOOR_LOWER, DOOR_UPPER, DOOR_ITEM]
  IMAGE_FILES = %w[grass_top grass_side dirt stone sand water log_side log_top leaves planks cobble glass snow
                   snow_side bedrock brick coal iron gravel diamond cactus_side cactus_top tall_grass rose dandelion
                   torch porkchop wood_pick stone_pick iron_pick diamond_pick bow arrow lava wool fire sapling apple
                   wood_sword stone_sword iron_sword diamond_sword iron_ingot furnace cooked_porkchop wood_axe
                   stone_axe iron_axe diamond_axe wood_shovel stone_shovel iron_shovel diamond_shovel seeds wheat_1
                   wheat_2 wheat_ripe wheat bread craft_top craft_side ladder bucket water_bucket lava_bucket
                   furnace_side furnace_top door_lower door_upper door_item]

  def self.images(px)
    s = 0
    while s < IMAGE_LAYERS.size
      path = "assets/pixel-perfection/#{IMAGE_FILES[s]}.png"
      abort "#{path} did not load" unless Gfx.gfx_png(path)
      i = 0
      while i < 256
        px[IMAGE_LAYERS[s] * 256 + i] = Gfx.gfx_png_pixel(i)
        i += 1
      end
      s += 1
    end
  end

  def self.build
    px = Array.new(LAYERS * 256, 0)
    i = 0
    while i < 256
      px[i] = rgba(255, 255, 255, 255)
      i += 1
    end
    noisy(px, SKIN, 220, 220, 220, 25, 9)
    bed(px)
    chest(px)
    puff(px)
    rain(px)
    heart(px, HEART, 220, 30, 40)
    heart(px, HEART_EMPTY, 50, 20, 20)
    font(px)
    cracks(px)
    images(px)
    bleed(px, LEAVES)
    bleed(px, GLASS)
    bleed(px, TALL_GRASS)
    bleed(px, ROSE)
    bleed(px, DANDELION)
    bleed(px, FIRE)
    bleed(px, PUFF)
    bleed(px, RAIN)
    bleed(px, SAPLING)
    bleed(px, SEEDS)
    bleed(px, WHEAT_1)
    bleed(px, WHEAT_2)
    bleed(px, WHEAT_RIPE)
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


  # Chest: wood with a dark rim, and a band and a metal latch on the sides.
  def self.chest(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = rnd(x / 4, y, 91) / 12 + (rnd(x, y, 92) - 128) / 20
        edge = x == 0 || y == 0 || x == 15 || y == 15
        c = edge ? 85 : 150 + v
        set(px, CHEST_TOP, x, y, c, (c * 0.68).to_i, (c * 0.38).to_i, 255)
        band = y == 5 || y == 6
        side = edge || band ? 85 : 150 + v
        set(px, CHEST_SIDE, x, y, side, (side * 0.68).to_i, (side * 0.38).to_i, 255)
        x += 1
      end
      y += 1
    end
    set(px, CHEST_SIDE, 7, 6, 200, 200, 210, 255)
    set(px, CHEST_SIDE, 8, 6, 200, 200, 210, 255)
    set(px, CHEST_SIDE, 7, 7, 160, 160, 170, 255)
    set(px, CHEST_SIDE, 8, 7, 160, 160, 170, 255)
  end

  # Bed: a red blanket on top of the foot, a white pillow on top of the
  # head, and a wooden frame on the sides. The pillow sits in the middle,
  # so it looks right for each direction of the bed.
  def self.bed(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = (rnd(x, y, 81) - 128) / 12
        fold = y == 0 || y == 15 || x == 0 || x == 15 ? 25 : 0
        set(px, BED_TOP, x, y, 180 + v - fold, 35 + v, 40 + v, 255)
        if y > 2 && y < 13 && x > 2 && x < 13
          set(px, BED_HEAD_TOP, x, y, 235 + v, 235 + v, 230 + v, 255)
        else
          set(px, BED_HEAD_TOP, x, y, 180 + v - fold, 35 + v, 40 + v, 255)
        end
        if y < 6
          set(px, BED_SIDE, x, y, 180 + v, 35 + v, 40 + v, 255)
        elsif y < 11
          set(px, BED_SIDE, x, y, 160 + v, 120 + v, 75 + v, 255)
        else
          set(px, BED_SIDE, x, y, 0, 0, 0, (x < 3 || x > 12) ? 255 : 0)
          set(px, BED_SIDE, x, y, 120, 85, 50, 255) if x < 3 || x > 12
        end
        x += 1
      end
      y += 1
    end
  end























  HEART_ROWS = [
    "................", "................", "..####....####..", ".######..######.",
    "################", "################", "################", ".##############.",
    "..############..", "...##########...", "....########....", ".....######.....",
    "......####......", ".......##.......", "................", "................"
  ]

  def self.heart(px, layer, r, g, b)
    y = 0
    while y < 16
      row = HEART_ROWS[y]
      x = 0
      while x < 16
        if row[x] == "#"
          shine = y < 6 && x > 2 && x < 6 ? 60 : 0
          set(px, layer, x, y, r + shine, g + shine, b + shine, 255)
        end
        x += 1
      end
      y += 1
    end
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
