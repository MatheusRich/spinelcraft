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
    @walk = VoxelWalk.new
  end

  def hit? = @hit

  # The distance along the view ray of the last trace to the box from x0, y0,
  # z0 to x1, y1, z1, or -1.0 when the ray misses it.
  def box_distance(x0, y0, z0, x1, y1, z1) = @walk.box_distance(x0, y0, z0, x1, y1, z1)

  # Walks the cells along the view ray of player, from its eyes, until a
  # block stops the ray (see stops_view?).
  def trace(world, player)
    @hit = false
    # to_f: Spinel cannot type the position of the player.
    @walk.from(player.x.to_f, player.eye_y.to_f, player.z.to_f)
    front_x = @walk.x
    front_y = @walk.y
    front_z = @walk.z
    @walk.toward(player.fx, player.fy, player.fz, reach: Player::REACH) do |x, y, z|
      return hit_at(front_x, front_y, front_z) if stops_view?(world.get(x, y, z))

      front_x = x
      front_y = y
      front_z = z
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
  # box_top) in the cell of the walk within reach.
  def in_box?(block)
    half_x = Block.box_hx(block)
    half_z = Block.box_hz(block)
    x = @walk.x + 0.5 + Block.box_dx(block)
    y = @walk.y + Block.box_dy(block)
    z = @walk.z + 0.5 + Block.box_dz(block)
    along = @walk.box_distance(x - half_x, y, z - half_z, x + half_x, y + Block.box_top(block), z + half_z)
    along >= 0.0 && along <= Player::REACH
  end

  # The block is in the cell of the walk, and the cell before it is front.
  def hit_at(front_x, front_y, front_z)
    @hit = true
    @distance = @walk.along
    @x = @walk.x
    @y = @walk.y
    @z = @walk.z
    @front_x = front_x
    @front_y = front_y
    @front_z = front_z
    nil
  end
end
