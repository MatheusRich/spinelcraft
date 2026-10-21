# The love mode of one animal: it eats its food, walks to a mate, and
# waits after the baby comes. Game#court_mates pairs the lovers, and
# Game#breed makes the baby. minecraft.wiki/w/Breeding
class Love
  # An animal that eats its food stays in love mode for 30 seconds, and
  # finds a mate in love mode up to 8 blocks away. After the baby comes,
  # the parents wait 5 minutes before they can breed again.
  # minecraft.wiki/w/Breeding
  TIME = 30.0
  MATE_REACH = 8.0
  BREED_WAIT = 300.0
  # Two mates make the baby when they are nearer than 3 blocks and have
  # walked to each other for 3 seconds. The wiki does not give these
  # values; they are those of the game code (BreedGoal: distanceToSqr < 9
  # and loveTime >= 60 ticks).
  MATE_NEAR = 3.0
  COURT_TIME = 3.0
  # An animal in love mode gives off one heart each 10 ticks. This is the
  # game code (Animal.aiStep), and not on the wiki. The wiki says that
  # Java Edition stopped to show these hearts in 15w33c, and that Bedrock
  # Edition shows them all the time. minecraft.wiki/w/Breeding
  HEART_EVERY = 0.5

  # Seconds that the animal still stays in love mode.
  attr_reader :left
  # Seconds before the animal can enter love mode again.
  attr_reader :wait
  # The place of the mate that the lover walks to (see court).
  attr_reader :mate_x, :mate_z
  # Seconds that the lover has walked to its mate.
  attr_reader :court_time
  # True when the lover gives off a heart, until Game#update_mobs shows it.
  attr_accessor :heart

  def initialize
    @left = 0.0
    @wait = 0.0
    @courting = false
    @mate_x = 0.0
    @mate_z = 0.0
    @court_time = 0.0
    @heart = false
    @heart_wait = 0.0
  end

  def on? = @left > 0.0

  # True while the lover walks to a mate.
  def courting? = @courting

  # The adult eats its food, and returns true when it enters love mode. It
  # does not while it is in love mode or waits after breeding. The rules
  # come from the game code (Animal.mobInteract); the wiki does not give
  # them all.
  def feed
    return false if on? || @wait > 0.0

    @left = TIME
    @heart_wait = HEART_EVERY
    true
  end

  # dt more seconds of love mode and of the wait after breeding.
  def clock(dt)
    if on?
      @left -= dt
      @heart_wait -= dt
      if @heart_wait <= 0.0
        @heart_wait += HEART_EVERY
        @heart = true
      end
    end
    # A heart shows only while the animal is still in love mode.
    @heart = false unless on?
    alone unless on?
    @wait -= dt if @wait > 0.0
  end

  # This lover walks to its mate at x, z.
  def court(x, z)
    @courting = true
    @mate_x = x
    @mate_z = z
  end

  # dt more seconds of the walk to the mate.
  def walk(dt)
    @court_time += dt
  end

  # This lover has no mate in reach.
  def alone
    @courting = false
    @court_time = 0.0
  end

  # The baby came: the parent leaves love mode and waits BREED_WAIT.
  def bred
    alone
    @left = 0.0
    @wait = BREED_WAIT
  end

  # A hit ends love mode. The wiki does not say; this is the game code
  # (Animal.hurt calls resetLove).
  def reset
    @left = 0.0
  end
end
