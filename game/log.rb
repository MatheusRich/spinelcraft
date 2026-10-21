# The debug log. LOG=save,mobs turns on the topics in the list, and LOG=all
# turns on all of them. Each line goes to stderr with the seconds since the
# start and the topic name. A topic that is off costs one array read, and
# the block that makes the line does not run.
module Log
  NAMES = ["save", "world", "stream", "mobs", "frame"]
  # The topics, as indexes in NAMES.
  SAVE = 0 # save and load
  WORLD = 1 # a new world, spawn, respawn
  STREAM = 2 # the chunks and far tiles for each new stream center
  MOBS = 3 # mobs that spawn and mobs that go
  FRAME = 4 # frames that take more than SLOW_MS of CPU, by step
  # A frame takes more CPU time than this to be in the frame topic: half a
  # frame at 60 Hz.
  SLOW_MS = 8.0

  @on = Array.new(NAMES.size, false)
  @start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Turns on the topics in spec, a list of names with commas, and turns off
  # the rest. A name that is not a topic gets a warning.
  def self.setup(spec)
    @on.fill(false)
    spec.split(",").each do |name|
      topic = NAMES.index(name)
      if name == "all"
        @on.fill(true)
      elsif topic
        @on[topic] = true
      else
        $stderr.puts "LOG: #{name} is not a topic. The topics are all, #{NAMES.join(", ")}"
      end
    end
  end

  # Writes the line from the block when the topic is on.
  def self.debug(topic)
    return unless @on[topic]

    seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start
    $stderr.puts "#{format("%9.3f", seconds)} #{NAMES[topic]}: #{yield}"
  end
end
