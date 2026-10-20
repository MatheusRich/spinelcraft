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

  # Runs a frame of dt seconds: the steps of water and lava that start,
  # with each change in the world before the next one, as
  # Game#update_fluids does.
  def frame(dt)
    pour while @fluids.next_water(@changes) if @fluids.water_step?(dt)
    pour while @fluids.next_lava(@changes) if @fluids.lava_step?(dt)
  end

  def pour
    x, y, z, block = @changes
    @changes.clear
    put(x, y, z, block)
  end

  # Runs count steps of water and of lava.
  def steps(count) = count.times { frame(Fluids::LAVA_STEP) }

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
      assert_equal Block::FLOW + 6, @fluids.water_wanted(4, Y, Z), source_x
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
    assert_equal([-1] * 5, (4..8).map { |x| @fluids.lava_wanted(x, Y, Z) })
  end

  def test_lava_flows_into_a_plant_and_into_water_of_each_flowing_level
    @world.set(5, Y, Z, Block::ROSE)
    @world.set(3, Y, Z, Block::FLOW)
    @world.set(4, Y, Z, Block::LAVA)
    assert_equal [Block::LAVA_FLOW + 2] * 2, [@fluids.lava_wanted(5, Y, Z), @fluids.lava_wanted(3, Y, Z)]
  end

  def test_no_fluid_flows_out_of_the_world
    @world.set(4, 0, Z, Block::LAVA)
    @world.set(5, 0, Z, Block::WATER)
    assert_equal [-1, -1], [@fluids.lava_wanted(4, -1, Z), @fluids.water_wanted(5, -1, Z)]
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

  # Lava that falls onto flowing water takes its place, and the water
  # next to it cools it.
  def test_lava_takes_the_place_of_flowing_water_and_the_water_cools_it
    @world.set(2, Y, Z, Block::WATER)
    @world.set(3, Y, Z, Block::FLOW + 6)
    put(3, Y + 1, Z, Block::LAVA)
    assert_equal Block::LAVA_FLOW + 2, @fluids.lava_wanted(3, Y, Z)
    steps(2)
    assert_equal Block::COBBLE, @world.get(3, Y, Z)
  end

  def test_lava_does_not_take_the_place_of_a_water_source
    @world.set(4, Y, Z, Block::WATER)
    @world.set(4, Y + 1, Z, Block::LAVA)
    assert_equal(-1, @fluids.lava_wanted(4, Y, Z))
  end

  # Water moves 1 block in each 0.25 s, and lava 1 block in each 1.5 s.
  # The first frame starts the first step, and the steps after it start at
  # 0.25 s, 0.5 s and so on. A frame of 1/16 s is exact in binary.
  def test_water_moves_1_block_in_each_0_25_seconds
    put(4, Y, Z, Block::WATER)
    15.times { frame(1.0 / 16) }
    assert_equal [8, 7, 6, 5, 4, 0], levels(4..9)
    frame(1.0 / 16)
    assert_equal 3, levels([9]).first
  end

  def test_lava_moves_1_block_in_each_1_5_seconds
    put(4, Y, Z, Block::LAVA)
    47.times { frame(1.0 / 16) }
    assert_equal [4, 3, 2, 0], lava_levels(4..7)
    frame(1.0 / 16)
    assert_equal 1, lava_levels([7]).first
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
    assert_equal([-1, -1, -1, -1], [4, 10, 7, 13].map { |x| @fluids.water_wanted(x, Y, Z) })
    assert_equal([-1, -1, -1, -1], [4, 10, 7, 13].map { |x| @fluids.lava_wanted(x, Y, Z) })
  end

  def test_clear_forgets_the_cells_that_woke
    put(4, Y, Z, Block::WATER)
    put(10, Y, Z, Block::LAVA)
    @fluids.clear
    steps(1)
    assert_equal [8, 0], levels(4..5)
    assert_equal [4, 0], lava_levels(10..11)
  end
end
