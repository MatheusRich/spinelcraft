require_relative "test_helper"

# The debug log writes a line to stderr only for a topic that LOG turns on.
class LogTest < Minitest::Test
  def teardown
    Log.setup("")
  end

  def test_a_topic_in_the_list_writes_its_line_with_the_time_and_the_name
    Log.setup("save,mobs")
    assert_output(nil, /\A *\d+\.\d{3} save: saved 3 chunks\n *\d+\.\d{3} mobs: a pig\n\z/) do
      Log.debug(Log::SAVE) { "saved #{1 + 2} chunks" }
      Log.debug(Log::WORLD) { "a new world" }
      Log.debug(Log::MOBS) { "a pig" }
    end
  end

  def test_a_topic_that_is_off_does_not_run_the_block
    Log.setup("save")
    ran = false
    assert_output(nil, "") { Log.debug(Log::FRAME) { ran = true } }
    refute ran
  end

  def test_all_turns_on_every_topic
    Log.setup("all")
    _, err = capture_io { Log::NAMES.size.times { |topic| Log.debug(topic) { "on" } } }
    assert_equal(Log::NAMES, err.lines.map { |line| line.split[1].chomp(":") })
  end

  def test_setup_turns_off_the_topics_that_are_not_in_the_list
    Log.setup("all")
    Log.setup("world")
    _, err = capture_io { Log::NAMES.size.times { |topic| Log.debug(topic) { "on" } } }
    assert_equal(["world"], err.lines.map { |line| line.split[1].chomp(":") })
  end

  def test_a_name_that_is_not_a_topic_gets_a_warning_and_the_rest_turn_on
    assert_output(nil, "LOG: chunks is not a topic. The topics are all, save, world, stream, mobs, frame\n") do
      Log.setup("chunks,stream")
    end
    assert_output(nil, /stream: on/) { Log.debug(Log::STREAM) { "on" } }
  end

  def test_the_time_is_the_seconds_since_the_start
    Log.setup("frame")
    _, err = capture_io { Log.debug(Log::FRAME) { "slow" } }
    seconds = err.split.first.to_f
    assert_operator seconds, :>, 0.0
    assert_operator seconds, :<, 600.0
  end
end
