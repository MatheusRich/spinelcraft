require_relative "test_helper"

class VitalsTest < Minitest::Test
  DT = 0.05

  # 400 meters of sprint take 40 exhaustion: the 5 points of saturation,
  # then 5 points of hunger.
  def test_standing_still_costs_no_hunger_and_a_sprint_does
    vitals = Vitals.new
    1200.times { vitals.update_vitals(DT, false, false, false) }
    assert_equal Vitals::MAX_HUNGER, vitals.hunger
    vitals.move(400.0, true, false, false)
    vitals.update_vitals(DT, false, false, false)
    assert_equal 15, vitals.hunger
  end

  # Full hunger with 3 saturation heals 3 / 6 each half second, for 3
  # exhaustion.
  def test_a_full_stomach_with_saturation_heals_each_half_second
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.saturation = 3.0
    11.times { vitals.update_vitals(DT, false, false, false) }
    assert_equal 10.5, vitals.health
    assert_in_delta 3.0, vitals.exhaustion, 0.01
  end

  # 18 hunger heals 1 each 4 seconds, for 6 exhaustion.
  def test_18_hunger_heals_1_each_4_seconds
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.hunger = 18
    vitals.saturation = 0.0
    79.times { vitals.update_vitals(DT, false, false, false) }
    assert_equal 10.0, vitals.health
    2.times { vitals.update_vitals(DT, false, false, false) }
    assert_equal 11.0, vitals.health
  end
end
