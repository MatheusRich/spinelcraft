# The block in the crosshair: the first block that the view ray of the
# player meets within Player::REACH, and the empty cell in front of it,
# where a placed block goes. Game#update_game traces it once a frame.
# Minecraft keeps the same in a HitResult, and Luanti in its
# pointed_thing.
class BlockTarget
  # The cell of the block, the cell in front of it, and the distance from
  # the eyes along the ray. They keep the last hit while hit? is false.
  attr_reader :x, :y, :z, :front_x, :front_y, :front_z, :distance

  def initialize
    @hit = false
    @x = 0
    @y = 0
    @z = 0
    @front_x = 0
    @front_y = 0
    @front_z = 0
    @distance = 0.0
    # The walk of a trace, along x, y and z: the eyes, the direction of
    # the view, the cell, the cell before it, the distance along the ray
    # to the next border of a cell, and the distance between two borders.
    @eye = Array.new(3, 0.0)
    @dir = Array.new(3, 0.0)
    @cell = Array.new(3, 0)
    @last = Array.new(3, 0)
    @border = Array.new(3, 0.0)
    @span = Array.new(3, 0.0)
  end

  def hit? = @hit

  # Walks the cells along the view ray of player, from its eyes, until a
  # block stops the ray (see stops_view?).
  def trace(world, player)
    start(player)
    @hit = false
    along = 0.0
    while along <= Player::REACH
      return hit_at(along) if stops_view?(world.get(@cell[0], @cell[1], @cell[2]))

      along = step
    end
    nil
  end

  # The walk starts in the cell of the eyes.
  def start(player)
    # to_f: Spinel cannot type the position of the player.
    @eye[0] = player.x.to_f
    @eye[1] = player.eye_y.to_f
    @eye[2] = player.z.to_f
    @dir[0] = player.fx
    @dir[1] = player.fy
    @dir[2] = player.fz
    axis = 0
    while axis < 3
      origin = @eye[axis]
      dir = @dir[axis]
      cell = origin.floor
      @cell[axis] = cell
      @last[axis] = cell
      span = dir == 0.0 ? 1.0e9 : (1.0 / dir).abs
      @span[axis] = span
      @border[axis] = dir > 0.0 ? (cell + 1.0 - origin) * span : (origin - cell) * span
      axis += 1
    end
    nil
  end

  # Air, water and lava let the ray pass, and so does a plant or a shaped
  # block when the ray misses its box.
  def stops_view?(block)
    return false if block == Block::AIR || Block.water?(block) || Block.lava?(block)
    return true unless Block.plant?(block) || Block::SHAPE[block] > 0

    in_box?(block)
  end

  # True when the ray meets the box of block (Block.box_hx, box_hz and
  # box_top) in the cell within reach.
  def in_box?(block)
    half_x = Block.box_hx(block)
    half_z = Block.box_hz(block)
    x = @cell[0] + 0.5 + Block.box_dx(block)
    y = @cell[1] + Block.box_dy(block)
    z = @cell[2] + 0.5 + Block.box_dz(block)
    along = Ray.box_distance(@eye[0], @eye[1], @eye[2], @dir[0], @dir[1], @dir[2],
                             x - half_x, y, z - half_z, x + half_x, y + Block.box_top(block), z + half_z)
    along >= 0.0 && along <= Player::REACH
  end

  # Steps to the next cell through the nearest border, and returns the
  # distance along the ray to it.
  def step
    axis = next_axis
    @last[0] = @cell[0]
    @last[1] = @cell[1]
    @last[2] = @cell[2]
    @cell[axis] += @dir[axis] > 0.0 ? 1 : -1
    along = @border[axis]
    @border[axis] += @span[axis]
    along
  end

  # The axis of the nearest border. In a tie, the later axis wins: y over
  # x, and z over x and y.
  def next_axis
    return 0 if @border[0] < @border[1] && @border[0] < @border[2]
    return 1 if @border[1] < @border[2]

    2
  end

  def hit_at(along)
    @hit = true
    @distance = along
    @x = @cell[0]
    @y = @cell[1]
    @z = @cell[2]
    @front_x = @last[0]
    @front_y = @last[1]
    @front_z = @last[2]
    nil
  end
end
