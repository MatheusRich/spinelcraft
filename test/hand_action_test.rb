require_relative "test_helper"

class HandActionTest < Minitest::Test
  def setup
    @hand = HandAction.new
  end

  def test_a_new_hand_does_nothing
    refute @hand.mining?
    refute @hand.eating?
    refute @hand.drawing?
    refute @hand.using_item?
    assert_equal HandAction::NONE, @hand.eat_seconds
    assert_equal HandAction::NONE, @hand.draw_seconds
    assert_equal 0.0, @hand.mining_progress
    assert @hand.pause_over?(0.0)
  end

  def test_the_hand_mines_a_block_until_it_breaks
    @hand.mine_block(World.key(1, 2, 3))
    assert @hand.mining?
    refute @hand.using_item?
    assert_equal World.key(1, 2, 3), @hand.mined_key
    @hand.break_more(0.6)
    refute @hand.broken?
    @hand.mine_block(World.key(1, 2, 3))
    @hand.break_more(0.4)
    assert @hand.broken?
    assert_in_delta 1.0, @hand.mining_progress
  end

  def test_a_new_block_starts_with_no_progress
    @hand.mine_block(World.key(1, 2, 3))
    @hand.break_more(0.5)
    @hand.mine_block(World.key(1, 2, 4))
    assert_equal 0.0, @hand.mining_progress
    assert_equal World.key(1, 2, 4), @hand.mined_key
    @hand.break_more(0.5)
    @hand.mine_block(World.key(1, 3, 4))
    assert_equal 0.0, @hand.mining_progress
    @hand.break_more(0.5)
    @hand.mine_block(World.key(2, 3, 4))
    assert_equal 0.0, @hand.mining_progress
  end

  def test_a_block_that_the_hand_stopped_mining_starts_over
    @hand.mine_block(World.key(1, 2, 3))
    @hand.break_more(0.5)
    @hand.stop
    refute @hand.mining?
    @hand.mine_block(World.key(1, 2, 3))
    assert_equal 0.0, @hand.mining_progress
  end

  def test_the_dig_sound_plays_at_once_and_then_each_quarter_second
    @hand.mine_block(World.key(1, 2, 3))
    assert @hand.dig_sound_due?(0.05)
    refute @hand.dig_sound_due?(0.125)
    assert @hand.dig_sound_due?(0.125)
  end

  def test_a_new_block_plays_the_dig_sound_at_once
    @hand.mine_block(World.key(1, 2, 3))
    @hand.dig_sound_due?(0.05)
    @hand.mine_block(World.key(1, 2, 4))
    assert @hand.dig_sound_due?(0.05)
  end

  def test_a_broken_block_with_a_hardness_makes_the_hand_wait
    @hand.mine_block(World.key(1, 2, 3))
    @hand.finish_block(0.5)
    refute @hand.mining?
    refute @hand.pause_over?(0.2)
    assert @hand.pause_over?(0.1)
  end

  def test_a_block_without_a_hardness_makes_no_wait
    @hand.mine_block(World.key(1, 2, 3))
    @hand.finish_block(0.0)
    refute @hand.mining?
    assert @hand.pause_over?(0.0)
  end

  def test_eating_bites_after_a_while_and_then_swallows
    assert_equal HandAction::CHEWING, @hand.chew(0.3)
    assert @hand.eating?
    assert @hand.using_item?
    assert_equal HandAction::BITE, @hand.chew(0.1)
    assert_equal HandAction::CHEWING, @hand.chew(0.1)
    assert_equal HandAction::BITE, @hand.chew(0.1)
    assert_in_delta 0.6, @hand.eat_seconds
    assert_equal HandAction::SWALLOW, @hand.chew(1.0)
    refute @hand.eating?
    assert_equal HandAction::NONE, @hand.eat_seconds
  end

  def test_the_first_bite_plays_at_the_chew_start
    assert_equal HandAction::BITE, @hand.chew(HandAction::CHEW_START)
  end

  def test_a_stopped_meal_starts_over
    @hand.chew(1.0)
    @hand.stop
    refute_equal HandAction::SWALLOW, @hand.chew(1.0)
    assert_in_delta 1.0, @hand.eat_seconds
  end

  def test_the_draw_of_the_bow_grows
    @hand.draw_bow(0.25)
    @hand.draw_bow(0.5)
    assert @hand.drawing?
    assert @hand.using_item?
    assert_in_delta 0.75, @hand.draw_seconds
    assert_equal HandAction::NONE, @hand.eat_seconds
  end

  def test_the_hand_does_one_thing_at_a_time
    @hand.mine_block(World.key(1, 2, 3))
    @hand.chew(0.5)
    refute @hand.mining?
    @hand.draw_bow(0.25)
    refute @hand.eating?
    assert_in_delta 0.25, @hand.draw_seconds
    @hand.chew(0.25)
    refute @hand.drawing?
    assert_in_delta 0.25, @hand.eat_seconds
    @hand.mine_block(World.key(1, 2, 3))
    refute @hand.eating?
  end

  def test_the_end_of_an_item_use_does_not_stop_the_mining
    @hand.mine_block(World.key(1, 2, 3))
    @hand.stop_using_item
    assert @hand.mining?
    @hand.draw_bow(0.5)
    @hand.stop_using_item
    refute @hand.drawing?
    @hand.chew(0.5)
    @hand.stop_using_item
    refute @hand.eating?
  end
end
