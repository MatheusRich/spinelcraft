# Counts times in buckets of BUCKET_MS, so that adding a time costs no
# allocation. A percentile is the upper edge of a bucket.
class TimeHistogram
  BUCKET_MS = 0.5
  # The last bucket also takes every time that is longer than the first
  # BUCKETS - 1 buckets reach.
  BUCKETS = 200

  attr_reader :count, :largest

  def initialize
    @buckets = Array.new(BUCKETS, 0)
    reset
  end

  def reset
    @buckets.fill(0)
    @count = 0
    @sum = 0.0
    @largest = 0.0
  end

  def add(milliseconds)
    @buckets[bucket_of(milliseconds)] += 1
    @count += 1
    @sum += milliseconds
    @largest = milliseconds if milliseconds > @largest
  end

  def sum_ms = @sum

  def average
    return 0.0 if @count.zero?

    @sum / @count
  end

  # The time that the share (0.0 to 1.0) of the added times stay under.
  def percentile(share)
    return 0.0 if @count.zero?

    wanted = (@count * share).ceil
    seen = 0
    reached = @buckets.index do |times|
      seen += times
      seen >= wanted
    end
    return BUCKETS * BUCKET_MS unless reached

    (reached + 1) * BUCKET_MS
  end

  private

  def bucket_of(milliseconds)
    bucket = (milliseconds / BUCKET_MS).to_i
    return BUCKETS - 1 if bucket >= BUCKETS

    bucket
  end
end
