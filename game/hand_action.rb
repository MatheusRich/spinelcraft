# What the hand of the player does over time: nothing, mining a block,
# eating, or drawing the bow. The hand does one of these at a time, so a
# start of one ends the other. Game acts on what this class reports: it
# breaks the block, eats the food and shoots the arrow.
class HandAction
  IDLE = 0
  MINING = 1
  EATING = 2
  DRAWING = 3

  # What a step of eating gives (see chew).
  CHEWING = 0
  BITE = 1
  SWALLOW = 2

  # Eating takes 32 ticks. minecraft.wiki/w/Food
  EAT_TIME = 1.6
  # A bite plays each 4 ticks after the first 7 ticks of eating, as in
  # Minecraft (LivingEntity.shouldTriggerItemUseEffects, not on the wiki).
  CHEW_START = 0.35
  CHEW_EVERY = 0.2
  # Seconds before the next block starts to break, after a block that did
  # not break at once: 6 ticks. minecraft.wiki/w/Breaking
  MINE_DELAY = 0.3
  DIG_SOUND_EVERY = 0.25
  # The seconds of a meal or a draw that the hand does not do.
  NONE = -1.0

  # The World.key of the block that the hand mines, and the part of it
  # that is broken.
  attr_reader :mined_key, :mining_progress

  def initialize
    @state = IDLE
    @seconds = 0.0
    @mined_key = 0
    @mining_progress = 0.0
    @dig_wait = 0.0
    @mine_delay = 0.0
  end

  def mining? = @state == MINING

  def eating? = @state == EATING

  def drawing? = @state == DRAWING

  def using_item? = eating? || drawing?

  def stop
    @state = IDLE
  end

  def stop_using_item
    stop if using_item?
  end

  # dt seconds of the pause after the last block broke. True when the
  # pause is over.
  def pause_over?(dt)
    @mine_delay -= dt
    @mine_delay <= 0.0
  end

  # The hand mines the block at the World.key key. A new block starts with
  # no progress.
  def mine_block(key)
    return if mining? && key == @mined_key

    @state = MINING
    @mined_key = key
    @mining_progress = 0.0
    @dig_wait = 0.0
  end

  # Adds part to the broken part of the block.
  def break_more(part)
    @mining_progress += part
  end

  def broken? = @mining_progress >= 1.0

  # dt more seconds of the dig sound. True when it plays again.
  def dig_sound_due?(dt)
    @dig_wait -= dt
    return false if @dig_wait > 0.0

    @dig_wait = DIG_SOUND_EVERY
    true
  end

  # The block broke. Only a block with a hardness makes the hand wait.
  def finish_block(hardness)
    @mine_delay = MINE_DELAY if hardness > 0.0
    stop
  end

  # dt more seconds of eating: CHEWING, BITE when a bite plays, or SWALLOW
  # when the meal ends.
  def chew(dt)
    before = eating? ? @seconds : 0.0
    @state = EATING
    @seconds = before + dt
    if @seconds >= EAT_TIME
      stop
      return SWALLOW
    end
    return BITE if @seconds >= CHEW_START && bite_count(@seconds) != bite_count(before)

    CHEWING
  end

  # dt more seconds of the draw of the bow.
  def draw_bow(dt)
    @seconds = 0.0 unless drawing?
    @state = DRAWING
    @seconds += dt
  end

  def eat_seconds = eating? ? @seconds : NONE

  def draw_seconds = drawing? ? @seconds : NONE

  private

  def bite_count(seconds) = ((seconds - CHEW_START) / CHEW_EVERY).floor
end
