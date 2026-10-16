require_relative "test_helper"

class MobTest < Minitest::Test
  DT = 1.0 / 60.0

  def setup
    @world = world_with_one_chunk
  end

  def test_a_creeper_hisses_once_when_it_lights_its_fuse
    lay_floor
    player = Player.new(8.5, SKY_Y - 1.0, 8.5)
    creeper = Mob.new(Mob::CREEPER, player.x + 1.5, player.y, player.z, 11)
    hisses = 0
    20.times do
      creeper.update_mob(@world, DT, player, 0.3, Block::AIR)
      hisses += 1 if creeper.hiss
      creeper.hiss = false
    end
    assert_equal 1, hisses
    assert_operator creeper.fuse, :>, 0.0
  end

  def test_a_hit_makes_a_mob_cry_out
    pig = Mob.new(Mob::PIG, 8.5, SKY_Y - 1.0, 8.5, 5)
    pig.wound(1.0)
    assert pig.ouch
  end

  def test_a_walking_mob_makes_step_sounds
    lay_floor
    player = Player.new(2.5, SKY_Y - 1.0, 8.5)
    zombie = Mob.new(Mob::ZOMBIE, 10.5, SKY_Y - 1.0, 8.5, 3)
    steps = 0
    120.times do
      zombie.update_mob(@world, DT, player, 0.0, Block::AIR)
      steps += 1 if zombie.step
      zombie.step = false
    end
    assert_operator steps, :>=, 1
  end

  def test_the_legs_of_a_mob_swing_as_it_walks_and_come_to_rest_when_it_stops
    lay_floor
    player = Player.new(8.5, SKY_Y - 1.0, 0.5)
    zombie = Mob.new(Mob::ZOMBIE, 8.5, SKY_Y - 1.0, 15.5, 3)
    30.times { zombie.update_mob(@world, DT, player, 0.0, Block::AIR) }
    assert_operator zombie.leg_swing, :>, 0.5
    player.z = 300.0
    60.times { zombie.update_mob(@world, DT, player, 0.0, Block::AIR) }
    assert_operator zombie.leg_swing, :<, 0.05
  end

  def test_a_chicken_falls_slowly
    player = Player.new(8.5, SKY_Y - 1.0, 8.5)
    hen = Mob.new(Mob::CHICKEN, 4.5, SKY_Y.to_f, 4.5, 13)
    pig = Mob.new(Mob::PIG, 7.5, SKY_Y.to_f, 4.5, 13)
    60.times do
      hen.update_mob(@world, DT, player, 0.5, Block::AIR)
      pig.update_mob(@world, DT, player, 0.5, Block::AIR)
    end
    assert_operator hen.vy, :>=, Mob::CHICKEN_FALL
    assert_operator pig.vy, :<, Mob::CHICKEN_FALL * 4.0
  end

  def test_a_chick_grows_up_after_20_minutes
    chick = Mob.new(Mob::CHICKEN, 8.5, SKY_Y.to_f, 8.5, 6)
    chick.make_baby
    chick.grow_up(Mob::GROW_TIME - 1.0)
    assert chick.baby?
    chick.grow_up(1.0)
    refute chick.baby?
    assert_equal Mob::HALF[Mob::CHICKEN], chick.half
    assert_equal Mob::TALL[Mob::CHICKEN], chick.tall
  end

  private

  # A stone floor under SKY_Y - 1 over the whole chunk, in open air.
  def lay_floor
    16.times { |x| 16.times { |z| @world.set(x, SKY_Y - 2, z, Block::STONE) } }
  end
end
