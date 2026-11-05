require_relative "test_helper"

class BurningTest < Minitest::Test
  def test_a_new_burning_is_not_lit
    burning = Burning.new

    refute burning.lit?
    refute burning.burn(1.0)
  end

  def test_ignite_keeps_the_longer_fire
    burning = Burning.new
    burning.ignite(5.0)
    burning.ignite(2.0)

    assert_equal 5.0, burning.seconds
    burning.ignite(8.0)

    assert_equal 8.0, burning.seconds
  end

  # minecraft.wiki/w/Damage
  def test_the_fire_does_1_at_once_and_then_1_each_second
    burning = Burning.new
    burning.ignite(3.0)

    assert_equal [true, false, false, false, true], Array.new(5) { burning.burn(0.25) }
    assert_equal 1.75, burning.seconds
  end

  def test_the_fire_goes_out_when_its_seconds_run_out
    burning = Burning.new
    burning.ignite(1.0)
    burning.burn(1.0)

    refute burning.lit?
    refute burning.burn(1.0)
  end

  def test_a_doused_fire_does_no_damage
    burning = Burning.new
    burning.ignite(5.0)
    burning.douse

    refute burning.lit?
    refute burning.burn(1.0)
  end

  def test_a_source_waits_a_full_second_before_the_first_damage
    burning = Burning.new
    burning.ignite_in_source(Burning::LAVA_SECONDS)

    assert_equal [false, false, false, true], Array.new(4) { burning.burn(0.25) }
  end

  def test_a_source_keeps_the_longer_fire
    burning = Burning.new
    burning.ignite(20.0)
    burning.ignite_in_source(Burning::LAVA_SECONDS)

    assert_equal 20.0, burning.seconds
  end

  def test_a_fire_after_one_that_went_out_hurts_at_once
    burning = Burning.new
    burning.ignite(0.5)
    burning.burn(0.25)
    burning.burn(0.5)
    burning.burn(0.25)
    burning.ignite(5.0)

    assert burning.burn(0.25)
  end
end
