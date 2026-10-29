# The frame times of one stretch of play, and the CPU time of the same
# frames.
class FrameStats
  # A frame at 60 Hz and a frame at 30 Hz. A frame over the first one is
  # late, and a frame over the second one is a stutter.
  LATE_MS = 1000.0 / 60.0
  STUTTER_MS = 1000.0 / 30.0
  MILLISECONDS_PER_SECOND = 1000.0

  attr_reader :late_frames, :stutters

  def initialize
    @frame_times = TimeHistogram.new
    @cpu_times = TimeHistogram.new
    reset
  end

  def reset
    @frame_times.reset
    @cpu_times.reset
    @late_frames = 0
    @stutters = 0
  end

  def add(frame_ms, cpu_ms)
    @frame_times.add(frame_ms)
    @cpu_times.add(cpu_ms)
    @late_frames += 1 if frame_ms > LATE_MS
    @stutters += 1 if frame_ms > STUTTER_MS
  end

  def count = @frame_times.count
  def seconds = @frame_times.sum_ms / MILLISECONDS_PER_SECOND
  def worst_ms = @frame_times.largest
  def cpu_average_ms = @cpu_times.average

  # The frame time that the share (0.0 to 1.0) of the frames stay under.
  def frame_percentile(share) = @frame_times.percentile(share)

  # The same for the milliseconds of CPU in a frame.
  def cpu_percentile(share) = @cpu_times.percentile(share)
end
