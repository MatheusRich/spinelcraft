require_relative "test_helper"

# Bed.use: the player sleeps when the sky is dark enough and no monster is
# near, and the night passes. minecraft.wiki/w/Bed
class BedTest < Minitest::Test
  X = 8
  Y = SKY_Y
  Z = 8

  def setup
    @clock = Clock.new(0.75, 3)
  end

  def test_at_night_the_night_passes
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, 4, [], @clock)
    assert_equal Clock::MORNING, @clock.time_of_day
    assert_equal 4, @clock.day
  end

  def test_by_day_the_player_cannot_sleep
    assert_equal "SPAWN SET: YOU CAN ONLY SLEEP AT NIGHT", Bed.use(X, Y, Z, 15, [], @clock)
    assert_equal 0.75, @clock.time_of_day
  end

  def test_the_player_sleeps_at_a_sky_light_of_11_but_not_12
    assert_equal "SPAWN SET: YOU CAN ONLY SLEEP AT NIGHT", Bed.use(X, Y, Z, 12, [], @clock)
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, 11, [], @clock)
  end

  # Rain darkens the sky, so the time to sleep comes earlier in the evening.
  def test_in_rain_the_player_sleeps_earlier
    assert_equal "SPAWN SET: YOU CAN ONLY SLEEP AT NIGHT", Bed.use(X, Y, Z, Light.sky(12200, raining: false), [], @clock)
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, Light.sky(12200, raining: true), [], @clock)
  end

  def test_a_monster_within_8_blocks_across_keeps_the_player_awake
    assert_equal "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY", Bed.use(X, Y, Z, 4, [zombie(8.0, 0.0, 0.0)], @clock)
    assert_equal 0.75, @clock.time_of_day
    assert_equal "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY", Bed.use(X, Y, Z, 4, [zombie(0.0, 0.0, -8.0)], @clock)
    assert_equal "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY", Bed.use(X, Y, Z, 4, [zombie(0.0, 0.0, 8.0)], @clock)
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, 4, [zombie(8.1, 0.0, 0.0)], @clock)
  end

  def test_a_monster_farther_than_8_blocks_along_z_lets_the_player_sleep
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, 4, [zombie(0.0, 0.0, 8.1)], @clock)
  end

  def test_a_monster_up_to_5_blocks_up_or_down_keeps_the_player_awake
    assert_equal "YOU CANNOT SLEEP NOW: MONSTERS ARE NEARBY", Bed.use(X, Y, Z, 4, [zombie(0.0, -5.0, 0.0)], @clock)
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, 4, [zombie(0.0, 5.1, 0.0)], @clock)
  end

  def test_an_animal_or_a_dying_monster_lets_the_player_sleep
    cow = Animal.new(Mob::COW, X + 1.5, Y.to_f, Z + 0.5, 3)
    dying = zombie(1.0, 0.0, 0.0)
    dying.hp = 0.0
    assert_equal "GOOD MORNING", Bed.use(X, Y, Z, 4, [cow, dying], @clock)
  end

  private

  # A zombie at across, up and along from the middle of the bed.
  def zombie(across, up, along) = Monster.new(Mob::ZOMBIE, X + 0.5 + across, Y + up, Z + 0.5 + along, 9)
end
