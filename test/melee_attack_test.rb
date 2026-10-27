require_relative "test_helper"

class MeleeAttackTest < Minitest::Test
  SWORD = Block::IRON_SWORD
  AXE = Block::IRON_AXE

  Faller = Struct.new(:falling) do
    def falling_attack? = falling
  end
  FALLING = Faller.new(true)
  STANDING = Faller.new(false)

  def setup
    @melee_attack = MeleeAttack.new
  end

  def test_a_new_melee_has_the_cooldown_full
    @melee_attack.advance(10.0)
    assert_equal 1.0, @melee_attack.charge(SWORD)
  end

  def test_the_cooldown_starts_almost_empty_after_a_restart
    @melee_attack.advance(10.0)
    @melee_attack.restart
    assert_in_delta MeleeAttack::HALF_TICK * Block.attack_speed(SWORD), @melee_attack.charge(SWORD), 1.0e-9
  end

  def test_the_charge_grows_with_the_time_and_the_attack_speed
    @melee_attack.restart
    @melee_attack.advance(0.25)
    expected = (0.25 + MeleeAttack::HALF_TICK) * Block.attack_speed(SWORD)
    assert_in_delta expected, @melee_attack.charge(SWORD), 1.0e-9
  end

  def test_a_slower_weapon_fills_slower
    @melee_attack.restart
    @melee_attack.advance(0.3)
    assert_operator Block.attack_speed(SWORD), :>, Block.attack_speed(AXE)
    assert_operator @melee_attack.charge(SWORD), :>, @melee_attack.charge(AXE)
  end

  def test_the_charge_stays_at_1
    @melee_attack.advance(1000.0)
    assert_equal 1.0, @melee_attack.charge(SWORD)
  end

  def test_a_hit_does_the_damage_that_the_charge_scales
    @melee_attack.restart
    charge = @melee_attack.charge(SWORD)
    assert_in_delta Block.damage(SWORD) * (0.2 + 0.8 * charge * charge), @melee_attack.scaled_damage(SWORD), 1.0e-9
  end

  def test_a_hit_at_full_charge_does_all_of_the_damage
    @melee_attack.advance(10.0)
    assert_in_delta Block.damage(SWORD), @melee_attack.scaled_damage(SWORD), 1.0e-9
  end

  def test_a_falling_attack_with_a_full_cooldown_is_critical
    @melee_attack.advance(10.0)
    assert @melee_attack.critical?(SWORD, FALLING)
  end

  def test_an_attack_that_does_not_fall_is_not_critical
    @melee_attack.advance(10.0)
    refute @melee_attack.critical?(SWORD, STANDING)
  end

  def test_a_falling_attack_with_an_empty_cooldown_is_not_critical
    @melee_attack.restart
    refute @melee_attack.critical?(SWORD, FALLING)
  end

  def test_the_critical_hit_starts_at_84_8_percent
    speed = Block.attack_speed(SWORD)
    @melee_attack.advance(0.848 / speed - MeleeAttack::HALF_TICK + 1.0e-6)
    assert @melee_attack.critical?(SWORD, FALLING)
    @melee_attack.restart
    @melee_attack.advance(0.848 / speed - MeleeAttack::HALF_TICK - 1.0e-6)
    refute @melee_attack.critical?(SWORD, FALLING)
  end

  def test_a_critical_hit_at_exactly_84_8_percent
    # A hand fills 4 for each second, and 0.187 + 0.025 seconds is 0.848.
    @melee_attack.advance(0.187)
    assert_equal 0.848, @melee_attack.charge(Block::AIR)
    assert @melee_attack.critical?(Block::AIR, FALLING)
  end

  def test_a_critical_hit_does_one_and_a_half_times_the_damage
    @melee_attack.advance(10.0)
    plain = @melee_attack.damage(SWORD, STANDING)
    assert_in_delta plain * 1.5, @melee_attack.damage(SWORD, FALLING), 1.0e-9
  end

  def test_a_hit_in_creative_does_10_damage_whatever_the_cooldown
    @melee_attack.restart
    assert_in_delta 10.0, @melee_attack.creative_damage, 1.0e-9
    @melee_attack.advance(10.0)
    assert_in_delta 10.0, @melee_attack.creative_damage, 1.0e-9
  end
end
