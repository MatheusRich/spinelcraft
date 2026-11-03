# minecraft.wiki/w/Bed
class Sleep
  FALL_ASLEEP = 101 / 20.0
  # The shade is at most 220 / 255 opaque, and clears in 10 ticks after the
  # night passes. The wiki does not give these values (Gui and Player in
  # Java Edition).
  WAKE_FADE = 10 / 20.0
  DARKEST = 220.0 / 255.0
  AWAKE = FALL_ASLEEP + WAKE_FADE

  def initialize(player)
    @player = player
    @bed = nil
    @time = AWAKE
    @first_cell = 0
  end

  def over? = @time >= FALL_ASLEEP

  def start(bed)
    @bed = bed
    @first_cell = bed.nearest_cell(@player.x.to_f, @player.z.to_f)
    @time = 0.0
    bed.lay(@player)
  end

  # True on the step that the night passes.
  def advance(dt, world, sky)
    return pass_time(dt) if over?
    return wake_early(world) unless sky.sleep_time?
    return wake_early(world) unless @bed.whole?(world)

    @time += dt
    return false if @time < FALL_ASLEEP

    @time = FALL_ASLEEP
    stand_up(world)
    true
  end

  def stop(world)
    return if over?

    @time = AWAKE
    stand_up(world)
  end

  def darkness = DARKEST * [@time / FALL_ASLEEP, 1.0 - (@time - FALL_ASLEEP) / WAKE_FADE].min.clamp(0.0, 1.0)

  private

  def pass_time(dt)
    @time += dt
    false
  end

  def wake_early(world)
    stop(world)
    false
  end

  def stand_up(world) = @bed.stand_beside(@player, world, @first_cell)
end
