require_relative "test_helper"

class ChunkGeneratorTest < Minitest::Test
  # A desert well has the blocks of minecraft.wiki/w/Desert_Well/Structure:
  # 89 sandstone and 12 slabs, which are sandstone here, 4 sand and 2
  # suspicious sand, which are sand here, and 5 water.
  def test_a_desert_well_has_the_blocks_of_minecraft
    generator = ChunkGenerator.new(World.new(1337), 1337)
    reach = -ChunkGenerator::WELL_REACH..ChunkGenerator::WELL_REACH
    blocks = (-2..4).flat_map { |dy| reach.flat_map { |dx| reach.map { |dz| generator.well_block(dx, dy, dz) } } }
    assert_equal 101, blocks.count(Block::SANDSTONE)
    assert_equal 6, blocks.count(Block::SAND)
    assert_equal 5, blocks.count(Block::WATER)
  end

  def test_the_water_of_a_desert_well_is_a_cross_with_air_above_it
    generator = ChunkGenerator.new(World.new(1337), 1337)
    [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dz|
      assert_equal Block::WATER, generator.well_block(dx, 0, dz)
      assert_equal Block::AIR, generator.well_block(dx, 1, dz)
    end
  end

  def test_the_layers_below_the_sea_each_stand_for_2_layers_of_minecraft
    assert_equal ChunkGenerator::MC_BOTTOM, ChunkGenerator.mc_y(1)
    assert_equal ChunkGenerator::MC_BOTTOM + 2, ChunkGenerator.mc_y(2)
    assert_equal ChunkGenerator::MC_SEA - 2, ChunkGenerator.mc_y(SEA - 1)
    assert_equal ChunkGenerator::MC_SEA, ChunkGenerator.mc_y(SEA)
    assert_equal ChunkGenerator::MC_SEA + 1, ChunkGenerator.mc_y(SEA + 1)
  end

  # So the ore of a column is that of a column of Minecraft from its
  # bottom to the y of the top layer here.
  def test_a_column_holds_as_much_of_each_ore_as_in_minecraft
    ORES.each do |ore|
      here = (1...WY).sum { |y| ChunkGenerator.ore_at(ore, y) }
      there = (ChunkGenerator::MC_BOTTOM..ChunkGenerator.mc_y(WY - 1)).sum { |m| ChunkGenerator.mc_ore(ore, m) }
      assert_in_delta there, here, 1e-9
    end
  end

  # minecraft.wiki/w/Ore_(feature) gives the veins of each chunk.
  def test_the_ore_of_a_chunk_is_its_veins_times_their_blocks
    total = ->(ore) { (-200..500).sum { |m| ChunkGenerator.mc_ore(ore, m) } }
    assert_in_delta 50 * ChunkGenerator::VEIN_17, total.(Block::COAL_ORE), 1e-9
    assert_in_delta 100 * ChunkGenerator::VEIN_9 + 10 * ChunkGenerator::VEIN_4, total.(Block::IRON), 1e-9
    assert_in_delta 7 * ChunkGenerator::VEIN_4 + 6 * ChunkGenerator::VEIN_8 + ChunkGenerator::VEIN_12 / 9, total.(Block::DIAMOND), 1e-9
    assert_in_delta 4.5 * ChunkGenerator::VEIN_9, total.(Block::SPINEL_ORE), 1e-9
  end

  # minecraft.wiki/w/Ore lists the layers with none of each ore.
  def test_each_ore_lies_in_its_layers_of_minecraft
    assert_equal 0.0, ChunkGenerator.mc_ore(Block::COAL_ORE, -1)
    assert_operator ChunkGenerator.mc_ore(Block::COAL_ORE, 1), :>, 0.0
    assert_equal 0.0, ChunkGenerator.mc_ore(Block::COAL_ORE, 321)
    assert_operator ChunkGenerator.mc_ore(Block::COAL_ORE, 320), :>, 0.0
    assert_operator ChunkGenerator.mc_ore(Block::IRON, 72), :>, 0.0
    assert((73..80).all? { |m| ChunkGenerator.mc_ore(Block::IRON, m) == 0.0 })
    assert_operator ChunkGenerator.mc_ore(Block::IRON, 81), :>, 0.0
    assert_equal 0.0, ChunkGenerator.mc_ore(Block::IRON, -65)
    assert_operator ChunkGenerator.mc_ore(Block::DIAMOND, 15), :>, 0.0
    assert_equal 0.0, ChunkGenerator.mc_ore(Block::DIAMOND, 16)
    assert_operator ChunkGenerator.mc_ore(Block::SPINEL_ORE, 31), :>, 0.0
    assert_equal 0.0, ChunkGenerator.mc_ore(Block::SPINEL_ORE, 32)
    assert_operator ChunkGenerator.mc_ore(Block::SPINEL_ORE, -64), :>, 0.0
    assert_equal 0.0, ChunkGenerator.mc_ore(Block::SPINEL_ORE, -65)
  end

  # A layer holds the veins that start at it, times their blocks. In a
  # triangle from y low to high, the peak layer gets 2 / (high - low) of
  # the veins. In an even spread, each layer gets 1 / (high - low + 1).
  # minecraft.wiki/w/Coal_Ore, /w/Iron_Ore, /w/Diamond_Ore and
  # /w/Gold_Ore (which spinel copies) give the veins and the spreads.
  def test_each_layer_of_minecraft_holds_the_veins_that_start_at_it
    coal = ChunkGenerator::VEIN_17
    assert_in_delta coal * 20 * 2 / 192, ChunkGenerator.mc_ore(Block::COAL_ORE, 96), 1e-9
    assert_in_delta coal * 20 * 2 / 192 * 57 / 96, ChunkGenerator.mc_ore(Block::COAL_ORE, 135), 1e-9
    assert_in_delta coal * (20 * 2.0 / 192 * 56 / 96 + 30 / 185.0), ChunkGenerator.mc_ore(Block::COAL_ORE, 136), 1e-9
    assert_in_delta coal * 30 / 185, ChunkGenerator.mc_ore(Block::COAL_ORE, 193), 1e-9
    iron = ChunkGenerator::VEIN_9
    small = ChunkGenerator::VEIN_4 * 10 / 137
    assert_in_delta small, ChunkGenerator.mc_ore(Block::IRON, -64), 1e-9
    assert_in_delta iron * 10 * 2 / 80 * 2 / 40 + small, ChunkGenerator.mc_ore(Block::IRON, -22), 1e-9
    assert_in_delta iron * 10 * 2 / 80 + small, ChunkGenerator.mc_ore(Block::IRON, 16), 1e-9
    assert_in_delta iron * 10 * 2 / 80 * 2 / 40 + small, ChunkGenerator.mc_ore(Block::IRON, 54), 1e-9
    assert_in_delta iron * 90 * 2 / 304, ChunkGenerator.mc_ore(Block::IRON, 232), 1e-9
    veins = 7 * ChunkGenerator::VEIN_4 + 4 * ChunkGenerator::VEIN_8 + ChunkGenerator::VEIN_12 / 9
    medium = 2 * ChunkGenerator::VEIN_8 / 61
    assert_in_delta veins * 2 / 160 + medium, ChunkGenerator.mc_ore(Block::DIAMOND, -64), 1e-9
    assert_in_delta veins * 2 / 160 * 20 / 80 + medium, ChunkGenerator.mc_ore(Block::DIAMOND, -4), 1e-9
    assert_in_delta veins * 2 / 160 * 19 / 80, ChunkGenerator.mc_ore(Block::DIAMOND, -3), 1e-9
    spinel = ChunkGenerator::VEIN_9 * 4 * 2 / 96
    lower = ChunkGenerator::VEIN_9 * 0.5 / 17
    assert_in_delta lower, ChunkGenerator.mc_ore(Block::SPINEL_ORE, -64), 1e-9
    assert_in_delta spinel * 16 / 48 + lower, ChunkGenerator.mc_ore(Block::SPINEL_ORE, -48), 1e-9
    assert_in_delta spinel * 17 / 48, ChunkGenerator.mc_ore(Block::SPINEL_ORE, -47), 1e-9
    assert_in_delta spinel, ChunkGenerator.mc_ore(Block::SPINEL_ORE, -16), 1e-9
  end

  ORES = [Block::COAL_ORE, Block::IRON, Block::DIAMOND, Block::SPINEL_ORE].freeze

  # The stone and ore blocks of each layer, and the blocks of each ore by
  # its cell (x >> 2, y >> 1, z >> 2 for coal, x >> 1, y >> 1, z >> 1 for
  # the others), in the 4 x 4 chunks from x = z = 0.
  def self.ore_area
    @ore_area ||= begin
      world = World.new(1337)
      4.times { |cx| 4.times { |cz| world.load_chunk(cx, cz) } }
      stone = Array.new(WY, 0)
      cells = ORES.to_h { |ore| [ore, Hash.new(0)] }
      64.times do |x|
        64.times do |z|
          (1...WY).each do |y|
            b = world.get(x, y, z)
            stone[y] += 1 if b == Block::STONE || cells.key?(b)
            next unless cells.key?(b)
            cell = b == Block::COAL_ORE ? [x >> 2, y >> 1, z >> 2] : [x >> 1, y >> 1, z >> 1]
            cells[b][cell] += 1
          end
        end
      end
      [stone, cells]
    end
  end

  def test_each_ore_fills_its_share_of_the_stone_at_each_layer
    stone, cells = ChunkGeneratorTest.ore_area
    ORES.each do |ore|
      want = (1...WY).sum { |y| stone[y] * ChunkGenerator.ore_at(ore, y) / 256 }
      assert_in_delta 1.0, cells[ore].values.sum / want, 0.15, Block::NAMES[ore]
    end
  end

  # Caves and the land surface cut some clumps, so a clump holds a bit
  # less than a vein.
  def test_a_clump_of_ore_fills_its_cell_with_about_the_blocks_of_a_vein
    _, cells = ChunkGeneratorTest.ore_area
    { Block::COAL_ORE => ChunkGenerator::VEIN_17, Block::IRON => ChunkGenerator::VEIN_9, Block::DIAMOND => ChunkGenerator::DIAMOND_VEIN,
      Block::SPINEL_ORE => ChunkGenerator::VEIN_9 }.each do |ore, vein|
      mean = cells[ore].values.sum.to_f / cells[ore].size
      assert_in_delta 0.93 * vein, mean, 0.08 * vein, Block::NAMES[ore]
    end
  end

  # Each cell has its own roll. So few pairs of cells at one height both
  # hold coal in one chunk, or both hold iron or diamond side by side.
  def test_each_cell_has_its_own_roll
    _, cells = ChunkGeneratorTest.ore_area
    pairs = ->(keys, &group) { keys.group_by(&group).values.sum { |same| same.size * (same.size - 1) / 2 } }
    coal = cells[Block::COAL_ORE].keys
    assert_operator pairs.(coal) { |x, y, z| [x >> 2, y, z >> 2] }, :<, coal.size / 3
    others = cells[Block::IRON].keys + cells[Block::DIAMOND].keys + cells[Block::SPINEL_ORE].keys
    assert_operator pairs.(others) { |x, y, z| [x >> 1, y, z] }, :<, others.size / 10
    assert_operator pairs.(others) { |x, y, z| [x, y, z >> 1] }, :<, others.size / 10
  end

  # The generator keeps the rolls of the coal cells of the last chunk, so
  # the next chunk must make all of its own.
  def test_a_chunk_has_the_same_blocks_after_another_chunk
    first = World.new(1337)
    first.load_chunk(0, 0)
    second = World.new(1337)
    second.load_chunk(5, 3)
    second.load_chunk(0, 0)
    assert_equal first.chunk_bytes(0, 0), second.chunk_bytes(0, 0)
  end

  # 1 block of ore in each layer of a chunk takes 1 full cell in 256
  # columns, and twice as many cells when each holds half its blocks.
  def test_the_odds_of_a_clump_give_the_blocks_of_each_layer
    assert_equal 256, ChunkGenerator.ore_odds(1.0, 8, 8.0)
    assert_equal 512, ChunkGenerator.ore_odds(1.0, 8, 4.0)
    assert_equal 1024, ChunkGenerator.ore_odds(2.0, 32, 16.0)
  end
end
