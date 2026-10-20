require_relative "test_helper"

class FlowQueueTest < Minitest::Test
  def setup
    @queue = FlowQueue.new(0.25)
  end

  # The cells of the step that starts now.
  def cells
    list = []
    list << [@queue.x, @queue.y, @queue.z] while @queue.next?
    list
  end

  def test_a_cell_wakes_with_its_six_neighbors
    @queue.wake(4, 5, 6)
    assert @queue.start?(0.0)
    assert_equal [[4, 5, 6], [5, 5, 6], [3, 5, 6], [4, 6, 6], [4, 4, 6], [4, 5, 7], [4, 5, 5]], cells
  end

  def test_a_step_starts_each_step_seconds_while_a_cell_is_awake
    refute @queue.start?(0.01)
    @queue.wake(4, 5, 6)
    refute @queue.start?(0.2)
    assert @queue.start?(0.05)
    cells
    @queue.wake(4, 5, 6)
    refute @queue.start?(0.125)
    assert @queue.start?(0.125)
  end

  # The time past a step counts toward the next one, but a long frame
  # does not start more steps after it.
  def test_the_time_past_a_step_counts_toward_the_next_step
    @queue.wake(4, 5, 6)
    assert @queue.start?(0.0)
    @queue.wake(4, 5, 6)
    assert @queue.start?(0.375)
    @queue.wake(4, 5, 6)
    refute @queue.start?(0.0625)
    assert @queue.start?(0.0625)
    @queue.wake(4, 5, 6)
    assert @queue.start?(1.0)
    @queue.wake(4, 5, 6)
    refute @queue.start?(0.125)
    assert @queue.start?(0.125)
    @queue.wake(4, 5, 6)
    assert @queue.start?(0.5)
    @queue.wake(4, 5, 6)
    refute @queue.start?(0.125)
  end

  def test_a_cell_that_wakes_during_a_step_waits_for_the_next_step
    @queue.wake(4, 5, 6)
    @queue.start?(0.0)
    assert @queue.next?
    @queue.wake(10, 5, 6)
    assert_equal 6, cells.size
    assert @queue.start?(0.25)
    assert_equal [10, 5, 6], cells.first
  end

  # Each wake adds 7 cells. The cells past FlowQueue::STEP_CELLS wait for
  # the next step, after the cells that woke during the step.
  def test_a_step_looks_at_6000_cells_at_most
    (FlowQueue::STEP_CELLS / 7).times { @queue.wake(1, 1, 1) }
    @queue.wake(4, 5, 6)
    @queue.start?(0.0)
    assert @queue.next?
    @queue.wake(10, 5, 6)
    assert_equal [4, 5, 6], cells.last
    @queue.start?(0.25)
    assert_equal [[10, 5, 6], [5, 5, 6]], cells.values_at(0, 7)
  end

  def test_clear_forgets_the_cells_that_woke
    @queue.wake(4, 5, 6)
    @queue.clear
    refute @queue.start?(1.0)
  end
end
