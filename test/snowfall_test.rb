require_relative "test_helper"

class SnowfallTest < Minitest::Test
  FRAME = 1.0 / 60.0

  def test_flakes_fall_over_snow_and_not_over_rain_or_a_desert
    assert_operator flakes_over(-70, -70).size, :>, 20
    assert_empty flakes_over(-70, -47)
    assert_empty flakes_over(-8, 16)
  end

  def test_no_flake_falls_without_rain
    assert_empty flakes_over(-70, -70, strength: 0.0)
  end

  def test_a_stronger_rain_has_more_flakes
    weak = flakes_over(-70, -70, strength: 0.3).size
    strong = flakes_over(-70, -70, strength: 1.0).size
    assert_operator weak, :>, 0
    assert_operator strong, :>, weak
  end

  def test_the_fast_graphics_have_fewer_flakes
    fancy = flakes_over(-70, -70, mode: GraphicsMode::FANCY).size
    fast = flakes_over(-70, -70, mode: GraphicsMode::FAST).size
    assert_operator fast, :<, fancy
    assert_operator fancy, :<=, Snowfall::FLAKES
  end

  def test_each_flake_falls_down
    snowfall, world, player = snow_in(-70, -70)
    before = heights(snowfall, player)
    snowfall.update(world, player, 0.1)
    after = heights(snowfall, player)
    shared = before.keys & after.keys
    assert_operator shared.size, :>, 20
    assert(shared.all? { |z| after[z] < before[z] })
  end

  def test_a_flake_that_lands_goes_away
    snowfall, world, player = snow_in(-70, -70)
    ground = world.height_at(player.x.floor, player.z.floor)
    player.y = ground.to_f - 30.0
    before = flakes(snowfall, player).size
    snowfall.update(world, player, 60.0)
    assert_operator flakes(snowfall, player).size, :<, before / 10
  end

  def test_the_flakes_stay_in_the_box_around_the_player
    snowfall, world, player = snow_in(-70, -70)
    player.x += 5.0
    300.times { snowfall.update(world, player, FRAME) }
    xs = flakes(snowfall, player).flatten(1).map { |vertex| vertex[0] }
    assert_operator xs.size, :>, 0
    assert_operator (xs.max - player.x), :<=, Weather::FAST_R + 1.0
    assert_operator (player.x - xs.min), :<=, Weather::FAST_R + 1.0
  end

  def test_a_new_flake_grows_from_nothing
    snowfall, world, player = snow_in(-70, -70, seconds: 0.0)
    snowfall.update(world, player, FRAME)
    widths = flakes(snowfall, player).map { |quad| (quad[0][0] - quad[1][0]).abs + (quad[0][2] - quad[1][2]).abs }
    assert_operator widths.size, :>, 0
    assert_operator widths.max, :<, 0.1 * Snowfall::HALF
  end

  def test_the_flakes_of_a_slot_sway_at_their_own_pace
    snowfall, world, player = snow_in(-70, -70)
    first = flakes(snowfall, player).map { |quad| quad[0][0] }
    snowfall.update(world, player, 0.5)
    second = flakes(snowfall, player).map { |quad| quad[0][0] }
    refute_equal first.first(20), second.first(20)
  end

  def test_the_first_frame_starts_a_fixed_number_of_flakes
    _snowfall, _world, _player = nil
    world = World.new(1337)
    world.load_chunk(-70, -70)
    player = Player.new(-1111.5, 90.0, -1111.5)
    snowfall = Snowfall.new(1)
    snowfall.graphics = GraphicsMode::FAST
    snowfall.strength = 1.0
    snowfall.update(world, player, FRAME)
    assert_equal Snowfall::REFILLS_PER_FRAME, flakes(snowfall, player).size
  end

  def test_a_new_snowfall_has_no_rain_and_the_radius_of_the_fancy_graphics
    default = Snowfall.new(1)
    world = World.new(1337)
    world.load_chunk(-70, -70)
    player = Player.new(-1111.5, 80.0, -1111.5)
    10.times { default.update(world, player, FRAME) }
    assert_empty flakes(default, player)
    fancy = Snowfall.new(1)
    fancy.graphics = GraphicsMode::FANCY
    assert_equal count_in(fancy), count_in(default, strength: 1.0)
  end

  def test_the_flakes_appear_on_both_sides_of_the_player_and_far_from_it
    snowfall, _world, player = snow_in(-70, -70)
    xs = flakes(snowfall, player).map { |quad| quad[0][0] - player.x }
    zs = flakes(snowfall, player).map { |quad| quad[0][2] - player.z }
    [xs, zs].each do |offsets|
      assert_operator offsets.min, :<, -0.5 * Weather::FAST_R
      assert_operator offsets.max, :>, 0.5 * Weather::FAST_R
    end
  end

  def test_the_flakes_appear_from_10_blocks_below_the_player_to_14_above_and_not_under_the_ground
    world = World.new(1337)
    world.load_chunk(-70, -70)
    grounds = (-1118..-1105).flat_map { |x| (-1118..-1105).map { |z| world.height_at(x, z) } }
    { grounds.max + 40.0 => grounds.max + 30.0, grounds.min + 5.0 => grounds.min.to_f }.each do |height, lowest|
      snowfall = Snowfall.new(1)
      snowfall.graphics = GraphicsMode::FAST
      snowfall.strength = 1.0
      player = Player.new(-1111.5, height, -1111.5)
      ys = (0...60).flat_map do
        snowfall.update(world, player, 0.0)
        flakes(snowfall, player).map { |quad| quad[0][1] }
      end
      assert_operator ys.min, :>=, lowest - 0.2
      assert_operator ys.max, :<=, height + 14.0 + 0.2
      assert_operator ys.max - ys.min, :>, 5.0
    end
  end

  def test_the_pace_of_a_slot_is_from_zero_up_to_one_and_differs_between_neighbors
    paces = (0...10).map { |index| Snowfall.pace(index) }
    assert_equal 10, paces.uniq.size
    assert(paces.all? { |pace| pace >= 0.0 && pace < 1.0 })
    assert_equal(paces, (10...20).map { |index| Snowfall.pace(index) })
  end

  def test_a_flake_sways_toward_a_higher_x_as_it_ages
    snowfall, world, player = snow_in(-70, -70, seconds: 0.2)
    before = flakes(snowfall, player).to_h { |quad| [quad[0][2], center_x(quad)] }
    snowfall.update(world, player, 0.1)
    after = flakes(snowfall, player).to_h { |quad| [quad[0][2], center_x(quad)] }
    shared = before.keys & after.keys
    assert_operator shared.size, :>, 20
    assert(shared.all? { |z| after[z] > before[z] })
  end

  def test_a_flake_faces_the_camera
    snowfall, _world, player = snow_in(-70, -70)
    player.yaw = 0.7
    player.pitch = 0.4
    view = [player.fx, player.fy, player.fz]
    quads = flakes(snowfall, player)
    refute_empty quads
    quads.each do |quad|
      quad.each_cons(2) do |from, to|
        edge = [to[0] - from[0], to[1] - from[1], to[2] - from[2]]
        assert_in_delta 0.0, edge.zip(view).sum { |a, b| a * b }, 1.0e-9
      end
    end
  end

  private

  def center_x(quad) = quad.sum { |vertex| vertex[0] } / quad.size

  def count_in(snowfall, strength: 1.0)
    snowfall.strength = strength
    fall_in(snowfall, -70, -70, strength).size
  end

  def fall_in(snowfall, chunk_x, chunk_z, strength)
    world = World.new(1337)
    world.load_chunk(chunk_x, chunk_z)
    player = Player.new(chunk_x * 16 + 8.5, 80.0, chunk_z * 16 + 8.5)
    snowfall.strength = strength
    180.times { snowfall.update(world, player, FRAME) }
    flakes(snowfall, player)
  end

  def flakes_over(chunk_x, chunk_z, strength: 1.0, mode: GraphicsMode::FAST)
    snowfall, _world, player = snow_in(chunk_x, chunk_z, strength: strength, mode: mode)
    flakes(snowfall, player)
  end

  def snow_in(chunk_x, chunk_z, strength: 1.0, mode: GraphicsMode::FAST, seconds: 3.0)
    world = World.new(1337)
    world.load_chunk(chunk_x, chunk_z)
    x = chunk_x * 16 + 8
    z = chunk_z * 16 + 8
    player = Player.new(x + 0.5, world.height_at(x, z).to_f, z + 0.5)
    snowfall = Snowfall.new(1)
    snowfall.graphics = mode
    snowfall.strength = strength
    (seconds / FRAME).to_i.times { snowfall.update(world, player, FRAME) }
    [snowfall, world, player]
  end

  def flakes(snowfall, player)
    mesh = Mesh3.new
    snowfall.draw(mesh, player)
    mesh.v.each_slice(11).each_slice(6).to_a
  end

  def heights(snowfall, player)
    flakes(snowfall, player).to_h { |quad| [quad[0][2], quad[0][1]] }
  end
