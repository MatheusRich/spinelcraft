require_relative "test_helper"

# The chat on the HUD: what the player sees of the chat lines, the input
# line and the names that Tab can complete.
class ChatViewTest < Minitest::Test
  Drawn = Data.define(:x, :y, :width, :height, :text, :color) do
    def bottom = y + height
    def right = x + width

    def covers?(other)
      x <= other.x && y <= other.y && right >= other.right && bottom >= other.bottom
    end

    def times(factor) = with(x: x * factor, y: y * factor, width: width * factor, height: height * factor)
  end

  # A Ui that keeps each backdrop and each text that it draws.
  class Recorder < Ui
    # The height of a glyph of the font at text scale 1 (Ui#text).
    GLYPH_HEIGHT = 5.0

    attr_reader :rects, :texts

    def initialize
      super
      @rects = []
      @texts = []
    end

    def rect(x, y, w, h, color)
      @rects << Drawn.new(x, y, w, h, "", color)
      super
    end

    def text(x, y, s, scale, color)
      @texts << Drawn.new(x, y, text_width(s, scale), GLYPH_HEIGHT * scale, s, color)
      super
    end

    def drawn = @rects + @texts
  end

  FRAME_WIDTH = 640.0
  FRAME_HEIGHT = 360.0
  HOTBAR_TOP = 304.0
  CURSOR_SHOWN = 0.0
  CURSOR_HIDDEN = 0.5

  def setup
    @chat = Chat.new
  end

  def test_a_new_line_shows_and_an_old_one_shows_only_while_the_player_types
    @chat.post("old")
    @chat.age(Chat::SHOW)
    @chat.post("new")
    ui = draw_lines
    assert_equal ["NEW"], ui.texts.map(&:text)
    ui = draw { |view| view.draw_all_lines(FRAME_WIDTH, HOTBAR_TOP) }
    assert_equal ["NEW", "OLD"], ui.texts.map(&:text)
  end

  def test_a_line_and_its_backdrop_fade_out_together
    @chat.post("old")
    @chat.age(Chat::SHOW - 0.5)
    @chat.post("new")
    ui = draw_lines
    new_line, old_line = ui.texts
    new_backdrop, old_backdrop = ui.rects
    assert_equal 0.5, old_line.color.alpha / new_line.color.alpha
    assert_equal 0.5, old_backdrop.color.alpha / new_backdrop.color.alpha
  end

  def test_the_newest_line_is_at_the_bottom_above_the_hotbar_and_an_error_line_is_red
    @chat.post("first")
    @chat.post_error("second")
    second, first = draw_lines.texts
    assert_operator second.bottom, :<, HOTBAR_TOP
    assert_operator first.bottom, :<, second.y
    assert_equal [1.0, 1.0], [first.color.green, first.color.blue]
    assert_operator second.color.green, :<, 1.0
    assert_operator second.color.blue, :<, 1.0
  end

  def test_a_long_line_wraps_into_rows_that_read_from_the_top
    row = "a" * ChatView::FEWEST_CHARACTERS_IN_A_ROW
    @chat.post(row)
    @chat.post(row + "b")
    tail, head, full = draw_lines(frame_width: 0.0).texts
    assert_equal ["B", row.upcase, row.upcase], [tail.text, head.text, full.text]
    assert_operator head.bottom, :<, tail.y
    assert_operator full.bottom, :<, head.y
  end

  def test_a_line_wraps_at_half_the_width_of_a_wide_screen
    row_size = 30
    @chat.post("a" * row_size + "b")
    frame_width = row_size * character_width / ChatView::WRAP_PART_OF_WIDTH
    assert_equal ["B", "A" * row_size], draw_lines(frame_width: frame_width).texts.map(&:text)
  end

  def test_the_input_line_shows_the_typed_text_and_a_blinking_cursor_at_its_end
    @chat.start("/time")
    input, cursor = draw_input(CURSOR_SHOWN).texts
    assert_equal ["/TIME", "_"], [input.text, cursor.text]
    assert_equal input.right, cursor.x
    assert_equal ["/TIME"], draw_input(CURSOR_HIDDEN).texts.map(&:text)
  end

  def test_a_cursor_inside_the_line_is_a_bar_between_two_characters
    @chat.start("/tme")
    @chat.move(-2)
    input, cursor = draw_input(CURSOR_SHOWN).texts
    assert_equal ["/TME", "|"], [input.text, cursor.text]
    assert_equal input.x + 2 * character_width, cursor.x + character_width / 2.0
  end

  def test_an_input_line_wider_than_the_screen_shows_the_part_around_the_cursor
    @chat.start("a" * (Chat::MAX - 1) + "b")
    [1.0, 2.0].each do |scale|
      width = (character_width * 10.0 + 2.0 * ChatView::INPUT_TEXT_LEFT) * scale
      @chat.move(Chat::MAX)
      ui = draw(scale: scale) { |view| view.draw_input(width, FRAME_HEIGHT, CURSOR_SHOWN) }
      input, cursor = ui.texts
      assert_equal ["A" * 8 + "B", "_"], [input.text, cursor.text]
      assert_equal input.right, cursor.x
      @chat.move(-Chat::MAX)
      ui = draw(scale: scale) { |view| view.draw_input(width, FRAME_HEIGHT, CURSOR_SHOWN) }
      assert_equal ["A" * 10, "|"], ui.texts.map(&:text)
    end
  end

  def test_the_input_backdrop_spans_the_frame_at_the_bottom
    @chat.start("/time")
    backdrop = draw_input(CURSOR_SHOWN).rects.first
    assert_equal FRAME_WIDTH - backdrop.right, backdrop.x
    assert_operator backdrop.bottom, :<, FRAME_HEIGHT
    assert_operator backdrop.y, :>, HOTBAR_TOP
  end

  def test_the_names_that_tab_completes_show_under_the_word_and_the_one_on_the_line_is_yellow
    @chat.start("/t")
    @chat.tab
    ui = draw_input(CURSOR_HIDDEN)
    input, *names = ui.texts
    assert_equal ["TELEPORT", "TIME", "TP"], names.map(&:text)
    assert_equal [Ui::MATCH_CURRENT, Ui::MATCH_OTHER, Ui::MATCH_OTHER], names.map(&:color)
    word_x = input.x + character_width
    assert_equal [word_x], names.map(&:x).uniq
    assert_operator names.last.bottom, :<=, ui.rects.first.y
    names.each_cons(2) { |above, below| assert_operator above.bottom, :<=, below.y }
  end

  def test_the_names_start_under_the_first_character_of_the_last_word
    @chat.start("/summon c")
    input, name = draw_input(CURSOR_HIDDEN).texts
    assert_equal "CREEPER", name.text
    assert_equal input.x + "/summon ".size * character_width, name.x
  end

  def test_past_the_names_that_fit_the_list_moves_with_the_name_on_the_line
    @chat.start("/")
    (Chat::MATCHES + 1).times { @chat.tab }
    _input, *names = draw_input(CURSOR_HIDDEN).texts
    assert_equal Chat::MATCHES, names.size
    assert_equal Ui::MATCH_CURRENT, names.last.color
    assert_equal @chat.text.upcase, "/#{names.last.text}"
  end

  def test_each_backdrop_covers_its_text
    @chat.post("a line")
    @chat.post("a" * 50)
    @chat.start("/t")
    @chat.tab
    ui = draw do |view|
      view.draw_lines(FRAME_WIDTH, HOTBAR_TOP)
      view.draw_input(FRAME_WIDTH, FRAME_HEIGHT, CURSOR_SHOWN)
    end
    ui.texts.each do |text|
      assert ui.rects.any? { |backdrop| backdrop.covers?(text) }, "no backdrop covers #{text.text}"
    end
  end

  def test_twice_the_scale_draws_everything_twice_as_big
    @chat.post("a line")
    @chat.post("a" * 50)
    @chat.start("/t")
    @chat.tab
    small = draw_all(1.0)
    large = draw_all(2.0)
    assert_equal small.drawn.map { |drawn| drawn.times(2.0) }, large.drawn
  end

  private

  def character_width = Ui::CHARACTER_WIDTH * ChatView::TEXT_SCALE

  def draw(scale: 1.0)
    ui = Recorder.new
    view = ChatView.new(ui, @chat)
    view.scale = scale
    yield view
    ui
  end

  def draw_lines(frame_width: FRAME_WIDTH)
    draw { |view| view.draw_lines(frame_width, HOTBAR_TOP) }
  end

  def draw_input(time, frame_width: FRAME_WIDTH)
    draw { |view| view.draw_input(frame_width, FRAME_HEIGHT, time) }
  end

  def draw_all(scale)
    draw(scale: scale) do |view|
      view.draw_lines(FRAME_WIDTH * scale, HOTBAR_TOP * scale)
      view.draw_input(FRAME_WIDTH * scale, FRAME_HEIGHT * scale, CURSOR_SHOWN)
    end
  end
end
