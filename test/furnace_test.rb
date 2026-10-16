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
    furnace = loaded(Block::IRON, 2, Block::COAL, 3)
    tick(furnace, 199)
    assert furnace.lit?
    assert_equal 2, furnace.slots.count(Furnace::FUEL)
    assert_equal 1600, furnace.burn_total
    assert furnace.slots.empty?(Furnace::OUTPUT)
    tick(furnace, 1)
    assert_equal 1, furnace.slots.count(Furnace::INPUT)
    assert_equal Block::IRON_INGOT, furnace.slots.block(Furnace::OUTPUT)
    assert_equal 1, furnace.slots.count(Furnace::OUTPUT)
  end

  def test_fuel_does_not_burn_without_something_to_smelt
    furnace = loaded(Block::AIR, 0, Block::COAL, 1)
    tick(furnace, 5)
    refute furnace.lit?
    assert_equal 1, furnace.slots.count(Furnace::FUEL)
  end

  def test_a_new_fuel_item_burns_only_when_the_input_smelts
    furnace = loaded(Block::STONE, 1, Block::COAL, 1)
    furnace.tick(0, 0, 1600)
    refute furnace.lit?
    assert_equal 1, furnace.slots.count(Furnace::FUEL)
  end

  def test_a_lit_fuel_item_burns_to_its_end
    furnace = loaded(Block::IRON, 1, Block::OAK_PLANKS, 1)
    # The tick that lights the fuel does not take from its burn time.
    tick(furnace, 200)
    assert furnace.lit?
    assert_equal 101, furnace.burn
    tick(furnace, 100)
    assert furnace.lit?
    tick(furnace, 1)
    refute furnace.lit?
  end

  def test_the_progress_goes_back_twice_as_fast_while_the_furnace_is_out
    furnace = loaded(Block::IRON, 1, Block::OAK_PLANKS, 0)
    furnace.progress = 9
    tick(furnace, 2)
    assert_equal 5, furnace.progress
    tick(furnace, 3)
    assert_equal 0, furnace.progress
  end

  def test_nothing_smelts_when_the_output_slot_holds_another_item
    furnace = loaded(Block::IRON, 1, Block::COAL, 1)
    furnace.slots.set(Furnace::OUTPUT, Block::COAL, 1)
    tick(furnace, 10)
    refute furnace.lit?
    assert_equal 0, furnace.progress
    assert_equal 1, furnace.slots.count(Furnace::FUEL)
  end

  def test_nothing_smelts_when_the_output_stack_is_full
    furnace = loaded(Block::IRON, 1, Block::COAL, 1)
    furnace.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Block.stack(Block::IRON_INGOT))
    tick(furnace, 10)
    refute furnace.lit?
    furnace.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Block.stack(Block::IRON_INGOT) - 1)
    tick(furnace, 200)
    assert_equal Block.stack(Block::IRON_INGOT), furnace.slots.count(Furnace::OUTPUT)
  end

  def test_the_next_item_takes_200_ticks_again
    furnace = loaded(Block::IRON, 2, Block::COAL, 1)
    tick(furnace, 200)
    tick(furnace, 199)
    assert_equal 1, furnace.slots.count(Furnace::OUTPUT)
    tick(furnace, 1)
    assert_equal 2, furnace.slots.count(Furnace::OUTPUT)
  end

  def test_a_lit_furnace_stops_smelting_when_the_output_stack_is_full
    furnace = loaded(Block::IRON, 1, Block::COAL, 0)
    furnace.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, Block.stack(Block::IRON_INGOT))
    furnace.burn = 1000
    tick(furnace, 300)
    assert furnace.lit?
    assert_equal 0, furnace.progress
    assert_equal 1, furnace.slots.count(Furnace::INPUT)
    assert_equal Block.stack(Block::IRON_INGOT), furnace.slots.count(Furnace::OUTPUT)
  end

  def test_an_item_in_the_fuel_slot_that_does_not_burn_stays
    furnace = loaded(Block::IRON, 1, Block::STONE, 1)
    tick(furnace, 5)
    refute furnace.lit?
    assert_equal 1, furnace.slots.count(Furnace::FUEL)
    assert_equal 0, furnace.progress
  end

  def test_a_burn_time_without_a_fuel_item_lights_nothing
    furnace = loaded(Block::IRON, 1, Block::AIR, 0)
    furnace.tick(Block::IRON_INGOT, 1, 1600)
    refute furnace.lit?
  end

  def test_the_progress_goes_back_also_with_fuel_but_no_input
    furnace = loaded(Block::AIR, 0, Block::COAL, 1)
    furnace.progress = 9
    tick(furnace, 1)
    assert_equal 7, furnace.progress
  end

  def test_a_new_furnace_is_cold_and_has_three_empty_slots_at_its_block
    furnace = Furnace.new(1, 2, 3)
    assert_equal [1, 2, 3], [furnace.x, furnace.y, furnace.z]
    assert_equal 0, furnace.burn
    assert_equal 0, furnace.burn_total
    assert_equal 0, furnace.progress
    assert [Furnace::INPUT, Furnace::FUEL, Furnace::OUTPUT].all? { |slot| furnace.slots.empty?(slot) }
  end

  def test_a_furnace_is_idle_while_it_is_cold_and_empty
    furnace = Furnace.new(1, 2, 3)
    assert furnace.idle?
    tick(furnace, 3)
    assert_equal 0, furnace.burn
    assert furnace.idle?
    furnace.progress = 1
    refute furnace.idle?
    furnace.progress = 0
    furnace.burn = 1
    refute furnace.idle?
    refute loaded(Block::IRON, 1, Block::AIR, 0).idle?
    refute loaded(Block::AIR, 0, Block::COAL, 1).idle?
    furnace = Furnace.new(1, 2, 3)
    furnace.slots.set(Furnace::OUTPUT, Block::IRON_INGOT, 1)
    refute furnace.idle?
  end

  # A furnace with input_count of input and fuel_count of fuel.
  def loaded(input, input_count, fuel, fuel_count)
    furnace = Furnace.new(0, 0, 0)
    furnace.slots.set(Furnace::INPUT, input, input_count)
    furnace.slots.set(Furnace::FUEL, fuel, fuel_count)
    furnace
  end

  # Runs a furnace that smelts iron for a count of ticks, with the burn time
  # of the item in its fuel slot.
  def tick(furnace, ticks)
    ticks.times do
      out = furnace.slots.block(Furnace::INPUT) == Block::IRON ? Block::IRON_INGOT : 0
      furnace.tick(out, out == 0 ? 0 : 1, Furnace.fuel_ticks(furnace.slots.block(Furnace::FUEL)))
    end
  end
end
