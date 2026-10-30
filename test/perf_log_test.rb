require "tmpdir"
require_relative "test_helper"

# The perf log appends a header for each session, a line for each stretch of
# play and a line for each stutter.
class PerfLogTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @path = File.join(@dir, "perf.log")
    @log = PerfLog.new(@path)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def lines = File.readlines(@path, chomp: true)

  # Adds one second of frames at 10 ms each.
  def play_one_second = play_one_second_in(@log)

  def play_one_second_in(log)
    100.times { log.add(10.0, 2.0) }
  end

  def test_a_session_appends_its_header_and_keeps_the_sessions_before
    @log.start("session one")
    PerfLog.new(@path).start("session two")
    assert_equal ["", "session one", "", "session two"], lines
  end

  def test_a_log_that_cannot_be_written_does_not_raise
    log = PerfLog.new(File.join(@dir, "no-such-folder", "perf.log"))
    log.start("session")
    play_one_second_in(log)
    log.write_stretch("extra")
    log.write_stutter(50.0, "slow")
    refute_path_exists File.join(@dir, "no-such-folder")
  end

  def test_a_stretch_is_due_after_the_interval
    (PerfLog::INTERVAL_SECONDS.to_i - 1).times { play_one_second }
    refute_predicate @log, :due?
    play_one_second
    assert_predicate @log, :due?
  end

  def test_a_stretch_line_has_the_percentiles_the_shares_and_the_extra_text
    play_one_second
    @log.write_stretch("memory 900 MB")
    assert_equal ["1 s: 100 frames, frame ms p50 10.5 p95 10.5 p99 10.5 worst 10.0, " \
                  "over 16.7 ms 0.0%, over 33.3 ms 0.0%, cpu ms avg 2.0 p99 2.5, memory 900 MB"], lines
  end

  def test_a_stretch_line_counts_the_frames_over_each_budget
    @log.add(10.0, 1.0)
    @log.add(20.0, 1.0)
    @log.add(40.0, 1.0)
    @log.add(10.0, 1.0)
    @log.write_stretch("")
    assert_includes lines.first, "over 16.7 ms 50.0%, over 33.3 ms 25.0%"
  end

  def test_a_stretch_line_rounds_the_worst_frame_the_cpu_average_and_the_shares
    @log.add(10.0, 1.0)
    @log.add(20.04, 1.0)
    @log.add(12.0, 1.4)
    @log.write_stretch("")
    assert_includes lines.first, "worst 20.0, over 16.7 ms 33.3%, over 33.3 ms 0.0%, cpu ms avg 1.13 p99"
  end

  def test_a_stretch_begins_again_after_its_line
    play_one_second
    @log.write_stretch("first")
    refute_predicate @log, :due?
    @log.write_stretch("nothing played")
    play_one_second
    @log.write_stretch("second")
    assert_equal 2, lines.size
    assert_match(/\A2 s: 100 frames/, lines.last)
  end

  def test_the_seconds_of_a_session_add_up_over_the_stretches
    PerfLog::INTERVAL_SECONDS.to_i.times { play_one_second }
    @log.write_stretch("")
    PerfLog::INTERVAL_SECONDS.to_i.times { play_one_second }
    @log.write_stretch("")
    assert_equal(["30 s", "60 s"], lines.map { |line| line[/\A\d+ s/] })
  end

  def test_only_a_frame_over_33_ms_is_a_stutter
    refute @log.stutter?(33.0)
    assert @log.stutter?(34.0)
  end

  def test_a_frame_of_exactly_33_ms_at_30_hz_is_not_a_stutter
    refute @log.stutter?(FrameStats::STUTTER_MS)
  end

  def test_a_stutter_line_has_the_time_the_frame_and_the_detail
    3.times { play_one_second }
    @log.write_stutter(41.26, "chunks 30 ms")
    assert_equal ["stutter at 3 s: frame 41.3 ms, chunks 30 ms"], lines
  end

  def test_a_stretch_writes_a_limited_number_of_stutters_and_the_next_stretch_writes_more
    (PerfLog::MAX_STUTTERS + 3).times { @log.write_stutter(50.0, "slow") }
    assert_equal PerfLog::MAX_STUTTERS, lines.size
    play_one_second
    @log.write_stretch("")
    @log.write_stutter(50.0, "slow")
    assert_equal PerfLog::MAX_STUTTERS + 2, lines.size
  end

  def test_a_stretch_line_counts_the_stutters_and_the_window_events_that_it_did_not_write
    play_one_second
    (PerfLog::MAX_STUTTERS + 3).times { @log.write_stutter(50.0, "slow") }
    (PerfLog::MAX_WINDOW_EVENTS + 2).times { @log.write_window_event("moved") }
    @log.write_stretch("extra")
    assert_match(/cpu ms avg 2.0 p99 2.5, not written: 3 stutters, 2 window events, extra\z/, lines.last)
  end

  def test_a_stretch_line_counts_a_kind_of_line_that_it_left_out_when_the_other_kind_is_complete
    play_one_second
    (PerfLog::MAX_STUTTERS + 1).times { @log.write_stutter(50.0, "slow") }
    @log.write_stretch("")
    assert_includes lines.last, "not written: 1 stutters, 0 window events, "
    play_one_second
    (PerfLog::MAX_WINDOW_EVENTS + 1).times { @log.write_window_event("moved") }
    @log.write_stretch("")
    assert_includes lines.last, "not written: 0 stutters, 1 window events, "
  end

  def test_a_stretch_line_with_every_line_written_has_no_count
    play_one_second
    @log.write_stretch("extra")
    refute_includes lines.last, "not written"
  end

  def test_an_event_line_has_the_time_and_the_text
    2.times { play_one_second }
    @log.write_event("world saved in 40 ms")
    assert_equal ["event at 2 s: world saved in 40 ms"], lines
  end

  def test_the_events_of_the_game_are_not_limited_and_the_events_of_the_window_do_not_use_up_their_room
    (PerfLog::MAX_WINDOW_EVENTS + 5).times { @log.write_window_event("moved") }
    @log.write_event("world saved in 40 ms")
    assert_equal "event at 0 s: world saved in 40 ms", lines.last
    assert_equal PerfLog::MAX_WINDOW_EVENTS + 1, lines.size
  end
end
