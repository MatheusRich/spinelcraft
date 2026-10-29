require_relative "test_helper"
require "tmpdir"

# The options start as in Minecraft, their sliders go in steps, and the
# options file keeps each option inside its range.
class OptionsTest < Minitest::Test
  # A file that no test makes.
  NO_FILE = File.join(Dir.tmpdir, "spinelcraft-no-such-options.txt")

  def test_new_options_start_at_half_with_the_normal_view_and_no_debug_lines
    options = Options.new(NO_FILE)
    assert_equal 0.5, options.brightness
    assert_equal 0.5, options.volume
    assert_equal 0.5, options.music
    assert_equal 1600.0, options.view
    assert_equal 70.0, options.fov_degrees
    assert_equal false, options.fullscreen
    assert_equal false, options.debug
    assert options.fancy_graphics
  end

  def test_the_render_distance_slider_goes_from_200_to_5000_in_steps_of_100_blocks
    options = Options.new(NO_FILE)
    options.slide_view(0.0)
    assert_equal 200.0, options.view
    options.slide_view(1.0)
    assert_equal 5000.0, options.view
    options.slide_view(0.5)
    assert_equal 2600.0, options.view
    assert_equal 0.5, options.view_share
    options.slide_view(0.51)
    assert_equal 2600.0, options.view
    options.slide_view(0.52)
    assert_equal 2700.0, options.view
  end

  def test_the_field_of_view_slider_goes_from_30_to_110_in_steps_of_1_degree
    options = Options.new(NO_FILE)
    options.slide_fov(0.0)
    assert_equal 30.0, options.fov_degrees
    options.slide_fov(1.0)
    assert_equal 110.0, options.fov_degrees
    options.slide_fov(0.5)
    assert_equal 70.0, options.fov_degrees
    assert_equal 0.5, options.fov_share
    options.slide_fov(0.506)
    assert_equal 70.0, options.fov_degrees
    options.slide_fov(0.507)
    assert_equal 71.0, options.fov_degrees
  end

  def test_the_half_fov_is_half_the_field_of_view_in_radians
    options = Options.new(NO_FILE)
    options.fov_degrees = 90.0
    assert_in_delta Math::PI / 4.0, options.half_fov, 1.0e-12
  end

  def test_the_file_keeps_every_option
    in_dir do |path|
      written = Options.new(path)
      written.brightness = 1.0
      written.volume = 0.25
      written.music = 0.0
      written.view = 1200.0
      written.fov_degrees = 90.0
      written.fullscreen = true
      written.debug = true
      written.fancy_graphics = false
      written.write_file
      assert_equal "graphics:fast\n", File.readlines(path).last
      read = Options.new(path)
      read.read_file
      assert_equal 1.0, read.brightness
      assert_equal 0.25, read.volume
      assert_equal 0.0, read.music
      assert_equal 1200.0, read.view
      assert_equal 90.0, read.fov_degrees
      assert read.fullscreen
      assert read.debug
      refute read.fancy_graphics
    end
  end

  def test_the_file_keeps_fancy_graphics
    in_dir do |path|
      Options.new(path).write_file
      read = Options.new(path)
      read.fancy_graphics = false
      read.read_file
      assert read.fancy_graphics
    end
  end

  def test_only_the_word_fast_turns_the_graphics_to_fast
    refute read_text("graphics:fast\n").fancy_graphics
    assert read_text("graphics:fancy\n") { |o| o.fancy_graphics = false }.fancy_graphics
    assert read_text("graphics:ultra\n").fancy_graphics
    assert read_text("graphics:\n").fancy_graphics
  end

  def test_a_value_outside_its_range_reads_as_the_nearest_end
    read = read_text("brightness:2\nvolume:-1\nmusic:1.5\nview:100\nfov:200\n")
    assert_equal 1.0, read.brightness
    assert_equal 0.0, read.volume
    assert_equal 1.0, read.music
    assert_equal 200.0, read.view
    assert_equal 110.0, read.fov_degrees
    read = read_text("view:9000\nfov:10\n")
    assert_equal 5000.0, read.view
    assert_equal 30.0, read.fov_degrees
  end

  def test_an_option_that_the_file_does_not_have_keeps_its_value
    read = read_text("volume:0.25\nnoise\nfov:a:b\nspeed:fast\n") { |o| o.debug = true }
    assert_equal 0.25, read.volume
    assert_equal 0.5, read.brightness
    assert_equal 70.0, read.fov_degrees
    assert read.debug
    assert read.fancy_graphics
  end

  def test_only_the_word_true_turns_an_on_or_off_option_on
    read = read_text("fullscreen:true\ndebug:yes\n") { |o| o.debug = true }
    assert read.fullscreen
    refute read.debug
    assert read_text("debug:true\n") { |o| o.debug = false }.debug
    refute read_text("fullscreen:\n").fullscreen
  end

  def test_a_missing_file_keeps_every_option
    options = Options.new(NO_FILE)
    options.volume = 0.1
    options.read_file
    assert_equal 0.1, options.volume
  end

  private

  # Yields the path of a file in a new, empty directory.
  def in_dir
    Dir.mktmpdir { |dir| yield File.join(dir, "options.txt") }
  end

  # Options that read text as their file. A block can change the options
  # before they read it.
  def read_text(text)
    in_dir do |path|
      File.write(path, text)
      read = Options.new(path)
      yield read if block_given?
      read.read_file
      read
    end
  end
end
