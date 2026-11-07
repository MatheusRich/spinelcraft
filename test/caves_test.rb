require_relative "test_helper"

# Caves#carve skips the cells that hold no cave and reuses the edges of a
# cell. A plain reference that blends the noise at each block must agree.
class CavesTest < Minitest::Test
  SEED = 1337
  # The first chunk has entrance patches in part of it, and the third in all
  # of it.
  CHUNKS = [[0, 0], [-1, 0], [3, -2], [-4, 5], [7, 7], [-6, -3]].freeze
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

  def open_by_reference?(shape, fields, x, y, z, top)
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

  def surface_heights(terrain, x0, z0)
    Array.new(CHUNK * CHUNK) { |column| terrain.surface_height(x0 + column / CHUNK, z0 + column % CHUNK) }
  end

  def carve_stone(cx, cz, heights)
    world = World.new(SEED)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    heights.each_with_index do |height, column|
      (1...height).each { |y| world.put_block(World.index(x0 + column / CHUNK, y, z0 + column % CHUNK), Block::STONE) }
    end
    Caves.new(world, CaveShape.new(SEED), heights).carve(x0, z0, heights.max)
    world
  end

  def carve_and_compare(cx, cz, heights)
    shape = CaveShape.new(SEED)
    fields = noise_fields(shape)
    world = carve_stone(cx, cz, heights)
    x0 = cx * CHUNK
    z0 = cz * CHUNK
    mismatches = []
    carved = Hash.new(0)
    heights.each_with_index do |height, column|
      x = x0 + column / CHUNK
      z = z0 + column % CHUNK
      top = height - 1
      last = Terrain.beach?(top) ? top - 3 : top
      (1...height).each do |y|
        open = y >= 2 && y <= last && open_by_reference?(shape, fields, x, y, z, top)
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

  # A player walks into a cave from the surface. The floor of a tunnel near
  # the surface must leave room for a player to jump.
  def test_most_of_the_floor_near_the_surface_has_room_to_jump
    floors = 0
    roomy = 0
    terrain = Terrain.new(SEED)
    chunk_range = (-4...4).to_a
    chunk_range.product(chunk_range).each do |cx, cz|
      heights = surface_heights(terrain, cx * CHUNK, cz * CHUNK)
      world = carve_stone(cx, cz, heights)
      heights.each_with_index do |height, column|
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

  # A level ground tests each height at each place in a cell of the cave
  # grid: a beach, the layers of the grid, and the top of the world.
  def test_the_carved_blocks_are_the_blocks_of_the_reference_at_each_height
    [CHUNKS[0], CHUNKS[2]].each do |chunk|
      [10, 67, 68, *40..47, WY - 1, WY].each do |height|
        mismatches, = carve_and_compare(*chunk, Array.new(CHUNK * CHUNK, height))
        assert_empty mismatches.first(5), "chunk #{chunk}, height #{height}"
      end
    end
  end
end
