require_relative "test_helper"

class SaveFileTest < Minitest::Test
  VERSION = "SPINELCRAFT0"

  def setup
    @file = SaveFile.new
  end

  def test_sections_and_chunks_survive_a_round_trip
    @file.add("player", [1.5, 2, 3.25])
    @file.add("hotbar", [4, 0, 9])
    first = "a" * CHUNK_BYTES
    second = "b" * CHUNK_BYTES
    data = @file.head(VERSION, [12, -3]) + first + second
    read = SaveFile.new

    assert read.read(data, VERSION)
    assert_equal %w[1.5 2 3.25], read.section("player")
    assert_equal %w[4 0 9], read.section("hotbar")
    assert_equal({ 12 => first, -3 => second }, read.chunks)
  end

  def test_a_save_may_lack_a_section
    read = SaveFile.new
    read.read(@file.head(VERSION, []), VERSION)

    assert_equal [], read.section("weather")
  end

  def test_a_reader_reads_a_section_that_it_does_not_know
    @file.add("seed", [7])
    @file.add("from_the_future", [1, 2])
    read = SaveFile.new

    assert read.read(@file.head(VERSION, []), VERSION)
    assert_equal ["7"], read.section("seed")
    assert_equal %w[1 2], read.section("from_the_future")
  end

  def test_refuses_an_empty_line
    read = SaveFile.new

    assert_equal false, read.read("#{VERSION}\n\nchunks \n", VERSION)
    assert_equal "it has an empty line", read.error
  end

  def test_a_save_that_reads_has_no_error_and_no_chunks
    read = SaveFile.new

    assert_equal true, read.read(@file.head(VERSION, []), VERSION)
    assert_equal "", read.error
    assert_empty read.chunks
  end

  def test_refuses_another_version
    read = SaveFile.new

    refute read.read(@file.head("SPINELCRAFT1", []), VERSION)
    assert_equal "its format is SPINELCRAFT1, not #{VERSION}", read.error
  end

  def test_names_only_the_first_word_of_the_first_line_of_another_version
    read = SaveFile.new

    refute read.read("SPINELCRAFT1 1 2 3 4 5\nseed 1\nchunks \n", VERSION)
    assert_equal "its format is SPINELCRAFT1, not #{VERSION}", read.error
  end

  def test_refuses_text_without_a_first_line
    read = SaveFile.new

    refute read.read("NOT A SAVE", VERSION)
    assert_equal "it has no first line", read.error
  end

  def test_refuses_a_save_without_the_chunks_line
    read = SaveFile.new

    refute read.read("#{VERSION}\nseed 1\n", VERSION)
    assert_equal "it has no line for the chunks", read.error
  end

  def test_refuses_chunks_of_the_wrong_size
    read = SaveFile.new

    refute read.read(@file.head(VERSION, [1, 2]) + "a" * CHUNK_BYTES, VERSION)
    assert_equal "it has #{CHUNK_BYTES} bytes of chunks, not 2 * #{CHUNK_BYTES}", read.error
  end
end