end

class FlakeTest < Minitest::Test
  Ground = Struct.new(:height) do
    def height_at(_x, _z) = height
  end

  def test_a_flake_falls_from_0_9_to_1_5_blocks_a_second_by_its_pace
    slow = started(10.0)
    slow.fall(1.0, 0.0)
    quick = started(10.0)
    quick.fall(1.0, 1.0)
    assert_in_delta 9.1, slow.y, 1.0e-9
    assert_in_delta 8.5, quick.y, 1.0e-9
  end

  def test_a_flake_does_not_fall_until_it_starts_and_stops_when_stopped
    flake = Flake.new
    refute flake.falling?
    flake.start(1.0, 2.0, 3.0)
    assert flake.falling?
    assert_equal [1.0, 2.0, 3.0], [flake.x, flake.y, flake.z]
    flake.stop
    refute flake.falling?
  end

  def test_a_flake_grows_to_full_size_in_half_a_second
    flake = started(10.0)
    assert_equal 0.0, flake.grown
    flake.fall(0.25, 0.0)
    assert_in_delta 0.5, flake.grown, 1.0e-9
    flake.fall(0.25, 0.0)
    assert_in_delta 1.0, flake.grown, 1.0e-9
    flake.fall(5.0, 0.0)
    assert_equal 1.0, flake.grown
  end

  def test_a_flake_sways_with_its_age_and_pace
    flake = started(10.0)
    assert_equal 0.0, flake.sway(0.0)
    flake.fall(1.0, 0.0)
    assert_in_delta 0.25 * Math.sin(0.8), flake.sway(0.0), 1.0e-9
    assert_in_delta 0.25 * Math.sin(1.4), flake.sway(1.0), 1.0e-9
  end

  def test_a_flake_lands_on_the_ground_and_not_above_it
    assert started(5.0).landed?(Ground.new(5))
    refute started(5.01).landed?(Ground.new(5))
    assert started(-1.0).landed?(Ground.new(5))
  end

  def test_a_flake_is_outside_the_box_past_the_radius_on_either_axis
    player = Player.new(100.0, 0.0, 200.0)
    refute Flake.new.tap { |flake| flake.start(106.0, 0.0, 206.0) }.outside?(player, 6.0)
    refute Flake.new.tap { |flake| flake.start(94.0, 0.0, 194.0) }.outside?(player, 6.0)
    assert Flake.new.tap { |flake| flake.start(106.1, 0.0, 200.0) }.outside?(player, 6.0)
    assert Flake.new.tap { |flake| flake.start(100.0, 0.0, 206.1) }.outside?(player, 6.0)
    assert Flake.new.tap { |flake| flake.start(93.9, 0.0, 200.0) }.outside?(player, 6.0)
    assert Flake.new.tap { |flake| flake.start(100.0, 0.0, 193.9) }.outside?(player, 6.0)
  end

  private

  def started(height)
    Flake.new.tap { |flake| flake.start(0.0, height, 0.0) }
  end
end
