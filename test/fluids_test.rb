require_relative "test_helper"

class FluidsTest < Minitest::Test
  # The height over the stone floor in the open air over the one loaded
  # chunk, and a row along x in the middle of the chunk.
  Y = SKY_Y - 20
  Z = 8

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::STONE) } }
    @fluids = Fluids.new(@world)
    @changes = []
  end

  # Puts block at x, y, z and wakes the cells around it, as
  # Game#set_block does.
  def put(x, y, z, block)
    @world.set(x, y, z, block)
    @fluids.wake(x, y, z)
  end

  # Runs count steps, and puts each change in the world before the next
  # one, as Game#update_water does.
  def steps(count)
    count.times do
      @fluids.start_step
      while @fluids.next_change(@changes)
        x, y, z, block = @changes
        @changes.clear
        put(x, y, z, block)
      end
    end
  end

  def levels(row, y = Y) = row.map { |x| Block::WATER_LEVEL[@world.get(x, y, Z)] }
  def lava_levels(row) = row.map { |x| Block::LAVA_LEVEL[@world.get(x, Y, Z)] }

  def test_water_spreads_7_blocks_over_a_floor
    put(4, Y, Z, Block::WATER)
    steps(10)
    assert_equal [8, 7, 6, 5, 4, 3, 2, 1, 0], levels(4..12)
    assert_equal [7, 6, 5, 4], levels(3.downto(0))
    assert_equal([7, 1, 1, 0], [Z + 1, Z + 7, Z - 7, Z - 8].map { |z| Block::WATER_LEVEL[@world.get(4, Y, z)] })
  end

  # The best neighbor gives the level, in each order of the neighbors.
  def test_the_best_neighbor_gives_the_level
    [3, 5].each do |source_x|
      @world.set(source_x, Y, Z, Block::WATER)
      [8 - source_x, 4].each { |x| @world.set(x, Y, Z + 1, Block::FLOW + 6) }
      [8 - source_x, 4].each { |x| @world.set(x, Y, Z - 1, Block::FLOW + 6) }
      @world.set(8 - source_x, Y, Z, Block::FLOW + 6)
      assert_equal Block::FLOW + 6, @fluids.wanted(4, Y, Z), source_x
    end
  end

  # Water falls from flowing water of each level, also the last one.
  def test_water_falls_from_its_last_level
    @world.set(11, Y - 1, Z, Block::AIR)
    put(4, Y, Z, Block::WATER)
    steps(10)
    assert_equal([1, 7], [Y, Y - 1].map { |y| Block::WATER_LEVEL[@world.get(11, y, Z)] })
  end

  # A source spreads sideways also with no solid block under it.
  def test_a_source_in_the_air_spreads_one_block_and_falls
    put(4, Y + 3, Z, Block::WATER)
    steps(2)
    assert_equal [8, 7, 0], levels(4..6, Y + 3)
    assert_equal [7, 7], levels(4..5, Y + 2)
  end

  def test_lava_spreads_3_blocks_over_a_floor
    put(4, Y, Z, Block::LAVA)
    steps(10)
    assert_equal [4, 3, 2, 1, 0], lava_levels(4..8)
  end

  def test_lava_falls_with_level_3_and_a_lava_source_spreads_in_the_air
    put(4, Y + 2, Z, Block::LAVA)
    steps(1)
    assert_equal([3, 3], [[4, Y + 1], [5, Y + 2]].map { |x, y| Block::LAVA_LEVEL[@world.get(x, y, Z)] })
  end

  def test_a_step_moves_the_fluid_one_block
    put(4, Y, Z, Block::WATER)
    steps(2)
    assert_equal [8, 7, 6, 0], levels(4..7)
  end

  def test_water_drains_when_its_source_is_gone
    put(4, Y, Z, Block::WATER)
    steps(10)
    put(4, Y, Z, Block::AIR)
    steps(10)
    assert_equal [0] * 9, levels(4..12)
  end

  def test_lava_drains_when_its_source_is_gone
    put(4, Y, Z, Block::LAVA)
    steps(10)
    put(4, Y, Z, Block::AIR)
    steps(10)
    assert_equal [0] * 5, lava_levels(4..8)
  end

  # Falling water has level 7 and spreads only where it rests on a solid
  # block. Glass around the source keeps it from spreading in the air.
  def test_water_falls_and_spreads_where_it_lands
    [[3, Z], [5, Z], [4, Z - 1], [4, Z + 1]].each { |x, z| @world.set(x, Y + 3, z, Block::GLASS) }
    put(4, Y + 3, Z, Block::WATER)
    steps(12)
    assert_equal([7, 7, 7], [Y + 2, Y + 1, Y].map { |y| Block::WATER_LEVEL[@world.get(4, y, Z)] })
    assert_equal [0, 0], levels(5..6, Y + 1)
    assert_equal [6, 5, 1, 0], levels([5, 6, 10, 11])
  end

  def test_water_on_a_side_cools_lava_into_cobblestone
    put(4, Y, Z, Block::LAVA)
    put(5, Y, Z, Block::WATER)
    steps(1)
    assert_equal Block::COBBLE, @world.get(4, Y, Z)
  end

  def test_lava_flows_into_a_cell_before_water
    @world.set(3, Y, Z, Block::WATER)
    put(5, Y, Z, Block::LAVA)
    steps(1)
    assert_equal 3, Block::LAVA_LEVEL[@world.get(4, Y, Z)]
  end

  def test_water_flows_into_a_plant_and_not_into_a_solid_block
    @world.set(5, Y, Z, Block::ROSE)
    @world.set(3, Y, Z, Block::GLASS)
    put(4, Y, Z, Block::WATER)
    steps(1)
    assert_equal 7, Block::WATER_LEVEL[@world.get(5, Y, Z)]
    assert_equal Block::GLASS, @world.get(3, Y, Z)
  end

  def test_a_source_and_a_cell_with_no_fluid_next_to_it_stay
    @world.set(4, Y, Z, Block::WATER)
    @world.set(10, Y, Z, Block::LAVA)
    @world.set(7, Y, Z, Block::ROSE)
    assert_equal([-1, -1, -1, -1], [4, 10, 7, 13].map { |x| @fluids.wanted(x, Y, Z) })
  end

  # The cells past Fluids::STEP_CELLS wait for the next step. Each wake
  # adds 7 cells, so the 6000th cell is the source, and the cells next to
  # it wait.
  def test_a_step_looks_at_6000_cells_at_most
    (Fluids::STEP_CELLS / 7).times { @fluids.wake(12, Y + 4, Z) }
    put(4, Y, Z, Block::WATER)
    steps(1)
    assert_equal [0, 8, 0], levels(3..5)
    steps(1)
    assert_equal [7, 8, 7], levels(3..5)
  end

  def test_a_cell_that_wakes_during_a_step_waits_for_the_next_step
    put(4, Y, Z, Block::WATER)
    @fluids.start_step
    assert @fluids.next_change(@changes)
    put(*@changes)
    @changes.clear
    put(10, Y, Z, Block::WATER)
    @changes.clear while @fluids.next_change(@changes)
    assert_equal 0, Block::WATER_LEVEL[@world.get(11, Y, Z)]
  end

  def test_a_step_is_due_each_0_15_seconds_while_a_cell_is_awake
    refute @fluids.due?(0.01)
    @fluids.wake(4, Y, Z)
    refute @fluids.due?(0.1)
    assert @fluids.due?(0.06)
    refute @fluids.due?(0.14)
    assert @fluids.due?(0.02)
    assert @fluids.due?(Fluids::STEP)
  end

  def test_clear_forgets_the_cells_that_woke
    put(4, Y, Z, Block::WATER)
    @fluids.clear
    steps(1)
    assert_equal [8, 0], levels(4..5)
    refute @fluids.due?(1.0)
  end
end
