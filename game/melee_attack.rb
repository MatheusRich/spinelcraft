# The melee attack of the player: how long ago the last attack was, how full
# the attack cooldown is, and the damage of a hit. The item in the hand
# gives the damage and the attack speed (Block.damage, Block.attack_speed),
# so each method takes it as an argument. minecraft.wiki/w/Melee_attack
class MeleeAttack
  # Half a tick, in seconds, that the charge counts ahead.
  HALF_TICK = 0.025
  # A falling attack with the cooldown at 84.8% or more is a critical hit:
  # 1.5 times the damage. minecraft.wiki/w/Damage
  CRIT_CHARGE = 0.848
  CRIT_MULTIPLIER = 1.5
  CREATIVE_DAMAGE = 10.0

  def initialize
    @time = 0.0
  end

  # An attack, a miss, a broken block and a new item in the hand start the
  # cooldown again.
  def restart
    @time = 0.0
  end

  def advance(dt)
    @time += dt
  end

  # The damage of a hit on a mob in survival, with the critical hit.
  def damage(item, player) = scaled_damage(item) * critical_multiplier(item, player)

  # The damage of a hit on a mob in creative: the same for each item, cooldown
  # and fall.
  def creative_damage = CREATIVE_DAMAGE

  def critical_multiplier(item, player)
    return CRIT_MULTIPLIER if critical?(item, player)

    1.0
  end

  # True when a hit of player with item is a critical hit: the player falls,
  # and the cooldown is full enough.
  def critical?(item, player) = player.falling_attack? && charge(item) >= CRIT_CHARGE

  # The damage of a hit with item at the charge of now: 0.2 + 0.8 * charge *
  # charge of its damage.
  def scaled_damage(item)
    filled = charge(item)
    Block.damage(item) * (0.2 + 0.8 * filled * filled)
  end

  # How full the attack cooldown is with item in the hand, from 0 to 1.
  def charge(item) = ((@time + HALF_TICK) * Block.attack_speed(item)).clamp(0.0, 1.0)
end
