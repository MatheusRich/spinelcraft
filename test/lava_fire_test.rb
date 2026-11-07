require_relative "test_helper"

# Lava that lights fires near it (LavaFire), with rolls that the test
# picks. minecraft.wiki/w/Lava
class LavaFireTest < Minitest::Test
  # A cell in the open air over a stone floor in the one loaded chunk.
  X = 8
  Y = SKY_Y - 20
  Z = 8
  # Rolls of a side step (Rng#between): one block back, none, and one block on.
  BACK = 0.0
  STAY = 0.5
  ON = 0.999

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::STONE) } }
    @changes = []
  end

  def set(x, y, z, block) = @world.set(x, y, z, block)

  # One random tick of the lava at x, y, z with rolls: the tick, the lamp,
  # the steps up, then the side steps. Gives the changes, each as [x, y, z,
  # block].
  def tick(rolls, at: [X, Y, Z])
    set(*at, Block::LAVA)
    LavaFire.new(@world, @changes, Rolls.new(0.0, 0.0, *rolls)).tick_lava(at, LavaFire::RANDOM_TICK)
    @changes.each_slice(4).to_a
  end

  def fire(x, y, z) = [x, y, z, Block::FIRE]

  # One step up and one block to a side, to air next to planks.
  def test_lava_lights_the_air_one_up_and_one_to_the_side_next_to_a_block_that_burns
    set(X + 2, Y + 1, Z + 1, Block::OAK_PLANKS)
    assert_equal [fire(X + 1, Y + 1, Z + 1)], tick([0.5, ON, ON])
  end

  def test_lava_lights_the_air_two_up_after_a_cell_that_does_not_stop_motion
    set(X + 1, Y + 2, Z + 2, Block::OAK_PLANKS)
    set(X + 1, Y + 1, Z, Block::TALL_GRASS)
    set(X + 2, Y + 1, Z, Block::OAK_PLANKS)
    assert_equal [fire(X + 1, Y + 2, Z + 1)], tick([0.7, ON, STAY, STAY, ON])
  end

  def test_a_block_that_stops_motion_stops_the_steps
    set(X + 1, Y + 1, Z, Block::STONE)
    set(X + 2, Y + 2, Z, Block::OAK_PLANKS)
    assert_empty tick([0.7, ON, STAY, STAY, STAY])
  end

  def test_lava_lights_the_air_above_a_block_that_burns_beside_it
    set(X + 1, Y, Z, Block::OAK_PLANKS)
    set(X - 1, Y, Z, Block::OAK_PLANKS)
    set(X - 1, Y + 1, Z, Block::STONE)
    assert_equal [fire(X + 1, Y + 1, Z)], tick([0.0, ON, STAY, BACK, STAY, STAY, STAY])
    @changes.clear
    set(X, Y, Z + 1, Block::OAK_PLANKS)
    assert_equal [fire(X, Y + 1, Z + 1)], tick([0.0, STAY, ON, STAY, STAY])
  end

  def test_lava_lights_nothing_in_a_chunk_that_is_not_loaded
    set(15, Y + 1, Z, Block::OAK_PLANKS)
    assert_empty tick([0.5, ON, STAY], at: [15, Y, Z])
  end

  def test_lava_lights_nothing_above_the_top_of_the_world
    set(X + 1, WY - 1, Z, Block::OAK_PLANKS)
    assert_empty tick([0.0, ON, STAY], at: [X, WY - 1, Z])
    set(X + 1, WY - 1, Z, Block::AIR)
    set(X, WY - 1, Z, Block::AIR)
    set(X + 1, WY - 2, Z, Block::OAK_PLANKS)
    assert_equal [fire(X + 1, WY - 1, Z)], tick([0.0, ON, STAY], at: [X, WY - 2, Z])
  end

  def test_a_lamp_that_is_not_lava_lights_nothing
    set(X + 2, Y + 1, Z, Block::OAK_PLANKS)
    tick([0.5, ON, STAY])
    @changes.clear
    set(X, Y, Z, Block::TORCH)
    LavaFire.new(@world, @changes, Rolls.new(0.0, 0.0, 0.5, ON, STAY)).tick_lava([X, Y, Z], LavaFire::RANDOM_TICK)
    assert_empty @changes
  end

  # The lava ticks of a minute from the column at x, z, with lava at X, Y,
  # Z next to air beside planks.
  def ticks_near(x, z)
    set(X + 2, Y + 1, Z, Block::OAK_PLANKS)
    set(X, Y, Z, Block::LAVA)
    LavaFire.new(@world, @changes, Rng.new(9)).tick_near(x, z, LavaFire::RANDOM_TICK * 60)
    @changes
  end

  def test_lava_in_a_chunk_within_reach_lights_fires
    refute_empty ticks_near(X + LavaFire::REACH_CHUNKS * 16, Z - LavaFire::REACH_CHUNKS * 16)
    @changes.clear
    refute_empty ticks_near(X - LavaFire::REACH_CHUNKS * 16, Z + LavaFire::REACH_CHUNKS * 16)
  end

  def test_lava_in_a_chunk_out_of_reach_lights_nothing
    assert_empty ticks_near(X + (LavaFire::REACH_CHUNKS + 1) * 16, Z)
    assert_empty ticks_near(X, Z - (LavaFire::REACH_CHUNKS + 1) * 16)
  end

  # Each lava in the list gets a random tick each RANDOM_TICK seconds on
  # average.
  def test_each_lava_gets_one_random_tick_each_68_seconds
    set(X + 2, Y + 1, Z, Block::OAK_PLANKS)
    set(X, Y, Z, Block::LAVA)
    lamps = [X, Y, Z, X, Y + 5, Z]
    LavaFire.new(@world, @changes, Rolls.new(0.999, 0.0, 0.5, ON, STAY)).tick_lava(lamps, LavaFire::RANDOM_TICK / 2.0)
    assert_equal [fire(X + 1, Y + 1, Z)], @changes.each_slice(4).to_a
    @changes.clear
    LavaFire.new(@world, @changes, Rolls.new(0.0, 0.0, 0.5, ON, STAY)).tick_lava(lamps, LavaFire::RANDOM_TICK / 4.0)
    assert_empty @changes
  end
end
