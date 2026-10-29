# The perf log: a text file that the game appends to while a person plays, so
# that a computer which cannot run the benchmarks still tells how the game
# runs on it. A session writes a header with the machine, then one line for
# each INTERVAL_SECONDS of play, and one line for each stutter (a frame over
# FrameStats::STUTTER_MS). A crash loses at most the last stretch. A percentile
# is the upper edge of a bucket of TimeHistogram, and 100.0 means 100 ms or
# more.
class PerfLog
  INTERVAL_SECONDS = 30.0
  # A stretch writes at most this many stutter lines, so that a stutter that
  # lasts does not fill the file.
  MAX_STUTTERS = 10
  PERCENT = 100.0
  MEDIAN = 0.5
  SLOW_TAIL = 0.95
  WORST_TAIL = 0.99

  def initialize(path)
    @path = path
    @stats = FrameStats.new
    @session_seconds = 0.0
    @stutters = 0
  end

  # Begins a session in the file. The header text says what the machine is.
  def start(header)
    append("\n#{header}")
  end

  def add(frame_ms, cpu_ms)
    @stats.add(frame_ms, cpu_ms)
  end

  def due? = @stats.seconds >= INTERVAL_SECONDS

  def stutter?(frame_ms) = frame_ms > FrameStats::STUTTER_MS && @stutters < MAX_STUTTERS

  def write_stutter(frame_ms, detail)
    @stutters += 1
    append("stutter at #{(@session_seconds + @stats.seconds).round} s: frame #{frame_ms.round(1)} ms, #{detail}")
  end

  # Writes the line of the stretch since the last one, then begins a new
  # stretch. The extra text carries what only the game knows.
  def write_stretch(extra)
    return if @stats.count.zero?

    @session_seconds += @stats.seconds
    append(stretch_line(extra))
    @stats.reset
    @stutters = 0
  end

  private

  def stretch_line(extra)
    "#{@session_seconds.round} s: #{@stats.count} frames, " \
      "frame ms p50 #{@stats.frame_percentile(MEDIAN)} p95 #{@stats.frame_percentile(SLOW_TAIL)} " \
      "p99 #{@stats.frame_percentile(WORST_TAIL)} worst #{@stats.worst_ms.round(1)}, " \
      "over 16.7 ms #{percent_of_frames(@stats.late_frames)}, over 33.3 ms #{percent_of_frames(@stats.stutters)}, " \
      "cpu ms avg #{@stats.cpu_average_ms.round(2)} p99 #{@stats.cpu_percentile(WORST_TAIL)}, #{extra}"
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
