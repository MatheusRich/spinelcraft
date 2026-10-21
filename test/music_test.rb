require_relative "test_helper"

# Music picks the tracks as in Minecraft: a long quiet gap after each
# track. Each track plays once before a track plays again, and never twice
# in a row. Underground the tracks are mining tracks, and at night no
# track starts on the surface.
class MusicTest < Minitest::Test
  def test_the_next_track_waits_for_the_track_to_end_and_then_for_the_gap
    music = Music.new(1)
    assert_includes 0...Music::MINING, music.next_track(Music::FIRST_WAIT_MAX, false, false, false)
    assert_equal(-1, music.next_track(Music::GAP_MAX, true, false, false))
    assert_equal(-1, music.next_track(Music::GAP_MIN - 1.0, false, false, false))
  end

  def test_the_first_track_starts_at_a_random_time_from_1_to_30_seconds
    waits = (1..100).map do |seed|
      music = Music.new(seed)
      seconds = 0.0
      seconds += 0.1 while music.next_track(0.1, false, false, false) < 0
      seconds
    end
    assert_operator waits.min, :>=, Music::FIRST_WAIT_MIN
    assert_operator waits.max, :<=, Music::FIRST_WAIT_MAX + 0.1
    assert_operator waits.uniq.size, :>, 50
  end

  def test_at_night_a_track_starts_underground_but_not_on_the_surface
    music = Music.new(1)
    assert_equal(-1, music.next_track(Music::GAP_MAX, false, false, true))
    assert_operator music.next_track(0.0, false, true, true), :>=, Music::MINING
  end

  # Each round of Music::MINING surface picks holds each surface track once.
  def test_each_track_plays_once_in_a_round_and_never_twice_in_a_row
    music = Music.new(2)
    tracks = Array.new(20 * Music::MINING) { music.next_track(Music::GAP_MAX, false, false, false) }
    tracks.each_slice(Music::MINING) do |round|
      assert_equal (0...Music::MINING).to_a, round.sort
    end
    tracks.each_cons(2) { |a, b| refute_equal a, b }
  end
end
