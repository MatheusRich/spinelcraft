require_relative "test_helper"

# Sfx as the listener: the volume and the pan of a sound from where the
# player hears it. At yaw 0 the listener looks toward -z, so +x is to the
# right.
class SfxTest < Minitest::Test
  def setup
    @sfx = Sfx.new
    @sfx.listen(8.0, 70.0, 8.0, 0.0)
  end

  def test_a_sound_pans_toward_the_side_that_it_comes_from
    assert_in_delta 1.0, @sfx.pan_to(13.0, 70.0, 8.0), 0.001
    assert_in_delta(-1.0, @sfx.pan_to(3.0, 70.0, 8.0), 0.001)
  end

  def test_a_sound_ahead_behind_or_above_plays_in_the_middle
    assert_in_delta 0.0, @sfx.pan_to(8.0, 70.0, 3.0), 0.001
    assert_in_delta 0.0, @sfx.pan_to(8.0, 70.0, 13.0), 0.001
    assert_in_delta 0.0, @sfx.pan_to(8.0, 75.0, 8.0), 0.001
  end

  def test_a_sound_at_the_listener_plays_in_the_middle
    assert_equal 0.0, @sfx.pan_to(8.0, 70.0, 8.0)
  end

  def test_the_pan_turns_with_the_listener
    @sfx.listen(8.0, 70.0, 8.0, Math::PI / 2.0)
    assert_in_delta 1.0, @sfx.pan_to(8.0, 70.0, 13.0), 0.001
    assert_in_delta 0.0, @sfx.pan_to(13.0, 70.0, 8.0), 0.001
  end

  def test_a_new_listener_hears_from_the_origin_and_looks_toward_minus_z
    assert_in_delta 1.0, Sfx.new.pan_to(5.0, 0.0, 0.0), 0.001
  end

  def test_a_half_way_sound_plays_at_half_volume_times_its_gain
    assert_in_delta 0.4, @sfx.near_volume(8.0, 70.0, 8.0 + Sfx::RANGE / 2.0, 0.8, Sfx::RANGE), 0.001
  end

  def test_a_sound_far_below_is_quiet
    assert_operator @sfx.near_volume(8.0, 58.0, 8.0, 1.0, Sfx::RANGE), :<, 0.3
    assert_equal 0.0, @sfx.near_volume(8.0, 50.0, 8.0, 1.0, Sfx::RANGE)
  end

  def test_an_explosion_carries_farther_than_other_sounds
    assert_operator @sfx.near_volume(8.0, 70.0, -32.0, 1.0, Sfx::RANGES[Sfx::EXPLODE]), :>, 0.0
    assert_equal 0.0, @sfx.near_volume(8.0, 70.0, -32.0, 1.0, Sfx::RANGES[Sfx::HIT])
  end
end
