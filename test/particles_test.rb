require_relative "test_helper"

class ParticlesTest < Minitest::Test
  # As in Minecraft.
  def test_a_broken_block_throws_64_chips
    particles = Particles.new(1)
    particles.burst(8, SKY_Y, 8, Block::STONE)
    assert_equal 64, particles.count(Particle::CHIP)
  end
end
