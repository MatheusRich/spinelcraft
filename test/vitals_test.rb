require_relative "test_helper"

class VitalsTest < Minitest::Test
  DT = 0.05
  # Frames of 0.25 seconds add up to whole half seconds with no float
  # error, so a timer reaches 0.0 exactly.
  QUARTER = 0.25

  def test_a_new_player_is_full_and_well
    vitals = Vitals.new
    refute vitals.dead?
    refute vitals.burning?
    refute vitals.hungry?
    assert vitals.can_sprint?
    refute vitals.hunger_effect?
  end

  def test_the_player_is_dead_at_0_health
    vitals = Vitals.new
    vitals.hurt(20)
    assert_equal 0.0, vitals.health
    assert vitals.dead?
  end

  def test_a_hit_takes_health_down_to_0_and_adds_exhaustion
    vitals = Vitals.new
    vitals.hurt(25)
    assert_equal 0.0, vitals.health
    assert_in_delta Vitals::HURT_COST, vitals.exhaustion
  end

  def test_a_kill_takes_all_health_and_adds_exhaustion
    vitals = Vitals.new
    vitals.hurt(7)
    vitals.kill
    assert_equal 0.0, vitals.health
    assert vitals.dead?
    assert_in_delta Vitals::HURT_COST * 2, vitals.exhaustion
  end

  def test_a_dead_player_takes_no_more_hits
    vitals = Vitals.new
    vitals.hurt(20)
    vitals.hurt(1)
    assert_in_delta Vitals::HURT_COST, vitals.exhaustion
  end

  def test_a_heal_stops_at_full_health
    vitals = Vitals.new
    vitals.health = 19.0
    vitals.heal(5.0)
    assert_equal Vitals::MAX_HEALTH, vitals.health
  end

  def test_the_player_is_hungry_below_full_hunger
    vitals = Vitals.new
    vitals.hunger = Vitals::MAX_HUNGER - 1
    assert vitals.hungry?
  end

  # minecraft.wiki/w/Sprinting
  def test_the_player_cannot_sprint_with_6_hunger_or_less
    vitals = Vitals.new
    vitals.hunger = 7
    assert vitals.can_sprint?
    vitals.hunger = 6
    refute vitals.can_sprint?
  end

  def test_food_stops_at_full_hunger_and_saturation_stops_at_the_hunger
    vitals = Vitals.new
    vitals.hunger = 10
    vitals.saturation = 0.0
    vitals.eat(4, 9.6)
    assert_equal 14, vitals.hunger
    assert_equal 9.6, vitals.saturation
    vitals.eat(8, 12.8)
    assert_equal Vitals::MAX_HUNGER, vitals.hunger
    assert_equal 20.0, vitals.saturation
  end

  def test_a_swim_a_sprint_and_a_jump_each_add_their_exhaustion
    vitals = Vitals.new
    vitals.move(10.0, false, true, false)
    assert_in_delta 10.0 * Vitals::SWIM_COST, vitals.exhaustion
    vitals = Vitals.new
    vitals.move(10.0, true, false, false)
    assert_in_delta 10.0 * Vitals::SPRINT_COST, vitals.exhaustion
    vitals = Vitals.new
    vitals.move(0.0, false, false, true)
    assert_in_delta Vitals::JUMP_COST, vitals.exhaustion
    vitals = Vitals.new
    vitals.move(0.0, true, false, true)
    assert_in_delta Vitals::SPRINT_JUMP_COST, vitals.exhaustion
  end

  def test_a_walk_costs_nothing_and_a_sprint_in_water_costs_as_a_swim
    vitals = Vitals.new
    vitals.move(10.0, false, false, false)
    assert_equal 0.0, vitals.exhaustion
    vitals.move(10.0, true, true, false)
    assert_in_delta 10.0 * Vitals::SWIM_COST, vitals.exhaustion
  end

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

  def test_exhaustion_takes_the_last_point_of_hunger_and_no_more
    vitals = Vitals.new
    vitals.hunger = 1
    vitals.saturation = 0.0
    vitals.exhaust(8.0)
    vitals.digest
    assert_equal 0, vitals.hunger
  end

  # Lava does 4 each half second, and the player burns for 15 seconds after
  # it. Armor lowers the lava damage, so Vitals leaves it for the game to
  # take. minecraft.wiki/w/Damage and /w/Lava
  def test_lava_gives_4_each_half_second_for_armor_and_sets_the_player_on_fire
    vitals = unhealing
    refute vitals.update_vitals(QUARTER, true, false, false)
    assert_equal 4.0, vitals.take_armorable_damage
    assert_equal 20.0, vitals.health
    assert vitals.burning?
    vitals.update_vitals(QUARTER, true, false, false)
    assert_equal 0.0, vitals.take_armorable_damage
    vitals.update_vitals(QUARTER, true, false, false)
    assert_equal 4.0, vitals.take_armorable_damage
    assert_equal Vitals::LAVA_FIRE, vitals.fire
  end

  # Fire does 1 each second. minecraft.wiki/w/Damage
  def test_out_of_the_lava_the_player_burns_1_each_second
    vitals = unhealing
    vitals.update_vitals(QUARTER, true, false, false)
    vitals.hurt(vitals.take_armorable_damage)
    3.times { refute vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 16.0, vitals.health
    assert vitals.update_vitals(QUARTER, false, false, false)
    assert_equal 15.0, vitals.health
    assert_equal Vitals::LAVA_FIRE - 1.0, vitals.fire
    3.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 15.0, vitals.health
    vitals.update_vitals(QUARTER, false, false, false)
    assert_equal 14.0, vitals.health
  end

  def test_the_fire_goes_out_after_15_seconds_or_when_doused
    vitals = unhealing
    vitals.update_vitals(QUARTER, true, false, false)
    vitals.health = Vitals::MAX_HEALTH
    60.times { vitals.update_vitals(QUARTER, false, false, false) }
    refute vitals.burning?
    burnt = vitals.health
    4.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal burnt, vitals.health
    vitals.update_vitals(QUARTER, true, false, false)
    vitals.douse
    refute vitals.burning?
  end

  # A cactus does 1 each half second, and armor lowers it.
  # minecraft.wiki/w/Cactus
  def test_a_cactus_gives_1_each_half_second_for_armor
    vitals = unhealing
    vitals.update_vitals(QUARTER, false, true, false)
    assert_equal 1.0, vitals.take_armorable_damage
    vitals.update_vitals(QUARTER, false, true, false)
    assert_equal 0.0, vitals.take_armorable_damage
    vitals.update_vitals(QUARTER, false, true, false)
    assert_equal 1.0, vitals.take_armorable_damage
    assert_equal 20.0, vitals.health
  end

  # Air lasts 15 seconds, then drowning does 2 each second.
  # minecraft.wiki/w/Damage (Drowning)
  def test_drowning_does_2_each_second_after_15_seconds_of_air
    vitals = unhealing
    60.times { refute vitals.update_vitals(QUARTER, false, false, true) }
    assert_equal Vitals::MAX_HEALTH, vitals.health
    assert_equal 0.0, vitals.air
    assert vitals.update_vitals(QUARTER, false, false, true)
    assert_equal 18.0, vitals.health
    3.times { vitals.update_vitals(QUARTER, false, false, true) }
    assert_equal 18.0, vitals.health
    vitals.update_vitals(QUARTER, false, false, true)
    assert_equal 16.0, vitals.health
  end

  # 1 of the 10 bubbles comes back each 0.2 seconds.
  def test_air_comes_back_out_of_the_water
    vitals = Vitals.new
    60.times { vitals.update_vitals(QUARTER, false, false, true) }
    vitals.update_vitals(1.0, false, false, false)
    assert_equal Vitals::MAX_AIR / 2.0, vitals.air
    vitals.update_vitals(2.0, false, false, false)
    assert_equal Vitals::MAX_AIR, vitals.air
  end

  # The Hunger effect adds 0.1 exhaustion each second for 30 seconds.
  # minecraft.wiki/w/Hunger_(effect)
  def test_the_hunger_effect_adds_exhaustion_for_30_seconds
    vitals = Vitals.new
    vitals.give_hunger_effect
    assert vitals.hunger_effect?
    120.times { vitals.update_vitals(QUARTER, false, false, false) }
    refute vitals.hunger_effect?
    assert_in_delta 3.0, vitals.exhaustion, 0.01
    4.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_in_delta 3.0, vitals.exhaustion, 0.01
  end

  def test_milk_clears_the_hunger_effect
    vitals = Vitals.new
    vitals.give_hunger_effect
    vitals.clear_effects
    refute vitals.hunger_effect?
  end

  # Full hunger with 3 saturation heals 3 / 6 each half second, for 3
  # exhaustion. minecraft.wiki/w/Hunger
  def test_a_full_stomach_with_saturation_heals_each_half_second
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.saturation = 3.0
    vitals.update_vitals(QUARTER, false, false, false)
    assert_equal 10.0, vitals.health
    vitals.update_vitals(QUARTER, false, false, false)
    assert_equal 10.5, vitals.health
    assert_in_delta 3.0, vitals.exhaustion, 0.01
  end

  # 18 hunger heals 1 each 4 seconds, for 6 exhaustion.
  def test_18_hunger_heals_1_each_4_seconds
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.hunger = 18
    vitals.saturation = 0.0
    15.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 10.0, vitals.health
    vitals.update_vitals(QUARTER, false, false, false)
    assert_equal 11.0, vitals.health
    assert_in_delta Vitals::HEAL_COST, vitals.exhaustion, 0.01
  end

  def test_full_hunger_with_no_saturation_heals_1_each_4_seconds
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.saturation = 0.0
    16.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 11.0, vitals.health
    vitals.update_vitals(QUARTER, false, false, false)
    assert_equal 11.0, vitals.health
    15.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 12.0, vitals.health
  end

  def test_saturation_without_full_hunger_heals_only_each_4_seconds
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.hunger = 19
    vitals.saturation = 3.0
    15.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 10.0, vitals.health
  end

  def test_less_than_18_hunger_does_not_heal
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.hunger = 17
    vitals.saturation = 0.0
    40.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 10.0, vitals.health
  end

  # The 4 seconds start again when the player stops healing.
  def test_the_heal_wait_starts_again_after_full_health
    vitals = Vitals.new
    vitals.health = 10.0
    vitals.hunger = 18
    vitals.saturation = 0.0
    12.times { vitals.update_vitals(QUARTER, false, false, false) }
    vitals.health = Vitals::MAX_HEALTH
    vitals.update_vitals(QUARTER, false, false, false)
    vitals.health = 10.0
    6.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 10.0, vitals.health
  end

  # With no hunger, the player starves 1 each 4 seconds, down to 1 health.
  # Starving costs no exhaustion. minecraft.wiki/w/Hunger
  def test_an_empty_stomach_starves_1_each_4_seconds_down_to_1_health
    vitals = Vitals.new
    vitals.health = 2.0
    vitals.hunger = 0
    vitals.saturation = 0.0
    16.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 1.0, vitals.health
    assert_equal 0, vitals.hunger
    32.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 1.0, vitals.health
    assert_equal 0.0, vitals.exhaustion
  end

  def test_one_point_of_hunger_at_full_health_costs_no_exhaustion
    vitals = Vitals.new
    vitals.hunger = 1
    vitals.saturation = 0.0
    20.times { vitals.update_vitals(QUARTER, false, false, false) }
    assert_equal 1, vitals.hunger
    assert_equal 0.0, vitals.exhaustion
  end

  private

  # A player with 17 hunger and no saturation does not heal and does not
  # starve, so only the damage changes the health.
  def unhealing
    vitals = Vitals.new
    vitals.hunger = 17
    vitals.saturation = 0.0
    vitals
  end
end
