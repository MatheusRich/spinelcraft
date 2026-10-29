require_relative "test_helper"

# Caves#carve skips work: it samples the noise on a coarse grid, skips the
# cells that hold no cave, and reuses the edges of a cell. This test carves
# chunks of solid stone and compares each block with a plain reference that
# interpolates the noise at each block.
class CavesTest < Minitest::Test
  SEED = 1337
  # Chunks with tunnels, rooms and lava. The first has entrance patches in
  # part of it, and the third in all of it.
  CHUNKS = [[0, 0], [-1, 0], [3, -2], [-4, 5], [7, 7], [-6, -3]].freeze

  # The cave noise at the block x, y, z, from the 8 grid points around it.
  def interpolate(x, y, z)
    gx = x >> 2
    gy = y >> 2
    gz = z >> 2
    tx = (x - gx * 4) / 4.0
    ty = (y - gy * 4) / 4.0
    tz = (z - gz * 4) / 4.0
    corners = (0..1).flat_map { |dx| (0..1).flat_map { |dy| (0..1).map { |dz| yield(gx + dx, gy + dy, gz + dz) } } }
    lerp = ->(low, high, amount) { low + (high - low) * amount }
    along_x = [0, 1, 2, 3].map { |pair| lerp.(corners[pair], corners[pair + 4], tx) }
    along_y = [lerp.(along_x[0], along_x[2], ty), lerp.(along_x[1], along_x[3], ty)]
    lerp.(along_y[0], along_y[1], tz)
  end

  def open_by_reference?(terrain, fields, x, y, z, top)
    depth = top - y
    width = (terrain.entrance?(x, z) ? Terrain::CAVE_WIDTH : Terrain.cave_width(depth)) * terrain.cave_region(x, z)
    return true if Terrain.cave?(interpolate(x, y, z, &fields[:cave_a]), interpolate(x, y, z, &fields[:cave_b]), width)

    depth > Terrain::ROOM_ROOF && interpolate(x, y, z, &fields[:cave_room]) > Terrain.room_threshold(depth)
  end

  # The noise of each field at a grid point, which the blocks around it share.
  def noise_fields(terrain)
    %i[cave_a cave_b cave_room].to_h do |field|
      memo = {}
      [field, ->(*point) { memo[point] ||= terrain.public_send(field, *point) }]
    end
  end

  def surface_heights(terrain, x0, z0)
    Array.new(CHUNK * CHUNK) { |column| terrain.surface_height(x0 + column / CHUNK, z0 + column % CHUNK) }
  end

  # Carves the chunk cx, cz out of solid stone, with the top block of column
  # lx * CHUNK + lz at heights[column] - 1. Gives each block that differs from
  # the reference, and the count of each block that the carve made.
  def carve_and_compare(cx, cz, heights)
    terrain = Terrain.new(SEED)
    fields = noise_fields(terrain)
    world = World.new(SEED)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    heights.each_with_index do |height, column|
      (1...height).each { |y| world.put_block(World.index(x0 + column / CHUNK, y, z0 + column % CHUNK), Block::STONE) }
    end
    Caves.new(world, terrain, heights).carve(x0, z0, heights.max)
    mismatches = []
    carved = Hash.new(0)
    heights.each_with_index do |height, column|
      x = x0 + column / CHUNK
      z = z0 + column % CHUNK
      top = height - 1
      last = Terrain.beach?(top) ? top - 3 : top
      (1...height).each do |y|
        open = y >= 2 && y <= last && open_by_reference?(terrain, fields, x, y, z, top)
        want = open ? (y <= Caves::LAVA_LEVEL ? Block::LAVA : Block::AIR) : Block::STONE
        block = world.block(World.index(x, y, z))
        carved[block] += 1 unless block == Block::STONE
        mismatches << [x, y, z, block, want] unless block == want
      end
    end
    [mismatches, carved]
  end

  def test_the_carved_blocks_are_the_blocks_of_the_reference
    air = 0
    lava = 0
    CHUNKS.each do |cx, cz|
      mismatches, carved = carve_and_compare(cx, cz, surface_heights(Terrain.new(SEED), cx * CHUNK, cz * CHUNK))
      assert_empty mismatches.first(5), "chunk #{cx}, #{cz}"
      air += carved[Block::AIR]
      lava += carved[Block::LAVA]
    end
    assert_operator air, :>, 500
    assert_operator lava, :>, 0
  end

  # The tops of the columns are not the same in each chunk, so a level
  # ground tests each height, at each place in a cell of the cave grid:
  # a beach, the layers of the grid, and the top of the world.
  def test_the_carved_blocks_are_the_blocks_of_the_reference_at_each_height
    [CHUNKS[0], CHUNKS[2]].each do |chunk|
      [10, 67, 68, *40..47, WY - 1, WY].each do |height|
        mismatches, = carve_and_compare(*chunk, Array.new(CHUNK * CHUNK, height))
        assert_empty mismatches.first(5), "chunk #{chunk}, height #{height}"
      end
    end
  end
end
