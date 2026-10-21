require_relative "test_helper"

# The light of a cell: from the sky by the time of day, and from torches,
# lava and jack o'lanterns, through the cells that are not opaque.
class LightTest < Minitest::Test
  # A cell high in the open air of the middle chunk.
  X = 8
  Y = SKY_Y
  Z = 8

  def setup
    @world = World.new(1337)
    (-1..1).each { |cx| (-1..1).each { |cz| @world.load_chunk(cx, cz) } }
    @light = Light.new(@world)
  end

  def test_the_sky_light_is_15_at_noon_7_at_tick_13200_4_at_midnight_and_12_in_rain
    assert_equal 15, Light.sky(6000, raining: false)
    assert_equal 7, Light.sky(13200, raining: false)
    assert_equal 4, Light.sky(18000, raining: false)
    assert_equal 12, Light.sky(6000, raining: true)
  end

  def test_the_sky_light_goes_down_at_the_first_tick_of_each_level_and_up_at_dawn
    assert_equal 15, Light.sky(12040, raining: false)
    assert_equal 14, Light.sky(12041, raining: false)
    assert_equal 4, Light.sky(22330, raining: false)
    assert_equal 5, Light.sky(22331, raining: false)
    assert_equal 15, Light.sky(23961, raining: false)
    assert_equal 15, Light.sky(0, raining: false)
    assert_equal 4, Light.sky(13670, raining: true)
    assert_equal 12, Light.sky(23992, raining: true)
  end

  def test_a_cell_under_the_open_sky_has_the_sky_light
    assert_equal 15, @light.level(X, Y, Z, 15, false, 15)
    assert_equal 4, @light.level(X, Y, Z, 4, false, 4)
  end

  def test_sky_light_comes_in_from_the_side_under_a_roof_one_less_for_each_step
    @world.set(X, Y + 1, Z, Block::STONE)
    assert_equal 14, @light.level(X, Y, Z, 15, false, 15)
    # Under a roof of 3 x 3 blocks, the open sky is 2 steps away.
    roof
    assert_equal 13, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_a_closed_cell_gets_no_sky_light
    close_cell
    assert_equal 0, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_the_search_stops_at_the_sky_reach
    @world.set(X, Y + 1, Z, Block::STONE)
    assert_equal 0, @light.level(X, Y, Z, 15, false, 1)
    assert_equal 14, @light.level(X, Y, Z, 15, false, 2)
    assert_equal 0, @light.level(X, Y, Z, 15, false, 0)
  end

  def test_leaves_let_the_sky_light_through
    @world.set(X, Y + 3, Z, Block::OAK_LEAVES)
    assert_operator @light.level(X, Y, Z, 15, false, 15), :>=, 14
  end

  def test_a_torch_lights_a_cell_through_an_opening_and_not_through_a_wall
    close_cell
    @world.set(X + 2, Y, Z, Block::TORCH)
    assert @light.lamp_near?(X, Y, Z)
    assert_equal 0, @light.level(X, Y, Z, 0, true, 0)
    @world.set(X + 1, Y, Z, Block::AIR)
    assert_equal(-1, @light.level(X, Y, Z, 0, true, 0))
  end

  def test_a_torch_lights_cells_fewer_than_14_steps_away
    @world.set(X + 13, Y, Z, Block::TORCH)
    assert_equal(-1, @light.level(X, Y, Z, 0, true, 0))
    @world.set(X + 13, Y, Z, Block::AIR)
    @world.set(X + 14, Y, Z, Block::TORCH)
    assert_operator @light.level(X, Y, Z, 0, true, 0), :>=, 0
  end

  def test_lava_and_a_jack_o_lantern_light_cells_fewer_than_15_steps_away
    @world.set(X + 14, Y, Z, Block::LAVA)
    assert_equal(-1, @light.level(X, Y, Z, 0, true, 0))
    @world.set(X + 14, Y, Z, Block::AIR)
    @world.set(X - 14, Y, Z, Block::JACK_O_LANTERN)
    assert_equal(-1, @light.level(X, Y, Z, 0, true, 0))
    @world.set(X - 14, Y, Z, Block::AIR)
    @world.set(X - 15, Y, Z, Block::JACK_O_LANTERN)
    assert_operator @light.level(X, Y, Z, 0, true, 0), :>=, 0
  end

  def test_the_search_looks_for_lamps_only_when_one_is_near
    @world.set(X + 2, Y, Z, Block::TORCH)
    assert_equal 15, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_a_lamp_is_near_when_fewer_than_15_steps_along_x_y_and_z
    @world.set(X + 5, Y - 4, Z + 5, Block::TORCH)
    assert @light.lamp_near?(X, Y, Z)
    refute @light.lamp_near?(X - 1, Y, Z)
    assert @light.lamp_near?(X + 10, Y, Z + 10)
    refute @light.lamp_near?(X + 11, Y, Z + 10)
  end

  def test_a_cell_on_the_ground_is_under_the_open_sky
    ground = @world.height_at(X, Z)
    assert_equal 15, @light.level(X, ground, Z, 15, false, 15)
  end

  def test_a_cell_under_the_open_sky_has_the_sky_light_with_a_reach_of_one_step
    assert_equal 15, @light.level(X, Y, Z, 15, false, 1)
  end

  def test_sky_light_comes_up_a_shaft_and_out_to_the_side
    close_cell
    @world.set(X, Y + 1, Z, Block::AIR)
    @world.set(X, Y + 2, Z, Block::STONE)
    assert_equal 13, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_sky_light_comes_down_and_along_a_tunnel
    close_cell
    @world.set(X, Y - 1, Z, Block::AIR)
    assert_equal 12, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_sky_light_comes_in_through_an_opening_on_either_side_along_z
    close_cell
    @world.set(X, Y, Z + 1, Block::AIR)
    assert_equal 14, @light.level(X, Y, Z, 15, false, 15)
    @world.set(X, Y, Z + 1, Block::STONE)
    @world.set(X, Y, Z - 1, Block::AIR)
    assert_equal 14, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_each_search_starts_again_from_its_own_cell
    roof
    assert_equal 13, @light.level(X, Y, Z, 15, false, 15)
    close_cell
    assert_equal 0, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_a_lamp_search_keeps_the_nearest_open_sky_and_stops_at_the_sky_reach
    @world.set(X + 20, Y, Z, Block::TORCH)
    assert_equal 15, @light.level(X, Y, Z, 15, true, 15)
    @world.set(X, Y + 1, Z, Block::STONE)
    assert_equal 0, @light.level(X, Y, Z, 15, true, 1)
  end

  def test_a_lamp_search_finds_a_torch_also_under_the_open_sky
    @world.set(X + 2, Y, Z, Block::TORCH)
    assert_equal(-1, @light.level(X, Y, Z, 15, true, 15))
  end

  def test_a_search_without_a_lamp_near_does_not_see_a_torch_or_lava_on_its_way
    roof
    @world.set(X - 1, Y, Z, Block::TORCH)
    @world.set(X, Y, Z - 1, Block::LAVA)
    assert_equal 13, @light.level(X, Y, Z, 15, false, 15)
  end

  def test_a_lamp_in_the_next_chunk_is_near
    @world.set(X + 12, Y, Z, Block::TORCH)
    assert @light.lamp_near?(X, Y, Z)
    @world.set(X + 12, Y, Z, Block::AIR)
    @world.set(X, Y, Z + 12, Block::TORCH)
    assert @light.lamp_near?(X, Y, Z)
  end

  def test_each_of_several_lamps_is_near
    @world.set(X + 1, Y, Z - 3, Block::TORCH)
    @world.set(X - 2, Y + 5, Z + 6, Block::TORCH)
    @world.set(X + 3, Y - 4, Z + 2, Block::TORCH)
    assert @light.lamp_near?(X + 3 + 6, Y - 4, Z + 2 - 7)
    refute @light.lamp_near?(X + 3 + 7, Y - 4, Z + 2 - 9)
  end

  # A roof of 3 x 3 blocks of stone over the cell.
  def roof
    (-1..1).each { |dx| (-1..1).each { |dz| @world.set(X + dx, Y + 1, Z + dz, Block::STONE) } }
  end

  # Stone on the four sides of the cell, above it and below it.
  def close_cell
    [[1, 0, 0], [-1, 0, 0], [0, 0, 1], [0, 0, -1], [0, 1, 0], [0, -1, 0]].each do |dx, dy, dz|
      @world.set(X + dx, Y + dy, Z + dz, Block::STONE)
    end
  end
end
