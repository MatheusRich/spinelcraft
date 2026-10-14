# Biomes: the kind of land at a column. The temperature and the humidity
# pick the biome, and the biome picks the ground block, the trees and the
# plants. The height adds beaches, bare rock and snow on top (World#top_block).
module Biome
  # Each table below has one entry for each biome, in this order.
  ALL = [PLAINS = 0, FOREST = 1, TAIGA = 2, SNOWY_TAIGA = 3, TUNDRA = 4, DESERT = 5, SAVANNA = 6,
         JUNGLE = 7, SWAMP = 8]

  # The top block of a column away from beaches and peaks.
  GROUND = [Block::GRASS, Block::GRASS, Block::GRASS, Block::SNOW_GRASS, Block::SNOW_GRASS,
            Block::SAND, Block::GRASS, Block::GRASS, Block::GRASS]
  # Trees per 65536 columns.
  TREES = [90, 2600, 2000, 1400, 50, 0, 160, 4200, 900]
  TREE_KINDS = [OAK = 0, SPRUCE = 1, ACACIA = 2, JUNGLE_TREE = 3]
  TREE = [OAK, OAK, SPRUCE, SPRUCE, SPRUCE, OAK, ACACIA, JUNGLE_TREE, OAK]
  # Large oaks per 65536 oaks. Plains: "1/3 are large"
  # (minecraft.wiki/w/Plains). Forest: 1/10, the chance that
  # minecraft.wiki/w/Oak gives for Alpha; the wiki does not confirm it
  # for today. Swamps grow no large oaks (minecraft.wiki/w/Oak).
  LARGE_OAKS = [21845, 6554, 0, 0, 0, 0, 0, 0, 0]
  # Pines per 65536 spruces. Taigas grow pines, and tundras do not
  # (minecraft.wiki/w/Spruce). The wiki does not confirm the share of a
  # third: it copies the taiga trees in the game code.
  PINES = [0, 0, 21845, 21845, 0, 0, 0, 0, 0]
  # Tall grass per 65536 columns of grass, before the meadow noise.
  GRASS = [9000, 5000, 3000, 0, 0, 0, 26000, 22000, 12000]
  # Flowers per 65536 columns of grass.
  FLOWERS = [2400, 600, 0, 0, 0, 0, 300, 0, 0]
  # The most trees of any biome, so a roll at or above it needs no biome.
  MAX_TREES = TREES.max

  # The biome for temperature t and humidity w. low is true near sea
  # level, the only land where swamps grow.
  def self.pick(t, w, low)
    if t < -0.32
      w > 0.1 ? SNOWY_TAIGA : TUNDRA
    elsif t < -0.14
      w > -0.1 ? TAIGA : PLAINS
    elsif t < 0.22
      if w < -0.1
        PLAINS
      elsif w > 0.14 && low
        SWAMP
      else
        FOREST
      end
    elsif w < -0.05
      DESERT
    else
      w > 0.16 ? JUNGLE : SAVANNA
    end
  end
end
