require_relative "test_helper"

class FurnacesTest < Minitest::Test
  def setup
    @world = world_with_one_chunk
    @book = RecipeBook.new
    @furnaces = Furnaces.new
    @changes = []
  end

  def test_a_cell_keeps_its_furnace
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    assert_same furnace, @furnaces.furnace_at(3, SKY_Y, 4)
    assert_equal [3, SKY_Y, 4], [furnace.x, furnace.y, furnace.z]
    assert_equal 1, @furnaces.size
  end

  def test_a_removed_furnace_is_forgotten
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    assert_same furnace, @furnaces.remove_at(World.key(3, SKY_Y, 4))
    assert_equal 0, @furnaces.size
    assert_nil @furnaces.remove_at(World.key(3, SKY_Y, 4))
  end

  def test_a_furnace_that_lights_and_goes_out_changes_its_block
    @world.set(3, SKY_Y, 4, Block::FURNACE)
    load_iron(@furnaces.furnace_at(3, SKY_Y, 4))
    @furnaces.smelt(1.0, @world, @book, @changes)
    assert_equal [3, SKY_Y, 4, lit_furnace], @changes
    @changes.clear
    @world.set(3, SKY_Y, 4, lit_furnace)
    @furnaces.smelt(1.0, @world, @book, @changes)
    assert_empty @changes, "a lit furnace that still burns"
    @furnaces.smelt(100.0, @world, @book, @changes)
    assert_equal [3, SKY_Y, 4, Block::FURNACE], @changes
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    assert_equal [Block::IRON_INGOT, 1], [furnace.slots.block(Furnace::OUTPUT), furnace.slots.count(Furnace::OUTPUT)]
  end

  # A lit block of a furnace that does not burn goes out at the next tick.
  def test_a_step_without_a_tick_changes_no_block
    @world.set(3, SKY_Y, 4, lit_furnace)
    @furnaces.furnace_at(3, SKY_Y, 4)
    @furnaces.smelt(0.01, @world, @book, @changes)
    assert_empty @changes
    @furnaces.smelt(0.05, @world, @book, @changes)
    assert_equal [3, SKY_Y, 4, Block::FURNACE], @changes
  end

  def test_a_furnace_burns_no_fuel_for_what_it_does_not_smelt
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    furnace.slots.set(Furnace::INPUT, Block::DIRT, 1)
    furnace.slots.set(Furnace::FUEL, Block::COAL, 1)
    @furnaces.smelt(1.0, @world, @book, @changes)
    refute furnace.lit?
    assert_equal [Block::DIRT, 1, Block::COAL, 1], [furnace.slots.block(Furnace::INPUT), furnace.slots.count(Furnace::INPUT),
                                                   furnace.slots.block(Furnace::FUEL), furnace.slots.count(Furnace::FUEL)]
    assert furnace.slots.empty?(Furnace::OUTPUT)
  end

  def test_a_furnace_without_its_block_changes_no_block
    load_iron(@furnaces.furnace_at(3, SKY_Y, 4))
    @furnaces.smelt(1.0, @world, @book, @changes)
    assert_empty @changes
  end

  def test_a_furnace_in_a_chunk_that_is_not_loaded_waits
    furnace = @furnaces.furnace_at(40, SKY_Y, 4)
    load_iron(furnace)
    @furnaces.smelt(1.0, @world, @book, @changes)
    assert_equal 0, furnace.progress
    refute furnace.lit?
  end

  # A tick is 0.05 seconds. Two steps of 0.03 seconds make one tick.
  def test_the_time_of_a_part_of_a_tick_waits_for_the_next_step
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    load_iron(furnace)
    @furnaces.smelt(0.03, @world, @book, @changes)
    assert_equal 0, furnace.progress
    @furnaces.smelt(0.03, @world, @book, @changes)
    assert_equal 1, furnace.progress
    @furnaces.smelt(1.0, @world, @book, @changes)
    assert_equal 21, furnace.progress
  end

  def test_clear_forgets_the_furnaces_and_the_time_of_a_part_of_a_tick
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    load_iron(furnace)
    @furnaces.smelt(0.03, @world, @book, @changes)
    @furnaces.clear
    assert_equal 0, @furnaces.size
    furnace = @furnaces.furnace_at(3, SKY_Y, 4)
    load_iron(furnace)
    @furnaces.smelt(0.03, @world, @book, @changes)
    assert_equal 0, furnace.progress
  end

  def test_the_save_keeps_each_furnace_that_is_not_idle
    hot = @furnaces.furnace_at(3, SKY_Y, 4)
    load_iron(hot)
    @furnaces.smelt(1.0, @world, @book, @changes)
    @furnaces.furnace_at(5, SKY_Y, 4)
    fields = @furnaces.to_a
    assert_equal 1 + Furnaces::FIELDS, fields.size
    assert_equal 1, fields[0]

    loaded = Furnaces.new
    loaded.furnace_at(9, SKY_Y, 9)
    saved = ["7"] + fields.map(&:to_s) + ["8"]
    assert_equal saved.size - 1, loaded.load(saved, 1)
    assert_equal 1, loaded.size
    furnace = loaded.furnace_at(3, SKY_Y, 4)
    assert_equal [hot.burn, hot.burn_total, hot.progress, hot.slots.to_a],
                 [furnace.burn, furnace.burn_total, furnace.progress, furnace.slots.to_a]
    assert_equal [3, SKY_Y, 4], [furnace.x, furnace.y, furnace.z]
  end

  private

  def lit_furnace = Block.furnace_id(Block::FACING[Block::FURNACE], true)

  # Iron ore to smelt and coal to burn.
  def load_iron(furnace)
    furnace.slots.set(Furnace::INPUT, Block::IRON, 1)
    furnace.slots.set(Furnace::FUEL, Block::COAL, 1)
  end
end
