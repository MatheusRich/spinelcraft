# The limit of one kind of line in a stretch of the perf log. A line is
# written until the stretch has `maximum` of them, and the others are counted.
class LineLimit
  attr_reader :dropped

  def initialize(maximum)
    @maximum = maximum
    @written = 0
    @dropped = 0
  end

  # True when the line may be written. Otherwise counts it as left out.
  def take
    if @written >= @maximum
      @dropped += 1
      return false
    end
    @written += 1
    true
  end

  def reset
    @written = 0
    @dropped = 0
  end
end
