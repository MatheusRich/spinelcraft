require_relative "test_helper"

# FrameStats keeps the frame times and the CPU times of a stretch of play,
# and counts the late frames and the stutters.
class FrameStatsTest < Minitest::Test
  def stats_with(fast_frames, slow_frames, slow_ms: 20.0)
    stats = FrameStats.new
    fast_frames.times { stats.add(4.0, 1.0) }
    slow_frames.times { stats.add(slow_ms, 3.0) }
    stats
  end

  def test_the_frame_percentile_counts_the_frame_time_and_the_cpu_percentile_counts_the_cpu_time
    stats = stats_with(90, 10)
    assert_equal 4.5, stats.frame_percentile(0.9)
    assert_equal 20.5, stats.frame_percentile(0.99)
    assert_equal 1.5, stats.cpu_percentile(0.9)
    assert_equal 3.5, stats.cpu_percentile(0.99)
  end

  def test_it_counts_the_frames_the_seconds_the_worst_frame_and_the_cpu_average
    stats = stats_with(3, 1, slow_ms: 23.3)
    assert_equal 4, stats.count
    assert_in_delta 0.0353, stats.seconds
    assert_equal 23.3, stats.worst_ms
    assert_in_delta 1.5, stats.cpu_average_ms
  end

  def test_a_late_frame_takes_longer_than_a_refresh_at_60_hz_and_a_stutter_longer_than_one_at_30_hz
    stats = FrameStats.new
    [16.0, 16.6, 17.0, 33.0, 33.4, 34.0].each { |frame_ms| stats.add(frame_ms, 1.0) }
    assert_equal 4, stats.late_frames
    assert_equal 2, stats.stutters
  end

  def test_a_frame_of_exactly_one_refresh_at_60_hz_is_not_late_and_one_at_30_hz_is_not_a_stutter
    stats = FrameStats.new
    stats.add(FrameStats::LATE_MS, 1.0)
    stats.add(FrameStats::STUTTER_MS, 1.0)
    assert_equal 1, stats.late_frames
    assert_equal 0, stats.stutters
  end

  def test_reset_begins_a_new_stretch
    stats = stats_with(3, 2, slow_ms: 40.0)
    stats.reset
    assert_equal 0, stats.count
    assert_equal 0, stats.late_frames
    assert_equal 0, stats.stutters
    assert_equal 0.0, stats.seconds
    assert_equal 0.0, stats.cpu_average_ms
  end
end
