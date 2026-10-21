require_relative "test_helper"

class LoveTest < Minitest::Test
  DT = 1.0 / 60.0

  def setup
    @world = world_with_one_chunk
    @player = Player.new(2.5, SKY_Y - 1.0, 2.5)
  end

  def test_an_adult_that_eats_stays_in_love_mode_for_30_seconds
    cow = new_cow
    assert cow.feed
    cow.love.clock(Love::TIME - 1.0)
    assert cow.love.on?
    cow.love.clock(1.0)
    refute cow.love.on?
  end

  def test_an_animal_in_love_mode_takes_no_more_food
    cow = new_cow
    cow.feed
    refute cow.feed
  end

  def test_a_baby_that_eats_grows_up_faster_and_does_not_enter_love_mode
    calf = new_cow
    calf.make_baby
    assert calf.feed
    refute calf.love.on?
    assert_in_delta Mob::GROW_TIME * (1.0 - Mob::FEED_GROWTH), calf.grow_left, 0.001
  end

  def test_food_speeds_up_a_baby_only_while_it_has_9_seconds_or_more_left
    calf = new_cow
    calf.make_baby
    calf.grow_up(Mob::GROW_TIME - Mob::FEED_MIN)
    calf.feed
    assert_in_delta Mob::FEED_MIN * (1.0 - Mob::FEED_GROWTH), calf.grow_left, 0.001
    left = calf.grow_left
    calf.feed
    assert_equal left, calf.grow_left
  end

  def test_an_animal_in_love_mode_gives_off_hearts_as_it_lives
    lay_floor
    cow = new_cow
    cow.feed
    31.times { cow.update_mob(@world, DT, @player, Block::AIR, sun: false) }
    assert cow.love.heart
  end

  def test_a_parent_takes_no_food_for_5_minutes_after_the_baby
    cow = new_cow
    cow.feed
    cow.love.bred
    refute cow.love.on?
    refute cow.feed
    cow.love.clock(Love::BREED_WAIT - 1.0)
    refute cow.feed
    cow.love.clock(1.0)
    assert cow.feed
  end

  def test_an_animal_gives_off_a_heart_each_half_second_only_in_love_mode
    lover = new_cow
    lover.feed
    other = new_cow
    assert_equal 2, hearts(lover, 70)
    assert_equal 0, hearts(other, 70)
  end

  def test_the_first_heart_comes_half_a_second_after_the_animal_eats
    cow = new_cow
    cow.feed
    cow.love.clock(Love::HEART_EVERY)
    assert cow.love.heart
  end

  def test_an_animal_gives_off_no_heart_in_the_step_that_ends_love_mode
    cow = new_cow
    cow.feed
    cow.love.clock(Love::TIME - Love::HEART_EVERY)
    cow.love.heart = false
    cow.love.clock(Love::HEART_EVERY)
    refute cow.love.on?
    refute cow.love.heart
  end

  # The last heart comes at the end of love mode, or one step too late.
  def test_the_hearts_stop_when_love_mode_ends
    cow = new_cow
    cow.feed
    assert_in_delta 60, hearts(cow, ((Love::TIME + 1.0) / DT).to_i), 1
    refute cow.love.on?
    assert_equal 0, hearts(cow, 60)
  end

  def test_a_hit_ends_love_mode
    cow = new_cow
    cow.feed
    cow.wound(1.0)
    refute cow.love.on?
  end

  def test_a_lover_walks_to_its_mate_and_counts_the_time
    lay_floor
    east = new_cow
    north = new_cow
    [east, north].each(&:feed)
    east.love.court(12.5, 4.5)
    north.love.court(4.5, 12.5)
    60.times do
      east.update_mob(@world, DT, @player, Block::AIR, sun: false)
      north.update_mob(@world, DT, @player, Block::AIR, sun: false)
    end
    assert_operator east.x, :>, 8.5
    assert_operator east.z, :<, 8.5
    assert_operator north.x, :<, 8.5
    assert_operator north.z, :>, 8.5
    assert_in_delta 1.0, east.love.court_time, DT
  end

  def test_a_lover_without_a_mate_forgets_the_time_it_walked
    lay_floor
    cow = new_cow
    cow.feed
    cow.love.court(12.5, 8.5)
    30.times { cow.update_mob(@world, DT, @player, Block::AIR, sun: false) }
    cow.love.alone
    assert_equal 0.0, cow.love.court_time
  end

  def test_a_lover_forgets_its_mate_when_love_mode_ends
    lay_floor
    cow = new_cow
    cow.feed
    cow.love.court(12.5, 8.5)
    cow.love.clock(Love::TIME)
    x = cow.x
    60.times { cow.update_mob(@world, DT, @player, Block::AIR, sun: false) }
    assert_equal 0.0, cow.love.court_time
    assert_operator cow.x, :<, x + 1.0
  end

  private

  def new_cow = Mob.new(Mob::COW, 8.5, SKY_Y - 1.0, 8.5, 3)

  # The hearts that the mob gives off in steps of DT.
  def hearts(mob, steps)
    count = 0
    steps.times do
      mob.love.clock(DT)
      count += 1 if mob.love.heart
      mob.love.heart = false
    end
    count
  end

  def lay_floor
    16.times { |x| 16.times { |z| @world.set(x, SKY_Y - 2, z, Block::STONE) } }
  end
end
