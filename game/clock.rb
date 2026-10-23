# The time of the world: the time of day and the count of days, as the
# daylight cycle of Minecraft. The time of day goes from 0.0 to 1.0, and
# 0.0 is 6:00 (tick 0). A new day starts at 6:00.
# minecraft.wiki/w/Daylight_cycle
class Clock
  # A day and a night last 20 minutes, or 24000 ticks.
  # minecraft.wiki/w/Daylight_cycle
  DAY_SECONDS = 1200.0
  DAY_TICKS = 24000
  # The lit part of the moon on each day of its 8-day cycle: full, waning
  # gibbous, third quarter, waning crescent, new, waxing crescent, first
  # quarter, waxing gibbous. The glow around the moon follows it.
  # minecraft.wiki/w/Moon gives the order, and the full moon on day 0. The
  # wiki does not give the lit parts.
  MOON_LIT = [1.0, 0.75, 0.5, 0.25, 0.0, 0.25, 0.5, 0.75]
  # The time of day after a night in a bed.
  MORNING = 0.02

  attr_accessor :time_of_day, :day

  def initialize(time_of_day, day)
    @time_of_day = time_of_day
    # The days since the world started, as Minecraft's daytime / 24000.
    @day = day
    nil
  end

  # Moves the time on by seconds. Each pass of 6:00 counts a new day.
  def advance(seconds)
    @time_of_day += seconds / DAY_SECONDS
    while @time_of_day >= 1.0
      @time_of_day -= 1.0
      @day += 1
    end
    nil
  end

  # The tick of the day, from 0 to DAY_TICKS - 1.
  def ticks = (@time_of_day * DAY_TICKS).to_i

  # /time set: the time of day of ticks. The day stays the same. The time
  # goes to the middle of the tick. At the start of the tick, a float error
  # can make ticks one less than the tick that it set.
  # minecraft.wiki/w/Commands/time
  def set_ticks(ticks)
    @time_of_day = (ticks % DAY_TICKS + 0.5) / DAY_TICKS
    nil
  end

  # /time add: the whole days count at once, and the rest moves the time on.
  # minecraft.wiki/w/Commands/time
  def add_ticks(ticks)
    @day += ticks / DAY_TICKS
    advance((ticks % DAY_TICKS) * DAY_SECONDS / DAY_TICKS)
  end

  # The morning after a night in a bed. A night is always before 6:00, so
  # the morning is on the next day.
  def skip_night
    @time_of_day = MORNING
    @day += 1
    nil
  end

  # The hour on a 24-hour clock, from 0 to 23.
  def hour = ((@time_of_day * 24.0 + 6.0) % 24.0).floor

  # The angle of the sun around the z axis, in radians: 0 when it rises at
  # 6:00, and PI / 2 at noon.
  def sun_angle = @time_of_day * Math::PI * 2.0

  # The light of the sun, from 0.12 at midnight to 1.0 by day.
  def daylight
    s = Math.sin(sun_angle)
    (0.5 + s * 0.9).clamp(0.12, 1.0)
  end

  # How bright the stars are, from 0.0 by day to 1.0 at night. The wiki
  # does not give the curve.
  def starlight = ((0.55 - daylight) * 2.5).clamp(0.0, 1.0)

  # The phase of the moon, from 0 (full) to 7.
  def moon_phase = @day % 8

  # The lit part of the moon tonight.
  def moon_lit = MOON_LIT[moon_phase]
end
