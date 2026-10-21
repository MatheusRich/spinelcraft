# The ores of Minecraft Java in the layers of this world: the blocks of
# each ore that a layer holds, and the ore of a clump in a cell of stone.
# ChunkGenerator rolls the cells and puts the ores.
class Ores
  # Ores copy the ore veins of Minecraft Java (minecraft.wiki/w/Ore_(feature)).
  # The world of Minecraft starts at y MC_BOTTOM, and the top water block
  # of its sea is at y MC_SEA (minecraft.wiki/w/Altitude). This world
  # starts at y 1, above the bedrock. So each layer from y 1 to the sea
  # stands for 2 layers of Minecraft and holds the ore of both (mc_y).
  # Above the sea, each layer stands for 1 layer.
  MC_BOTTOM = -64
  MC_SEA = 62
  # The average number of blocks in a vein of spawn size 4, 8, 9, 12 and
  # 17, in solid stone. The wiki gives only the largest numbers (5, 10,
  # 13, 23 and 37). It does not give the averages: they come from a run
  # of the vein algorithm of Minecraft.
  VEIN_4 = 2.0
  VEIN_8 = 5.7
  VEIN_9 = 6.8
  VEIN_12 = 11.6
  VEIN_17 = 22.2
  # The average diamond vein that starts in the world. Of each chunk's 7
  # veins of size 4, 4 of size 8 and 1/9 of size 12, half start below
  # MC_BOTTOM. The 2 veins of size 8 from y -64 to -4 all start in it.
  # minecraft.wiki/w/Diamond_Ore
  DIAMOND_VEIN = (3.5 * VEIN_4 + 2.0 * VEIN_8 + 0.5 / 9 * VEIN_12 + 2.0 * VEIN_8) / (3.5 + 2.0 + 0.5 / 9 + 2.0)
  # A cell of stone holds a clump of an ore at the odds of that ore at
  # the y of the block, out of 65536 (ore_odds). A coal cell is 4 x 2 x 4
  # blocks, and an iron, diamond or spinel cell is 2 x 2 x 2. Each block of a
  # clump is ore at the FILL odds, so a clump holds the average vein.
  COAL_CELL = 32
  ORE_CELL = 8
  COAL_FILL = (65536 * VEIN_17 / COAL_CELL).to_i
  IRON_FILL = (65536 * VEIN_9 / ORE_CELL).to_i
  DIAMOND_FILL = (65536 * DIAMOND_VEIN / ORE_CELL).to_i
  SPINEL_FILL = (65536 * VEIN_9 / ORE_CELL).to_i

  def initialize
    @coal_odds = Array.new(WY, 0)
    @iron_odds = Array.new(WY, 0)
    @diamond_odds = Array.new(WY, 0)
    @spinel_odds = Array.new(WY, 0)
    y = 0
    while y < WY
      @coal_odds[y] = Ores.ore_odds(Ores.ore_at(Block::COAL_ORE, y), COAL_CELL, VEIN_17)
      @iron_odds[y] = Ores.ore_odds(Ores.ore_at(Block::IRON, y), ORE_CELL, VEIN_9)
      @diamond_odds[y] = Ores.ore_odds(Ores.ore_at(Block::DIAMOND, y), ORE_CELL, DIAMOND_VEIN)
      @spinel_odds[y] = Ores.ore_odds(Ores.ore_at(Block::SPINEL_ORE, y), ORE_CELL, VEIN_9)
      y += 1
    end
    nil
  end

  # The y in Minecraft of layer y. Below the sea, layer y also stands for
  # the layer above that y in Minecraft.
  def self.mc_y(y)
    return y - SEA + MC_SEA if y >= SEA

    MC_BOTTOM + (y - 1) * 2
  end

  # The blocks of an ore in each chunk at layer y, in solid stone.
  def self.ore_at(ore, y)
    m = Ores.mc_y(y)
    return Ores.mc_ore(ore, m) if y >= SEA

    Ores.mc_ore(ore, m) + Ores.mc_ore(ore, m + 1)
  end

  # The blocks of an ore in each chunk of Minecraft at its layer m, in
  # solid stone: the veins that start at m, times the blocks of a vein.
  def self.mc_ore(ore, m)
    # 20 veins of size 17 in a triangle from y 0 to 192, and 30 spread
    # evenly from y 136 to 320. minecraft.wiki/w/Coal_Ore
    return VEIN_17 * (20 * Ores.peaked(m, 0, 192) + 30 * Ores.even(m, 136, 320)) if ore == Block::COAL_ORE
    # 90 veins of size 9 in a triangle from y 80 to 384, 10 in a triangle
    # from y -24 to 56, and 10 of size 4 spread evenly from y -64 to 72.
    # minecraft.wiki/w/Iron_Ore
    return VEIN_9 * (90 * Ores.peaked(m, 80, 384) + 10 * Ores.peaked(m, -24, 56)) + VEIN_4 * 10 * Ores.even(m, -64, 72) if ore == Block::IRON
    # Spinel copies gold ore: 4 veins of size 9 from y -64 to 32, most of
    # them near y -16, and half a vein of size 9 spread evenly from y -64
    # to -48. minecraft.wiki/w/Gold_Ore gives the veins as 0 to 13 blocks,
    # the largest of size 9. The wiki also says that half of these blocks
    # do not generate where they touch air. The game skips that rule. It
    # also skips the extra gold of the badlands, a biome that it does not
    # have.
    return VEIN_9 * (4 * Ores.peaked(m, -64, 32) + 0.5 * Ores.even(m, -64, -48)) if ore == Block::SPINEL_ORE

    # 7 veins of size 4, 4 of size 8 and 1/9 of size 12 in a triangle
    # that ends at y 16, and 2 of size 8 spread evenly from y -64 to -4.
    # minecraft.wiki/w/Diamond_Ore gives the range of the triangle as
    # -64 to 16 and says that the ore is more common lower down. The
    # wiki does not give the bottom of the triangle, -144 in the data of
    # the game, 80 layers below the bottom of the world.
    (7 * VEIN_4 + 4 * VEIN_8 + VEIN_12 / 9) * Ores.peaked(m, -144, 16) + 2 * VEIN_8 * Ores.even(m, -64, -4)
  end

  # The share of the veins that start at layer m, for veins in a triangle
  # from y low to high.
  def self.peaked(m, low, high)
    Ores.triangle(m, low.to_f, (low + high) / 2.0, high.to_f) * 2.0 / (high - low)
  end

  # The share of the veins that start at layer m, for veins spread evenly
  # from y low to high.
  def self.even(m, low, high)
    return 0.0 if m < low || m > high

    1.0 / (high - low + 1)
  end

  # The odds out of 65536 that a cell of `cell` blocks holds a clump, for
  # `blocks` of the ore in each layer of a chunk and clumps of `vein`
  # blocks.
  def self.ore_odds(blocks, cell, vein) = (blocks * 256 * cell / vein).round

  # 1 at peak, 0 at low and high and beyond, and a straight line between.
  def self.triangle(y, low, peak, high)
    return 0.0 if y <= low || y >= high

    y < peak ? (y - low) / (peak - low) : (high - y) / (high - peak)
  end

  # The ore of the clump at layer y, or stone: coal_r is the roll of the
  # coal cell, and r the roll of the iron, diamond or spinel cell. Spinel
  # takes the top of the roll. Its range then starts at the same roll in
  # both layers of a cell, even where the odds of iron and diamond change
  # from layer to layer.
  def clump(y, coal_r, r)
    return Block::COAL_ORE if coal_r < @coal_odds[y]

    iron = @iron_odds[y]
    return Block::IRON if r < iron
    return Block::DIAMOND if r < iron + @diamond_odds[y]
    return Block::SPINEL_ORE if r >= 65536 - @spinel_odds[y]

    Block::STONE
  end

  # True when block x, y, z of a clump of ore is ore. A roll for each block
  # leaves gaps in the clump.
  def self.fills?(ore, x, y, z)
    return Noise.hash3(x, y, z, 12) < COAL_FILL if ore == Block::COAL_ORE
    return Noise.hash3(x, y, z, 14) < IRON_FILL if ore == Block::IRON
    return Noise.hash3(x, y, z, 16) < DIAMOND_FILL if ore == Block::DIAMOND

    Noise.hash3(x, y, z, 18) < SPINEL_FILL
  end
end
