# The rules of one update of a fire: the fire ages, burns the blocks next
# to it, spreads to the air near blocks that burn, and goes out.
# FireSpread does not change the world. An update lists what it changes
# in outcomes, three Integers for each cell: its key (World.key), the new
# block, and the age of a new fire. minecraft.wiki/w/Fire
class FireSpread
  # A fire updates every 30 to 40 ticks. minecraft.wiki/w/Fire
  WAIT = 1.5
  WAIT_SPREAD = 0.5
  MAX_AGE = 15
  # Each update, the age grows by 1 with this chance. minecraft.wiki/w/Fire
  AGE_CHANCE = 1.0 / 3.0
  # A fire older than this goes out when no block next to it burns.
  # minecraft.wiki/w/Fire
  OLD_AGE = 3
  # A fire of MAX_AGE goes out with this chance when the block under it
  # does not burn. minecraft.wiki/w/Fire
  LAST_AGE_CHANCE = 0.25
  # Rain puts a fire out with RAIN_CHANCE plus RAIN_AGE_CHANCE for each
  # age, 20% to 65%. minecraft.wiki/w/Fire
  RAIN_CHANCE = 0.2
  RAIN_AGE_CHANCE = 0.03
  # Normal difficulty. minecraft.wiki/w/Difficulty
  DIFFICULTY = 2
  # A cell takes fire with (ignite odds + SPREAD_BASE + SPREAD_DIFFICULTY *
  # DIFFICULTY) / (age + SPREAD_AGE) chances out of SPREAD_ODDS, and
  # SPREAD_ODDS more for each step up past the first. The wiki gives these
  # numbers, but its formula is garbled. This reading is the one of the
  # Java code (FireBlock). minecraft.wiki/w/Fire
  SPREAD_BASE = 40
  SPREAD_DIFFICULTY = 7
  SPREAD_AGE = 30
  SPREAD_ODDS = 100
  SPREAD_DOWN = 1
  SPREAD_UP = 4
  # A block next to a fire burns away with its burn odds out of these: the
  # first for a block beside it, the second for the block above or under
  # it. A burned block becomes fire when a roll of age + BURN_FIRE_AGE is
  # under BURN_FIRE_ROLL, and air otherwise. The new fire is up to 1 older
  # than its fire, with chance NEW_FIRE_OLDER. The wiki does not give these
  # values. They are the ones of the Java code (FireBlock).
  SIDE_BURN_ODDS = 300
  END_BURN_ODDS = 250
  BURN_FIRE_AGE = 10
  BURN_FIRE_ROLL = 5
  NEW_FIRE_OLDER = 0.2
  # The key of a cell outside the loaded world.
  OUTSIDE = -1

  attr_reader :outcomes

  def initialize(world, weather, rng)
    @world = world
    @weather = weather
    @rng = rng
    @outcomes = Array.new(0, 0)
    nil
  end

  # The seconds until the next update of a fire.
  def wait = WAIT + @rng.rand01 * WAIT_SPREAD

  # True when the cell of key holds fire.
  def burning?(key) = @world.get(World.key_x(key), World.key_y(key), World.key_z(key)) == Block::FIRE

  # One update of the fire at key of age. The age grows first, but the
  # rules read the age from before. Gives the new age, or -1 when the fire
  # goes out. A fire with no block that burns next to it stays while it is
  # young and on a solid block, but it does not spread.
  def update(key, age)
    return put_out(key) if near_rain?(key) && @rng.rand01 < RAIN_CHANCE + age * RAIN_AGE_CHANCE

    older = age < MAX_AGE && @rng.rand01 < AGE_CHANCE ? age + 1 : age
    x = World.key_x(key)
    y = World.key_y(key)
    z = World.key_z(key)
    under = @world.get(x, y - 1, z)
    alone = !@world.next_to_flammable?(x, y, z)
    return older if alone && age <= OLD_AGE && Block.solid?(under)
    return put_out(key) if alone || (age == MAX_AGE && !Block.flammable?(under) && @rng.rand01 < LAST_AGE_CHANCE)

    burn_around(key, age)
    spread(key, age)
    older
  end

  private

  def put_out(key)
    @outcomes << key << Block::AIR << 0
    -1
  end

  # The key of x, y, z, or OUTSIDE.
  def cell_key(x, y, z) = @world.inside?(x, y, z) ? World.key(x, y, z) : OUTSIDE

  # Each block beside, above and under the fire may burn away.
  def burn_around(key, age)
    x = World.key_x(key)
    y = World.key_y(key)
    z = World.key_z(key)
    Block::DIR_DX.size.times do |dir|
      burn_away(cell_key(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir]), SIDE_BURN_ODDS, age)
    end
    burn_away(cell_key(x, y - 1, z), END_BURN_ODDS, age)
    burn_away(cell_key(x, y + 1, z), END_BURN_ODDS, age)
  end

  def burn_away(key, odds, age)
    return if key == OUTSIDE
    return unless (@rng.rand01 * odds).to_i < Block.burn_odds(@world.get(World.key_x(key), World.key_y(key), World.key_z(key)))

    if (@rng.rand01 * (age + BURN_FIRE_AGE)).to_i < BURN_FIRE_ROLL && !near_rain?(key)
      @outcomes << key << Block::FIRE << new_age(age)
    else
      @outcomes << key << Block::AIR << 0
    end
  end

  # The fire may light each air cell around it next to a block that burns.
  def spread(key, age)
    x = World.key_x(key)
    y = World.key_y(key)
    z = World.key_z(key)
    (-1..1).each do |side_x|
      (-1..1).each do |side_z|
        (-SPREAD_DOWN..SPREAD_UP).each do |up|
          spread_to(cell_key(x + side_x, y + up, z + side_z), up, age) unless side_x == 0 && up == 0 && side_z == 0
        end
      end
    end
  end

  def spread_to(key, up, age)
    odds = ignite_odds_at(key)
    return if odds == 0

    chances = (odds + SPREAD_BASE + SPREAD_DIFFICULTY * DIFFICULTY) / (age + SPREAD_AGE)
    out_of = SPREAD_ODDS * [up, 1].max
    return unless chances > 0 && (@rng.rand01 * out_of).to_i <= chances && !near_rain?(key)

    @outcomes << key << Block::FIRE << new_age(age)
  end

  # The highest ignite odds of the blocks next to the air cell of key, or 0
  # when the cell is not air.
  def ignite_odds_at(key)
    return 0 if key == OUTSIDE

    x = World.key_x(key)
    y = World.key_y(key)
    z = World.key_z(key)
    return 0 unless @world.get(x, y, z) == Block::AIR

    odds = [Block.ignite_odds(@world.get(x, y - 1, z)), Block.ignite_odds(@world.get(x, y + 1, z))].max
    Block::DIR_DX.size.times { |dir| odds = [odds, Block.ignite_odds(@world.get(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir]))].max }
    odds
  end

  def new_age(age) = @rng.rand01 < NEW_FIRE_OLDER ? [age + 1, MAX_AGE].min : age

  # True when rain falls on the cell of key or on a cell beside it.
  def near_rain?(key)
    x = World.key_x(key)
    y = World.key_y(key)
    z = World.key_z(key)
    return true if rain_on?(x, y, z)

    (0...Block::DIR_DX.size).any? { |dir| rain_on?(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir]) }
  end

  def rain_on?(x, y, z) = @weather.wet_at?(@world, x, z) && @world.under_sky?(x, y, z)
end
