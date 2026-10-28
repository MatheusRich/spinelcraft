require_relative "test_helper"

class ArrowTest < Minitest::Test
  # The sound of an arrow plays when it lands.
  def test_an_arrow_lands_once_when_it_sticks_in_a_block
    world = world_with_one_chunk
    arrow = Arrow.new(8.5, world.height_at(8, 8) + 2.0, 8.5, 0.0, -10.0, 0.0, 5.0, 0)
    steps = 0
    steps += 1 while arrow.fly(world, 1.0 / 60.0) && steps < 120
    assert arrow.landed
    arrow.landed = false
    arrow.fly(world, 1.0 / 60.0)
    refute arrow.landed
  end

  # Keeps the color of each box that an arrow draws.
  class BoxLog
    attr_reader :colors

    def initialize
      @colors = []
    end

    def box(*arguments)
      @colors << arguments.last
    end
  end

  def test_an_arrow_is_a_brown_shaft_with_light_feathers_at_the_back
    log = BoxLog.new
    Arrow.new(8.0, 70.0, 8.0, 1.0, 0.0, 0.0, 5.0, 0).draw(log)
    shaft, fletching = log.colors
    assert_equal 2, log.colors.size
    assert_operator shaft.red, :>, shaft.blue
    assert_operator fletching.red, :>, shaft.red
  end
end
