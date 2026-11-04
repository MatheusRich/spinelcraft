# Carves the caves of a CaveShape into the chunks of a World.
class Caves
  GX = CHUNK / 4 + 1
  GY = WY / 4 + 1
  # Caves at this height and below fill with lava. Minecraft fills them
  # below y -54, 10 layers above the bottom of its world
  # (minecraft.wiki/w/Altitude).
  LAVA_LEVEL = 9

  def initialize(world, cave_shape, column_heights)
    @world = world
    @cave_shape = cave_shape
    @column_heights = column_heights
    @cave_a = Array.new(GX * GY * GX, 0.0)
    @cave_b = Array.new(GX * GY * GX, 0.0)
    @cave_room = Array.new(GX * GY * GX, 0.0)
    # 1 where a cell of the cave grid can hold a cave.
    @cave_cell = Array.new(GX * GY * GX, 0)
    @edges_a = Array.new(4, 0.0)
    @edges_c = Array.new(4, 0.0)
    @edges_room = Array.new(4, 0.0)
    # The grid layers that the edges hold.
    @a_layer = -1
    @c_layer = -1
    @room_layer = -1
    @cell_x = 0.0
    @cell_z = 0.0
    @room_peak = 0.0
  end

  def carve(x0, z0, highest)
    fill_cave_grid(x0, z0, highest)
    CHUNK.times do |lx|
      CHUNK.times { |lz| carve_column(x0, z0, lx, lz) }
    end
  end

  # Caves stay under the top block of a column, so the grid stops at the
  # layer above the highest top block.
  def fill_cave_grid(x0, z0, highest)
    gx0 = x0 >> 2
    gz0 = z0 >> 2
    gy = (highest - 1) / 4 + 2
    gy = GY if gy > GY
    i = 0
    while i < GX
      j = 0
      while j < gy
        k = 0
        while k < GX
          n = (i * GY + j) * GX + k
          @cave_a[n] = @cave_shape.cave_a(gx0 + i, j, gz0 + k)
          @cave_b[n] = @cave_shape.cave_b(gx0 + i, j, gz0 + k)
          k += 1
        end
        j += 1
      end
      i += 1
    end
    # Rooms lie under the roof, so the layers above it need no room noise.
    room_gy = (highest - 1 - CaveShape::ROOM_ROOF) / 4 + 2
    fill_room_grid(gx0, gz0, room_gy > gy ? gy : room_gy)
    mark_cave_cells(gy)
  end

  def fill_room_grid(gx0, gz0, gy)
    @room_peak = 0.0
    GX.times do |ix|
      gy.times do |iy|
        GX.times do |iz|
          point = (ix * GY + iy) * GX + iz
          @cave_room[point] = @cave_shape.cave_room(gx0 + ix, iy, gz0 + iz)
          @room_peak = @cave_room[point] if @cave_room[point] > @room_peak
        end
      end
    end
    nil
  end

  def mark_cave_cells(gy)
    (GX - 1).times do |i|
      (gy - 1).times do |j|
        (GX - 1).times do |k|
          n = (i * GY + j) * GX + k
          @cave_cell[n] = cave_cell(n)
        end
      end
    end
  end

  # A beach keeps the 3 blocks under its top block.
  def carve_column(x0, z0, lx, lz)
    x = x0 + lx
    z = z0 + lz
    top = @column_heights[lx * CHUNK + lz] - 1
    region = @cave_shape.cave_region(x, z)
    entrance = @cave_shape.entrance?(x, z)
    base = World.index(x, 0, z)
    fx = lx / 4.0
    fz = lz / 4.0
    ix = fx.to_i
    iz = fz.to_i
    @cell_x = fx - ix
    @cell_z = fz - iz
    @a_layer = -1
    @c_layer = -1
    @room_layer = -1
    last = Terrain.beach?(top) ? top - 3 : top
    y = 2
    while y <= last
      n = (ix * GY + (y >> 2)) * GX + iz
      open = @cave_cell[n] == 1 && tunnel?(n, y, fx - ix, fz - iz, (entrance ? CaveShape::CAVE_WIDTH : CaveShape.cave_width(top - y)) * region)
      open ||= room?(n, y, top - y) if @room_peak > CaveShape::ROOM_THRESHOLD && top - y > CaveShape::ROOM_ROOF
      @world.put_block(base + y, y <= LAVA_LEVEL ? Block::LAVA : Block::AIR) if open
      y += 1
    end
    nil
  end

  # The 4 layers of a grid cell share its edges along x, so a column reads
  # them once a layer.
  def tunnel?(n, y, tx, tz, width)
    fy = y / 4.0
    iy = fy.to_i
    if iy != @a_layer
      @a_layer = iy
      CaveShape.x_edges(@cave_a, n, GY, GX, tx, @edges_a)
    end
    a = CaveShape.yz_lerp(@edges_a, fy - iy, tz)
    return false unless CaveShape.cave_possible?(a, width)

    if iy != @c_layer
      @c_layer = iy
      CaveShape.x_edges(@cave_b, n, GY, GX, tx, @edges_c)
    end
    CaveShape.cave?(a, CaveShape.yz_lerp(@edges_c, fy - iy, tz), width)
  end

  def room?(point, y, depth)
    fy = y / 4.0
    iy = fy.to_i
    if iy != @room_layer
      @room_layer = iy
      CaveShape.x_edges(@cave_room, point, GY, GX, @cell_x, @edges_room)
    end
    CaveShape.yz_lerp(@edges_room, fy - iy, @cell_z) > CaveShape.room_threshold(depth)
  end

  # The first field mixes the values at the 8 corners of a cell. When all
  # of them are too far from zero on one side, every block of the cell is too.
  def cave_cell(n)
    low = 1.0
    high = -1.0
    2.times do |di|
      2.times do |dj|
        2.times do |dk|
          a = @cave_a[n + (di * GY + dj) * GX + dk]
          low = a if a < low
          high = a if a > high
        end
      end
    end
    CaveShape.cave_possible?(low, CaveShape::CAVE_WIDTH) || CaveShape.cave_possible?(high, CaveShape::CAVE_WIDTH) || (low < 0.0 && high > 0.0) ? 1 : 0
  end
end
