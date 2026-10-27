require_relative "test_helper"

class StormTest < Minitest::Test
  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, SKY_Y - 2, z, Block::STONE) } }
    @weather = Weather.new(1)
    @weather.start_rain
    @weather.start_thunder
    @weather.settle
    @mobs = []
    @storm = Storm.new(7, @world, @weather, @mobs)
    @particles = Particles.new(1)
    @player = Player.new(2.5, SKY_Y - 1.0, 2.5)
  end

  def zombie_at(x, z)
    zombie = Monster.new(Mob::ZOMBIE, x, SKY_Y - 1.0, z, 9)
    @mobs << zombie
    zombie
  end

  def test_a_strike_hurts_and_burns_a_mob_under_it
    zombie = zombie_at(10.5, 10.5)
    @storm.strike(10, 10, @player, @particles)
    assert_equal Mob::HP[Mob::ZOMBIE] - Storm::STRIKE_DAMAGE, zombie.hp
    assert_equal Storm::STRIKE_FIRE, zombie.fire
  end

  def test_a_strike_leaves_a_mob_out_of_its_reach_alone
    zombie = zombie_at(5.5, 5.5)
    @storm.strike(10, 10, @player, @particles)
    assert_equal Mob::HP[Mob::ZOMBIE], zombie.hp
    assert_equal 0.0, zombie.fire
  end

  def test_a_mob_next_to_the_strike_draws_it_to_itself
    zombie_at(11.5, 10.5)
    @storm.strike(10, 10, @player, @particles)
    assert_equal 11, @storm.lightning.x
    assert_equal 10, @storm.lightning.z
  end

  def test_a_strike_reports_a_hit_on_the_player
    assert @storm.strike(2, 2, @player, @particles)
    refute @storm.strike(12, 12, @player, @particles)
  end

  def test_a_glass_roof_stops_the_strike
    zombie = zombie_at(10.5, 10.5)
    @world.set(10, SKY_Y + 2, 10, Block::GLASS)
    @storm.strike(11, 10, @player, @particles)
    assert_equal Mob::HP[Mob::ZOMBIE], zombie.hp
  end

  def test_a_mob_with_its_feet_in_water_is_hit
    @world.set(10, SKY_Y - 1, 10, Block::WATER)
    zombie = zombie_at(10.5, 10.5)
    @storm.strike(10, 10, @player, @particles)
    assert_equal Mob::HP[Mob::ZOMBIE] - Storm::STRIKE_DAMAGE, zombie.hp
    assert @storm.lightning.visible?
  end

  def test_a_glass_roof_does_not_draw_the_strike_from_the_next_column
    zombie = zombie_at(10.5, 10.5)
    @world.set(10, SKY_Y + 2, 10, Block::GLASS)
    @storm.strike(11, 10, @player, @particles)
    assert_equal 11, @storm.lightning.x
    assert_equal Mob::HP[Mob::ZOMBIE], zombie.hp
  end

  def test_strikes_fall_only_in_loaded_chunks
    500.times do
      @storm.advance(1.0e9, @player, @particles)
      next unless @storm.lightning.visible?

      assert_includes 0...CHUNK, @storm.lightning.x
      assert_includes 0...CHUNK, @storm.lightning.z
      @storm.lightning.update_lightning(Lightning::LIFE + Lightning::FADE)
    end
  end

  def test_a_dying_mob_does_not_draw_a_strike
    zombie = zombie_at(11.5, 10.5)
    zombie.wound(Mob::HP[Mob::ZOMBIE])
    @storm.strike(10, 10, @player, @particles)
    assert_equal 10, @storm.lightning.x
  end

  def test_a_clear_sky_has_no_strikes
    @weather.stop_thunder
    @weather.settle
    100_000.times { refute @storm.advance(1.0, @player, @particles) }
    refute @storm.lightning.visible?
  end

  def test_a_storm_strikes_now_and_then_around_the_player
    strikes = 0
    10_000.times do
      @storm.advance(1.0, @player, @particles)
      strikes += 1 if @storm.lightning.visible?
      @storm.lightning.update_lightning(Lightning::LIFE)
    end
    assert_operator strikes, :>, 0
  end
end
