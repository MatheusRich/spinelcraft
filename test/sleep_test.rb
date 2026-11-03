require_relative "test_helper"

# minecraft.wiki/w/Bed
class SleepTest < Minitest::Test
  FOOT_X = 8
  HEAD_X = 9
  Y = SKY_Y
  Z = 8
  NOON = 6000
  MIDNIGHT = 18000

  def setup
    @world = world_with_one_chunk
    (2..14).each do |x|
      (2..14).each { |z| @world.set(x, Y - 1, z, Block::STONE) }
    end
    @world.set(FOOT_X, Y, Z, Block.bed_id(1, false))
    @world.set(HEAD_X, Y, Z, Block.bed_id(0, true))
    @player = Player.new(FOOT_X - 0.5, Y.to_f, Z + 0.5)
    @sleep = @player.sleep
  end

  def test_the_player_lies_in_bed_at_once
    refute @player.in_bed?
    start
    assert @player.in_bed?
    assert_in_delta HEAD_X + 0.5, @player.x
  end

  def test_the_screen_darkens_and_the_night_passes_after_101_ticks
    start
    assert_in_delta 0.0, @sleep.darkness
    refute advance(Sleep::FALL_ASLEEP / 2.0)
    assert_in_delta Sleep::DARKEST / 2.0, @sleep.darkness
    refute advance(Sleep::FALL_ASLEEP / 2.0 - 0.01)
    assert @player.in_bed?
    assert advance(0.01)
    refute @player.in_bed?
    assert_in_delta FOOT_X - 0.5, @player.x
    assert_in_delta 1.0, @player.fx
    refute advance(1.0)
  end

  def test_after_the_night_the_screen_clears_in_10_ticks
    start
    advance(Sleep::FALL_ASLEEP + 1.0)
    assert_in_delta Sleep::DARKEST, @sleep.darkness
    advance(Sleep::WAKE_FADE / 2.0)
    assert_in_delta Sleep::DARKEST / 2.0, @sleep.darkness
    advance(Sleep::WAKE_FADE / 2.0)
    assert_in_delta 0.0, @sleep.darkness
    advance(1.0)
    assert_in_delta 0.0, @sleep.darkness
  end

  def test_the_player_who_stops_stands_up_and_the_screen_clears_at_once
    start
    advance(1.0)
    @sleep.stop(@world)
    refute @player.in_bed?
    assert_in_delta 0.0, @sleep.darkness
    assert_in_delta FOOT_X - 0.5, @player.x
    refute advance(Sleep::FALL_ASLEEP)
  end

  def test_daylight_gets_the_player_up_and_the_night_does_not_pass
    start
    refute @sleep.advance(1.0, @world, sky_at(NOON))
    refute @player.in_bed?
    assert_in_delta FOOT_X - 0.5, @player.x
  end

  def test_a_broken_bed_gets_the_player_up_and_the_night_does_not_pass
    start
    @world.set(HEAD_X, Y, Z, Block::AIR)
    refute advance(1.0)
    refute @player.in_bed?
    assert_in_delta FOOT_X - 0.5, @player.x
  end

  # Each hurt and each pause stops the sleep, also of a player out of bed.
  def test_a_player_out_of_bed_does_not_go_back_to_it
    start
    @sleep.stop(@world)
    @player.move_to(3.5, Y.to_f, 3.5)
    @sleep.stop(@world)
    assert_in_delta 3.5, @player.x
    advance(1.0)
    assert_in_delta 3.5, @player.x
  end

  def test_the_player_stands_up_where_they_got_in
    @player.move_to(HEAD_X + 0.5, Y.to_f, Z + 1.6)
    start
    @sleep.stop(@world)
    assert_in_delta HEAD_X + 0.5, @player.x
    assert_in_delta Z + 1.5, @player.z
  end

  def test_a_second_night_in_bed_starts_with_a_clear_screen
    start
    advance(3.0)
    @sleep.stop(@world)
    start
    assert_in_delta 0.0, @sleep.darkness
  end

  private

  def start = @sleep.start(Bed.new(@world, FOOT_X, Y, Z))

  def advance(dt) = @sleep.advance(dt, @world, sky_at(MIDNIGHT))

  def sky_at(tick)
    clock = Clock.new(0.0, 0)
    clock.set_ticks(tick)
    Sky.new(clock, Weather.new(1), Camera.new)
  end
end
