require_relative "test_helper"

# The player stands at 8.5, SKY_Y, 8.5 in open air. A yaw of 0 looks along
# -z, so the eyes look at the cells 8, EYE_CELL, z for z < 8.
class BlockTargetTest < Minitest::Test
  EYE_CELL = (SKY_Y + Player::EYE).floor

  def setup
    @world = world_with_one_chunk
    @player = Player.new(8.5, SKY_Y.to_f, 8.5)
    @target = BlockTarget.new
  end

  def test_a_new_target_has_no_hit
    assert_equal false, @target.hit?
  end

  def test_eyes_in_a_block_hit_it_at_once
    @world.set(8, EYE_CELL, 8, Block::STONE)
    trace
    assert_equal [8, EYE_CELL, 8], [@target.x, @target.y, @target.z]
    assert_equal [8, EYE_CELL, 8], [@target.front_x, @target.front_y, @target.front_z]
    assert_equal 0.0, @target.distance
  end

  def test_the_distance_counts_from_the_eyes_off_the_middle_of_a_cell
    @player.x = 8.2
    @player.yaw = Math::PI / 2.0
    @world.set(11, EYE_CELL, 8, Block::STONE)
    trace
    assert_in_delta 2.8, @target.distance, 1.0e-9
  end

  def test_the_distance_counts_along_a_slant_ray
    @player.x = 8.2
    @player.yaw = Math::PI / 4.0
    (4..8).each { |z| @world.set(10, EYE_CELL, z, Block::STONE) }
    trace
    assert_equal [10, 6], [@target.x, @target.z]
    assert_in_delta 1.8 / Math.sin(Math::PI / 4.0), @target.distance, 1.0e-9
  end

  # The ray goes east and up at 45 degrees. It crosses the top of the
  # cell of the eyes before its east side, so it passes over the block to
  # the east.
  def test_the_ray_crosses_the_nearest_border_first
    @world.set(9, EYE_CELL, 8, Block::STONE)
    @world.set(9, EYE_CELL + 1, 8, Block::STONE)
    @player.yaw = Math::PI / 2.0
    @player.pitch = Math::PI / 4.0
    trace
    assert_equal [9, EYE_CELL + 1], [@target.x, @target.y]
    assert_equal [8, EYE_CELL + 1], [@target.front_x, @target.front_y]
  end

  # The ray goes east, a little south and a little up. It crosses the east
  # side of the cell first, then the south side, and the top last.
  def test_the_ray_crosses_the_border_on_x_before_a_farther_one_on_z
    @world.set(9, EYE_CELL, 8, Block::STONE)
    @player.yaw = 2.0
    @player.pitch = 0.1
    trace
    assert_equal [9, EYE_CELL, 8], [@target.x, @target.y, @target.z]
    assert_in_delta 0.5 / (Math.sin(2.0) * Math.cos(0.1)), @target.distance, 1.0e-9
  end

  def test_the_ray_hits_the_first_block_ahead_and_the_cell_in_front_of_it
    @world.set(8, EYE_CELL, 5, Block::STONE)
    @world.set(8, EYE_CELL, 4, Block::STONE)
    trace
    assert @target.hit?
    assert_equal [8, EYE_CELL, 5], [@target.x, @target.y, @target.z]
    assert_equal [8, EYE_CELL, 6], [@target.front_x, @target.front_y, @target.front_z]
    assert_in_delta 2.5, @target.distance, 1.0e-9
  end

  # The near face of the block at z = 3 is just Player::REACH away.
  def test_the_ray_reaches_a_block_within_reach_and_not_one_past_it
    @world.set(8, EYE_CELL, 3, Block::STONE)
    trace
    assert @target.hit?
    assert_in_delta Player::REACH, @target.distance, 1.0e-9
    @world.set(8, EYE_CELL, 3, Block::AIR)
    @world.set(8, EYE_CELL, 2, Block::STONE)
    trace
    refute @target.hit?
  end

  def test_a_miss_keeps_the_cells_of_the_last_hit
    @world.set(8, EYE_CELL, 5, Block::STONE)
    trace
    @world.set(8, EYE_CELL, 5, Block::AIR)
    trace
    refute @target.hit?
    assert_equal [8, EYE_CELL, 5], [@target.x, @target.y, @target.z]
  end

  def test_the_ray_passes_water_and_lava
    @world.set(8, EYE_CELL, 7, Block::WATER)
    @world.set(8, EYE_CELL, 6, Block::LAVA)
    @world.set(8, EYE_CELL, 5, Block::STONE)
    trace
    assert_equal 5, @target.z
    assert_equal 6, @target.front_z
  end

  # The flower box is small and stands in the middle of its cell. A ray
  # at the side of the cell misses it, and a ray at the middle hits it.
  def test_the_ray_hits_a_plant_only_in_its_box
    @world.set(8, SKY_Y, 6, Block::ROSE)
    (-3..2).each { |dy| @world.set(8, SKY_Y + dy, 4, Block::STONE) }
    @player.pitch = -Math.atan((Player::EYE - 0.3) / 2.0)
    @player.x = 8.05
    trace
    assert_equal 4, @target.z
    @player.x = 8.5
    trace
    assert_equal [6, SKY_Y], [@target.z, @target.y]
  end

  # A ladder is a thin box at one side of its cell. Facing 2, the box
  # stands across the ray at the north side, and facing 0, it stands along
  # the ray at the west side, where the ray misses it.
  def test_the_ray_hits_a_ladder_only_on_its_thin_box
    @world.set(8, EYE_CELL, 4, Block::STONE)
    @world.set(8, EYE_CELL, 6, Block.facing_id(Block::LADDER, 2))
    trace
    assert_equal 6, @target.z
    @world.set(8, EYE_CELL, 6, Block.facing_id(Block::LADDER, 0))
    trace
    assert_equal 4, @target.z
  end

  # A closed door facing 0 is a thin box at the east side of its cell.
  def test_the_ray_passes_a_door_that_it_misses
    @world.set(8, EYE_CELL, 6, Block.door_id(0, false, false))
    @world.set(8, EYE_CELL, 4, Block::STONE)
    trace
    assert_equal 4, @target.z
    @player.x = 8.9
    trace
    assert_equal 6, @target.z
  end

  # A torch on a wall stands 0.2 above the floor of its cell and leans
  # 0.3 toward the wall, here to the west.
  def test_the_ray_hits_a_torch_on_a_wall_only_in_its_box
    @world.set(8, EYE_CELL, 6, Block.facing_id(Block::TORCH, 0))
    @world.set(8, EYE_CELL, 4, Block::STONE)
    trace
    assert_equal 4, @target.z
    @player.x = 8.2
    trace
    assert_equal 6, @target.z
  end

  # Facing 2, the ladder box is at the north side of its cell, from z = 6
  # to z = 6.0625. Here the ray looks east along it.
  def test_the_ray_hits_a_ladder_from_the_side_only_in_its_box
    @player.x = 7.5
    @player.yaw = Math::PI / 2.0
    @world.set(9, EYE_CELL, 6, Block.facing_id(Block::LADDER, 2))
    @world.set(11, EYE_CELL, 6, Block::STONE)
    @player.z = 6.5
    trace
    assert_equal 11, @target.x
    @player.z = 6.03
    trace
    assert_equal 9, @target.x
  end

  def test_eyes_in_the_box_of_a_ladder_hit_it_at_once
    @world.set(8, EYE_CELL, 8, Block.facing_id(Block::LADDER, 2))
    @player.z = 8.03
    trace
    assert_equal [8, 0.0], [@target.z, @target.distance]
  end

  # The cell at z = 3 starts just within reach. A ladder at its far side
  # is out of reach, and one at its near side is just within reach.
  def test_the_box_of_a_ladder_must_be_within_reach
    @world.set(8, EYE_CELL, 3, Block.facing_id(Block::LADDER, 2))
    trace
    refute @target.hit?
    @world.set(8, EYE_CELL, 3, Block.facing_id(Block::LADDER, 3))
    trace
    assert_equal 3, @target.z
  end

  def test_a_look_down_hits_the_floor_and_the_cell_over_it
    @world.set(8, SKY_Y - 1, 8, Block::STONE)
    @player.pitch = -1.55
    trace
    assert_equal [8, SKY_Y - 1, 8], [@target.x, @target.y, @target.z]
    assert_equal [8, SKY_Y, 8], [@target.front_x, @target.front_y, @target.front_z]
    assert_in_delta Player::EYE, @target.distance, 0.01
  end

  def test_a_look_up_east_and_west_hits_the_block_on_each_side
    @world.set(8, EYE_CELL + 2, 8, Block::STONE)
    @player.pitch = 1.55
    trace
    assert_equal EYE_CELL + 2, @target.y
    assert_equal EYE_CELL + 1, @target.front_y
    @player.pitch = 0.0
    [[Math::PI / 2.0, 11, 10], [-Math::PI / 2.0, 5, 6]].each do |yaw, x, front|
      @world.set(x, EYE_CELL, 8, Block::STONE)
      @player.yaw = yaw
      trace
      assert_equal [x, front], [@target.x, @target.front_x]
    end
  end

  private

  def trace = @target.trace(@world, @player)
end
