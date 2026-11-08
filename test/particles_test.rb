require_relative "test_helper"

class ParticlesTest < Minitest::Test
  # As in Minecraft.
  def test_a_broken_block_throws_64_chips
    particles = Particles.new(1)
    particles.burst(8, SKY_Y, 8, Block::STONE)
    assert_equal 64, particles.count(Particle::CHIP)
  end

  def test_an_explosion_makes_a_cloud_that_goes_away
    world = world_with_one_chunk
    particles = Particles.new(1)
    particles.blast(8.0, SKY_Y.to_f, 8.0)
    assert_equal 48, particles.count(Particle::BLAST)
    particles.update(world, 0.29)
    assert_equal 48, particles.count(Particle::BLAST)
    particles.update(world, 0.6)
    assert_equal 0, particles.count(Particle::BLAST)
  end

  # The puffs stay where they start, up to 4 blocks from the middle of the
  # explosion along each axis, and each one is 1.5 to 3 blocks wide.
  def test_the_cloud_of_an_explosion_spreads_and_stays_in_place
    particles = Particles.new(1)
    particles.blast(8.0, SKY_Y.to_f, 8.0)
    particles.update(world_with_one_chunk, 0.29)
    mesh = SquareLog.new
    particles.draw(mesh, 1.0, 0.0, 0.0, 1.0, 0.0)
    [8.0, SKY_Y.to_f, 8.0].each_with_index do |middle, axis|
      offsets = mesh.squares.map { |square| square[axis] - middle }
      assert_operator offsets.map(&:abs).max, :<, 4.0
      assert_operator offsets.max - offsets.min, :>, 3.0
      assert_in_delta 0.0, offsets.sum / offsets.size, 0.75
    end
    mesh.squares.each do |square|
      assert_includes 0.75..1.5, square[3]
      assert_includes 0.55..1.0, square[4]
    end
  end

  def test_flames_smoke_specks_sparks_sparkles_and_hearts_do_not_fall
    [Particle::FLAME, Particle::SMOKE, Particle::EFFECT, Particle::CRIT, Particle::GROWTH, Particle::HEART].each do |kind|
      assert_equal SKY_Y.to_f, height_after_a_while(kind), "kind #{kind}"
    end
  end

  def test_chips_embers_and_drops_of_rain_fall
    [Particle::CHIP, Particle::EMBER, Particle::DROP].each do |kind|
      assert_operator height_after_a_while(kind), :<, SKY_Y.to_f, "kind #{kind}"
    end
  end

  # A world with block in one cell and air in the others, or block in
  # every cell when the cell is nil.
  class FireWorld
    def initialize(block, cell = nil)
      @block = block
      @cell = cell
    end

    def get(x, y, z) = (@cell.nil? || [x, y, z] == @cell) ? @block : Block::AIR
  end

  # A world of lava up to y 64 and air above it.
  class LavaSea
    def get(_x, y, _z) = y <= 64 ? Block::LAVA : Block::AIR
  end

  # The middles of the squares that sample_fire makes in world in seconds,
  # around a player at 0, 64, 0.
  def fire_squares(world, seconds)
    particles = Particles.new(1)
    particles.sample_fire(world, 0.0, 64.0, 0.0, seconds)
    squares_of(particles)
  end

  def squares_of(particles)
    mesh = SquareLog.new
    particles.draw(mesh, 1.0, 0.0, 0.0, 1.0, 0.0)
    mesh.squares.map { |square| square.take(3) }
  end

  # A torch flame starts at height 0.75 of its block.
  def flame?(middle) = (middle[1] % 1.0 - 0.75).abs < 0.001

  def test_torches_burn_within_the_sample_reach_on_each_side_of_each_axis
    reach = Particles::SAMPLE_REACH
    flames = fire_squares(FireWorld.new(Block::TORCH), 0.05).select { |middle| flame?(middle) }
    [0.5, 64.75, 0.5].each_with_index do |middle_of_box, axis|
      values = flames.map { |middle| middle[axis] }
      assert_in_delta middle_of_box - reach, values.min, 0.001
      assert_in_delta middle_of_box + reach, values.max, 0.001
    end
  end

  def test_a_torch_on_the_floor_burns_in_the_middle_of_its_block_and_smokes_above_it
    middles = fire_squares(FireWorld.new(Block::TORCH, [2, 63, 3]), 5.0).uniq
    expected = [[2.5, 63.75, 3.5], [2.5, 63.9, 3.5]]
    assert_equal expected.size, middles.size
    expected.each { |want| assert(middles.any? { |middle| middle.zip(want).all? { |a, b| (a - b).abs < 0.001 } }, "no square at #{want}") }
  end

  # The flame and the smoke move from the middle of the block toward the
  # wall, against the facing of the torch, and stay in the block.
  def test_a_torch_on_a_wall_leans_its_flame_and_smoke_toward_the_wall
    4.times do |turn|
      torch = Block::WALL_TORCH + turn
      facing = Block::FACING[torch]
      middles = fire_squares(FireWorld.new(torch, [2, 63, 3]), 5.0).uniq
      assert_equal 2, middles.size
      flame, smoke = middles.sort_by { |middle| middle[1] }
      lean = ->(middle) { -((middle[0] - 2.5) * Block::DIR_DX[facing] + (middle[2] - 3.5) * Block::DIR_DZ[facing]) }
      across = ->(middle) { ((middle[0] - 2.5) * Block::DIR_DZ[facing] - (middle[2] - 3.5) * Block::DIR_DX[facing]).abs }
      assert_in_delta 63.75 + Block::WALL_LIFT, flame[1], 0.001
      assert_operator lean.call(flame), :<, 0.5
      assert_operator lean.call(flame), :>, lean.call(smoke)
      assert_operator lean.call(smoke), :>, 0.0
      assert_in_delta 0.0, across.call(flame) + across.call(smoke), 0.001
    end
  end

  def test_about_half_of_the_torch_flames_smoke
    particles = Particles.new(1)
    particles.sample_fire(FireWorld.new(Block::TORCH), 0.0, 64.0, 0.0, 0.1)
    share = particles.count(Particle::SMOKE).fdiv(particles.count(Particle::FLAME))
    assert_in_delta 0.5, share, 0.1
  end

  # After 0.7 seconds only the smoke is left. It rose 0.35 blocks above its
  # start at height 0.9, and it drifted a little to each side.
  def test_torch_smoke_rises_and_drifts_little
    world = FireWorld.new(Block::TORCH)
    particles = Particles.new(1)
    particles.sample_fire(world, 0.0, 64.0, 0.0, 0.05)
    35.times { particles.update(world, 0.02) }
    middles = squares_of(particles)
    refute_empty middles
    middles.each { |middle| assert_in_delta 0.25, middle[1] % 1.0, 0.001 }
    [0, 2].each do |axis|
      drifts = middles.map { |middle| middle[axis] % 1.0 - 0.5 }
      assert_operator drifts.map(&:abs).max, :<, 0.03
      assert_in_delta 0.0, drifts.sum / drifts.size, 0.005
    end
  end

  # A flame lives 0.3 to 0.5 seconds, and its smoke 0.8 to 1.4 seconds.
  def test_torch_flames_and_smoke_live_for_their_time
    world = FireWorld.new(Block::TORCH)
    { 0.29 => [1.0, 1.0], 0.51 => [0.0, 1.0], 0.79 => [0.0, 1.0], 1.41 => [0.0, 0.0] }.each do |seconds, (flames, smoke)|
      particles = Particles.new(1)
      particles.sample_fire(world, 0.0, 64.0, 0.0, 0.05)
      born = [Particle::FLAME, Particle::SMOKE].map { |kind| particles.count(kind) }
      particles.update(world, seconds)
      left = [Particle::FLAME, Particle::SMOKE].map { |kind| particles.count(kind) }
      assert_equal [flames, smoke], left.zip(born).map { |now, before| now.fdiv(before) }, "after #{seconds} s"
    end
  end

  # A sample hits the top of the lava 1 time in 21, and 1 hit in 20 throws
  # an ember: about 43 embers in a second.
  def test_lava_under_air_now_and_then_throws_embers_from_its_top
    particles = Particles.new(1)
    particles.sample_fire(LavaSea.new, 0.0, 64.0, 0.0, 1.0)
    assert_includes 25..65, particles.count(Particle::EMBER)
    reach = Particles::SAMPLE_REACH
    squares_of(particles).each do |middle|
      assert_in_delta 65.0, middle[1], 0.001
      [0, 2].each { |axis| assert_includes(-reach.to_f...(reach + 1).to_f, middle[axis]) }
    end
  end

  # An ember flies up at 3 to 5 blocks a second and out at up to 1 block a
  # second on each side.
  def test_an_ember_flies_up_and_out
    particles = Particles.new(1)
    world = LavaSea.new
    particles.sample_fire(world, 0.0, 64.0, 0.0, 1.0)
    before = squares_of(particles)
    step = 0.001
    particles.update(world, step)
    speeds = squares_of(particles).zip(before).map { |now, start| now.zip(start).map { |a, b| (a - b) / step } }
    speeds.each { |speed| assert_includes 2.9..5.0, speed[1] }
    assert_operator speeds.map { |speed| speed[1] }.max, :>, 4.5
    [0, 2].each do |axis|
      sideways = speeds.map { |speed| speed[axis] }
      assert_operator sideways.map(&:abs).max, :<=, 1.0
      assert_operator sideways.max, :>, 0.6
      assert_operator sideways.min, :<, -0.6
    end
  end

  def test_lava_under_lava_throws_no_embers
    particles = Particles.new(1)
    particles.sample_fire(FireWorld.new(Block::LAVA), 0.0, 64.0, 0.0, 1.0)
    assert_equal 0, particles.count(Particle::EMBER)
  end

  # The height of a particle of kind that starts still in the air, 0.2
  # seconds later.
  def height_after_a_while(kind)
    particles = Particles.new(1)
    particles.add(kind, 8.0, SKY_Y.to_f, 8.0, 0.0, 0.0, 0.0, 1.0, Tex::PUFF)
    particles.update(world_with_one_chunk, 0.2)
    mesh = SquareLog.new
    particles.draw(mesh, 1.0, 0.0, 0.0, 1.0, 0.0)
    mesh.squares[0][1]
  end

  # A mesh that keeps the middle, the half size, the red and the color of each square.
  class SquareLog
    attr_reader :squares
    attr_writer :glow

    def initialize
      @squares = []
    end

    def billboard(x, y, z, half, _rx, _rz, _ux, _uy, _uz, _u0, _v0, _du, _layer, color)
      @squares << [x, y, z, half, color.red, color]
    end
  end

  # The square of a particle of kind that has left of its life (1.0 at birth).
  def square_at(kind, left)
    particles = Particles.new(1)
    particles.add(kind, 8.0, SKY_Y.to_f, 8.0, 0.0, 0.0, 0.0, 1.0, Tex::PUFF)
    particles.update(world_with_one_chunk, 1.0 - left)
    mesh = SquareLog.new
    particles.draw(mesh, 1.0, 0.0, 0.0, 1.0, 0.0)
    mesh.squares.fetch(0)
  end

  def test_a_flame_shrinks_and_turns_deeper_orange_as_it_dies
    young = square_at(Particle::FLAME, 1.0)
    old = square_at(Particle::FLAME, 0.2)
    assert_operator old[3], :<, young[3]
    assert_equal [1.0, 1.0], [young[5].red, old[5].red]
    assert_operator old[5].green, :<, young[5].green
    assert_operator old[5].blue, :<, young[5].blue
  end

  def test_smoke_grows_and_darkens_as_it_dies
    young = square_at(Particle::SMOKE, 1.0)
    old = square_at(Particle::SMOKE, 0.2)
    assert_operator old[3], :>, young[3]
    assert_operator old[5].red, :<, young[5].red
    assert_equal [old[5].red], [old[5].green, old[5].blue].uniq
  end

  def test_the_sparkles_of_bone_meal_and_the_sparks_of_a_critical_hit_shrink_as_they_die
    [Particle::GROWTH, Particle::CRIT].each do |kind|
      assert_operator square_at(kind, 0.2)[3], :<, square_at(kind, 1.0)[3], "kind #{kind}"
    end
  end

  def test_an_ember_turns_deeper_orange_as_it_dies
    young = square_at(Particle::EMBER, 1.0)
    old = square_at(Particle::EMBER, 0.2)
    assert_operator old[5].green, :<, young[5].green
    assert_equal [1.0, 0.1], [old[5].red, old[5].blue]
  end

  # minecraft.wiki/w/Hunger_(effect) and VoxeLibre: the dull green of the
  # effect and the green of the bone meal sparkle, as #RRGGBB.
  def test_the_specks_of_an_effect_and_the_sparkles_of_bone_meal_have_the_colors_of_their_sources
    { Particle::EFFECT => 0x587653, Particle::GROWTH => 0x00EE00 }.each do |kind, rgb|
      color = square_at(kind, 1.0)[5]
      [color.red, color.green, color.blue].zip([rgb >> 16, (rgb >> 8) & 0xFF, rgb & 0xFF]) do |part, byte|
        assert_in_delta byte / 255.0, part, 0.005, "kind #{kind}"
      end
    end
  end
end
