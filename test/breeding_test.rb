require_relative "test_helper"

# Breeding#pair_lovers: lovers walk to the nearest mate, and two mates
# near each other make a baby. minecraft.wiki/w/Breeding
class BreedingTest < Minitest::Test
  def setup
    @breeding = Breeding.new(1)
    @particles = Particles.new(1)
  end

  def test_two_mates_that_walked_to_each_other_make_one_baby
    first = lover(Mob::COW, 8.5)
    second = lover(Mob::COW, 10.5)
    mobs = [first, second]
    first.love.walk(Love::COURT_TIME)
    @breeding.pair_lovers(mobs, @particles)
    assert_equal 3, mobs.size
    assert_predicate mobs.last, :baby?
    assert_equal Mob::COW, mobs.last.kind
    refute_predicate first.love, :on?
    refute_predicate second.love, :on?
    assert_operator first.love.wait, :>, 0.0
    assert_operator second.love.wait, :>, 0.0
    assert_equal 14, @particles.count(Particle::HEART)
  end

  def test_mates_make_no_baby_before_they_walked_to_each_other_for_a_while
    first = lover(Mob::COW, 8.5)
    second = lover(Mob::COW, 10.5)
    mobs = [first, second]
    first.love.walk(Love::COURT_TIME - 0.1)
    @breeding.pair_lovers(mobs, @particles)
    assert_equal 2, mobs.size
    assert_predicate first.love, :courting?
    assert_predicate second.love, :courting?
  end

  # In the game code, two mates make a baby when they are less than
  # MATE_NEAR apart (BreedGoal: distanceToSqr < 9).
  def test_mates_make_no_baby_at_mate_near_apart
    first = lover(Mob::COW, 8.5)
    mobs = [first, lover(Mob::COW, 8.5 + Love::MATE_NEAR)]
    first.love.walk(Love::COURT_TIME)
    @breeding.pair_lovers(mobs, @particles)
    assert_equal 2, mobs.size
    assert_predicate first.love, :courting?
  end

  def test_mates_make_no_baby_at_mate_near_apart_along_z
    first = lover(Mob::COW, 8.5)
    mobs = [first, lover(Mob::COW, 8.5, z: 8.5 + Love::MATE_NEAR)]
    first.love.walk(Love::COURT_TIME)
    @breeding.pair_lovers(mobs, @particles)
    assert_equal 2, mobs.size
  end

  def test_a_lover_walks_to_its_nearest_mate
    first = lover(Mob::COW, 8.5)
    far = lover(Mob::COW, 14.5)
    near = lover(Mob::COW, 12.5)
    @breeding.pair_lovers([first, far, near], @particles)
    assert_equal near.x, first.love.mate_x
    assert_equal near.x, far.love.mate_x
    assert_equal far.x, near.love.mate_x
  end

  def test_a_mate_is_of_the_same_kind
    cow = lover(Mob::COW, 8.5)
    @breeding.pair_lovers([cow, lover(Mob::PIG, 9.5)], @particles)
    refute_predicate cow.love, :courting?
  end

  def test_a_mate_is_in_love_mode
    cow = lover(Mob::COW, 8.5)
    cold = Animal.new(Mob::COW, 9.5, SKY_Y.to_f, 8.5, 2)
    @breeding.pair_lovers([cow, cold], @particles)
    refute_predicate cow.love, :courting?
    refute_predicate cold.love, :courting?
  end

  def test_a_mate_is_nearer_than_mate_reach
    cow = lover(Mob::COW, 8.5)
    @breeding.pair_lovers([cow, lover(Mob::COW, 8.5 + Love::MATE_REACH)], @particles)
    refute_predicate cow.love, :courting?
  end

  def test_the_reach_counts_along_z_and_up
    cow = lover(Mob::COW, 8.5)
    @breeding.pair_lovers([cow, lover(Mob::COW, 8.5, z: 8.5 + Love::MATE_REACH)], @particles)
    refute_predicate cow.love, :courting?
    @breeding.pair_lovers([cow, lover(Mob::COW, 8.5, y: SKY_Y + Love::MATE_REACH)], @particles)
    refute_predicate cow.love, :courting?
  end

  def test_a_dying_animal_is_no_mate
    cow = lover(Mob::COW, 8.5)
    dying = lover(Mob::COW, 9.5)
    dying.hp = 0.0
    @breeding.pair_lovers([cow, dying], @particles)
    refute_predicate cow.love, :courting?
  end

  def test_a_lover_that_loses_its_mate_stops_courting
    cow = lover(Mob::COW, 8.5)
    mate = lover(Mob::COW, 9.5)
    @breeding.pair_lovers([cow, mate], @particles)
    assert_predicate cow.love, :courting?
    @breeding.pair_lovers([cow], @particles)
    refute_predicate cow.love, :courting?
  end

  def test_monsters_take_no_part
    cow = lover(Mob::COW, 8.5)
    mobs = [Monster.new(Mob::ZOMBIE, 9.5, SKY_Y.to_f, 8.5, 2), Monster.new(Mob::ZOMBIE, 10.5, SKY_Y.to_f, 8.5, 4), cow]
    @breeding.pair_lovers(mobs, @particles)
    refute_predicate cow.love, :courting?
    assert_equal 3, mobs.size
  end

  private

  # An adult of kind in love mode at x, y, z.
  def lover(kind, x, y: SKY_Y.to_f, z: 8.5)
    animal = Animal.new(kind, x, y.to_f, z, 3)
    animal.love.feed
    animal
  end
end
