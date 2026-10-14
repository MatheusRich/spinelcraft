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
  DOOR = 54
  DOOR_OPEN = 55
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
  FONT = 83
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

  def self.ore(px, layer, r, g, b, salt)
    noisy(px, layer, 125, 125, 125, 18, 4)
    y = 0
    while y < 16
      x = 0
      while x < 16
        if rnd(x / 3, y / 3, salt) < 70 && rnd(x, y, salt + 1) < 170
          v = rnd(x, y, salt + 2) / 6
          set(px, layer, x, y, r + v, g + v, b + v, 255)
        end
        x += 1
      end
      y += 1
    end
  end

  def self.build
    px = Array.new(LAYERS * 256, 0)
    i = 0
    while i < 256
      px[i] = rgba(255, 255, 255, 255)
      i += 1
    end
    noisy(px, GRASS_TOP, 95, 160, 60, 22, 1)
    noisy(px, DIRT, 134, 96, 67, 20, 2)
    noisy(px, STONE, 125, 125, 125, 18, 4)
    noisy(px, SAND, 219, 206, 160, 12, 5)
    noisy(px, SNOW, 240, 245, 250, 6, 6)
    noisy(px, GRAVEL, 130, 122, 118, 40, 7)
    noisy(px, BEDROCK, 70, 70, 70, 60, 8)
    noisy(px, SKIN, 220, 220, 220, 25, 9)
    y = 0
    while y < 16
      x = 0
      while x < 16
        # grass side: dirt with a ragged grass lip
        lip = 3 + rnd(x, 0, 11) % 3
        if y < lip
          v = (rnd(x, y, 12) - 128) * 22 / 128
          set(px, GRASS_SIDE, x, y, 95 + v, 160 + v, 60 + v, 255)
        else
          v = (rnd(x, y, 13) - 128) * 20 / 128
          set(px, GRASS_SIDE, x, y, 134 + v, 96 + v, 67 + v, 255)
        end
        slip = 3 + rnd(x, 0, 14) % 3
        if y < slip
          set(px, SNOW_SIDE, x, y, 240, 245, 250, 255)
        else
          v = (rnd(x, y, 15) - 128) * 20 / 128
          set(px, SNOW_SIDE, x, y, 134 + v, 96 + v, 67 + v, 255)
        end
        # water: soft blue, translucent
        v = rnd(x / 2 + y, y, 16) / 12
        set(px, WATER, x, y, 40 + v, 90 + v, 200, 170)
        # log side: vertical bark stripes
        v = rnd(x, y / 4, 17) / 8 + (x % 4 == 0 ? -18 : 0)
        set(px, LOG_SIDE, x, y, 105 + v, 80 + v, 50 + v, 255)
        # log top: rings
        dx = x - 7.5
        dy = y - 7.5
        ring = Math.sqrt(dx * dx + dy * dy).to_i
        edge = x == 0 || y == 0 || x == 15 || y == 15
        if edge
          set(px, LOG_TOP, x, y, 105, 80, 50, 255)
        elsif ring % 3 == 0
          set(px, LOG_TOP, x, y, 160, 130, 80, 255)
        else
          set(px, LOG_TOP, x, y, 185, 152, 98, 255)
        end
        # leaves: holes let the sky through
        if rnd(x, y, 18) < 60
          set(px, LEAVES, x, y, 0, 0, 0, 0)
        else
          v = (rnd(x, y, 19) - 128) * 40 / 128
          set(px, LEAVES, x, y, 55 + v, 125 + v, 40 + v, 255)
        end
        # planks: four boards with seams
        v = rnd(x / 8 + y / 4 * 3, y / 4, 20) / 10 + (rnd(x, y, 21) - 128) / 24
        if y % 4 == 3 || (x == (y / 4 % 2 == 0 ? 4 : 11))
          set(px, PLANKS, x, y, 120, 92, 56, 255)
        else
          set(px, PLANKS, x, y, 168 + v, 132 + v, 82 + v, 255)
        end
        # cobble: stone lumps with dark mortar
        cell = rnd(x / 4 + (y / 4 % 2) * 7, y / 4, 22)
        if x % 4 == 0 || y % 4 == 0
          set(px, COBBLE, x, y, 85, 85, 85, 255)
        else
          v = cell / 5 + (rnd(x, y, 23) - 128) / 16
          set(px, COBBLE, x, y, 105 + v, 105 + v, 105 + v, 255)
        end
        # glass: frame and a glint
        if edge
          set(px, GLASS, x, y, 210, 235, 240, 255)
        elsif (x == y + 3 || x == y + 4) && x < 10
          set(px, GLASS, x, y, 240, 250, 255, 200)
        else
          set(px, GLASS, x, y, 0, 0, 0, 0)
        end
        # brick
        row = y / 4
        offset = row % 2 == 0 ? 0 : 4
        if y % 4 == 0 || (x + offset) % 8 == 0
          set(px, BRICK, x, y, 200, 195, 185, 255)
        else
          v = (rnd(x, y, 24) - 128) / 10
          set(px, BRICK, x, y, 150 + v, 70 + v, 55 + v, 255)
        end
        # cactus
        v = (rnd(x, y, 25) - 128) / 10
        if x % 4 == 1 && y % 3 == 0
          set(px, CACTUS_SIDE, x, y, 220, 230, 180, 255)
        else
          set(px, CACTUS_SIDE, x, y, 60 + v, 130 + v, 50 + v, 255)
        end
        set(px, CACTUS_TOP, x, y, 80 + v, 150 + v, 70 + v, 255)
        x += 1
      end
      y += 1
    end
    plants(px)
    torch(px)
    porkchop(px)
    pick(px, WOOD_PICK, 170, 130, 80)
    pick(px, STONE_PICK, 135, 135, 135)
    pick(px, IRON_PICK, 225, 220, 210)
    pick(px, DIAMOND_PICK, 90, 230, 225)
    bow(px)
    arrow(px)
    door(px)
    sapling(px)
    apple(px)
    sword(px, WOOD_SWORD, 160, 120, 70)
    sword(px, STONE_SWORD, 135, 135, 135)
    sword(px, IRON_SWORD, 225, 220, 210)
    sword(px, DIAMOND_SWORD, 90, 230, 225)
    axe(px, WOOD_AXE, 160, 120, 70)
    axe(px, STONE_AXE, 135, 135, 135)
    axe(px, IRON_AXE, 225, 220, 210)
    axe(px, DIAMOND_AXE, 90, 230, 225)
    shovel(px, WOOD_SHOVEL, 160, 120, 70)
    shovel(px, STONE_SHOVEL, 135, 135, 135)
    shovel(px, IRON_SHOVEL, 225, 220, 210)
    shovel(px, DIAMOND_SHOVEL, 90, 230, 225)
    ingot(px)
    crop(px, SEEDS, 4, 80, 170, 60)
    crop(px, WHEAT_1, 8, 90, 160, 50)
    crop(px, WHEAT_2, 12, 140, 160, 50)
    crop(px, WHEAT_RIPE, 15, 215, 180, 70)
    wheat(px)
    bread(px)
    furnace(px)
    crafting_table(px)
    ladder(px)
    lava(px)
    noisy(px, WOOL, 232, 232, 228, 14, 71)
    bed(px)
    chest(px)
    ore(px, COAL, 30, 30, 30, 30)
    ore(px, IRON, 200, 160, 120, 40)
    ore(px, DIAMOND, 90, 220, 220, 50)
    fire(px)
    puff(px)
    rain(px)
    heart(px, HEART, 220, 30, 40)
    heart(px, HEART_EMPTY, 50, 20, 20)
    font(px)
    cracks(px)
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

  # Tongues of flame: tall in the middle, yellow at the base, red at the tips.
  def self.fire(px)
    x = 0
    while x < 16
      edge = (x - 7.5).abs / 8.0
      tall = (16.0 * (1.0 - edge * edge) * (0.55 + rnd(x / 2, 0, 81) / 570.0)).to_i
      y = 0
      while y < 16
        up = 15 - y
        if up < tall
          t = up.to_f / tall
          if t < 0.4
            set(px, FIRE, x, y, 255, 225, 90, 255)
          elsif t < 0.75
            set(px, FIRE, x, y, 250, 140, 30, 255)
          else
            set(px, FIRE, x, y, 215, 55, 20, 255)
          end
        end
        y += 1
      end
      x += 1
    end
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

  def self.plants(px)
    x = 0
    while x < 16
      # tall grass: blades of random height
      top = 3 + rnd(x, 0, 31) % 9
      y = top
      while y < 16
        if rnd(x, 1, 32) < 190
          v = (rnd(x, y, 33) - 128) / 8
          set(px, TALL_GRASS, x, y, 80 + v, 150 + v, 50 + v, 255)
        end
        y += 1
      end
      x += 1
    end
    # flowers: a stem and a petal head
    y = 7
    while y < 16
      set(px, ROSE, 7, y, 50, 120, 40, 255)
      set(px, DANDELION, 8, y, 50, 120, 40, 255)
      y += 1
    end
    set(px, ROSE, 6, 11, 50, 120, 40, 255)
    set(px, DANDELION, 9, 12, 50, 120, 40, 255)
    y = 3
    while y < 8
      x = 5
      while x < 10
        corner = (x == 5 || x == 9) && (y == 3 || y == 7)
        unless corner
          set(px, ROSE, x, y, 210 - (x + y) % 3 * 25, 25, 35, 255)
          set(px, DANDELION, x + 1, y + 1, 250, 215 - (x + y) % 2 * 30, 40, 255)
        end
        x += 1
      end
      y += 1
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

  # Bed: a red blanket with a white pillow on top, a wooden frame on the sides.
  def self.bed(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = (rnd(x, y, 81) - 128) / 12
        if y < 5 && x > 1 && x < 14
          set(px, BED_TOP, x, y, 235 + v, 235 + v, 230 + v, 255)
        else
          set(px, BED_TOP, x, y, 180 + v, 35 + v, 40 + v, 255)
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

  def self.lava(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = rnd(x / 2 + y / 3, y / 2, 61)
        hot = v > 170 ? 1 : 0
        set(px, LAVA, x, y, 230 + hot * 25, 90 + v / 4 + hot * 90, 20 + hot * 60, 255)
        x += 1
      end
      y += 1
    end
  end

  def self.bow(px)
    arc = [[3, 13], [3, 12], [4, 11], [4, 10], [5, 9], [5, 8], [6, 7], [7, 6], [8, 5], [9, 5], [10, 4], [11, 4], [12, 3], [13, 3]]
    arc.each do |c|
      set(px, BOW, c[0], c[1], 140, 95, 50, 255)
      set(px, BOW, c[0] - 1, c[1] - 1, 110, 75, 40, 255)
    end
    i = 3
    while i < 13
      set(px, BOW, i + 1, 15 - i - 1, 230, 230, 230, 255)
      i += 1
    end
  end

  def self.arrow(px)
    i = 3
    while i < 13
      set(px, ARROW, i, 15 - i, 150, 110, 70, 255)
      i += 1
    end
    [[12, 2], [13, 2], [13, 3], [11, 2], [13, 1]].each { |c| set(px, ARROW, c[0], c[1], 200, 200, 205, 255) }
    [[2, 12], [3, 13], [2, 13], [1, 13], [2, 14]].each { |c| set(px, ARROW, c[0], c[1], 235, 235, 235, 255) }
  end

  # A pickaxe: a diagonal handle and a curved head in the tier's color.
  def self.pick(px, layer, r, g, b)
    i = 3
    while i < 15
      set(px, layer, i, 15 - i, 110, 80, 45, 255)
      set(px, layer, i + 1, 15 - i, 85, 60, 35, 255)
      i += 1
    end
    head = [[2, 4], [3, 3], [4, 2], [5, 2], [6, 1], [7, 1], [8, 1], [9, 1], [10, 2], [11, 2], [12, 3], [13, 4],
            [3, 4], [4, 3], [5, 3], [11, 3], [12, 4], [13, 5], [14, 6], [14, 7], [13, 6], [2, 5], [1, 6], [1, 7]]
    head.each { |c| set(px, layer, c[0], c[1], r, g, b, 255) }
  end

  # A door of boards with a dark frame and a knob. The open door shows only
  # its edge at the hinge side; the rest is clear.
  def self.door(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = rnd(x / 4, y, 101) / 12 + (rnd(x, y, 102) - 128) / 20
        edge = x == 0 || y == 0 || x == 15 || y == 15 || x % 5 == 0
        c = edge ? 95 : 160 + v
        set(px, DOOR, x, y, c, (c * 0.7).to_i, (c * 0.42).to_i, 255)
        set(px, DOOR_OPEN, x, y, c, (c * 0.7).to_i, (c * 0.42).to_i, x < 3 ? 255 : 0)
        x += 1
      end
      y += 1
    end
    set(px, DOOR, 12, 8, 210, 205, 190, 255)
    set(px, DOOR, 12, 9, 170, 165, 150, 255)
  end

  # A thin stem with a few round leaves.
  def self.sapling(px)
    y = 9
    while y < 16
      set(px, SAPLING, 7, y, 110, 80, 45, 255)
      y += 1
    end
    [[7, 3, 3.2], [4, 7, 2.6], [10, 6, 2.8], [7, 8, 2.2]].each do |c|
      y = 0
      while y < 16
        x = 0
        while x < 16
          d = (x - c[0]) ** 2 + (y - c[1]) ** 2
          v = rnd(x, y, 111) / 8
          set(px, SAPLING, x, y, 50 + v, 120 + v, 40 + v, 255) if d < c[2] * c[2]
          x += 1
        end
        y += 1
      end
    end
  end

  def self.apple(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        dx = (x - 7.5) / 5.5
        dy = (y - 9.0) / 5.5
        if dx * dx + dy * dy < 1.0
          v = rnd(x, y, 121) / 10
          light = x < 7 && y < 8 ? 40 : 0
          set(px, APPLE, x, y, 200 + v + light, 30 + v + light, 35 + v + light, 255)
        end
        x += 1
      end
      y += 1
    end
    set(px, APPLE, 8, 2, 100, 70, 40, 255)
    set(px, APPLE, 8, 3, 100, 70, 40, 255)
    set(px, APPLE, 9, 2, 60, 140, 50, 255)
    set(px, APPLE, 10, 1, 60, 140, 50, 255)
  end

  # A sword: a diagonal blade in the tier's color, a cross guard, and a handle.
  def self.sword(px, layer, r, g, b)
    i = 0
    while i < 9
      set(px, layer, 5 + i, 10 - i, r, g, b, 255)
      set(px, layer, 6 + i, 10 - i, r * 3 / 4, g * 3 / 4, b * 3 / 4, 255)
      i += 1
    end
    [[3, 9], [4, 10], [5, 11], [6, 12], [7, 13]].each { |c| set(px, layer, c[0], c[1], 90, 70, 50, 255) }
    [[4, 12], [3, 13], [2, 14]].each { |c| set(px, layer, c[0], c[1], 110, 80, 45, 255) }
    set(px, layer, 1, 15, 90, 65, 40, 255)
  end

  # A diagonal handle with a wide blade at the top right.
  def self.axe(px, layer, r, g, b)
    handle(px, layer)
    [[8, 1], [9, 1], [10, 1], [7, 2], [8, 2], [9, 2], [10, 2], [11, 2], [7, 3], [8, 3], [9, 3], [11, 3],
     [12, 3], [7, 4], [8, 4], [12, 4], [8, 5], [12, 5], [13, 5], [12, 6], [13, 6]].each do |c|
      set(px, layer, c[0], c[1], r, g, b, 255)
    end
  end

  # A diagonal handle with a rounded blade at the top right.
  def self.shovel(px, layer, r, g, b)
    handle(px, layer)
    [[11, 1], [12, 1], [13, 1], [10, 2], [11, 2], [12, 2], [13, 2], [14, 2], [10, 3], [11, 3], [12, 3],
     [13, 3], [14, 3], [11, 4], [12, 4], [13, 4]].each do |c|
      set(px, layer, c[0], c[1], r, g, b, 255)
    end
  end

  # The handle of an axe or a shovel: from the lower left to the middle.
  def self.handle(px, layer)
    i = 2
    while i < 12
      set(px, layer, i, 15 - i, 110, 80, 45, 255)
      set(px, layer, i + 1, 15 - i, 85, 60, 35, 255)
      i += 1
    end
  end

  # Rows of stalks of height tall (in pixels) in color r, g, b.
  def self.crop(px, layer, tall, r, g, b)
    x = 1
    while x < 16
      h = tall - rnd(x, 0, layer) % 3
      h = 2 if h < 2
      y = 16 - h
      while y < 16
        v = rnd(x, y, layer + 1) / 10
        set(px, layer, x, y, r + v, g + v, b + v / 2, 255)
        y += 1
      end
      x += 3
    end
  end

  # A bundle of golden stalks, tied in the middle.
  def self.wheat(px)
    x = 3
    while x < 13
      y = 1 + (x - 8).abs / 2
      while y < 15
        v = rnd(x, y, 151) / 8
        set(px, WHEAT, x, y, 210 + v, 175 + v, 70, 255) if (x + y) % 3 != 0
        y += 1
      end
      x += 1
    end
    x = 4
    while x < 12
      set(px, WHEAT, x, 9, 130, 95, 45, 255)
      x += 1
    end
  end

  # A loaf: a brown oval, lighter on top.
  def self.bread(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        dx = (x - 7.5) / 7.0
        dy = (y - 9.0) / 4.5
        if dx * dx + dy * dy < 1.0
          v = rnd(x, y, 161) / 12
          top = y < 8 ? 30 : 0
          set(px, BREAD, x, y, 170 + v + top, 110 + v + top, 50 + v, 255)
        end
        x += 1
      end
      y += 1
    end
  end

  def self.ingot(px)
    y = 6
    while y < 11
      x = 2 + (10 - y) / 2
      while x < 14 - (10 - y) / 2
        v = rnd(x, y, 131) / 12
        c = y == 6 ? 240 : 200
        set(px, IRON_INGOT, x, y, c + v - 10, c + v - 12, c + v - 18, 255)
        x += 1
      end
      y += 1
    end
  end

  # Ladder: two rails and four rungs; the rest is transparent.
  def self.ladder(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        rail = x == 2 || x == 3 || x == 12 || x == 13
        rung = (y % 4 == 1 || y % 4 == 2) && x > 3 && x < 12
        if rail || rung
          v = (rnd(x, y, 95) - 128) / 16
          dark = x == 3 || x == 13 || y % 4 == 2 ? 25 : 0
          set(px, LADDER, x, y, 150 + v - dark, 105 + v - dark, 60 + v - dark, 255)
        end
        x += 1
      end
      y += 1
    end
  end

  # Crafting table: planks with a dark grid on top, and a hammer and a saw
  # on the sides.
  def self.crafting_table(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        v = rnd(x / 4, y, 93) / 12 + (rnd(x, y, 94) - 128) / 20
        edge = x == 0 || y == 0 || x == 15 || y == 15
        top = edge || x == 5 || x == 10 || y == 5 || y == 10 ? 85 : 150 + v
        set(px, CRAFT_TOP, x, y, top, (top * 0.68).to_i, (top * 0.38).to_i, 255)
        side = edge || y == 3 ? 85 : 150 + v
        set(px, CRAFT_SIDE, x, y, side, (side * 0.68).to_i, (side * 0.38).to_i, 255)
        x += 1
      end
      y += 1
    end
    y = 6
    while y < 14
      set(px, CRAFT_SIDE, 4, y, 70, 45, 25, 255)
      set(px, CRAFT_SIDE, y - 4, 6, 180, 180, 190, 255) if y < 9
      set(px, CRAFT_SIDE, 10, y, 190, 190, 200, 255)
      set(px, CRAFT_SIDE, 11, y, 150, 150, 160, 255) if y > 6
      y += 1
    end
  end

  # Gray stone around a dark mouth with a glow at its bottom.
  def self.furnace(px)
    noisy(px, FURNACE, 120, 120, 120, 20, 141)
    y = 0
    while y < 16
      x = 0
      while x < 16
        set(px, FURNACE, x, y, 75, 75, 75, 255) if x == 0 || y == 0 || x == 15 || y == 15
        set(px, FURNACE, x, y, 25, 22, 20, 255) if x > 3 && x < 12 && y > 7 && y < 14
        set(px, FURNACE, x, y, 230, 120, 30, 255) if x > 4 && x < 11 && y == 12
        x += 1
      end
      y += 1
    end
  end

  def self.porkchop(px)
    meat(px, PORKCHOP, 215, 95, 105, 245, 225, 215)
    meat(px, COOKED_PORKCHOP, 150, 85, 45, 200, 160, 110)
  end

  # A round piece of meat with a rim of fat.
  def self.meat(px, layer, r, g, b, fr, fg, fb)
    y = 0
    while y < 16
      x = 0
      while x < 16
        dx = (x - 7.5) / 6.5
        dy = (y - 8.0) / 5.0
        d = dx * dx + dy * dy
        if d < 1.0
          if d > 0.62
            set(px, layer, x, y, fr, fg, fb, 255)
          else
            v = rnd(x, y, 41) / 10
            set(px, layer, x, y, r + v, g + v, b + v, 255)
          end
        end
        x += 1
      end
      y += 1
    end
  end

  def self.torch(px)
    y = 6
    while y < 16
      set(px, TORCH, 7, y, 120, 85, 50, 255)
      set(px, TORCH, 8, y, 95, 65, 40, 255)
      y += 1
    end
    set(px, TORCH, 7, 3, 255, 240, 150, 255)
    set(px, TORCH, 8, 3, 255, 220, 120, 255)
    set(px, TORCH, 7, 4, 255, 200, 60, 255)
    set(px, TORCH, 8, 4, 255, 230, 110, 255)
    set(px, TORCH, 7, 5, 240, 140, 30, 255)
    set(px, TORCH, 8, 5, 255, 180, 50, 255)
    set(px, TORCH, 6, 4, 230, 120, 20, 255)
    set(px, TORCH, 9, 4, 230, 120, 20, 255)
    set(px, TORCH, 7, 2, 250, 200, 80, 255)
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
