require_relative "test_helper"

class ControlsTest < Minitest::Test
  def setup
    @controls = Controls.new
  end

  def test_new_controls_hold_no_key
    assert_equal 0.0, @controls.forward
    assert_equal 0.0, @controls.strafe
    assert_equal false, @controls.jump
    assert_equal false, @controls.sneak
    assert_equal false, @controls.sprint
    assert_equal false, @controls.tap_sprint?
  end

  def test_the_controls_hold_the_keys_of_a_frame
    @controls.hold(1.0, -1.0, jump: true, sneak: true, sprint: true)
    assert_equal 1.0, @controls.forward
    assert_equal(-1.0, @controls.strafe)
    assert @controls.jump
    assert @controls.sneak
    assert @controls.sprint
  end

  def test_forward_alone_is_no_sprint
    @controls.hold(1.0, 0.0, jump: false, sneak: false, sprint: false)
    refute @controls.sprint
  end

  def test_the_player_sprints_only_forward
    @controls.hold(0.0, 1.0, jump: false, sneak: false, sprint: true)
    refute @controls.sprint
    @controls.hold(-1.0, 0.0, jump: false, sneak: false, sprint: true)
    refute @controls.sprint
  end

  def test_a_release_lets_go_of_each_key
    @controls.hold(1.0, 1.0, jump: true, sneak: true, sprint: true)
    @controls.release_keys
    assert_equal 0.0, @controls.forward
    assert_equal 0.0, @controls.strafe
    refute @controls.jump
    refute @controls.sneak
    refute @controls.sprint
  end

  def test_the_autopilot_flies_forward_in_a_sprint_and_keeps_the_other_keys
    @controls.hold(0.0, 1.0, jump: true, sneak: false, sprint: false)
    @controls.cruise
    assert_equal 1.0, @controls.forward
    assert_equal 1.0, @controls.strafe
    assert @controls.jump
    assert @controls.sprint
  end

  def test_two_presses_of_forward_close_together_start_a_sprint
    @controls.tap_forward(10.0)
    refute @controls.tap_sprint?
    @controls.tap_forward(10.0 + Controls::DOUBLE_TAP - 0.01)
    assert @controls.tap_sprint?
  end

  def test_two_presses_of_forward_far_apart_do_not
    @controls.tap_forward(0.0)
    @controls.tap_forward(Controls::DOUBLE_TAP)
    refute @controls.tap_sprint?
  end

  def test_two_presses_at_the_same_time_do_not
    @controls.tap_forward(5.0)
    @controls.tap_forward(5.0)
    refute @controls.tap_sprint?
  end

  def test_a_third_press_starts_a_new_pair
    @controls.tap_forward(10.0)
    @controls.tap_forward(10.1)
    @controls.tap_forward(10.2)
    assert @controls.tap_sprint?
    @controls.tap_forward(11.0)
    refute @controls.tap_sprint?
  end

  # The game time wraps after 1000 seconds, so a press can come at an
  # earlier time than the one before it.
  def test_a_press_at_an_earlier_time_does_not_start_a_sprint
    @controls.tap_forward(999.9)
    @controls.tap_forward(0.05)
    refute @controls.tap_sprint?
  end

  def test_the_first_press_at_the_start_of_the_game_does_not_start_a_sprint
    @controls.tap_forward(0.0)
    refute @controls.tap_sprint?
  end

  def test_a_release_of_forward_ends_the_sprint_of_two_presses
    @controls.tap_forward(10.0)
    @controls.tap_forward(10.1)
    @controls.release_forward
    refute @controls.tap_sprint?
  end
end
