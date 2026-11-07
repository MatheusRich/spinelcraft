require_relative "test_helper"

# Caves#carve skips the cells that hold no cave and reuses the edges of a
# cell. A plain reference that blends the noise at each block must agree.
class CavesTest < Minitest::Test
  SEED = 1337
  # The first chunk has entrance patches in part of it, and the third in all
  # of it.
  CHUNKS = [[0, 0], [-1, 0], [3, -2], [-4, 5], [7, 7], [-6, -3]].freeze
  # Without a shore, each has sea water beside a cave.
  SEA_CHUNKS = [[115, 89], [114, 88], [-22, -32]].freeze
  SIDES = [[1, 0], [-1, 0], [0, 1], [0, -1]].freeze
  POND_SPACING = 7
  POND_HEIGHT = 20
  LAND_HEIGHT = 100
  NEAR_SURFACE = 14
  HEADROOM = 3

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

  def open_by_reference?(shape, fields, x, y, z, height_at)
    top = height_at.(x, z) - 1
    shore = SIDES.map { |dx, dz| height_at.(x + dx, z + dz) - 2 }.min
    return false if y > shore && y <= SEA

    depth = top - y
    width = (shape.entrance?(x, z) ? CaveShape::CAVE_WIDTH : CaveShape.cave_width(depth)) * shape.cave_region(x, z)
    return true if CaveShape.cave?(interpolate(x, y, z, &fields[:cave_a]), interpolate(x, y, z, &fields[:cave_b]), width)

    depth > CaveShape::ROOM_ROOF && interpolate(x, y, z, &fields[:cave_room]) > CaveShape.room_threshold(depth)
  end

  def noise_fields(shape)
    %i[cave_a cave_b cave_room].to_h do |field|
      memo = {}
      [field, ->(*point) { memo[point] ||= shape.public_send(field, *point) }]
    end
  end

  def terrain_heights
    terrain = Terrain.new(SEED)
    ->(x, z) { terrain.surface_height(x, z) }
  end

  def chunk_heights(cx, cz, height_at)
    Array.new(CHUNK * CHUNK) { |column| height_at.(cx * CHUNK + column / CHUNK, cz * CHUNK + column % CHUNK) }
  end

  def border_heights(cx, cz, height_at)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    (0...CHUNK).map { |i| height_at.(x0 - 1, z0 + i) } + (0...CHUNK).map { |i| height_at.(x0 + CHUNK, z0 + i) } +
      (0...CHUNK).map { |i| height_at.(x0 + i, z0 - 1) } + (0...CHUNK).map { |i| height_at.(x0 + i, z0 + CHUNK) }
  end

  def carve_stone(cx, cz, height_at)
    world = World.new(SEED)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    heights = chunk_heights(cx, cz, height_at)
    heights.each_with_index do |height, column|
      (1...height).each { |y| world.put_block(World.index(x0 + column / CHUNK, y, z0 + column % CHUNK), Block::STONE) }
    end
    Caves.new(world, CaveShape.new(SEED), heights, border_heights(cx, cz, height_at)).carve(x0, z0, heights.max)
    world
  end

  def carve_and_compare(cx, cz, height_at)
    shape = CaveShape.new(SEED)
    fields = noise_fields(shape)
    world = carve_stone(cx, cz, height_at)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    mismatches = []
    carved = Hash.new(0)
    chunk_heights(cx, cz, height_at).each_with_index do |height, column|
      x = x0 + column / CHUNK
      z = z0 + column % CHUNK
      top = height - 1
      last = Terrain.beach?(top) ? top - 3 : top
      (1...height).each do |y|
        open = y >= 2 && y <= last && open_by_reference?(shape, fields, x, y, z, height_at)
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
    height_at = terrain_heights
    (CHUNKS + SEA_CHUNKS).each do |cx, cz|
      mismatches, carved = carve_and_compare(cx, cz, height_at)
      assert_empty mismatches.first(5), "chunk #{cx}, #{cz}"
      air += carved[Block::AIR]
      lava += carved[Block::LAVA]
    end
    assert_operator air, :>, 500
    assert_operator lava, :>, 0
  end

  # A player walks into a cave from the surface. The floor of a tunnel near
  # the surface must leave room for a player to jump.
  def test_most_of_the_floor_near_the_surface_has_room_to_jump
    floors = 0
    roomy = 0
    height_at = terrain_heights
    chunk_range = (-4...4).to_a
    chunk_range.product(chunk_range).each do |cx, cz|
      world = carve_stone(cx, cz, height_at)
      chunk_heights(cx, cz, height_at).each_with_index do |height, column|
        x = cx * CHUNK + column / CHUNK
        z = cz * CHUNK + column % CHUNK
        top = height - 1
        floor_heights = (top - NEAR_SURFACE..top).select do |y|
          world.block(World.index(x, y, z)) == Block::AIR && world.block(World.index(x, y - 1, z)) == Block::STONE
        end
        floors += floor_heights.size
        roomy += floor_heights.count { |y| (1...HEADROOM).all? { |up| world.block(World.index(x, y + up, z)) == Block::AIR } }
      end
    end
    assert_operator floors, :>, 200
    assert_operator roomy, :>, floors * 11 / 20
  end

  # Generated water does not flow. A cave beside the sea must not leave the
  # water standing as a wall.
  def test_no_sea_water_stands_beside_a_cave
    SEA_CHUNKS.each do |sea_cx, sea_cz|
      world = World.new(SEED)
      (sea_cx - 1..sea_cx + 1).each { |cx| (sea_cz - 1..sea_cz + 1).each { |cz| world.load_chunk(cx, cz) } }
      assert_equal 0, water_walls(world, sea_cx, sea_cz), "chunk #{sea_cx}, #{sea_cz}"
    end
  end

  # It counts one column past each side of the chunk, so it also sees the
  # water of a neighbor chunk beside a cave of this one.
  def water_walls(world, cx, cz)
    columns = (-1..CHUNK).to_a
    columns.product(columns).sum do |lx, lz|
      x = cx * CHUNK + lx
      z = cz * CHUNK + lz
      (1..SEA).count do |y|
        world.get(x, y, z) == Block::WATER &&
          (world.get(x, y - 1, z) == Block::AIR || SIDES.any? { |dx, dz| world.get(x + dx, y, z + dz) == Block::AIR })
      end
    end
  end

  # A swamp at sea level has water as its top block. A cave beside it keeps
  # the block at sea level.
  def test_a_cave_keeps_the_block_beside_a_swamp_at_sea_level
    land = ->(_x, _z) { LAND_HEIGHT }
    cx, cz = CHUNKS.first
    open_land = carve_stone(cx, cz, land)
    inner = (1...CHUNK - 1).to_a
    x, z = inner.product(inner).map { |lx, lz| [cx * CHUNK + lx, cz * CHUNK + lz] }
                .find { |column_x, column_z| open_land.block(World.index(column_x, SEA, column_z)) == Block::AIR }
    swamp = ->(column_x, column_z) { column_x == x + 1 && column_z == z ? SEA + 1 : LAND_HEIGHT }
    assert_equal Block::STONE, carve_stone(cx, cz, swamp).block(World.index(x, SEA, z))
  end

  # Low columns stand among high ones, so each column of the chunk and of
  # its border has a lower column on some side.
  def test_the_carved_blocks_are_the_blocks_of_the_reference_beside_ponds
    ponds = ->(x, z) { (x + (z * 2)) % POND_SPACING == 0 ? POND_HEIGHT : LAND_HEIGHT }
    CHUNKS.each do |chunk|
      mismatches, = carve_and_compare(*chunk, ponds)
      assert_empty mismatches.first(5), "chunk #{chunk}"
    end
  end

  # ChunkGenerator gives Caves the heights of the columns around the chunk.
  def test_a_generated_chunk_has_the_caves_of_its_heights
    height_at = terrain_heights
    SEA_CHUNKS.each do |sea_cx, sea_cz|
      world = World.new(SEED)
      (sea_cx - 1..sea_cx + 1).each { |cx| (sea_cz - 1..sea_cz + 1).each { |cz| world.load_chunk(cx, cz) } }
      carved = carve_stone(sea_cx, sea_cz, height_at)
      differences = chunk_heights(sea_cx, sea_cz, height_at).each_with_index.sum do |height, column|
        x = sea_cx * CHUNK + column / CHUNK
        z = sea_cz * CHUNK + column % CHUNK
        (2...height).count { |y| cave?(world.get(x, y, z)) != cave?(carved.block(World.index(x, y, z))) }
      end
      assert_equal 0, differences, "chunk #{sea_cx}, #{sea_cz}"
    end
  end

  def cave?(block) = block == Block::AIR || block == Block::LAVA

  # A level ground tests each height at each place in a cell of the cave
  # grid: a beach, the layers of the grid, and the top of the world.
  def test_the_carved_blocks_are_the_blocks_of_the_reference_at_each_height
    [CHUNKS[0], CHUNKS[2]].each do |chunk|
      [10, 67, 68, *40..47, WY - 1, WY].each do |height|
        mismatches, = carve_and_compare(*chunk, ->(_x, _z) { height })
        assert_empty mismatches.first(5), "chunk #{chunk}, height #{height}"
      end
    end
  end
end
