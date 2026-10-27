require_relative "test_helper"

class SpellTest < Minitest::Test
  LASTS = 10.0..20.0
  PAUSES = 100.0..200.0

  def setup
    @spell = Spell.new(Rng.new(1), LASTS, PAUSES)
  end

  def test_a_new_spell_is_off_and_has_no_strength
    refute @spell.on?
    assert_equal 0.0, @spell.strength
  end

  def test_start_turns_it_on_for_a_time_of_the_lasts_range_and_stop_for_one_of_the_pauses_range
    @spell.start
    assert @spell.on?
    assert LASTS.cover?(@spell.timer)
    @spell.stop
    refute @spell.on?
    assert PAUSES.cover?(@spell.timer)
  end

  def test_the_strength_follows_the_flag_over_the_fade_time
    @spell.start
    @spell.advance(Spell::FADE / 2.0)
    assert_in_delta 0.5, @spell.strength, 1e-9
    @spell.advance(Spell::FADE)
    assert_equal 1.0, @spell.strength
    @spell.stop
    @spell.advance(Spell::FADE / 4.0)
    assert_in_delta 0.75, @spell.strength, 1e-9
  end

  def test_settle_moves_the_strength_to_the_flag_at_once
    @spell.start.settle
    assert_equal 1.0, @spell.strength
    @spell.stop.settle
    assert_equal 0.0, @spell.strength
  end

  def test_the_flag_turns_over_when_the_timer_ends
    @spell.timer = 1.0
    @spell.advance(1.5)
    assert @spell.on?
    @spell.timer = 1.0
    @spell.advance(1.5)
    refute @spell.on?
  end

  def test_the_save_fields_load_back_at_full_strength
    @spell.start
    @spell.timer = 77.5
    other = Spell.new(Rng.new(2), LASTS, PAUSES)
    assert_equal 5, other.load((["x", "x", "x"] + @spell.to_a).map(&:to_s), 3)
    assert other.on?
    assert_equal 77.5, other.timer
    assert_equal 1.0, other.strength
  end
end
