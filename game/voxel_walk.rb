# The cells that a ray crosses, in order, from the cell where it starts.
# Each step goes into the next cell through the nearest border, so the
# walk never skips a cell, also at a corner. This is the voxel traversal
# of Amanatides and Woo (1987).
#
#   walk.from(x, y, z).toward(dir_x, dir_y, dir_z, reach: 4.5) { |x, y, z| ... }
#   walk.from(x, y, z).to(target_x, target_y, target_z) { |x, y, z| ... }
#
# The block gets each cell as x, y and z. While it runs, along is where
# the walk came into that cell.
class VoxelWalk
  # The distance along the ray at which the walk came into the cell: 0.0
  # in the first cell. It counts in lengths of the direction, so it is in
  # blocks when the direction has a length of 1.
  attr_reader :along

  def initialize
    @along = 0.0
    # Along x, y and z: the start, the direction, the cell, the distance
    # along the ray to the next border of a cell, and the distance between
    # two borders.
    @origin = Array.new(3, 0.0)
    @dir = Array.new(3, 0.0)
    @cell = Array.new(3, 0)
    @border = Array.new(3, 0.0)
    @span = Array.new(3, 0.0)
  end

  def x = @cell[0]
  def y = @cell[1]
  def z = @cell[2]

  # The walk starts at x, y, z, in the cell of that point.
  def from(x, y, z)
    @origin[0] = x
    @origin[1] = y
    @origin[2] = z
    @cell[0] = x.floor
    @cell[1] = y.floor
    @cell[2] = z.floor
    self
  end

  # Walks along dir_x, dir_y, dir_z, through each cell that the walk comes
  # into within reach.
  def toward(dir_x, dir_y, dir_z, reach:)
    aim(dir_x, dir_y, dir_z)
    while @along <= reach
      yield @cell[0], @cell[1], @cell[2]
      step
    end
    nil
  end

  # Walks the cells between the start and the target, the cell of the
  # target too. The direction is the whole step to the target, so the
  # walk reaches it at an along of 1.0.
  def to(target_x, target_y, target_z)
    toward(target_x - @origin[0], target_y - @origin[1], target_z - @origin[2], reach: 1.0) { |x, y, z| yield x, y, z }
  end

  # The distance along the ray to the box from x0, y0, z0 to x1, y1, z1,
  # or -1.0 when the ray misses it (see Ray.box_distance).
  def box_distance(x0, y0, z0, x1, y1, z1) =
    Ray.box_distance(@origin[0], @origin[1], @origin[2], @dir[0], @dir[1], @dir[2], x0, y0, z0, x1, y1, z1)

  # Points the walk along dir_x, dir_y, dir_z from the start.
  def aim(dir_x, dir_y, dir_z)
    @dir[0] = dir_x
    @dir[1] = dir_y
    @dir[2] = dir_z
    @along = 0.0
    axis = 0
    while axis < 3
      origin = @origin[axis]
      dir = @dir[axis]
      cell = origin.floor
      @cell[axis] = cell
      span = dir == 0.0 ? 1.0e9 : (1.0 / dir).abs
      @span[axis] = span
      @border[axis] = dir > 0.0 ? (cell + 1.0 - origin) * span : (origin - cell) * span
      axis += 1
    end
    nil
  end

  # Goes into the next cell.
  def step
    axis = next_axis
    @cell[axis] += @dir[axis] > 0.0 ? 1 : -1
    @along = @border[axis]
    @border[axis] += @span[axis]
    nil
  end

  # The axis of the nearest border. In a tie, the later axis wins: y over
  # x, and z over x and y.
  def next_axis
    return 0 if @border[0] < @border[1] && @border[0] < @border[2]
    return 1 if @border[1] < @border[2]

    2
  end
end
