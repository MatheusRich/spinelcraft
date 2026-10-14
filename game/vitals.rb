# The health, hunger, air and fire of the player in survival. Lava sets
# the player on fire, air runs out under water, walking uses hunger, and a
# full stomach heals.
class Vitals
  MAX_HEALTH = 20
  MAX_HUNGER = 20
  # Seconds of air under water.
  MAX_AIR = 10.0

  attr_accessor :health, :hunger
  # Seconds of air left under water.
  attr_reader :air
  # Seconds that the player keeps burning after lava.
  attr_reader :fire

  def initialize
    @health = MAX_HEALTH
    @hunger = MAX_HUNGER
    @air = MAX_AIR
    @fire = 0.0
    # Seconds until the next point of fire damage, and of lava damage.
    @fire_tick = 0.0
    @lava_tick = 0.0
    @hunger_timer = 0.0
    @regen = 0.0
    @since_damage = 0.0
  end

  def dead? = @health <= 0
  def burning? = @fire > 0.0
  def hungry? = @hunger < MAX_HUNGER

  def hurt(amount)
    return if dead?
    @health -= amount
    @health = 0 if @health < 0
    @since_damage = 0.0
  end

  def eat(food)
    @hunger = [@hunger + food, MAX_HUNGER].min
  end

  def douse
    @fire = 0.0
  end

  # dt seconds of lava, fire, air, hunger and healing. in_lava is true when
  # the player touches lava, and under_water when the head is in water.
  # speed is the speed on the ground. Returns true when the player took
  # damage.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_vitals(dt, in_lava, under_water, speed)
    health = @health
    if in_lava
      @lava_tick -= dt
      if @lava_tick <= 0.0
        @lava_tick = 0.5
        hurt(4)
      end
      # Out of the lava, the player burns on for a while.
      @fire = 4.0
      @fire_tick = 1.0
    elsif burning?
      @fire -= dt
      @fire_tick -= dt
      if @fire_tick <= 0.0
        @fire_tick = 1.0
        hurt(1)
      end
    end
    if under_water
      @air -= dt
      if @air < 0.0
        @air += 1.0
        hurt(2)
      end
    else
      @air = MAX_AIR
    end
    @since_damage += dt
    @hunger_timer += dt * (speed > 5.0 ? 2.5 : 1.0)
    if @hunger_timer > 25.0
      @hunger_timer = 0.0
      @hunger -= 1 if @hunger > 0
    end
    @regen += dt
    if @regen > 4.0
      @regen = 0.0
      if @hunger >= 15 && @health < MAX_HEALTH && @since_damage > 5.0
        @health += 1
      elsif @hunger == 0 && @health > 1
        hurt(1)
      end
    end
    @health < health
  end
end
