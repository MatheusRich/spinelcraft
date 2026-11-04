# The directions in which fluid spreads sideways: those of the shortest
# paths to a way down, or all 4 when no way down is in reach. Water and
# lava look REACH blocks or fewer past the cell next to them.
# minecraft.wiki/w/Water, minecraft.wiki/w/Lava
class DropSearch
  REACH = 4
  RADIUS = REACH + 1
  # The search spans 2 * RADIUS + 1 cells, fewer than SIDE, so x & MASK and
  # z & MASK give each cell its own place.
  MASK = 15
  SIDE = MASK + 1
  ALL_DIRECTIONS = 0b1111
  # A seen cell holds (its steps + 1) * STEPS plus the bits (1 << direction)
  # of the first steps of its shortest paths.
  STEPS = 16

  def self.place(x, z) = (x & MASK) * SIDE + (z & MASK)

  def initialize(flow)
    @flow = flow
    @seen = Array.new(SIDE * SIDE, 0)
    @cells = Array.new(0, 0)
    # Kept until the next step, as fluid in Minecraft looks only when it
    # moves.
    @directions = {}
    nil
  end

  def forget = @directions.clear

  def directions(x, y, z)
    key = World.key(x, y, z)
    return @directions[key] if @directions.key?(key)

    @directions[key] = search(x, y, z)
  end

  def search(x, y, z)
    return ALL_DIRECTIONS unless way_down_near?(x, y, z)

    start(x, y, z)
    nearest = 0
    nearest_steps = 0
    index = 0
    while index < @cells.size
      seen = @seen[DropSearch.place(@cells[index], @cells[index + 1])]
      break if nearest > 0 && seen / STEPS > nearest_steps

      if @flow.way_down?(@cells[index], y, @cells[index + 1])
        nearest |= seen % STEPS
        nearest_steps = seen / STEPS
      elsif seen / STEPS <= RADIUS
        expand(index, y)
      end
      index += 2
    end
    return ALL_DIRECTIONS if nearest == 0

    nearest
  end

  def start(x, y, z)
    (0...@cells.size).step(2) { |index| @seen[DropSearch.place(@cells[index], @cells[index + 1])] = 0 }
    @cells.clear
    Block::DIR_DX.each_index do |dir|
      nx = x + Block::DIR_DX[dir]
      nz = z + Block::DIR_DZ[dir]
      next unless @flow.passes?(nx, y, nz)

      @seen[DropSearch.place(nx, nz)] = 2 * STEPS + (1 << dir)
      @cells << nx << nz
    end
  end

  # A cell one step farther takes the bits of the cell at index, also when
  # another path of the same steps saw it first.
  def expand(index, y)
    x = @cells[index]
    z = @cells[index + 1]
    farther = @seen[DropSearch.place(x, z)] + STEPS
    Block::DIR_DX.each_index do |dir|
      nx = x + Block::DIR_DX[dir]
      nz = z + Block::DIR_DZ[dir]
      place = DropSearch.place(nx, nz)
      seen = @seen[place]
      if seen == 0
        next unless @flow.passes?(nx, y, nz)

        @seen[place] = farther
        @cells << nx << nz
      elsif seen / STEPS == farther / STEPS
        @seen[place] = seen | (farther % STEPS)
      end
    end
  end

  def way_down_near?(x, y, z)
    (-RADIUS..RADIUS).any? do |along_x|
      along_z = RADIUS - along_x.abs
      (-along_z..along_z).any? { |offset| @flow.way_down?(x + along_x, y, z + offset) }
    end
  end
end
