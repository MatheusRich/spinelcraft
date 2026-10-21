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
      want = (1...WY).sum { |y| stone[y] * Ores.ore_at(ore, y) / 256 }
      assert_in_delta 1.0, cells[ore].values.sum / want, 0.15, Block::NAMES[ore]
    end
  end

  # Caves and the land surface cut some clumps, so a clump holds a bit
  # less than a vein.
  def test_a_clump_of_ore_fills_its_cell_with_about_the_blocks_of_a_vein
    _, cells = ChunkGeneratorTest.ore_area
    { Block::COAL_ORE => Ores::VEIN_17, Block::IRON => Ores::VEIN_9, Block::DIAMOND => Ores::DIAMOND_VEIN,
      Block::SPINEL_ORE => Ores::VEIN_9 }.each do |ore, vein|
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
end
