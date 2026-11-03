require_relative "test_helper"

# One update of a fire (Fires), with rolls that the test picks.
# minecraft.wiki/w/Fire
class FireRulesTest < Minitest::Test
  # A cell in the open air over a stone floor in the one loaded chunk.
  X = 8
  Y = SKY_Y - 20
  Z = 8

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::STONE) } }
    @weather = Weather.new(1)
    @changes = []
  end

  # Puts a fire of age at x, y, z, and runs its first update with rolls
  # after the rolls of its first and its next wait. Gives the changes, each
  # as [x, y, z, block].
  def update(*rolls, age: 0, at: [X, Y, Z])
    @fires = Fires.new(FireSpread.new(@world, @weather, Rolls.new(0.0, 0.0, *rolls)))
    @world.set(*at, Block::FIRE)
    @fires.add(World.key(*at), age)
    @fires.update_fires(FireSpread::WAIT, @changes)
    @changes.each_slice(4).to_a
  end

  def set(x, y, z, block) = @world.set(x, y, z, block)

  def rain
    @weather.rain.start
    @weather.settle
  end

  # A fire on a floor of planks, a column of planks 2 to its side, and
  # planks up and to the other side.
  def build_planks
    set(X, Y - 1, Z, Block::OAK_PLANKS)
    (Y..Y + 5).each { |y| set(X + 2, y, Z, Block::OAK_PLANKS) }
    set(X, Y + 2, Z + 2, Block::OAK_PLANKS)
  end

  def fire(x, y, z) = [x, y, z, Block::FIRE]

  def test_when_each_roll_hits_the_floor_burns_into_fire_and_fire_spreads_from_1_below_to_4_above
    build_planks
    expected = [fire(X, Y - 1, Z), fire(X, Y + 2, Z + 1)] + (Y..Y + 4).map { |y| fire(X + 1, y, Z) }
    assert_equal expected.sort, update(0.0).sort
    assert_equal [1, 1, 1], [@fires.age_at(X, Y, Z), @fires.age_at(X + 1, Y + 4, Z), @fires.age_at(X, Y - 1, Z)]
  end

  # The cells right above and beside the fire can take fire, also one
  # whose only block that burns is above it.
  def test_fire_spreads_to_the_cells_next_to_it_and_above_it
    set(X, Y - 1, Z, Block::OAK_PLANKS)
    set(X - 1, Y + 1, Z, Block::OAK_PLANKS)
    set(X - 1, Y + 3, Z, Block::OAK_PLANKS)
    set(X, Y, Z + 2, Block::OAK_PLANKS)
    set(X + 1, Y + 1, Z, Block::OAK_PLANKS)
    spread = update(0.0)
    [fire(X, Y + 1, Z), fire(X, Y + 3, Z), fire(X, Y, Z + 1), fire(X + 1, Y, Z)].each { |change| assert_includes spread, change }
  end

  # A cell 2 to 4 above the fire takes fire with a chance 2 to 4 times
  # less than a cell beside it.
  def test_fire_spreads_up_more_rarely
    build_planks
    assert_equal [fire(X, Y - 1, Z), fire(X + 1, Y, Z), fire(X + 1, Y + 1, Z)].sort, update(0.015).sort
  end

  def test_when_no_roll_hits_the_fire_changes_nothing
    build_planks
    assert_empty update(0.999)
    assert_equal [0, 1], [@fires.age_at(X, Y, Z), @fires.size]
  end

  # Wool (ignite odds 30) next to a fire of age 10 gets (30 + 40 + 7 * 2) /
  # (10 + 30) = 2 chances out of 100, and planks (5) get 1.
  def test_a_cell_gets_more_chances_next_to_a_block_that_catches_fire_more_easily
    set(X, Y - 1, Z, Block::OAK_PLANKS)
    set(X + 1, Y - 1, Z, Block::WOOL)
    set(X - 1, Y - 1, Z, Block::OAK_PLANKS)
    assert_equal [fire(X, Y - 1, Z), fire(X + 1, Y, Z)].sort, update(0.025, age: 10).sort
  end

  def test_a_lone_young_fire_on_a_solid_block_stays_and_ages
    assert_empty update(0.0, age: 3)
    assert_equal [4, 1], [@fires.age_at(X, Y, Z), @fires.size]
  end

  # A roll of exactly 1/3 does not age the fire.
  def test_a_fire_ages_on_a_roll_under_one_third
    update(1.0 / 3.0, age: 3)
    assert_equal 3, @fires.age_at(X, Y, Z)
  end

  def test_a_lone_old_fire_goes_out
    assert_equal [[X, Y, Z, Block::AIR]], update(0.999, age: 4)
    assert_equal 0, @fires.size
  end

  def test_a_lone_fire_with_air_under_it_goes_out
    assert_equal [[X, Y + 2, Z, Block::AIR]], update(0.999, at: [X, Y + 2, Z])
  end

  def test_a_fire_of_the_last_age_goes_out_now_and_then_on_a_block_that_does_not_burn
    set(X + 1, Y, Z, Block::OAK_PLANKS)
    assert_equal [[X, Y, Z, Block::AIR]], update(0.0, age: 15)
    @changes.clear
    assert_empty update(0.25, age: 15)
  end

  def test_a_fire_of_the_last_age_stays_on_a_block_that_burns
    set(X, Y - 1, Z, Block::OAK_PLANKS)
    assert_equal [fire(X, Y - 1, Z)], update(0.0, age: 15)
    assert_equal 15, @fires.age_at(X, Y, Z)
  end

  def test_each_block_beside_above_and_under_the_fire_burns_into_fire
    set(X, Y - 1, Z, Block::OAK_PLANKS)
    set(X, Y + 1, Z, Block::OAK_PLANKS)
    set(X + 1, Y, Z, Block::OAK_PLANKS)
    set(X - 1, Y, Z, Block::OAK_PLANKS)
    set(X, Y, Z + 1, Block::OAK_PLANKS)
    set(X, Y, Z - 1, Block::OAK_PLANKS)
    burned = update(0.0)
    [fire(X, Y - 1, Z), fire(X, Y + 1, Z), fire(X + 1, Y, Z), fire(X - 1, Y, Z), fire(X, Y, Z + 1), fire(X, Y, Z - 1)].each do |change|
      assert_includes burned, change
    end
  end

  # A burned block becomes fire when a roll of age + 10 is under 5.
  def test_a_burned_block_becomes_fire_or_air
    set(X + 1, Y, Z, Block::OAK_PLANKS)
    assert_equal [fire(X + 1, Y, Z)], update(0.999, 0.0, 0.45, 0.2, 0.999)
    assert_equal 0, @fires.age_at(X + 1, Y, Z)
    @changes.clear
    assert_equal [[X + 1, Y, Z, Block::AIR]], update(0.999, 0.0, 0.55)
  end

  def test_one_update_can_burn_a_block_into_air_and_another_into_fire
    set(X + 1, Y, Z, Block::OAK_PLANKS)
    set(X - 1, Y, Z, Block::OAK_PLANKS)
    assert_equal [[X + 1, Y, Z, Block::AIR], fire(X - 1, Y, Z)], update(0.999, 0.0, 0.55, 0.0, 0.0, 0.999, age: 5)
    assert_equal 5, @fires.age_at(X - 1, Y, Z)
  end

  def test_a_burned_block_in_the_rain_becomes_air
    rain
    set(X + 1, Y, Z, Block::OAK_PLANKS)
    assert_equal [[X + 1, Y, Z, Block::AIR]], update(0.999, 0.999, 0.0, 0.0)
  end

  # Rain puts out a fire with a chance of 20%, and 3% more for each age.
  def test_rain_puts_out_a_fire_with_a_chance_that_grows_with_its_age
    rain
    set(X + 1, Y, Z, Block::OAK_LOG)
    assert_equal [[X, Y, Z, Block::AIR]], update(0.19)
    @changes.clear
    assert_empty update(0.2)
    @changes.clear
    assert_equal [[X, Y, Z, Block::AIR]], update(0.49, age: 10)
    @changes.clear
    assert_empty update(0.51, age: 10)
  end

  def test_rain_on_the_cell_of_the_fire_alone_puts_it_out
    rain
    Block::DIR_DX.size.times { |dir| set(X + Block::DIR_DX[dir], Y + 3, Z + Block::DIR_DZ[dir], Block::STONE) }
    assert_equal [[X, Y, Z, Block::AIR]], update(0.0)
  end

  def test_rain_on_a_cell_beside_the_fire_puts_it_out
    rain
    [[0, 0], [-1, 0], [0, 1], [0, -1]].each { |side_x, side_z| set(X + side_x, Y + 3, Z + side_z, Block::STONE) }
    assert_equal [[X, Y, Z, Block::AIR]], update(0.0)
  end

  # Rain on a cell keeps the fire from it, but not from the cells that the
  # roof keeps dry.
  def test_fire_does_not_spread_into_the_rain
    set(X, Y - 1, Z, Block::OAK_PLANKS)
    set(X + 2, Y, Z + 1, Block::OAK_PLANKS)
    [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]].each { |side_x, side_z| set(X + side_x, Y + 5, Z + side_z, Block::STONE) }
    assert_equal [fire(X, Y - 1, Z), fire(X + 1, Y, Z + 1)].sort, update(0.0).sort
    @changes.clear
    rain
    assert_equal [fire(X, Y - 1, Z)], update(0.0)
  end

  def test_fire_does_not_spread_into_a_chunk_that_is_not_loaded
    set(15, Y - 1, Z, Block::OAK_PLANKS)
    set(15, Y + 1, Z, Block::OAK_PLANKS)
    assert(update(0.0, at: [15, Y, Z]).all? { |x, _y, _z, _block| x.between?(0, 15) })
  end

  def test_a_fire_whose_block_is_gone_is_forgotten
    @fires = Fires.new(FireSpread.new(@world, @weather, Rolls.new(0.0)))
    @fires.add(World.key(X, Y, Z), 0)
    @fires.update_fires(0.1, @changes)
    assert_equal 0, @fires.size
  end

  # Each fire keeps its own age and wait when another fire is forgotten.
  def test_a_fire_keeps_its_age_and_wait_when_another_one_is_forgotten
    rain
    @fires = Fires.new(FireSpread.new(@world, @weather, Rolls.new(0.999, 0.0)))
    @fires.add(World.key(X, Y + 3, Z), 0)
    set(X, Y, Z, Block::FIRE)
    @fires.add(World.key(X, Y, Z), 7)
    @fires.update_fires(0.1, @changes)
    assert_equal [7, 1], [@fires.age_at(X, Y, Z), @fires.size]
    @fires.update_fires(1.45, @changes)
    assert_equal [X, Y, Z, Block::AIR], @changes
  end

  # A new fire waits 1.5 to 2 seconds for its first update.
  def test_a_new_fire_waits_for_its_first_update
    rain
    @fires = Fires.new(FireSpread.new(@world, @weather, Rolls.new(0.999, 0.0, 0.0)))
    set(X, Y, Z, Block::FIRE)
    @fires.add(World.key(X, Y, Z), 0)
    @fires.update_fires(1.95, @changes)
    assert_empty @changes
    @fires.update_fires(0.1, @changes)
    assert_equal [X, Y, Z, Block::AIR], @changes
  end
end
