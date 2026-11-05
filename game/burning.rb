# The fire on a mob or the player after the sun, lava, a fire block or
# lightning sets it alight. It does 1 damage each second until it goes out
# or water puts it out.
class Burning
  # minecraft.wiki/w/Damage
  DAMAGE = 1.0
  DAMAGE_INTERVAL = 1.0
  # Seconds that lava sets a mob or the player on fire for. minecraft.wiki/w/Lava
  LAVA_SECONDS = 15.0

  attr_reader :seconds

  def initialize
    @seconds = 0.0
    @until_damage = 0.0
  end

  def lit? = @seconds > 0.0

  # Sets the fire to seconds, unless it burns for longer.
  def ignite(seconds)
    @seconds = seconds if @seconds < seconds
  end

  # Lava and a fire block hurt on their own, so the burning does its first
  # damage a full interval after the last frame in them.
  def ignite_in_source(seconds)
    ignite(seconds)
    @until_damage = DAMAGE_INTERVAL
  end

  def douse
    @seconds = 0.0
  end

  # Burns for dt seconds, and returns true when the fire does DAMAGE in that
  # time.
  def burn(dt)
    unless lit?
      @until_damage = 0.0
      return false
    end

    @seconds -= dt
    @until_damage -= dt
    return false if @until_damage > 0.0

    @until_damage = DAMAGE_INTERVAL
    true
  end
end
