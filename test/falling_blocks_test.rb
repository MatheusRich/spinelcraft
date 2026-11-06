require_relative "test_helper"

class FallingBlocksTest < Minitest::Test
  # The height of the stone floor in the open air over the one loaded
  # chunk, and a column in the middle of the chunk.
  FLOOR = SKY_Y - 20
  X = 8
  Z = 8
  STEP = 0.02
  LONG_UPDATE = 0.5
  # Long enough to fall from FLOOR out of the world.
  LONG_FALL = 20.0

  def setup
    @world = world_with_one_chunk
    @world.set(X, FLOOR, Z, Block::STONE)
    @falling = FallingBlocks.new(@world)
    @landings = []
  end

  def start(block, x, y) = @falling.add(FallingBlock.new(block, x, y.to_f, Z))

  # Runs one update of dt seconds, and puts each landing in the world
  # before the next one, as Game#update_falling does.
  def update(dt)
    @falling.update(dt) do |falling, y|
      @landings << [falling.x, y, falling.z, falling.block]
      @world.set(falling.x, y, falling.z, falling.block)
      yield if block_given?
    end
  end

  def fall_for(seconds) = (seconds / STEP).round.times { update(STEP) }

  def test_sand_lands_on_the_floor
    start(Block::SAND, X, FLOOR + 6)
    fall_for(2.0)
    assert_equal [[X, FLOOR + 1, Z, Block::SAND]], @landings
    assert_empty @falling
  end

  def test_blocks_in_one_column_stack_in_the_order_that_they_land
    start(Block::SAND, X, FLOOR + 6)
    start(Block::GRAVEL, X, FLOOR + 7)
    fall_for(2.0)
    assert_equal [[X, FLOOR + 1, Z, Block::SAND], [X, FLOOR + 2, Z, Block::GRAVEL]], @landings
  end

  def test_gravel_falls_through_lava_to_the_bottom
    @world.set(X, FLOOR + 1, Z, Block::LAVA)
    @world.set(X, FLOOR + 2, Z, Block::LAVA)
    start(Block::GRAVEL, X, FLOOR + 6)
    fall_for(2.0)
    assert_equal [[X, FLOOR + 1, Z, Block::GRAVEL]], @landings
  end

  def test_sand_lands_in_the_cell_of_a_torch
    @world.set(X, FLOOR + 1, Z, Block::TORCH)
    start(Block::SAND, X, FLOOR + 6)
    fall_for(2.0)
    assert_equal [[X, FLOOR + 1, Z, Block::SAND]], @landings
  end

  def test_a_block_that_waits_does_not_stop_the_others
    start(Block::SAND, X + CHUNK, FLOOR + 6)
    start(Block::GRAVEL, X, FLOOR + 6)
    fall_for(2.0)
    assert_equal [[X, FLOOR + 1, Z, Block::GRAVEL]], @landings
  end

  # A landing can make more blocks fall (Game#set_block). They fall in the
  # same update.
  def test_a_block_that_starts_in_an_update_falls_in_that_update
    @world.set(X + 1, FLOOR + 1, Z, Block::STONE)
    start(Block::SAND, X, FLOOR + 1)
    update(STEP) { start(Block::GRAVEL, X + 1, FLOOR + 2) if @landings.size == 1 }
    assert_equal [[X, FLOOR + 1, Z, Block::SAND], [X + 1, FLOOR + 2, Z, Block::GRAVEL]], @landings
  end

  # A long update can take a block past the top of a stack. It lands on top.
  def test_a_block_that_falls_into_a_stack_in_one_update_lands_on_top
    (FLOOR..FLOOR + 3).each { |y| @world.set(X, y, Z, Block::STONE) }
    start(Block::SAND, X, FLOOR + 6)
    update(LONG_UPDATE)
    assert_equal [[X, FLOOR + 4, Z, Block::SAND]], @landings
  end

  # A block of a column that is full up to the top of the world lands in
  # the top cell, and not over the world.
  def test_a_block_in_a_full_column_lands_in_the_top_cell
    (FLOOR..WY - 1).each { |y| @world.set(X, y, Z, Block::STONE) }
    start(Block::SAND, X, FLOOR + 2)
    update(STEP)
    assert_equal [[X, WY - 1, Z, Block::SAND]], @landings
  end

  def test_a_block_that_falls_out_of_the_world_goes_with_no_landing
    (0..FLOOR).each { |y| @world.set(X, y, Z, Block::AIR) }
    start(Block::SAND, X, FLOOR + 6)
    fall_for(LONG_FALL)
    assert_empty @landings
    assert_empty @falling
  end

  def test_a_block_over_a_chunk_that_is_not_loaded_waits
    start(Block::SAND, X + CHUNK, FLOOR + 6)
    fall_for(LONG_FALL)
    assert_equal 1, @falling.size
  end

  def test_clear_forgets_the_falling_blocks
    start(Block::SAND, X, FLOOR + 6)
    @falling.clear
    fall_for(2.0)
    assert_empty @landings
  end
end
