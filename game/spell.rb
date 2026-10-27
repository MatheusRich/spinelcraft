# A spell of weather: a flag that turns on and off on its own timer, and a
# strength from 0 to 1 that follows the flag. Rain and thunder are each one
# Spell (see Weather).
class Spell
  # Seconds that the strength takes to go from none to full, or back. In
  # Java Edition the rain level moves 0.01 each tick toward its target, so a
  # full change takes 100 ticks. The wiki does not give this value:
  # minecraft.wiki/w/Rain and minecraft.wiki/w/Commands/weather do not
  # describe the change.
  FADE = 5.0

  # The strength of the spell, from 0 (none) to 1.
  attr_reader :strength
  # Seconds until the flag turns on or off.
  attr_accessor :timer

  # lasts and pauses are the ranges of seconds that the flag stays on and
  # off. rng gives the length of each.
  def initialize(rng, lasts, pauses)
    @rng = rng
    @lasts = lasts
    @pauses = pauses
    @on = false
    @strength = 0.0
    @timer = 0.0
  end

  def on? = @on

  # Turns the flag on or off, and sets how long it stays so. The strength
  # follows over FADE seconds.
  def start
    @on = true
    @timer = seconds(@lasts)
    self
  end

  def stop
    @on = false
    @timer = seconds(@pauses)
    self
  end

  # Moves the strength to the full strength of the flag, or to none, at once.
  def settle
    @strength = @on ? 1.0 : 0.0
  end

  # dt seconds of the timer and of the fade.
  def advance(dt)
    @timer -= dt
    turn if @timer <= 0.0
    step = dt / FADE
    @strength = (@on ? @strength + step : @strength - step).clamp(0.0, 1.0)
  end

  # The flag (1 or 0) and the seconds to its next change, for the save.
  def to_a = [@on ? 1 : 0, @timer]

  # Reads what to_a wrote from fields at at, and returns the place after it.
  def load(fields, at)
    @on = fields[at] == "1"
    @timer = fields[at + 1].to_f
    settle
    at + 2
  end

  private

  def turn = @on ? stop : start

  def seconds(range) = range.begin + @rng.rand01 * (range.end - range.begin)
end
