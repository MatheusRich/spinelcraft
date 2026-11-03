require_relative "test_helper"

# minecraft.wiki/w/Bed
class BedTest < Minitest::Test
  FOOT_X = 8
  HEAD_X = 9
  Y = SKY_Y
  Z = 8
  FOOT = Block.bed_id(1, false)
  HEAD = Block.bed_id(0, true)
  NIGHT = "SPAWN SET: YOU CAN ONLY SLEEP AT NIGHT"
  MONSTERS = "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY"
  NOON = 6000
  EVENING = 12200
  MIDNIGHT = 18000

  def setup
    @world = world_with_one_chunk
    (2..14).each do |x|
      (2..14).each { |z| @world.set(x, Y - 1, z, Block::STONE) }
    end
    @world.set(FOOT_X, Y, Z, FOOT)
    @world.set(HEAD_X, Y, Z, HEAD)
    @bed = Bed.new(@world, FOOT_X, Y, Z)
    @player = Player.new(FOOT_X - 0.5, Y.to_f, Z + 0.5)
  end

  def test_at_night_the_player_lies_down
    assert_nil reason(sky_at(MIDNIGHT), [])
    assert @player.in_bed?
  end

  def test_by_day_the_player_stays_up
    assert_equal NIGHT, reason(sky_at(NOON), [])
    refute @player.in_bed?
  end

  # Rain darkens the sky, so the time to sleep comes earlier in the evening.
  def test_in_rain_the_player_sleeps_earlier
    sky = sky_at(EVENING)
    assert_equal NIGHT, reason(sky, [])
    @weather.rain.start.settle
    assert_nil reason(sky, [])
  end

  def test_a_monster_within_8_blocks_across_of_the_head_keeps_the_player_awake
    assert_equal MONSTERS, reason_at_night([zombie(8.0, 0.0, 0.0)])
    assert_equal MONSTERS, reason_at_night([zombie(-8.0, 0.0, 0.0)])
    assert_equal MONSTERS, reason_at_night([zombie(0.0, 0.0, -8.0)])
    assert_equal MONSTERS, reason_at_night([zombie(0.0, 0.0, 8.0)])
    refute @player.in_bed?
    assert_nil reason_at_night([zombie(8.1, 0.0, 0.0)])
    assert_nil reason_at_night([zombie(0.0, 0.0, 8.1)])
  end

  def test_a_monster_up_to_5_blocks_up_or_down_keeps_the_player_awake
    assert_equal MONSTERS, reason_at_night([zombie(0.0, -5.0, 0.0)])
    assert_equal MONSTERS, reason_at_night([zombie(0.0, 5.0, 0.0)])
    assert_nil reason_at_night([zombie(0.0, 5.1, 0.0)])
  end

  def test_an_animal_or_a_dying_monster_lets_the_player_sleep
    cow = Animal.new(Mob::COW, HEAD_X + 1.5, Y.to_f, Z + 0.5, 3)
    dying = zombie(1.0, 0.0, 0.0)
    dying.hp = 0.0
    assert_nil reason_at_night([cow, dying])
  end

  def test_the_player_lies_with_the_head_on_the_head_and_looks_to_the_foot
    @player.pitch = -1.0
    @player.flying = true
    @bed.lay(@player)
    assert_in_delta HEAD_X + 0.5, @player.x
    assert_in_delta Z + 0.5, @player.z
    assert_in_delta Y + Block.box_top(HEAD) + Player::LYING_EYE, @player.eye_y
    assert_in_delta(-1.0, @player.fx)
    assert_in_delta 0.0, @player.fy
    refute @player.flying
  end

  def test_the_head_and_the_foot_are_one_bed
    Bed.new(@world, HEAD_X, Y, Z).lay(@player)
    assert_in_delta HEAD_X + 0.5, @player.x
    assert_in_delta(-1.0, @player.fx)
  end

  def test_the_player_stands_where_they_got_in_and_faces_the_head
    @bed.lay(@player)
    stand_up(FOOT_X - 0.5, Z + 0.5)
    assert_stands_at FOOT_X - 1, Y, Z
    assert_in_delta 1.0, @player.fx
    assert_in_delta Player::EYE, @player.eye_y - @player.y
  end

  def test_the_player_who_got_in_from_the_side_stands_on_that_side
    stand_up(HEAD_X + 0.5, Z + 1.6)
    assert_stands_at HEAD_X, Y, Z + 1
  end

  def test_the_player_who_got_in_beside_the_foot_stands_there
    stand_up(FOOT_X + 0.5, Z + 1.6)
    assert_stands_at FOOT_X, Y, Z + 1
  end

  def test_with_no_ground_where_they_got_in_the_player_stands_beside_the_foot
    @world.set(FOOT_X - 1, Y - 1, Z, Block::AIR)
    stand_up(FOOT_X - 0.5, Z + 0.5)
    assert_stands_at FOOT_X, Y, Z + 1
  end

  def test_the_player_stands_beside_lava_not_in_it
    @world.set(FOOT_X - 1, Y, Z, Block::LAVA)
    stand_up(FOOT_X - 0.5, Z + 0.5)
    assert_stands_at FOOT_X, Y, Z + 1
  end

  def test_the_player_steps_up_onto_a_block_beside_the_bed
    @world.set(FOOT_X - 1, Y, Z, Block::STONE)
    stand_up(FOOT_X - 0.5, Z + 0.5)
    assert_stands_at FOOT_X - 1, Y + 1, Z
  end

  def test_with_no_room_the_player_stands_up_on_the_bed
    (FOOT_X - 1..HEAD_X + 1).each do |x|
      (Z - 1..Z + 1).each { |z| @world.set(x, Y - 1, z, Block::AIR) }
    end
    @bed.lay(@player)
    stand_up(FOOT_X - 0.5, Z + 0.5)
    assert_in_delta HEAD_X + 0.5, @player.x
    assert_in_delta Player::EYE, @player.eye_y - @player.y
  end

  # A bed with its head to the south (+z). Only the cell west of the head
  # has ground, so the player tries each cell.
  def test_a_bed_along_z
    (2..14).each do |x|
      (2..14).each { |z| @world.set(x, Y - 1, z, Block::AIR) }
    end
    @world.set(FOOT_X - 1, Y - 1, Z + 2, Block::STONE)
    @world.set(HEAD_X, Y, Z, Block::AIR)
    @world.set(FOOT_X, Y, Z, Block.bed_id(3, false))
    @world.set(FOOT_X, Y, Z + 1, Block.bed_id(2, true))
    bed = Bed.new(@world, FOOT_X, Y, Z + 1)
    bed.lay(@player)
    assert_in_delta FOOT_X + 0.5, @player.x
    assert_in_delta Z + 1.5, @player.z
    assert_in_delta(-1.0, @player.fz)
    assert bed.whole?(@world)
    bed.stand_beside(@player, @world, bed.nearest_cell(FOOT_X + 0.5, Z - 0.5))
    assert_stands_at FOOT_X - 1, Y, Z + 2
    assert_in_delta 1.0, @player.fz
  end

  def test_the_bed_is_whole_until_it_breaks
    assert @bed.whole?(@world)
    @world.set(HEAD_X, Y, Z, Block::AIR)
    refute @bed.whole?(@world)
  end

  private

  # The reason that the bed yields, or nil when the player lies down.
  def reason(sky, mobs)
    said = nil
    @bed.use(@player, sky, mobs) { |text| said = text }
    said
  end

  def reason_at_night(mobs) = reason(sky_at(MIDNIGHT), mobs)

  def sky_at(tick)
    clock = Clock.new(0.0, 0)
    clock.set_ticks(tick)
    @weather = Weather.new(1)
    Sky.new(clock, @weather, Camera.new)
  end

  def stand_up(entry_x, entry_z) = @bed.stand_beside(@player, @world, @bed.nearest_cell(entry_x, entry_z))

  # A zombie at across, up and along from the middle of the head.
  def zombie(across, up, along) = Monster.new(Mob::ZOMBIE, HEAD_X + 0.5 + across, Y + up, Z + 0.5 + along, 9)

  def assert_stands_at(x, y, z)
    assert_in_delta x + 0.5, @player.x
    assert_in_delta y, @player.y
    assert_in_delta z + 0.5, @player.z
  end
end
