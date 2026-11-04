# Where the caves of one seed are, from noise alone. Caves carves them into a chunk.
class CaveShape
  # A tunnel is where both cave noise fields are near zero: the sum of their
  # squares is below the width.
  CAVE_WIDTH = 0.006
  CAVE_ROOF = 4
  CAVE_FADE = 8
  CAVE_REGION_SCALE = 150.0
  CAVE_REGION_LOW = 0.0
  CAVE_REGION_HIGH = 0.12
  ROOM_THRESHOLD = 0.55
  ROOM_ROOF = 14
  ROOM_FADE = 6
  ROOM_SCALE = 56.0
  ROOM_SCALE_UP = 26.0
  # Minecraft also keeps most tunnels under the surface, and opens a rarer
  # set of entrances.
  ENTRANCE = 0.25
  ENTRANCE_SCALE = 48.0

  def self.cave?(a, c, width) = a * a + c * c < width
  # When the first field alone rules out a cave, the second needs no sample.
  def self.cave_possible?(a, width) = a * a < width

  def self.cave_width(depth)
    return 0.0 if depth <= CAVE_ROOF
    return CAVE_WIDTH if depth >= CAVE_ROOF + CAVE_FADE

    CAVE_WIDTH * (depth - CAVE_ROOF) / CAVE_FADE
  end

  # No value of the noise reaches 2.0, so the roof has no room.
  def self.room_threshold(depth)
    return 2.0 if depth <= ROOM_ROOF
    return ROOM_THRESHOLD if depth >= ROOM_ROOF + ROOM_FADE

    ROOM_THRESHOLD + (1.0 - ROOM_THRESHOLD) * (ROOM_ROOF + ROOM_FADE - depth) / ROOM_FADE
  end

  # The 4 edges along x of the cell of grid g from point n, in the order
  # y, z: 0 0, 1 0, 0 1, 1 1.
  def self.x_edges(g, n, gy, gz, tx, e)
    sx = gy * gz
    e[0] = g[n] + (g[n + sx] - g[n]) * tx
    e[1] = g[n + gz] + (g[n + sx + gz] - g[n + gz]) * tx
    e[2] = g[n + 1] + (g[n + sx + 1] - g[n + 1]) * tx
    e[3] = g[n + gz + 1] + (g[n + sx + gz + 1] - g[n + gz + 1]) * tx
  end

  def self.yz_lerp(e, ty, tz)
    c0 = e[0] + (e[1] - e[0]) * ty
    c1 = e[2] + (e[3] - e[2]) * ty
    c0 + (c1 - c0) * tz
  end

  # The seeds of the noise of Terrain, so the caves stay where they were.
  def initialize(seed)
    @room_noise = Noise.new(seed)
    @noise_a = Noise.new(seed * 31 + 7)
    @noise_b = Noise.new(seed * 17 + 3)
    @region_noise = Noise.new(seed * 43 + 11)
    @corner_a = Array.new(8, 0.0)
    @corner_b = Array.new(8, 0.0)
    @edges = Array.new(4, 0.0)
  end

  def cave_region(x, z)
    noise = @region_noise.noise2(x / CAVE_REGION_SCALE + 90.0, z / CAVE_REGION_SCALE + 30.0)
    ((noise - CAVE_REGION_LOW) / (CAVE_REGION_HIGH - CAVE_REGION_LOW)).clamp(0.0, 1.0)
  end

  def entrance?(x, z) = @room_noise.noise2(x / ENTRANCE_SCALE + 200.0, z / ENTRANCE_SCALE) > ENTRANCE

  # The cave grid has a point every 4 blocks.
  def cave_a(gx, gy, gz) = @noise_a.noise3(gx * 4 / 40.0, gy * 4 / 22.0, gz * 4 / 40.0)
  def cave_b(gx, gy, gz) = @noise_b.noise3(gx * 4 / 40.0 + 50.0, gy * 4 / 22.0, gz * 4 / 40.0)
  def cave_room(gx, gy, gz) = @room_noise.noise3(gx * 4 / ROOM_SCALE + 120.0, gy * 4 / ROOM_SCALE_UP, gz * 4 / ROOM_SCALE)

  # The tunnels of one block of an entrance patch, with the numbers of the
  # cave grid of Caves. Rooms lie deeper than ROOM_ROOF, so it skips them.
  def carved?(x, y, z)
    gx = x >> 2
    gy = y >> 2
    gz = z >> 2
    n = 0
    2.times do |i|
      2.times do |j|
        2.times do |k|
          @corner_a[n] = cave_a(gx + i, gy + j, gz + k)
          @corner_b[n] = cave_b(gx + i, gy + j, gz + k)
          n += 1
        end
      end
    end
    tx = (x - gx * 4) / 4.0
    ty = (y - gy * 4) / 4.0
    tz = (z - gz * 4) / 4.0
    CaveShape.cave?(trilinear(@corner_a, 0, 2, 2, tx, ty, tz), trilinear(@corner_b, 0, 2, 2, tx, ty, tz), CAVE_WIDTH * cave_region(x, z))
  end

  def opening?(x, y, z) = entrance?(x, z) && carved?(x, y, z)

  def trilinear(g, n, gy, gz, tx, ty, tz)
    CaveShape.x_edges(g, n, gy, gz, tx, @edges)
    CaveShape.yz_lerp(@edges, ty, tz)
  end
end
