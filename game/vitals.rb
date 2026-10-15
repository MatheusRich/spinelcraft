# The health, hunger, air and fire of the player in survival, with the
# values of Minecraft on Normal difficulty. Lava sets the player on fire,
# air runs out under water, and a full stomach heals.
#
# Hunger works as in Minecraft (minecraft.wiki/w/Hunger). Actions add
# exhaustion. Each 4 points of exhaustion take 1 point of saturation, or 1
# point of hunger when the saturation is empty. Food gives back hunger and
# saturation.
class Vitals
  MAX_HEALTH = 20.0
  MAX_HUNGER = 20
  # Seconds of air under water. minecraft.wiki/w/Damage (Drowning)
  MAX_AIR = 15.0
  # Seconds of air that come back each second: 1 of the 10 bubbles each 0.2
  # seconds. minecraft.wiki/w/Damage (Drowning)
  AIR_REFILL = MAX_AIR / 10.0 / 0.2
  # Seconds that lava sets the player on fire for. minecraft.wiki/w/Lava
  LAVA_FIRE = 15.0
  # Exhaustion for one point of saturation or hunger.
  EXHAUSTION_STEP = 4.0
  # Exhaustion for each meter of sprint and of swim, each jump and each
  # sprint jump, each attack, each hit taken, and each block broken.
  SPRINT_COST = 0.1
  SWIM_COST = 0.01
  JUMP_COST = 0.05
  SPRINT_JUMP_COST = 0.2
  ATTACK_COST = 0.1
  HURT_COST = 0.1
  MINE_COST = 0.005
  # Exhaustion for each point of health that comes back.
  HEAL_COST = 6.0
  # A heal with saturation uses at most this much of it. minecraft.wiki/w/Hunger
  HEAL_SATURATION = 6.0
  # The player cannot sprint with this much hunger or less.
  # minecraft.wiki/w/Sprinting
  SPRINT_HUNGER = 6
  # The Hunger effect of rotten flesh lasts 30 seconds and adds 0.005
  # exhaustion each tick, which is 0.1 each second.
  # minecraft.wiki/w/Rotten_Flesh and /w/Hunger_(effect)
  HUNGER_EFFECT_TIME = 30.0
  HUNGER_EFFECT_COST = 0.1

  attr_accessor :health, :hunger, :saturation, :exhaustion
  # Seconds of air left under water.
  attr_reader :air
  # Seconds that the player keeps burning after lava.
  attr_reader :fire
  # Seconds of the Hunger effect left.
  attr_reader :hunger_effect

  def initialize
    @health = MAX_HEALTH
    @hunger = MAX_HUNGER
    @saturation = 5.0
    @exhaustion = 0.0
    @air = MAX_AIR
    @fire = 0.0
    @hunger_effect = 0.0
    # Seconds until the next point of fire damage, of lava damage, and of
    # cactus damage.
    @fire_tick = 0.0
    @lava_tick = 0.0
    @cactus_tick = 0.0
    # Seconds toward the next heal, or toward the next starve damage.
    @regen = 0.0
  end

  def dead? = @health <= 0.0
  def burning? = @fire > 0.0
  def hungry? = @hunger < MAX_HUNGER
  def can_sprint? = @hunger > SPRINT_HUNGER
  def hunger_effect? = @hunger_effect > 0.0

  # A second dose starts the Hunger effect over and does not add to it.
  def give_hunger_effect
    @hunger_effect = HUNGER_EFFECT_TIME
  end

  # The Hunger effect is the only effect in the game.
  def clear_effects
    @hunger_effect = 0.0
  end

  def hurt(amount)
    return if dead?
    @health -= amount.to_f
    @health = 0.0 if @health < 0.0
    exhaust(HURT_COST)
  end

  def heal(amount)
    @health = [@health + amount, MAX_HEALTH].min
  end

  def exhaust(amount)
    @exhaustion += amount
  end

  # dist meters of movement in one step. A swim costs more than a walk, and
  # a sprint more than a swim.
  def move(dist, sprint, swim, jumped)
    exhaust(dist * SWIM_COST) if swim
    exhaust(dist * SPRINT_COST) if sprint && !swim
    exhaust(sprint ? SPRINT_JUMP_COST : JUMP_COST) if jumped
  end

  # Eating gives food points of hunger and sat points of saturation. The
  # saturation never goes above the hunger.
  def eat(food, sat)
    @hunger = [@hunger + food, MAX_HUNGER].min
    @saturation = [@saturation + sat, @hunger.to_f].min
  end

  def douse
    @fire = 0.0
  end

  # dt seconds of lava, fire, cactus, air, hunger and healing. in_lava is
  # true when the player touches lava, on_cactus when the player touches a
  # cactus, and under_water when the head is in water. Returns true when
  # the player took damage.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_vitals(dt, in_lava, on_cactus, under_water)
    health = @health
    # Lava does 4 each half second, and fire 1 each second, and drowning 2
    # each second. minecraft.wiki/w/Damage
    if in_lava
      @lava_tick -= dt
      if @lava_tick <= 0.0
        @lava_tick = 0.5
        hurt(4)
      end
      # Out of the lava, the player burns on for a while.
      @fire = LAVA_FIRE
      @fire_tick = 1.0
    elsif burning?
      @fire -= dt
      @fire_tick -= dt
      if @fire_tick <= 0.0
        @fire_tick = 1.0
        hurt(1)
      end
    end
    # A cactus does 1 each half second. minecraft.wiki/w/Cactus
    @cactus_tick -= dt
    if on_cactus && @cactus_tick <= 0.0
      @cactus_tick = 0.5
      hurt(1)
    end
    if under_water
      @air -= dt
      if @air < 0.0
        @air += 1.0
        hurt(2)
      end
    else
      @air = [@air + dt * AIR_REFILL, MAX_AIR].min
    end
    if hunger_effect?
      exhaust(dt * HUNGER_EFFECT_COST)
      @hunger_effect -= dt
    end
    digest
    update_regen(dt)
    @health < health
  end

  # Takes a point of saturation, or of hunger, for each EXHAUSTION_STEP.
  def digest
    while @exhaustion >= EXHAUSTION_STEP
      @exhaustion -= EXHAUSTION_STEP
      if @saturation > 0.0
        @saturation = [@saturation - 1.0, 0.0].max
      elsif @hunger > 0
        @hunger -= 1
      end
    end
  end

  # As in Minecraft (minecraft.wiki/w/Hunger): with full hunger and
  # saturation left, the player heals each half second, by a sixth of the
  # saturation up to 6, and that much saturation goes to exhaustion. With
  # 18 hunger or more, the player heals 1 each 4 seconds for 6 exhaustion.
  # With no hunger, the player starves 1 each 4 seconds, down to 1 health.
  def update_regen(dt)
    wounded = @health < MAX_HEALTH
    saturated = wounded && @saturation > 0.0 && @hunger >= MAX_HUNGER
    wait = if saturated
      0.5
    elsif wounded && @hunger >= 18
      4.0
    elsif @hunger <= 0
      4.0
    else
      0.0
    end
    if wait == 0.0
      @regen = 0.0
      return
    end
    @regen += dt
    return if @regen < wait
    @regen = 0.0
    if saturated
      used = [@saturation, HEAL_SATURATION].min
      heal(used / HEAL_SATURATION)
      exhaust(used)
    elsif @hunger > 0
      heal(1.0)
      exhaust(HEAL_COST)
    elsif @health > 1.0
      # Starving costs no exhaustion.
      @health -= 1.0
    end
  end
end
