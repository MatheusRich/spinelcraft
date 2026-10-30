# The perf log: a text file that the game appends to while a person plays, so
# that a computer which cannot run the benchmarks still tells how the game
# runs on it. A session writes a header with the machine, then one line for
# each INTERVAL_SECONDS of play, and one line for each stutter (a frame over
# FrameStats::STUTTER_MS). The game also writes a line for each event that can
# explain a stutter, such as a save or a change of the window. A crash loses at most the last stretch. A percentile
# is the upper edge of a bucket of TimeHistogram, and 100.0 means 100 ms or
# more.
class PerfLog
  INTERVAL_SECONDS = 30.0
  # A stretch writes at most this many stutter lines, so that a stutter that
  # lasts does not fill the file.
  MAX_STUTTERS = 10
  # A stretch writes at most this many lines for the events of the window.
  MAX_WINDOW_EVENTS = 20
  PERCENT = 100.0
  MEDIAN = 0.5
  SLOW_TAIL = 0.95
  WORST_TAIL = 0.99

  def initialize(path)
    @path = path
    @stats = FrameStats.new
    @session_seconds = 0.0
    @limits = { stutters: LineLimit.new(MAX_STUTTERS), window_events: LineLimit.new(MAX_WINDOW_EVENTS) }
  end

  # Begins a session in the file. The header text says what the machine is.
  def start(header)
    append("\n#{header}")
  end

  def add(frame_ms, cpu_ms)
    @stats.add(frame_ms, cpu_ms)
  end

  def due? = @stats.seconds >= INTERVAL_SECONDS

  def stutter?(frame_ms) = frame_ms > FrameStats::STUTTER_MS

  # Writes the line of a stutter, until the stretch has MAX_STUTTERS of them.
  # The line of the stretch counts the others.
  def write_stutter(frame_ms, detail)
    return unless @limits[:stutters].take

    append("stutter at #{now_seconds} s: frame #{frame_ms.round(1)} ms, #{detail}")
  end

  def write_event(text)
    append("event at #{now_seconds} s: #{text}")
  end

  # Writes the line of an event of the window, until the stretch has
  # MAX_WINDOW_EVENTS of them.
  def write_window_event(text)
    write_event(text) if @limits[:window_events].take
  end

  # Writes the line of the stretch since the last one, then begins a new
  # stretch. The extra text carries what only the game knows.
  def write_stretch(extra)
    return if @stats.count.zero?

    @session_seconds += @stats.seconds
    append(stretch_line(extra))
    @stats.reset
    @limits.each_value(&:reset)
  end

  private

  def now_seconds = (@session_seconds + @stats.seconds).round

  def stretch_line(extra)
    "#{@session_seconds.round} s: #{@stats.count} frames, " \
      "frame ms p50 #{@stats.frame_percentile(MEDIAN)} p95 #{@stats.frame_percentile(SLOW_TAIL)} " \
      "p99 #{@stats.frame_percentile(WORST_TAIL)} worst #{@stats.worst_ms.round(1)}, " \
      "over 16.7 ms #{percent_of_frames(@stats.late_frames)}, over 33.3 ms #{percent_of_frames(@stats.stutters)}, " \
      "cpu ms avg #{@stats.cpu_average_ms.round(2)} p99 #{@stats.cpu_percentile(WORST_TAIL)}, #{dropped_text}#{extra}"
  end

  def dropped_text
    stutters = @limits[:stutters].dropped
    events = @limits[:window_events].dropped
    return "" if stutters.zero? && events.zero?

    "not written: #{stutters} stutters, #{events} window events, "
  end

  def percent_of_frames(frames) = "#{(frames * PERCENT / @stats.count).round(1)}%"

  # A log that cannot be written (a folder without write access) must not
  # stop the game.
  def append(text)
    File.write(@path, "#{text}\n", mode: "a")
  rescue SystemCallError
    nil
  end
end
