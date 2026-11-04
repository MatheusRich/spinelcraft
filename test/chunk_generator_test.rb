require_relative "test_helper"

class ChunkGeneratorTest < Minitest::Test
  ORES = [Block::COAL_ORE, Block::IRON, Block::DIAMOND, Block::SPINEL_ORE].freeze

  # Coal cells are x >> 2, y >> 1, z >> 2, and the other ore cells x >> 1,
  # y >> 1, z >> 1.
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

  # minecraft.wiki/w/Desert_Well/Structure: 89 sandstone, 12 slabs and 4
  # sand, 2 suspicious sand and 5 water. Here slabs are sandstone and
  # suspicious sand is sand.
  def test_a_desert_well_has_the_blocks_of_minecraft
    generator = ChunkGenerator.new(World.new(1337), 1337)
    reach = -ChunkGenerator::WELL_REACH..ChunkGenerator::WELL_REACH
    blocks = (-2..4).flat_map { |dy| reach.flat_map { |dx| reach.map { |dz| generator.well_block(dx, dy, dz) } } }
    assert_equal 101, blocks.count(Block::SANDSTONE)
    assert_equal 6, blocks.count(Block::SAND)
    assert_equal 5, blocks.count(Block::WATER)
  end

  def test_one_chunk_in_about_300_has_a_pumpkin_patch
    side = 600
    expected = side * side / 300.0
    patches = (-side / 2...side / 2).sum { |cx| (-side / 2...side / 2).count { |cz| ChunkGenerator.pumpkin_patch?(cx, cz) } }
    assert_in_delta expected, patches, expected * 0.05
  end

  def test_pumpkins_grow_only_in_a_patch_chunk
    world = World.new(1337)
    patch = [23, -5]
    neighborhood = (-1..1).to_a.product((-1..1).to_a).map { |dx, dz| [patch[0] + dx, patch[1] + dz] }
    pumpkins = neighborhood.to_h do |chunk|
      world.load_chunk(*chunk)
      [chunk, world.chunk_bytes(*chunk).count(Block::PUMPKIN.chr)]
    end
    assert ChunkGenerator.pumpkin_patch?(*patch)
    assert_operator pumpkins.delete(patch), :>, 0
    assert_equal [0], pumpkins.values.uniq
  end

  def test_the_soil_under_a_stony_shore_is_stone
    top = SEA + 10
    [Block::STONE, Block::GRAVEL].each { |surface| assert_equal Block::STONE, ChunkGenerator.ground_block(top - 1, top, surface) }
    assert_equal Block::DIRT, ChunkGenerator.ground_block(top - 1, top, Block::GRASS)
  end

  def test_the_water_of_a_desert_well_is_a_cross_with_air_above_it
    generator = ChunkGenerator.new(World.new(1337), 1337)
    [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dz|
      assert_equal Block::WATER, generator.well_block(dx, 0, dz)
      assert_equal Block::AIR, generator.well_block(dx, 1, dz)
    end
  end

  # The 3 x 3 chunks around x -1600, z 1408 of seed 1337 are desert.
  def test_desert_sand_grows_dry_grass_and_cacti
    world = World.new(1337)
    counts = Hash.new(0)
    (-1..1).each do |dx|
      (-1..1).each do |dz|
        world.load_chunk((-1600 >> 4) + dx, (1408 >> 4) + dz)
        world.chunk_bytes((-1600 >> 4) + dx, (1408 >> 4) + dz).each_byte { |block| counts[block] += 1 }
      end
    end
    assert_operator counts[Block::DRY_GRASS], :>, 20
    assert_operator counts[Block::CACTUS], :>, 5
  end

  def air_runs(world, x, z)
    runs = []
    run = []
    (Caves::LAVA_LEVEL + 1...world.height_at(x, z) - 1).each do |y|
      if world.get(x, y, z) == Block::AIR
        run << y
      else
        runs << run unless run.empty?
        run = []
      end
    end
    runs
  end

  def test_the_world_has_rooms_under_a_roof
    world = World.new(1337)
    (-2..1).each { |cx| (-2..1).each { |cz| world.load_chunk(cx, cz) } }
    rooms = (-32...32).flat_map { |x| (-32...32).flat_map { |z| air_runs(world, x, z).select { |run| run.size >= 6 }.map { |run| [run.last, world.height_at(x, z) - 1] } } }
    assert(rooms.any? { |top_of_room, top_of_column| top_of_column - top_of_room > CaveShape::ROOM_ROOF })
  end

  def test_a_chunk_in_a_closed_region_has_no_tunnel
    terrain = Terrain.new(1337)
    closed = (-8..8).flat_map { |cx| (-8..8).map { |cz| [cx, cz] } }.find do |cx, cz|
      CHUNK.times.all? { |dx| CHUNK.times.all? { |dz| terrain.cave_shape.cave_region(cx * CHUNK + dx, cz * CHUNK + dz) == 0.0 } }
    end
    refute_nil closed
    world = World.new(1337)
    world.load_chunk(*closed)
    x0 = closed[0] * CHUNK
    z0 = closed[1] * CHUNK
    # The ground, not height_at: the air under the leaves of a tree is no tunnel.
    shallow = CHUNK.times.flat_map do |dx|
      CHUNK.times.flat_map do |dz|
        ground = terrain.surface_height(x0 + dx, z0 + dz)
        air_runs(world, x0 + dx, z0 + dz).flatten.select { |y| y < ground && ground - 1 - y <= CaveShape::ROOM_ROOF }
      end
    end
    assert_empty shallow
  end

  def test_each_ore_fills_its_share_of_the_stone_at_each_layer
    stone, cells = ChunkGeneratorTest.ore_area
    ORES.each do |ore|
      want = (1...WY).sum { |y| stone[y] * Ores.ore_at(ore, y) / 256 }
      assert_in_delta 1.0, cells[ore].values.sum / want, 0.15, Block::NAMES[ore]
    end
  end

  # Caves and the land surface cut some clumps, so a clump holds a bit less
  # than a vein.
  def test_a_clump_of_ore_fills_its_cell_with_about_the_blocks_of_a_vein
    _, cells = ChunkGeneratorTest.ore_area
    { Block::COAL_ORE => Ores::VEIN_17, Block::IRON => Ores::VEIN_9, Block::DIAMOND => Ores::DIAMOND_VEIN,
      Block::SPINEL_ORE => Ores::VEIN_9 }.each do |ore, vein|
      mean = cells[ore].values.sum.to_f / cells[ore].size
      assert_in_delta 0.93 * vein, mean, 0.08 * vein, Block::NAMES[ore]
    end
  end

  def test_each_cell_has_its_own_roll
    _, cells = ChunkGeneratorTest.ore_area
    pairs = ->(keys, &group) { keys.group_by(&group).values.sum { |same| same.size * (same.size - 1) / 2 } }
    coal = cells[Block::COAL_ORE].keys
    assert_operator pairs.(coal) { |x, y, z| [x >> 2, y, z >> 2] }, :<, coal.size / 3
    others = cells[Block::IRON].keys + cells[Block::DIAMOND].keys + cells[Block::SPINEL_ORE].keys
    assert_operator pairs.(others) { |x, y, z| [x >> 1, y, z] }, :<, others.size / 10
    assert_operator pairs.(others) { |x, y, z| [x, y, z >> 1] }, :<, others.size / 10
  end

  # The generator keeps the coal rolls of the last chunk.
  def test_a_chunk_has_the_same_blocks_after_another_chunk
    first = World.new(1337)
    first.load_chunk(0, 0)
    second = World.new(1337)
    second.load_chunk(5, 3)
    second.load_chunk(0, 0)
    assert_equal first.chunk_bytes(0, 0), second.chunk_bytes(0, 0)
  end
end
