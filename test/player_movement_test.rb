require_relative "test_helper"

# The movement of Player#update and Player#move, in steps of DT as in
# Game#update_game. The player stands at FLOOR, on a floor of stone that
# covers the chunk.
class PlayerMovementTest < Minitest::Test
  DT = 0.02
  FLOOR = SKY_Y

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, FLOOR - 1, z, Block::STONE) } }
    @player = Player.new(8.5, FLOOR.to_f, 8.5)
    walk(0.1)
  end

  def test_the_player_stands_on_the_floor
    assert @player.on_ground
    assert_equal FLOOR.to_f, @player.y
  end

  # A yaw of 0 looks along -z.
  def test_forward_walks_at_the_walk_speed_along_the_view
    walk(1.0, fwd: 1.0)
    assert_in_delta Player::WALK, @player.speed, 0.001
    assert_in_delta 0.0, @player.vx, 1.0e-9
    assert_operator @player.vz, :<, 0.0
  end

  def test_strafe_walks_to_the_right_of_the_view
    walk(1.0, strafe: 1.0)
    assert_in_delta Player::WALK, @player.vx, 0.001
  end

  def test_a_strafe_turns_with_the_view
    @player.yaw = Math::PI / 2.0
    walk(1.0, strafe: 1.0)
    assert_in_delta Player::WALK, @player.vz, 0.001
  end

  def test_a_walk_at_a_slant_to_the_axes_is_no_faster
    @player.yaw = Math::PI / 4.0
    walk(1.0, fwd: 1.0)
    assert_in_delta Player::WALK, @player.speed, 0.001
  end

  def test_a_diagonal_is_no_faster_than_a_straight_walk
    walk(1.0, fwd: 1.0, strafe: 1.0)
    assert_in_delta Player::WALK, @player.speed, 0.001
  end

  def test_the_player_turns_the_walk_with_the_view
    @player.yaw = Math::PI / 2.0
    walk(1.0, fwd: 1.0)
    assert_in_delta Player::WALK, @player.vx, 0.001
  end

  def test_a_sprint_is_faster_than_a_walk
    walk(1.0, fwd: 1.0, sprint: true)
    assert_in_delta Player::SPRINT, @player.speed, 0.001
  end

  def test_a_sneak_is_slow_and_stops_a_sprint
    walk(1.0, fwd: 1.0, down: true, sprint: true)
    assert_in_delta Player::WALK * Player::SNEAK, @player.speed, 0.001
  end

  def test_a_sneak_is_slow_along_x_too
    @player.yaw = Math::PI / 2.0
    @player.move_to(1.5, FLOOR.to_f, 8.5)
    walk(1.0, fwd: 1.0, down: true)
    assert_in_delta Player::WALK * Player::SNEAK, @player.speed, 0.001
  end

  # A sneak needs the ground. In the air, the walk keeps its speed.
  def test_a_sneak_in_the_air_does_not_slow_the_player
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    step
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    step(fwd: 1.0, down: true)
    assert_in_delta Player::WALK * 4.0 * DT, @player.speed, 1.0e-9
  end

  def test_a_slowed_player_moves_at_the_sneak_speed_and_does_not_sprint
    @player.slowed = true
    walk(1.0, fwd: 1.0, sprint: true)
    assert_in_delta Player::WALK * Player::SNEAK, @player.speed, 0.001
  end

  def test_the_player_stops_quickly_on_the_ground
    walk(1.0, fwd: 1.0)
    walk(0.5)
    assert_in_delta 0.0, @player.speed, 0.01
  end

  # In one step, the ground gives 14 * DT of the walk speed, and the air
  # 4 * DT. The step after a step on the ground counts as on the ground.
  def test_the_air_gives_less_control_than_the_ground
    step(fwd: 1.0)
    assert_in_delta Player::WALK * 14.0 * DT, @player.speed, 1.0e-9
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    step
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    step(fwd: 1.0)
    assert_in_delta Player::WALK * 4.0 * DT, @player.speed, 1.0e-9
  end

  def test_a_sneak_lowers_the_eyes
    assert_in_delta Player::EYE, @player.eye_y - @player.y, 1.0e-9
    walk(0.5, down: true)
    assert_in_delta Player::SNEAK_EYE, @player.eye_y - @player.y, 0.001
    walk(0.5)
    assert_in_delta Player::EYE, @player.eye_y - @player.y, 0.001
  end

  # minecraft.wiki/w/Jumping gives 1.2522 blocks.
  def test_a_jump_lifts_the_feet_a_block_and_a_quarter
    step(jump: true)
    assert @player.jumped
    refute @player.on_ground
    top = @player.y
    40.times do
      step
      refute @player.jumped
      top = @player.y if @player.y > top
    end
    assert_in_delta FLOOR + 1.2522, top, 0.001
    assert @player.on_ground
  end

  def test_a_jump_in_the_air_does_nothing
    step(jump: true)
    vy = @player.vy
    step(jump: true)
    refute @player.jumped
    assert_operator @player.vy, :<, vy
  end

  def test_a_sprint_jump_pushes_the_player_forward
    walk(1.0, fwd: 1.0, sprint: true)
    vz = @player.vz
    step(fwd: 1.0, sprint: true, jump: true)
    assert_operator @player.vz, :<, vz - Player::SPRINT_JUMP_PUSH * 0.9
    @player.move_to(8.5, FLOOR.to_f, 8.5)
    walk(1.0, fwd: 1.0)
    vz = @player.vz
    step(fwd: 1.0, jump: true)
    assert @player.jumped
    assert_operator @player.vz, :>, vz - 0.5
  end

  def test_a_sprint_jump_pushes_along_the_view
    @player.yaw = Math::PI / 2.0
    @player.move_to(1.5, FLOOR.to_f, 8.5)
    walk(1.0, fwd: 1.0, sprint: true)
    vx = @player.vx
    step(fwd: 1.0, sprint: true, jump: true)
    assert_operator @player.vx, :>, vx + Player::SPRINT_JUMP_PUSH * 0.9
  end

  def test_only_a_jump_on_land_counts_as_a_jump
    step(jump: true)
    assert @player.jumped
    @player.flying = true
    step(jump: true)
    refute @player.jumped
  end

  def test_a_fall_falls_faster_up_to_the_terminal_speed
    @player.move_to(8.5, FLOOR + 200.0, 8.5)
    @world.set(8, FLOOR - 1, 8, Block::AIR)
    step
    assert_in_delta(-Player::GRAVITY * DT, @player.vy, 1.0e-9)
    100.times { step }
    assert_operator @player.vy, :<, -40.0
    @player.vy = -Player::TERMINAL
    step
    assert_equal(-Player::TERMINAL, @player.vy)
  end

  def test_the_landing_step_gives_the_fall_distance
    @player.move_to(8.5, FLOOR + 10.0, 8.5)
    falls = Array.new(120) { step }
    assert_in_delta 10.0, falls.max, 1.0e-9
    assert_equal(1, falls.count { |fall| fall > 0.0 })
  end

  def test_a_jump_counts_its_fall_from_the_top
    falls = Array.new(60) { |i| step(jump: i.zero?) }
    assert_in_delta 1.2522, falls.max, 0.001
  end

  def test_water_takes_away_the_fall
    pool(FLOOR, 2)
    @player.move_to(8.5, FLOOR + 10.0, 8.5)
    falls = Array.new(200) { step }
    assert_equal 0.0, falls.max
  end

  def test_shallow_water_takes_away_the_fall
    pool(FLOOR, 1)
    @player.move_to(8.5, FLOOR + 10.0, 8.5)
    falls = Array.new(200) { step }
    assert_equal 0.0, falls.max
  end

  # The feet reach the water and the floor in the same step.
  def test_water_takes_away_the_fall_in_the_step_that_lands_in_it
    assert_in_delta 20.0, land_fast, 1.0e-9
    pool(FLOOR, 1)
    assert_equal 0.0, land_fast
  end

  def test_lava_takes_away_the_fall
    pool(FLOOR, 2, Block::LAVA)
    @player.move_to(8.5, FLOOR + 10.0, 8.5)
    falls = Array.new(200) { step }
    assert_equal 0.0, falls.max
  end

  def test_flight_takes_away_the_fall
    @player.move_to(8.5, FLOOR + 10.0, 8.5)
    @player.flying = true
    walk(0.5, down: true)
    @player.flying = false
    falls = Array.new(120) { step }
    assert_operator falls.max, :<, 10.0
  end

  def test_a_player_under_the_world_comes_back_from_the_sky
    @player.move_to(8.5, -19.0, 8.5)
    @player.vy = -50.0
    step
    assert_equal WY + 5.0, @player.y
    assert_equal 0.0, @player.vy
    falls = Array.new(30) { step }
    assert_equal 0.0, falls.max
  end

  def test_a_wall_stops_the_walk
    3.times { |y| @world.set(8, FLOOR + y, 7, Block::STONE) }
    walk(1.0, fwd: 1.0)
    assert_in_delta 8.0 + Player::HALF + 0.001, @player.z, 1.0e-9
    assert_equal 0.0, @player.vz
  end

  def test_a_wall_stops_the_walk_to_the_south
    3.times { |y| @world.set(8, FLOOR + y, 10, Block::STONE) }
    walk(1.0, fwd: -1.0)
    assert_in_delta 10.0 - Player::HALF - 0.001, @player.z, 1.0e-9
    assert_equal 0.0, @player.vz
  end

  def test_a_wall_stops_the_walk_to_the_east_and_to_the_west
    3.times { |y| @world.set(10, FLOOR + y, 8, Block::STONE) }
    3.times { |y| @world.set(6, FLOOR + y, 8, Block::STONE) }
    walk(1.0, strafe: 1.0)
    assert_in_delta 10.0 - Player::HALF - 0.001, @player.x, 1.0e-9
    assert_equal 0.0, @player.vx
    walk(1.5, strafe: -1.0)
    assert_in_delta 7.0 + Player::HALF + 0.001, @player.x, 1.0e-9
    assert_equal 0.0, @player.vx
  end

  def test_a_walk_moves_the_player_along_its_speed
    walk(0.5, strafe: 1.0)
    assert_operator @player.x, :>, 9.5
    walk(1.0, strafe: -1.0)
    assert_operator @player.x, :<, 8.5
  end

  def test_a_ceiling_stops_a_jump
    @world.set(8, FLOOR + 2, 8, Block::STONE)
    step(jump: true)
    top = @player.y
    20.times do
      step
      top = @player.y if @player.y > top
    end
    assert_in_delta FLOOR + 2.0 - Player::TALL - 0.001, top, 1.0e-9
  end

  def test_a_player_inside_a_block_climbs_out_on_top
    @world.set(8, FLOOR, 8, Block::STONE)
    @player.vy = 3.0
    step
    assert_equal FLOOR + 1.0, @player.y
    assert_equal 0.0, @player.vy
  end

  # The player stands at the north edge of a pillar, over the air.
  def test_a_sneak_does_not_step_off_an_edge
    pillar
    walk(2.0, fwd: 1.0, down: true)
    assert @player.on_ground
    assert_operator @player.z, :>, 8.0 - Player::HALF
    assert_in_delta FLOOR + 3.0, @player.y, 1.0e-9
  end

  def test_a_sneak_does_not_step_off_an_edge_to_the_side
    pillar
    @player.yaw = Math::PI / 2.0
    walk(2.0, strafe: -1.0, down: true)
    assert_operator @player.z, :>, 8.0 - Player::HALF
    assert_in_delta FLOOR + 3.0, @player.y, 1.0e-9
  end

  # The player stands at the west edge of a pillar.
  def test_a_sneak_does_not_step_off_an_edge_along_x
    3.times { |y| @world.set(8, FLOOR + y, 8, Block::STONE) }
    @player.move_to(8.0 - Player::HALF + 0.05, FLOOR + 3.0, 8.5)
    walk(0.1)
    walk(2.0, strafe: -1.0, down: true)
    assert_operator @player.x, :>, 8.0 - Player::HALF
    assert_in_delta FLOOR + 3.0, @player.y, 1.0e-9
    walk(2.0, strafe: -1.0)
    assert_operator @player.y, :<, FLOOR + 3.0
  end

  # On a pillar of one block, a sneak goes on until the box of the player
  # no longer overlaps the top, on each side.
  def test_a_sneak_reaches_over_each_edge_of_a_pillar
    [[0.0, 1.0], [0.0, -1.0], [Math::PI / 2.0, 1.0], [Math::PI / 2.0, -1.0]].each do |yaw, fwd|
      pillar
      @player.move_to(8.5, FLOOR + 3.0, 8.5)
      @player.yaw = yaw
      walk(2.0, fwd: fwd, down: true)
      assert_in_delta FLOOR + 3.0, @player.y, 1.0e-9
      assert_operator (@player.x - 8.5).abs + (@player.z - 8.5).abs, :>, 0.5 + Player::HALF - 0.05
    end
  end

  # The box of a chest is 1/16 smaller than its cell on each side. A sneak
  # stops where the box of the player no longer overlaps the box of the
  # chest, not the cell.
  def test_a_sneak_on_a_chest_stops_at_the_edge_of_its_box
    @world.set(8, FLOOR, 8, Block::CHEST)
    @player.move_to(8.5, FLOOR + 0.875, 8.5)
    walk(0.1)
    walk(3.0, fwd: 1.0, down: true)
    assert_in_delta FLOOR + 0.875, @player.y, 1.0e-9
    assert_operator @player.z, :>, 8.0 + 0.0625 - Player::HALF
  end

  def test_a_sneak_walks_across_the_floor
    walk(1.0, fwd: 1.0, down: true)
    assert_operator @player.z, :<, 8.5 - Player::WALK * Player::SNEAK * 0.8
  end

  def test_a_walk_steps_off_an_edge
    pillar
    walk(2.0, fwd: 1.0)
    assert_operator @player.y, :<, FLOOR + 3.0
  end

  def test_the_player_swims_at_the_swim_speed
    pool(FLOOR, 1)
    walk(1.0, fwd: 1.0)
    assert @player.in_water
    refute @player.in_lava
    assert_in_delta Player::SWIM, @player.speed, 0.01
  end

  def test_the_player_swims_slower_under_water_and_faster_in_a_sprint
    pool(FLOOR, 3)
    walk(1.0, fwd: 1.0)
    assert_in_delta Player::SWIM_UNDER, @player.speed, 0.01
    walk(1.0, fwd: 1.0, sprint: true)
    assert_in_delta Player::SWIM_SPRINT, @player.speed, 0.01
  end

  # The feet are out of the water, but the cell of the feet is water.
  def test_the_swim_speed_holds_at_the_surface
    pool(FLOOR, 1)
    @player.move_to(8.5, FLOOR + 0.7, 8.5)
    step
    @player.move_to(8.5, FLOOR + 0.7, 8.5)
    step(fwd: 1.0)
    refute @player.in_water
    assert_in_delta Player::SWIM * 4.0 * DT, @player.speed, 1.0e-9
  end

  def test_the_player_sinks_slowly_and_swims_up_with_jump
    pool(FLOOR, 8)
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    step
    assert_in_delta(-10.0 * DT, @player.vy, 1.0e-9)
    walk(1.0)
    assert_in_delta(-4.0, @player.vy, 1.0e-9)
    step(jump: true)
    assert_equal 3.2, @player.vy
  end

  def test_a_swim_up_against_a_wall_lifts_the_player_over_the_edge
    pool(FLOOR, 1)
    3.times { |y| @world.set(8, FLOOR + y, 7, Block::STONE) }
    walk(1.0, fwd: 1.0)
    step(fwd: 1.0, jump: true)
    assert_equal 6.0, @player.vy
  end

  def test_the_player_swims_slower_under_lava
    pool(FLOOR, 3, Block::LAVA)
    walk(1.0, fwd: 1.0)
    assert_in_delta Player::SWIM_UNDER * Player::LAVA, @player.speed, 0.01
  end

  def test_the_swim_speed_in_lava_holds_at_the_surface
    pool(FLOOR, 1, Block::LAVA)
    @player.move_to(8.5, FLOOR + 0.7, 8.5)
    step
    @player.move_to(8.5, FLOOR + 0.7, 8.5)
    step(fwd: 1.0)
    refute @player.in_lava
    assert_in_delta Player::SWIM * Player::LAVA * 4.0 * DT, @player.speed, 1.0e-9
  end

  # A liquid over the air, as in a waterfall: the feet are in the liquid,
  # but the cell of the feet is air.
  def test_the_player_swims_with_the_feet_in_a_liquid_over_the_air
    [[Block::WATER, Player::SWIM], [Block::LAVA, Player::SWIM * Player::LAVA]].each do |block, speed|
      @world.set(8, FLOOR + 1, 8, block)
      @player.move_to(8.5, FLOOR + 0.7, 8.5)
      step
      @player.move_to(8.5, FLOOR + 0.7, 8.5)
      step(fwd: 1.0)
      assert @player.in_water
      assert_in_delta speed * 4.0 * DT, @player.speed, 1.0e-9
    end
  end

  def test_a_swim_up_against_a_wall_to_the_east_lifts_the_player_too
    pool(FLOOR, 1)
    3.times { |y| @world.set(10, FLOOR + y, 8, Block::STONE) }
    walk(1.0, strafe: 1.0)
    step(strafe: 1.0, jump: true)
    assert_equal 6.0, @player.vy
  end

  def test_a_swim_up_away_from_the_wall_does_not_lift_the_player
    pool(FLOOR, 1)
    3.times { |y| @world.set(8, FLOOR + y, 7, Block::STONE) }
    walk(1.0, fwd: 1.0)
    walk(0.5, fwd: -1.0)
    step(fwd: -1.0, jump: true)
    assert_equal 3.2, @player.vy
  end

  def test_the_player_swims_slowly_in_lava
    pool(FLOOR, 1, Block::LAVA)
    walk(1.0, fwd: 1.0)
    assert @player.in_lava
    assert @player.in_water
    assert_in_delta Player::SWIM * Player::LAVA, @player.speed, 0.01
  end

  def test_jump_or_forward_climbs_a_ladder
    ladder
    step(jump: true)
    assert_equal Player::CLIMB, @player.vy
    step(fwd: 1.0)
    assert_equal Player::CLIMB, @player.vy
  end

  def test_sneak_holds_on_to_a_ladder_and_nothing_slides_down
    ladder
    @player.move_to(8.5, FLOOR + 1.0, 8.5)
    step(down: true)
    assert_equal 0.0, @player.vy
    assert_equal FLOOR + 1.0, @player.y
    step
    assert_equal(-Player::SLIDE, @player.vy)
    step(jump: true)
    step(down: true)
    assert_equal 0.0, @player.vy
  end

  def test_a_ladder_at_the_feet_or_at_the_head_climbs
    @world.set(8, FLOOR, 8, Block::LADDER)
    step(jump: true)
    assert_equal Player::CLIMB, @player.vy
    @world.set(8, FLOOR, 8, Block::AIR)
    @world.set(8, FLOOR + 1, 8, Block::LADDER)
    @player.move_to(8.5, FLOOR.to_f, 8.5)
    step(jump: true)
    assert_equal Player::CLIMB, @player.vy
  end

  def test_a_flying_player_does_not_climb
    ladder
    @player.flying = true
    step
    assert_equal 0.0, @player.vy
  end

  def test_a_ladder_takes_away_the_fall
    ladder
    @player.move_to(8.5, FLOOR + 3.0, 8.5)
    falls = Array.new(100) { step }
    assert_equal 0.0, falls.max
  end

  def test_a_ladder_in_water_climbs_at_the_swim_speed
    ladder
    pool(FLOOR, 1)
    @world.set(8, FLOOR, 8, Block::LADDER)
    step(jump: true)
    assert_equal Player::CLIMB, @player.vy
    walk(1.0, strafe: 1.0)
    assert_in_delta Player::SWIM, @player.speed, 0.01
  end

  # Each flight starts at the south edge of the chunk, so that it stays
  # over the floor. Out of the chunk, the terrain is low, and the flight
  # there gets a boost (Player#fly_boost).
  def test_the_player_flies_at_the_flight_speed_with_no_gravity
    @player.flying = true
    @player.move_to(8.5, FLOOR.to_f, 15.9)
    walk(0.5, fwd: 1.0)
    assert_in_delta Player::FLY, @player.speed, 0.01
    assert_equal FLOOR.to_f, @player.y
    @player.move_to(8.5, FLOOR.to_f, 15.9)
    walk(0.5, fwd: 1.0, sprint: true)
    assert_in_delta Player::SPRINT_FLY, @player.speed, 0.01
  end

  # The speed up or down gets 10 * DT closer to its aim each step. At the
  # floor, the aim is Player::FLY_UP.
  def test_jump_flies_up_and_sneak_flies_down
    @player.flying = true
    step(jump: true)
    assert_in_delta Player::FLY_UP * 10.0 * DT, @player.vy, 1.0e-9
    walk(1.0, jump: true)
    assert_operator @player.vy, :>, Player::FLY_UP
    walk(0.5, down: true)
    assert_operator @player.vy, :<, -Player::FLY_UP
    walk(1.0, jump: true, down: true)
    assert_in_delta 0.0, @player.vy, 0.001
  end

  def test_flight_high_above_the_ground_is_faster
    @player.flying = true
    @player.y = @world.height_at(8, 8) + Player::FLY_HIGH * 2.0
    walk(1.0, fwd: 1.0)
    assert_in_delta Player::FLY * Player::FLY_BOOST, @player.speed, 0.1
    walk(1.0, jump: true)
    assert_in_delta Player::FLY_UP * Player::FLY_BOOST, @player.vy, 0.01
  end

  def test_a_flying_player_does_not_sneak
    @player.flying = true
    walk(0.5, down: true)
    assert_in_delta Player::EYE, @player.eye_y - @player.y, 1.0e-9
  end

  # minecraft.wiki/w/Damage
  def test_an_attack_in_a_fall_is_critical
    refute @player.falling_attack?
    step(jump: true)
    refute @player.falling_attack?
    20.times { step }
    assert @player.falling_attack?
  end

  def test_an_attack_in_a_sprint_or_on_a_ladder_or_in_water_is_not_critical
    walk(0.5, fwd: 1.0, sprint: true)
    step(fwd: 1.0, sprint: true, jump: true)
    20.times { step(fwd: 1.0, sprint: true) }
    assert_operator @player.vy, :<, 0.0
    refute @player.falling_attack?
    ladder
    @player.move_to(8.5, FLOOR + 1.0, 8.5)
    step
    refute @player.falling_attack?
    pool(FLOOR, 8)
    @player.move_to(10.5, FLOOR + 5.0, 10.5)
    walk(0.2)
    refute @player.falling_attack?
  end

  def test_an_attack_in_flight_is_not_critical
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    @player.flying = true
    walk(0.2, down: true)
    assert_operator @player.vy, :<, 0.0
    refute @player.falling_attack?
  end

  private

  def step(fwd: 0.0, strafe: 0.0, jump: false, down: false, sprint: false)
    @player.controls.hold(fwd, strafe, jump: jump, sneak: down, sprint: sprint)
    @player.update(@world, DT)
  end

  def walk(seconds, **keys)
    (seconds / DT).round.times { step(**keys) }
  end

  # Water, or another block, over the floor, depth cells deep.
  def pool(y, depth, block = Block::WATER)
    16.times { |x| 16.times { |z| depth.times { |k| @world.set(x, y + k, z, block) } } }
  end

  # A pillar of 3 blocks, with the player on top at the north edge.
  def pillar
    3.times { |y| @world.set(8, FLOOR + y, 8, Block::STONE) }
    @player.move_to(8.5, FLOOR + 3.0, 8.0 - Player::HALF + 0.05)
    walk(0.1)
  end

  # The fall of a player that drops from 20 blocks over the floor at a speed
  # that takes it from the air above the cell of the feet to the floor in
  # one step.
  def land_fast
    @player.move_to(8.5, FLOOR + 5.0, 8.5)
    step
    @player.move_to(8.5, FLOOR + 0.65, 8.5)
    @player.fall_start = FLOOR + 20.0
    @player.vy = -35.0
    step
  end

  # A ladder up the cells at 8, 8, from the floor 4 high.
  def ladder
    4.times { |y| @world.set(8, FLOOR + y, 8, Block::LADDER) }
  end
end
