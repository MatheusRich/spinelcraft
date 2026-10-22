require_relative "test_helper"

class VoxelWalkTest < Minitest::Test
  def setup
    @walk = VoxelWalk.new
  end

  def test_the_walk_starts_in_the_cell_of_the_start
    @walk.from(2.5, -3.25, 7.75)
    assert_equal [2, -4, 7], [@walk.x, @walk.y, @walk.z]
    assert_equal [[2, -4, 7, 0.0]], cells_toward([2.5, -3.25, 7.75], [1.0, 0.0, 0.0], 0.0)
  end

  def test_a_walk_along_x_goes_through_each_border
    assert_equal [[2, 0, 0, 0.0], [3, 0, 0, 0.75], [4, 0, 0, 1.75], [5, 0, 0, 2.75]],
                 cells_toward([2.25, 0.5, 0.5], [1.0, 0.0, 0.0], 3.0)
  end

  def test_a_walk_goes_back_along_a_negative_direction
    assert_equal [[2, 0, 0, 0.0], [2, 0, -1, 0.5]], cells_toward([2.25, 0.5, 0.5], [0.0, 0.0, -1.0], 0.5)
    assert_equal [[2, 0, 0, 0.0], [1, 0, 0, 0.25]], cells_toward([2.25, 0.5, 0.5], [-1.0, 0.0, 0.0], 0.5)
  end

  def test_a_walk_goes_up_and_down
    assert_equal [[0, 4, 0, 0.0], [0, 5, 0, 0.25]], cells_toward([0.5, 4.75, 0.5], [0.0, 1.0, 0.0], 0.5)
    assert_equal [[0, 4, 0, 0.0], [0, 3, 0, 0.75]], cells_toward([0.5, 4.75, 0.5], [0.0, -1.0, 0.0], 1.0)
  end

  # The along of each cell counts in lengths of the direction.
  def test_the_along_counts_in_lengths_of_the_direction
    assert_equal [[0, 0, 0, 0.0], [1, 0, 0, 0.25]], cells_toward([0.5, 0.5, 0.5], [2.0, 0.0, 0.0], 0.25)
  end

  # The ray goes from 0.5, 0.25 at a slope of 1 in x and z: it crosses
  # x = 1 at 0.5 and z = 1 at 0.75, so it goes into 1, 0 first.
  def test_a_slant_walk_goes_through_the_nearest_border_first
    assert_equal [[0, 0, 0, 0.0], [1, 0, 0, 0.5], [1, 0, 1, 0.75]],
                 cells_toward([0.5, 0.5, 0.25], [1.0, 0.0, 1.0], 0.75)
    assert_equal [0, 1, 0], cells_toward([0.25, 0.5, 0.5], [1.0, 1.0, 0.0], 0.5)[1].first(3)
  end

  # Through a corner of four cells, the walk goes into one of the cells
  # at the side, so that it never skips past two blocks that touch only
  # at an edge.
  def test_a_walk_through_a_corner_goes_through_a_cell_at_the_side
    cells = cells_toward([0.5, 0.5, 0.5], [1.0, 0.0, 1.0], 0.5)
    assert_equal([[0, 0, 0], [0, 0, 1], [1, 0, 1]], cells.map { |cell| cell.first(3) })
    assert_equal [0, 1, 0], cells_toward([0.5, 0.5, 0.5], [1.0, 1.0, 0.0], 0.5)[1].first(3)
    assert_equal [0, 0, 1], cells_toward([0.5, 0.5, 0.5], [0.0, 1.0, 1.0], 0.5)[1].first(3)
  end

  def test_a_walk_starts_again_from_a_new_start
    cells_toward([0.5, 0.5, 0.5], [1.0, 0.0, 0.0], 3.0)
    assert_equal [[10, 0, 0, 0.0], [11, 0, 0, 0.5]], cells_toward([10.5, 0.5, 0.5], [1.0, 0.0, 0.0], 0.5)
  end

  # The cell at x = 4 starts at a distance of 1.75, and the one at x = 5 at
  # 2.75.
  def test_a_walk_goes_through_each_cell_that_starts_within_reach
    assert_equal [2, 3, 4], cells_toward([2.25, 0.5, -0.5], [1.0, 0.0, 0.0], 1.75).map(&:first)
  end

  def test_a_walk_stops_where_the_block_returns
    assert_equal 3, first_x_over(2)
  end

  def test_a_walk_to_a_target_goes_through_the_cell_of_the_target
    cells = []
    @walk.from(0.5, 0.5, 4.5).to(3.5, 0.5, 6.5) { |x, _y, z| cells << [x, z] }
    assert_equal [[0, 4], [1, 4], [1, 5], [2, 5], [2, 6], [3, 6]], cells
  end

  def test_a_second_walk_from_the_same_start_starts_over
    @walk.from(0.5, 0.5, 0.5)
    first = []
    @walk.toward(1.0, 0.0, 0.0, reach: 2.0) { |x, _y, _z| first << x }
    again = []
    @walk.toward(0.0, 0.0, 1.0, reach: 1.0) { |x, _y, z| again << [x, z, @walk.along] }
    assert_equal [0, 1, 2], first
    assert_equal [[0, 0, 0.0], [0, 1, 0.5]], again
  end

  def test_the_distance_to_a_box_is_along_the_ray_of_the_walk
    @walk.from(0.5, 0.5, 0.5).toward(0.0, 0.0, 1.0, reach: 0.0) { |_x, _y, _z| nil }
    assert_in_delta 2.5, @walk.box_distance(0.0, 0.0, 3.0, 1.0, 1.0, 4.0), 1.0e-9
    assert_equal(-1.0, @walk.box_distance(2.0, 0.0, 3.0, 3.0, 1.0, 4.0))
  end

  private

  # The cells that the walk goes through from origin along dir within reach,
  # each as x, y, z and along.
  def cells_toward(origin, dir, reach)
    cells = []
    @walk.from(*origin).toward(*dir, reach: reach) { |x, y, z| cells << [x, y, z, @walk.along] }
    cells
  end

  def first_x_over(limit)
    @walk.from(0.5, 0.5, 0.5).toward(1.0, 0.0, 0.0, reach: 10.0) { |x, _y, _z| return x if x > limit }
    nil
  end
end
