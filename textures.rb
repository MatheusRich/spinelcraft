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
  FONT = 51
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
    lava(px)
    noisy(px, WOOL, 232, 232, 228, 14, 71)
    bed(px)
    chest(px)
    ore(px, COAL, 30, 30, 30, 30)
    ore(px, IRON, 200, 160, 120, 40)
    ore(px, DIAMOND, 90, 220, 220, 50)
    heart(px, HEART, 220, 30, 40)
    heart(px, HEART_EMPTY, 50, 20, 20)
    font(px)
    cracks(px)
    bleed(px, LEAVES)
    bleed(px, GLASS)
    bleed(px, TALL_GRASS)
    bleed(px, ROSE)
    bleed(px, DANDELION)
    px
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

  def self.porkchop(px)
    y = 0
    while y < 16
      x = 0
      while x < 16
        dx = (x - 7.5) / 6.5
        dy = (y - 8.0) / 5.0
        d = dx * dx + dy * dy
        if d < 1.0
          if d > 0.62
            set(px, PORKCHOP, x, y, 245, 225, 215, 255)
          else
            v = rnd(x, y, 41) / 10
            set(px, PORKCHOP, x, y, 215 + v, 95 + v, 105 + v, 255)
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
