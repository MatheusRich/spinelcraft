require_relative "test_helper"

class ClockTest < Minitest::Test
  def test_the_time_moves_on_by_a_day_in_20_minutes
    clock = Clock.new(0.0, 0)
    clock.advance(300.0)
    assert_in_delta 0.25, clock.time_of_day, 1.0e-9
    assert_equal 0, clock.day
  end

  def test_a_new_day_starts_at_6_00
    clock = Clock.new(0.99, 4)
    clock.advance(Clock::DAY_SECONDS * 0.02)
    assert_equal 5, clock.day
    assert_in_delta 0.01, clock.time_of_day, 1.0e-9
  end

  def test_a_long_step_counts_each_day_that_it_passes
    clock = Clock.new(0.5, 0)
    clock.advance(Clock::DAY_SECONDS * 2.75)
    assert_equal 3, clock.day
    assert_in_delta 0.25, clock.time_of_day, 1.0e-9
  end

  def test_the_tick_of_the_day
    assert_equal 18000, Clock.new(0.75, 3).ticks
    assert_equal 0, Clock.new(0.0, 3).ticks
  end

  def test_time_set_moves_the_time_of_day_and_keeps_the_day
    clock = Clock.new(0.3, 7)
    clock.set_ticks(18000)
    assert_equal 0.75, clock.time_of_day
    clock.set_ticks(Clock::DAY_TICKS + 6000)
    assert_equal 0.25, clock.time_of_day
    assert_equal 7, clock.day
  end

  def test_time_add_counts_the_whole_days_and_moves_the_rest
    clock = Clock.new(0.75, 0)
    clock.add_ticks(6000)
    assert_equal 1, clock.day
    assert_in_delta 0.0, clock.time_of_day, 1.0e-9
    clock.add_ticks(Command::MAX_TICKS)
    assert_equal 1 + Command::MAX_TICKS / Clock::DAY_TICKS, clock.day
    assert_in_delta (Command::MAX_TICKS % Clock::DAY_TICKS) / 24000.0, clock.time_of_day, 1.0e-9
  end

  def test_a_night_in_a_bed_ends_in_the_morning_of_the_next_day
    clock = Clock.new(0.75, 2)
    clock.skip_night
    assert_equal 3, clock.day
    assert_equal Clock::MORNING, clock.time_of_day
    assert_operator clock.daylight, :>, 0.5
  end

  def test_a_bed_works_from_tick_12542_to_23459_in_clear_weather
    clock = Clock.new(0.0, 0)
    clock.set_ticks(12541)
    refute clock.night?
    clock.set_ticks(12542)
    assert clock.night?
    clock.set_ticks(23459)
    assert clock.night?
    clock.set_ticks(23460)
    refute clock.night?
  end

  def test_a_bed_works_from_tick_12010_to_23991_in_rain
    clock = Clock.new(0.0, 0)
    clock.set_ticks(12009)
    refute clock.rainy_night?
    clock.set_ticks(12010)
    assert clock.rainy_night?
    clock.set_ticks(23991)
    assert clock.rainy_night?
    clock.set_ticks(23992)
    refute clock.rainy_night?
  end

  def test_the_hour_starts_at_6_00
    assert_equal 6, Clock.new(0.0, 0).hour
    assert_equal 12, Clock.new(0.25, 0).hour
    assert_equal 0, Clock.new(0.75, 0).hour
    assert_equal 5, Clock.new(0.99, 0).hour
  end

  def test_the_daylight_is_full_at_noon_and_lowest_at_midnight
    assert_equal 1.0, Clock.new(0.25, 0).daylight
    assert_equal 0.12, Clock.new(0.75, 0).daylight
    assert_in_delta 0.5, Clock.new(0.0, 0).daylight, 1.0e-9
    assert_in_delta 0.5 + 0.9 * Math.sin(0.05 * Math::PI * 2.0), Clock.new(0.05, 0).daylight, 1.0e-9
  end

  def test_the_moon_is_full_on_day_0_and_new_on_day_4_of_its_8_days
    assert_equal 0, Clock.new(0.5, 0).moon_phase
    assert_equal 1.0, Clock.new(0.5, 0).moon_lit
    assert_equal 4, Clock.new(0.5, 4).moon_phase
    assert_equal 0.0, Clock.new(0.5, 4).moon_lit
    assert_equal 1, Clock.new(0.5, 9).moon_phase
  end
end
