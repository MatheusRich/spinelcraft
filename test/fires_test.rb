require_relative "test_helper"

# Fire that burns, spreads and goes out (Fires), and lava that lights it
# (LavaFire).
class FiresTest < Minitest::Test
  # A cell in the open air over a stone floor in the one loaded chunk.
  X = 8
  Y = SKY_Y - 20
  Z = 8
  FRAME = 0.05

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::STONE) } }
    @weather = Weather.new(1)
    @changes = []
    @fires = Fires.new(FireSpread.new(@world, @weather, Rng.new(5)))
    @lava_fire = LavaFire.new(@world, @changes, Rng.new(9))
  end

  # Puts block at x, y, z, and a fire in Fires, as Game#set_block does.
  def put(x, y, z, block)
    @world.set(x, y, z, block)
    @fires.add(World.key(x, y, z), 0) if block == Block::FIRE
  end

  # Runs the fires for seconds, with each change in the world after the
  # frame, as Game#update_fires does.
  def burn_for(seconds)
    (seconds / FRAME).to_i.times do
      @fires.update_fires(FRAME, @changes)
      apply
    end
  end

  def apply
    @changes.each_slice(4) { |x, y, z, block| put(x, y, z, block) }
    @changes.clear
  end

  def rain
    @weather.rain.start
    @weather.settle
  end

  def count(block) = (0...16).sum { |x| (Y - 1...Y + 8).sum { |y| (0...16).count { |z| @world.get(x, y, z) == block } } }

  def test_fire_holds_on_a_solid_block_or_beside_a_block_that_burns
    assert @world.can_hold?(Block::FIRE, X, Y, Z)
    assert !@world.can_hold?(Block::FIRE, X, Y + 1, Z)
    @world.set(X + 1, Y + 1, Z, Block::OAK_PLANKS)
    assert @world.can_hold?(Block::FIRE, X, Y + 1, Z)
    @world.set(X + 1, Y + 1, Z, Block::GLASS)
    assert !@world.can_hold?(Block::FIRE, X, Y + 1, Z)
    @world.set(X, Y + 2, Z, Block::WOOL)
    assert @world.can_hold?(Block::FIRE, X, Y + 1, Z)
  end

  def test_a_fire_that_breaks_drops_nothing
    assert_empty Block.dropped_items(Block::FIRE, Rolls.new(0.0))
  end

  def test_a_chunk_that_loads_again_lists_its_fire_as_a_light_and_gives_it_to_fires_at_age_0
    @world.set(X, Y, Z, Block::FIRE)
    @world.set(X + 2, Y + 1, Z + 3, Block::FIRE)
    @world.take_loaded_fires
    @world.load_chunk(0, 0)
    assert_includes @world.torches_of(0, 0).each_slice(3).to_a, [X, Y, Z]
    @fires.add_each(@world.take_loaded_fires)
    assert_equal [2, 0, 0], [@fires.size, @fires.age_at(X, Y, Z), @fires.age_at(X + 2, Y + 1, Z + 3)]
    assert_equal [], @world.take_loaded_fires
  end

  def test_fire_on_stone_waits_for_its_first_update_then_goes_out_when_it_is_old
    put(X, Y, Z, Block::FIRE)
    burn_for(FireSpread::WAIT - FRAME)
    assert_equal Block::FIRE, @world.get(X, Y, Z)
    burn_for(120.0)
    assert_equal Block::AIR, @world.get(X, Y, Z)
    assert_equal 0, @fires.size
  end

  def test_fire_spreads_over_planks_and_burns_them_away
    3.times { |side| 3.times { |up| @world.set(X + 1, Y + up, Z - 1 + side, Block::OAK_PLANKS) } }
    put(X, Y, Z, Block::FIRE)
    most = (1..33).map do
      burn_for(10.0)
      count(Block::FIRE)
    end.max
    assert_operator most, :>, 1
    assert_operator count(Block::OAK_PLANKS), :<, 5
  end

  def test_rain_puts_out_a_fire_that_a_log_keeps
    @world.set(X + 1, Y, Z, Block::OAK_LOG)
    put(X, Y, Z, Block::FIRE)
    burn_for(20.0)
    assert_equal Block::FIRE, @world.get(X, Y, Z)
    rain
    burn_for(20.0)
    assert_equal 0, count(Block::FIRE)
  end

  def test_a_roof_keeps_the_rain_off_a_fire
    @world.set(X + 1, Y, Z, Block::OAK_LOG)
    3.times { |side_x| 3.times { |side_z| @world.set(X - 1 + side_x, Y + 3, Z - 1 + side_z, Block::STONE) } }
    put(X, Y, Z, Block::FIRE)
    rain
    burn_for(20.0)
    assert_equal Block::FIRE, @world.get(X, Y, Z)
  end

  # A new fire is as old as the fire that lit it, or 1 older, and it grows
  # older from there. minecraft.wiki/w/Fire
  def test_a_fire_that_spreads_takes_the_age_of_its_fire
    16.times { |x| 16.times { |z| @world.set(x, Y, z, Block::WOOL) } }
    @world.set(X, Y + 1, Z, Block::FIRE)
    @fires.add(World.key(X, Y + 1, Z), 10)
    burn_for(20.0)
    ages = (0...16).flat_map { |x| (Y...Y + 3).flat_map { |y| (0...16).map { |z| @fires.age_at(x, y, z) } } }.reject(&:negative?)
    assert_operator ages.size, :>, 1
    assert_operator ages.min, :>=, 10
  end

  def test_lava_lights_the_air_above_it_next_to_a_block_that_burns
    @world.set(X, Y, Z, Block::LAVA)
    @world.set(X + 1, Y + 1, Z, Block::OAK_PLANKS)
    @world.set(X - 1, Y + 1, Z, Block::OAK_PLANKS)
    lamps = @world.torches_of(0, 0)
    60.times do
      @lava_fire.tick_lava(lamps, 10.0)
      apply
    end
    assert_operator count(Block::FIRE), :>, 0
  end

  def test_lava_lights_nothing_without_a_block_that_burns
    @world.set(X, Y, Z, Block::LAVA)
    lamps = @world.torches_of(0, 0)
    60.times { @lava_fire.tick_lava(lamps, 10.0) }
    assert_equal [], @changes
  end
end
