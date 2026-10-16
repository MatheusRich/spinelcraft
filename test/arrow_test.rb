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
end
