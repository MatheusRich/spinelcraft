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
