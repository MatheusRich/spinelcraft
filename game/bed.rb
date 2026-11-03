# minecraft.wiki/w/Bed
class Bed
  MONSTER_REACH = 8.0
  MONSTER_HEIGHT = 5.0
  # Steps from the foot along the bed and across it: one side of the foot,
  # around the foot, the other side, and around the head. The cell nearest
  # to the place where the player got in comes first (20w30a). The wiki does
  # not give the exact order.
  STAND_ALONG = [0, -1, -1, -1, 0, 1, 2, 2, 2, 1]
  STAND_ACROSS = [1, 1, 0, -1, -1, -1, -1, 0, 1, 1]
  STAND_HEIGHTS = [0, 1, -1]

  def initialize(world, x, y, z)
    block = world.get(x, y, z)
    # Each half faces away from the other.
    steps_from_foot = Block.bed_head?(block) ? 1 : 0
    @toward_head = Block::FACING[block] ^ (1 - steps_from_foot)
    @foot_x = x - along_x * steps_from_foot
    @foot_z = z - along_z * steps_from_foot
    @y = y
  end

  # Yields the reason when the player cannot sleep.
  def use(player, sky, mobs)
    return yield "SPAWN SET: YOU CAN ONLY SLEEP AT NIGHT" unless sky.sleep_time?
    return yield "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY" if monster_near?(mobs)

    player.sleep.start(self)
  end

  def whole?(world) = Block.bed?(world.get(head_x, @y, head_z))

  def lay(player)
    player.move_to(head_x + 0.5, @y + Block.box_top(Block::BED_BLOCK), head_z + 0.5)
    player.yaw = Math.atan2(-along_x, along_z)
    player.lie_down
  end

  def nearest_cell(x, z) = (0...STAND_ALONG.size).min_by { |cell| (cell_x(cell) + 0.5 - x)**2 + (cell_z(cell) + 0.5 - z)**2 }

  def stand_beside(player, world, first_cell)
    cells = [first_cell] + (0...STAND_ALONG.size).reject { |cell| cell == first_cell }
    cells.each do |cell|
      x = cell_x(cell) + 0.5
      z = cell_z(cell) + 0.5
      STAND_HEIGHTS.each do |height|
        next unless world.fits_dry?(x, @y + height, z, Player::HALF, Player::TALL)

        player.move_to(x, (@y + height).to_f, z)
        return face_head(player)
      end
    end
    face_head(player)
  end

  private

  def along_x = Block::DIR_DX[@toward_head]
  def along_z = Block::DIR_DZ[@toward_head]
  def head_x = @foot_x + along_x
  def head_z = @foot_z + along_z

  # The across step turns the along step a quarter turn.
  def cell_x(cell) = @foot_x + along_x * STAND_ALONG[cell] - along_z * STAND_ACROSS[cell]
  def cell_z(cell) = @foot_z + along_z * STAND_ALONG[cell] + along_x * STAND_ACROSS[cell]

  def face_head(player)
    player.yaw = Math.atan2(along_x, -along_z)
    player.stand_up
  end

  def monster_near?(mobs)
    mobs.any? do |mob|
      !mob.passive? && !mob.dying? && (mob.x - head_x - 0.5).abs <= MONSTER_REACH &&
        (mob.z - head_z - 0.5).abs <= MONSTER_REACH && (mob.y - @y).abs <= MONSTER_HEIGHT
    end
  end
end
