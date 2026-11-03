# The fire blocks that burn in the world. Fires keeps each fire with its
# age and the seconds until its next update, and FireSpread has the rules
# of an update. The age lives only here, so a fire that a chunk load
# brings back starts at age 0. minecraft.wiki/w/Fire
class Fires
  # A body in fire burns on for 160 ticks after it leaves.
  # minecraft.wiki/w/Fire
  BURN_SECONDS = 8.0
  # A fire block hurts a body in it each 0.5 seconds (the immunity after a
  # hit), and armor lowers the hurt. minecraft.wiki/w/Fire and
  # /w/Damage_type_tag_(Java_Edition) (in_fire is not in bypasses_armor).
  FLAME_DAMAGE = 1.0
  FLAME_WAIT = 0.5

  def initialize(spread)
    @spread = spread
    @keys = Array.new(0, 0)
    @ages = Array.new(0, 0)
    @waits = Array.new(0, 0.0)
    nil
  end

  def size = @keys.size

  # Keeps the fire at key (World.key) with age, unless Fires keeps it
  # already.
  def add(key, age)
    return if @keys.include?(key)

    @keys << key
    @ages << age
    @waits << @spread.wait
    nil
  end

  # The fires of a chunk that loads: x, y and z for each one.
  def add_each(cells)
    (cells.size / 3).times { |cell| add(World.key(cells[cell * 3], cells[cell * 3 + 1], cells[cell * 3 + 2]), 0) }
    nil
  end

  # The age of the fire at x, y, z, or -1 when Fires does not keep it.
  def age_at(x, y, z)
    key = World.key(x, y, z)
    return -1 unless @keys.include?(key)

    @ages[@keys.index(key)]
  end

  # The updates of the fires that wait dt seconds more, with their changes
  # in changes, four Integers for each block (x, y, z and the new block).
  # Game puts them in the world with Game#set_block. A fire that is no
  # longer in the world is gone, and so is a fire in a chunk that is not
  # loaded (World#get gives air there). The new fires of the updates wait
  # for their own.
  def update_fires(dt, changes)
    count = @keys.size
    keep = Array.new(0, 0)
    count.times do |fire|
      next unless @spread.burning?(@keys[fire])

      @waits[fire] -= dt
      keep << fire if @waits[fire] > 0.0 || burn(fire, changes)
    end
    (count...@keys.size).each { |fire| keep << fire }
    compact(keep)
  end

  private

  # One update of a fire, and the wait for the next one. Returns false when
  # the fire goes out.
  def burn(fire, changes)
    @waits[fire] = @spread.wait
    age = @spread.update(@keys[fire], @ages[fire])
    @ages[fire] = age
    take_outcomes(changes)
    age >= 0
  end

  # Moves the outcomes of FireSpread to changes, and keeps each new fire.
  def take_outcomes(changes)
    outcomes = @spread.outcomes
    (outcomes.size / 3).times do |outcome|
      key = outcomes[outcome * 3]
      block = outcomes[outcome * 3 + 1]
      changes << World.key_x(key) << World.key_y(key) << World.key_z(key) << block
      add(key, outcomes[outcome * 3 + 2]) if block == Block::FIRE
    end
    outcomes.clear
    nil
  end

  def compact(keep)
    @keys = keep.map { |fire| @keys[fire] }
    @ages = keep.map { |fire| @ages[fire] }
    @waits = keep.map { |fire| @waits[fire] }
    nil
  end
end
