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

  # A mesh that keeps the middle, the half size and the red of each square.
  class SquareLog
    attr_reader :squares
    attr_writer :glow

    def initialize
      @squares = []
    end

    def billboard(x, y, z, half, _rx, _rz, _ux, _uy, _uz, _u0, _v0, _du, _layer, red, *)
      @squares << [x, y, z, half, red]
    end
  end
end
