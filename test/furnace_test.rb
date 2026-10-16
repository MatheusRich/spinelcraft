require_relative "test_helper"

# A furnace burns fuel to smelt its input, one tick at a time.
class FurnaceTest < Minitest::Test
  def test_planks_and_logs_burn_for_15_seconds_and_coal_for_80
    assert_equal 300, Furnace.fuel_ticks(Block::OAK_PLANKS)
    assert_equal 300, Furnace.fuel_ticks(Block::BIRCH_LOG)
    assert_equal 1600, Furnace.fuel_ticks(Block::COAL)
    assert_equal 0, Furnace.fuel_ticks(Block::STONE)
    assert Furnace.fuel?(Block::SPRUCE_PLANKS)
    refute Furnace.fuel?(Block::IRON)
  end

  def test_an_item_smelts_in_200_ticks_and_burns_one_fuel_item
    f = furnace(Block::IRON, 2, Block::COAL, 3)
    tick(f, 199)
    assert f.lit?
    assert_equal 2, f.slots.count(Furnace::FUEL)
    assert_equal 1600, f.burn_total
    assert f.slots.empty?(Furnace::OUTPUT)
    tick(f, 1)
    assert_equal 1, f.slots.count(Furnace::INPUT)
    assert_equal Block::IRON_INGOT, f.slots.block(Furnace::OUTPUT)
    assert_equal 1, f.slots.count(Furnace::OUTPUT)
  end

  def test_fuel_does_not_burn_without_something_to_smelt
    f = furnace(Block::AIR, 0, Block::COAL, 1)
    tick(f, 5)
    refute f.lit?
    assert_equal 1, f.slots.count(Furnace::FUEL)
  end

  def test_a_new_fuel_item_burns_only_when_the_input_smelts
    f = furnace(Block::STONE, 1, Block::COAL, 1)
    f.tick(0, 0, 1600)
    refute f.lit?
    assert_equal 1, f.slots.count(Furnace::FUEL)
  end

  def test_a_lit_fuel_item_burns_to_its_end
    f = furnace(Block::IRON, 1, Block::OAK_PLANKS, 1)
    # The tick that lights the fuel does not take from its burn time.
    tick(f, 200)
    assert f.lit?
    assert_equal 101, f.burn
    tick(f, 100)
    assert f.lit?
    tick(f, 1)
    refute f.lit?
  end

  def test_the_progress_goes_back_twice_as_fast_while_the_furnace_is_out
    f = furnace(Block::IRON, 1, Block::OAK_PLANKS, 0)
    f.progress = 9
    tick(f, 2)
    assert_equal 5, f.progress
    tick(f, 3)
    assert_equal 0, f.progress
  end

  def test_nothing_smelts_when_the_output_slot_holds_another_item
    f = furnace(Block::IRON, 1, Block::COAL, 1)
    f.slots.set(Furnace::OUTPUT, Block::COAL, 1)
    tick(f, 10)
    refute f.lit?
    assert_equal 0, f.progress
    assert_equal 1, f.slots.count(Furnace::FUEL)
  end

  def test_nothing_smelts_when_the_output_stack_is_full
    f = furnace(Block::IRON, 1, Block::COAL, 1)
    f.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Block.stack(Block::IRON_INGOT))
    tick(f, 10)
    refute f.lit?
    f.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Block.stack(Block::IRON_INGOT) - 1)
    tick(f, 200)
    assert_equal Block.stack(Block::IRON_INGOT), f.slots.count(Furnace::OUTPUT)
  end

  def test_the_next_item_takes_200_ticks_again
    f = furnace(Block::IRON, 2, Block::COAL, 1)
    tick(f, 200)
    tick(f, 199)
    assert_equal 1, f.slots.count(Furnace::OUTPUT)
    tick(f, 1)
    assert_equal 2, f.slots.count(Furnace::OUTPUT)
  end

  def test_a_lit_furnace_stops_smelting_when_the_output_stack_is_full
    f = furnace(Block::IRON, 1, Block::COAL, 0)
    f.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Block.stack(Block::IRON_INGOT))
    f.burn = 1000
    tick(f, 300)
    assert f.lit?
    assert_equal 0, f.progress
    assert_equal 1, f.slots.count(Furnace::INPUT)
    assert_equal Block.stack(Block::IRON_INGOT), f.slots.count(Furnace::OUTPUT)
  end

  def test_an_item_in_the_fuel_slot_that_does_not_burn_stays
    f = furnace(Block::IRON, 1, Block::STONE, 1)
    tick(f, 5)
    refute f.lit?
    assert_equal 1, f.slots.count(Furnace::FUEL)
    assert_equal 0, f.progress
  end

  def test_a_burn_time_without_a_fuel_item_lights_nothing
    f = furnace(Block::IRON, 1, Block::AIR, 0)
    f.tick(Block::IRON_INGOT, 1, 1600)
    refute f.lit?
  end

  def test_the_progress_goes_back_also_with_fuel_but_no_input
    f = furnace(Block::AIR, 0, Block::COAL, 1)
    f.progress = 9
    tick(f, 1)
    assert_equal 7, f.progress
  end

  def test_a_cold_empty_furnace_stays_idle
    f = Furnace.new(0, 0, 0)
    tick(f, 3)
    assert_equal 0, f.burn
    assert f.idle?
  end

  def test_a_new_furnace_is_cold_and_has_three_empty_slots_at_its_block
    f = Furnace.new(1, 2, 3)
    assert_equal [1, 2, 3], [f.x, f.y, f.z]
    assert_equal 0, f.burn
    assert_equal 0, f.burn_total
    assert_equal 0, f.progress
    assert_equal 6, f.slots.to_a.size
  end

  def test_an_empty_cold_furnace_is_idle
    f = Furnace.new(1, 2, 3)
    assert f.idle?
    f.progress = 1
    refute f.idle?
    f.progress = 0
    f.burn = 1
    refute f.idle?
    refute furnace(Block::IRON, 1, Block::AIR, 0).idle?
    refute furnace(Block::AIR, 0, Block::COAL, 1).idle?
    f = Furnace.new(1, 2, 3)
    f.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, 1)
    refute f.idle?
  end

  # A furnace with n of input and m of fuel.
  def furnace(input, n, fuel, m)
    f = Furnace.new(0, 0, 0)
    f.slots.set(Furnace::INPUT, input, n)
    f.slots.set(Furnace::FUEL, fuel, m)
    f
  end

  # Runs n ticks of a furnace that smelts iron, with the burn time of the
  # item in its fuel slot.
  def tick(f, n)
    n.times do
      out = f.slots.block(Furnace::INPUT) == Block::IRON ? Block::IRON_INGOT : 0
      f.tick(out, out == 0 ? 0 : 1, Furnace.fuel_ticks(f.slots.block(Furnace::FUEL)))
    end
  end
end
