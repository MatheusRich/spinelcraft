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

  def test_an_animal_despawns_only_farther_than_160_blocks_along_x_and_z
    player = Player.new(0.0, 0.0, 0.0)
    refute Mob.new(Mob::COW, 159.0, 500.0, 0.0, 1).despawn?(player, 40.0)
    refute Mob.new(Mob::COW, 113.0, 0.0, 113.0, 1).despawn?(player, 40.0)
    assert Mob.new(Mob::COW, 114.0, 0.0, 114.0, 1).despawn?(player, 0.0)
    assert Mob.new(Mob::PIG, 0.0, 0.0, -161.0, 1).despawn?(player, 0.0)
  end

  def test_a_monster_farther_than_128_blocks_despawns_at_once
    player = Player.new(0.0, 0.0, 0.0)
    assert Mob.new(Mob::ZOMBIE, 0.0, 129.0, 0.0, 1).despawn?(player, 0.0)
    assert Mob.new(Mob::ZOMBIE, 91.0, 0.0, 91.0, 1).despawn?(player, 0.0)
    refute Mob.new(Mob::ZOMBIE, 0.0, 0.0, 127.0, 1).despawn?(player, 0.0)
  end

  def test_a_monster_farther_than_32_blocks_for_30_seconds_can_despawn
    player = Player.new(0.0, 0.0, 0.0)
    zombie = Mob.new(Mob::ZOMBIE, 33.0, 0.0, 0.0, 1)
    refute zombie.despawn?(player, 29.0)
    assert_equal 29.0, zombie.idle
    # With 40 seconds, the chance of 1 in 800 each tick is 1.
    assert zombie.despawn?(player, 40.0)
    refute Mob.new(Mob::ZOMBIE, 0.0, 33.0, 0.0, 1).despawn?(player, 30.0)
  end

  def test_a_monster_that_comes_near_the_player_starts_its_wait_again
    player = Player.new(0.0, 0.0, 0.0)
    zombie = Mob.new(Mob::ZOMBIE, 33.0, 0.0, 0.0, 1)
    zombie.despawn?(player, 29.0)
    zombie.x = 31.0
    refute zombie.despawn?(player, 40.0)
    assert_equal 0.0, zombie.idle
    zombie.x = 33.0
    refute zombie.despawn?(player, 29.0)
  end

  def test_the_despawn_distances_count_from_the_player_and_stop_short_of_their_edge
    player = Player.new(100.0, 64.0, -50.0)
    refute Mob.new(Mob::COW, 260.0, 64.0, -50.0, 1).despawn?(player, 0.0)
    refute Mob.new(Mob::ZOMBIE, 100.0, 64.0, 78.0, 1).despawn?(player, 0.0)
    assert Mob.new(Mob::ZOMBIE, 100.0, 193.0, -50.0, 1).despawn?(player, 0.0)
    zombie = Mob.new(Mob::ZOMBIE, 132.0, 64.0, -50.0, 1)
    refute zombie.despawn?(player, 40.0)
    assert_equal 0.0, zombie.idle
  end

  def test_an_idle_monster_despawns_rarely_in_short_steps
    player = Player.new(0.0, 0.0, 0.0)
    zombie = Mob.new(Mob::ZOMBIE, 50.0, 0.0, 0.0, 1)
    zombie.despawn?(player, 31.0) while zombie.idle < 31.0
    # A chance of 1 in 800 each tick: one tick at a time, 50 ticks.
    gone = 0
    50.times { gone += 1 if zombie.despawn?(player, 1.0 / 20.0) }
    assert_operator gone, :<=, 1
  end

  def test_a_monster_does_not_despawn_in_an_instant_without_time
    player = Player.new(0.0, 0.0, 0.0)
    zombie = Mob.new(Mob::ZOMBIE, 0.0, 0.0, 100.0, 1)
    zombie.despawn?(player, 31.0)
    refute zombie.despawn?(player, 0.0)
  end

  def test_a_sheep_eats_the_tall_grass_in_its_cell_first_then_the_grass_under_it
    @world.set(8, SKY_Y - 2, 8, Block::GRASS)
    sheep = Mob.new(Mob::SHEEP, 8.5, SKY_Y - 1.0, 8.5, 3)
    assert_equal 2, sheep.grass_under(@world)
    @world.set(8, SKY_Y - 1, 8, Block::TALL_GRASS)
    assert_equal 1, sheep.grass_under(@world)
    @world.set(8, SKY_Y - 1, 8, Block::AIR)
    @world.set(8, SKY_Y - 2, 8, Block::STONE)
    assert_equal 0, sheep.grass_under(@world)
  end

  def test_only_a_calm_sheep_with_grass_under_it_grazes
    @world.set(8, SKY_Y - 2, 8, Block::GRASS)
    sheep = Mob.new(Mob::SHEEP, 8.5, SKY_Y - 1.0, 8.5, 3)
    assert sheep.can_graze?(@world)
    refute Mob.new(Mob::PIG, 8.5, SKY_Y - 1.0, 8.5, 3).can_graze?(@world)
    sheep.start_graze
    refute sheep.can_graze?(@world)
    scared = Mob.new(Mob::SHEEP, 8.5, SKY_Y - 1.0, 8.5, 3)
    scared.hit(1.0, 7.0, 8.5)
    refute scared.can_graze?(@world)
    dead = Mob.new(Mob::SHEEP, 8.5, SKY_Y - 1.0, 8.5, 3)
    dead.hp = 0.0
    refute dead.can_graze?(@world)
    @world.set(8, SKY_Y - 2, 8, Block::STONE)
    refute Mob.new(Mob::SHEEP, 8.5, SKY_Y - 1.0, 8.5, 3).can_graze?(@world)
  end

  def test_the_log_says_why_a_mob_goes
    pig = Mob.new(Mob::PIG, 8.5, SKY_Y - 1.0, 8.5, 5)
    assert_equal "despawns", pig.gone_reason(@world)
    pig.x = 40.5
    assert_equal "is out of the loaded chunks", pig.gone_reason(@world)
    pig.alive = false
    assert_equal "dies", pig.gone_reason(@world)
  end

  def test_a_sheep_on_tall_grass_over_stone_grazes
    @world.set(8, SKY_Y - 2, 8, Block::STONE)
    @world.set(8, SKY_Y - 1, 8, Block::TALL_GRASS)
    assert Mob.new(Mob::SHEEP, 8.5, SKY_Y - 1.0, 8.5, 3).can_graze?(@world)
  end

  # The cell of a sheep is the floor of its place, also below 0, and its
  # feet a hair under the top of a block still stand on that block.
  def test_a_sheep_eats_from_the_cell_that_it_stands_in
    @world.load_chunk(-1, -1)
    @world.set(-8, SKY_Y - 2, -8, Block::GRASS)
    sheep = Mob.new(Mob::SHEEP, -7.5, SKY_Y - 1.005, -7.5, 3)
    assert_equal 2, sheep.grass_under(@world)
  end

  private

  # A stone floor under SKY_Y - 1 over the whole chunk, in open air.
  def lay_floor
    16.times { |x| 16.times { |z| @world.set(x, SKY_Y - 2, z, Block::STONE) } }
  end
end
