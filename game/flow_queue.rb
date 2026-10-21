# The cells that wait for a step of one fluid, and the timer of its steps
# (see Fluids). A step looks at the cells that woke before it starts. A
# cell that wakes during the step waits for the next step.
class FlowQueue
  # A step looks at this many cells at most. The rest wait for the next
  # step.
  STEP_CELLS = 6000

  # The cell that next? moved to.
  attr_reader :x, :y, :z

  # step is the time from one step to the next, in seconds.
  def initialize(step)
    @step = step
    @timer = 0.0
    # The cells that woke since the step started: x, y and z for each one.
    @cells = Array.new(0, 0)
    # The cells of this step, and the index of the next one.
    @batch = Array.new(0, 0)
    @next = 0
    @x = 0
    @y = 0
    @z = 0
    nil
  end

  # Wakes the cell x, y, z and its six neighbors.
  def wake(x, y, z)
    @cells << x << y << z
    @cells << x + 1 << y << z
    @cells << x - 1 << y << z
    @cells << x << y + 1 << z
    @cells << x << y - 1 << z
    @cells << x << y << z + 1
    @cells << x << y << z - 1
    nil
  end

  # Forgets the cells that woke.
  def clear
    @cells.clear
    nil
  end

  # Moves the timer dt seconds on. When a step is due and a cell woke, it
  # starts the step and gives true. After a frame longer than a step, the
  # next step is a full step later.
  def start?(dt)
    @timer -= dt
    return false if @timer > 0.0

    @timer += @step
    @timer = @step if @timer <= 0.0
    return false if @cells.empty?

    @batch = @cells
    @cells = Array.new(0, 0)
    @next = 0
    true
  end

  # Moves to the next cell of the step and gives true. At the end of the
  # step it gives false, and the cells past STEP_CELLS wait for the next
  # step.
  def next?
    if @next < @batch.size && @next < STEP_CELLS * 3
      @x = @batch[@next]
      @y = @batch[@next + 1]
      @z = @batch[@next + 2]
      @next += 3
      return true
    end
    @cells.concat(@batch[@next, @batch.size - @next]) if @next < @batch.size
    false
  end
end
