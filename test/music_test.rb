require_relative "test_helper"

# Music picks the tracks as in Minecraft: a long quiet gap after each
# track. Each track plays once before a track plays again, and never twice
# in a row. Underground the tracks are mining tracks, and at night no
# track starts on the surface.
class MusicTest < Minitest::Test
  def test_the_next_track_waits_for_the_track_to_end_and_then_for_the_gap
    music = Music.new(1)
    assert_equal(-1, music.next_track(Music::FIRST_WAIT - 0.5, false, false, false))
    assert_includes 0...Music::MINING, music.next_track(1.0, false, false, false)
    assert_equal(-1, music.next_track(Music::GAP_MAX, true, false, false))
    assert_equal(-1, music.next_track(Music::GAP_MIN - 1.0, false, false, false))
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
