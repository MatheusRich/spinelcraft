# Biomes: the kind of land at a column. The temperature and the humidity
# pick the biome, and the biome picks the ground block, the trees and the
# plants. The height adds beaches, bare rock and snow on top (Terrain#top_block).
module Biome
  ALL = [PLAINS = 0, FOREST = 1, TAIGA = 2, SNOWY_TAIGA = 3, TUNDRA = 4, DESERT = 5, SAVANNA = 6,
         JUNGLE = 7, SWAMP = 8]
  TREE_KINDS = [OAK = 0, SPRUCE = 1, ACACIA = 2, JUNGLE_TREE = 3]

  # The top block of a column away from beaches and peaks.
  GROUND = []
  # Trees per 65536 columns.
  TREES = []
  TREE = []
  # Birches per 65536 trees of a biome with oaks.
  BIRCHES = []
  # Large oaks per 65536 oaks.
  LARGE_OAKS = []
  # Pines per 65536 spruces.
  PINES = []
  # Tall grass per 65536 columns of grass, before the meadow noise.
  GRASS = []
  # Flowers per 65536 columns of grass.
  FLOWERS = []
  # The colors of grass and of oak leaves (0xRRGGBB).
  GRASS_COLOR = []
  FOLIAGE_COLOR = []

  def self.define_biome(biome, ground:, trees:, tree:, grass:, grass_color:, foliage_color:,
                        birches: 0, large_oaks: 0, pines: 0, flowers: 0)
    abort "Biome.define_biome: biome #{biome} comes out of order" if biome != GROUND.size
    GROUND << ground
    TREES << trees
    TREE << tree
    BIRCHES << birches
    LARGE_OAKS << large_oaks
    PINES << pines
    GRASS << grass
    FLOWERS << flowers
    GRASS_COLOR << grass_color
    FOLIAGE_COLOR << foliage_color
    # A nil return keeps Spinel from boxing it.
    nil
  end

  # "1/3 are large" oaks. minecraft.wiki/w/Plains
  define_biome PLAINS, ground: Block::GRASS, trees: 90, tree: OAK, large_oaks: 21845,
                       grass: 9000, flowers: 2400, grass_color: 0x91BD59, foliage_color: 0x77AB2F
  # Forests grow birches (minecraft.wiki/w/Birch). The wiki does not confirm
  # the share of a fifth: it copies the forest trees in the game code. Large
  # oaks are 1/10, the chance that minecraft.wiki/w/Oak gives for Alpha; the
  # wiki does not confirm it for today.
  # minecraft.wiki/w/Forest
  define_biome FOREST, ground: Block::GRASS, trees: 2600, tree: OAK, birches: 13107, large_oaks: 6554,
                       grass: 5000, flowers: 600, grass_color: 0x79C05A, foliage_color: 0x59AE30
  # Taigas grow pines, and tundras do not (minecraft.wiki/w/Spruce). The
  # wiki does not confirm the share of a third: it copies the taiga trees in
  # the game code.
  # minecraft.wiki/w/Taiga
  define_biome TAIGA, ground: Block::GRASS, trees: 2000, tree: SPRUCE, pines: 21845,
                      grass: 3000, grass_color: 0x86B783, foliage_color: 0x68A464
  # minecraft.wiki/w/Snowy_Taiga
  define_biome SNOWY_TAIGA, ground: Block::SNOW_GRASS, trees: 1400, tree: SPRUCE, pines: 21845,
                            grass: 0, grass_color: 0x80B497, foliage_color: 0x60A17B
  # The tundra is the snowy plains. minecraft.wiki/w/Snowy_Plains
  define_biome TUNDRA, ground: Block::SNOW_GRASS, trees: 50, tree: SPRUCE,
                       grass: 0, grass_color: 0x80B497, foliage_color: 0x60A17B
  # minecraft.wiki/w/Desert
  define_biome DESERT, ground: Block::SAND, trees: 0, tree: OAK,
                       grass: 0, grass_color: 0xBFB755, foliage_color: 0xAEA42A
  # minecraft.wiki/w/Savanna
  define_biome SAVANNA, ground: Block::GRASS, trees: 160, tree: ACACIA,
                        grass: 26000, flowers: 300, grass_color: 0xBFB755, foliage_color: 0xAEA42A
  # minecraft.wiki/w/Jungle
  define_biome JUNGLE, ground: Block::GRASS, trees: 4200, tree: JUNGLE_TREE,
                       grass: 22000, grass_color: 0x59C93C, foliage_color: 0x30BB0B
  # Swamps grow no large oaks (minecraft.wiki/w/Oak). Swamp grass in
  # Minecraft takes 0x6A7039 or 0x4C763C from a noise. Here it is always
  # 0x6A7039.
  # minecraft.wiki/w/Swamp
  define_biome SWAMP, ground: Block::GRASS, trees: 900, tree: OAK,
                      grass: 12000, grass_color: 0x6A7039, foliage_color: 0x6A7039

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
