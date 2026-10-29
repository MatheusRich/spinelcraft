require_relative "test_helper"

# TimeHistogram counts times into buckets of half a millisecond, and reports
# a percentile as the upper edge of a bucket.
class TimeHistogramTest < Minitest::Test
  def histogram_with(fast_times, slow_times, fast_ms: 4.0, slow_ms: 20.0)
    histogram = TimeHistogram.new
    fast_times.times { histogram.add(fast_ms) }
    slow_times.times { histogram.add(slow_ms) }
    histogram
  end

  def test_a_percentile_is_the_upper_edge_of_the_bucket_that_holds_it
    histogram = histogram_with(90, 10)
    assert_equal 4.5, histogram.percentile(0.5)
    assert_equal 4.5, histogram.percentile(0.9)
    assert_equal 20.5, histogram.percentile(0.91)
    assert_equal 20.5, histogram.percentile(0.99)
  end

  def test_a_time_at_the_edge_of_a_bucket_counts_in_the_next_bucket
    histogram = histogram_with(1, 0, fast_ms: 4.5)
    assert_equal 5.0, histogram.percentile(1.0)
  end

  def test_the_largest_time_keeps_its_exact_value
    assert_equal 23.3, histogram_with(5, 1, slow_ms: 23.3).largest
  end

  def test_a_shorter_time_after_the_largest_does_not_replace_it
    histogram = TimeHistogram.new
    histogram.add(20.0)
    histogram.add(4.0)
    assert_equal 20.0, histogram.largest
  end

  def test_a_time_beyond_the_last_bucket_counts_in_the_last_bucket
    histogram = histogram_with(0, 1, slow_ms: 5000.0)
    assert_equal TimeHistogram::BUCKETS * TimeHistogram::BUCKET_MS, histogram.percentile(1.0)
    assert_equal 5000.0, histogram.largest
  end

  def test_a_time_at_the_reach_of_the_buckets_counts_in_the_last_bucket
    histogram = histogram_with(1, 0, fast_ms: TimeHistogram::BUCKETS * TimeHistogram::BUCKET_MS)
    assert_equal 1, histogram.count
    assert_equal TimeHistogram::BUCKETS * TimeHistogram::BUCKET_MS, histogram.percentile(1.0)
  end

  def test_a_share_above_one_reads_as_the_last_bucket
    histogram = histogram_with(9, 1)
    assert_equal TimeHistogram::BUCKETS * TimeHistogram::BUCKET_MS, histogram.percentile(1.5)
  end

  def test_the_last_bucket_reaches_just_past_the_last_time_it_holds
    just_inside = (TimeHistogram::BUCKETS - 1) * TimeHistogram::BUCKET_MS
    histogram = histogram_with(1, 0, fast_ms: just_inside)
    assert_equal TimeHistogram::BUCKETS * TimeHistogram::BUCKET_MS, histogram.percentile(1.0)
  end

  def test_it_counts_and_sums_the_times
    histogram = histogram_with(3, 1)
    assert_equal 4, histogram.count
    assert_equal 32.0, histogram.sum_ms
    assert_equal 8.0, histogram.average
  end

  def test_without_times_every_number_is_zero
    histogram = TimeHistogram.new
    assert_equal 0.0, histogram.percentile(0.99)
    assert_equal 0.0, histogram.average
    assert_equal 0.0, histogram.largest
    assert_equal 0, histogram.count
  end

  def test_reset_begins_again
    histogram = histogram_with(3, 2)
    histogram.reset
    assert_equal 0, histogram.count
    assert_equal 0.0, histogram.sum_ms
    assert_equal 0.0, histogram.largest
    assert_equal 0.0, histogram.percentile(0.5)
    histogram.add(8.0)
    assert_equal 8.5, histogram.percentile(1.0)
  end
end
