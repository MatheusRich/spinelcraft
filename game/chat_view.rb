# The chat on the HUD: the chat lines above the hotbar, and while the
# player types, the input line at the bottom of the screen and the names
# that Tab can complete.
class ChatView
  # Sizes in pixels at scale 1.
  TEXT_SCALE = 2.0
  ROW_HEIGHT = 12.0
  NEWEST_LINE_ABOVE_HOTBAR = 120.0
  EDGE_MARGIN = 4.0
  BACKDROP_PADDING = 2.0
  LINE_BACKDROP_RIGHT_PADDING = 4.0
  INPUT_TOP = 18.0
  INPUT_HEIGHT = 14.0
  INPUT_TEXT_TOP = 15.0
  INPUT_TEXT_LEFT = 8.0
  # A long chat line wraps at this part of the width of the screen, but
  # not before this many characters.
  WRAP_PART_OF_WIDTH = 0.5
  FEWEST_CHARACTERS_IN_A_ROW = 20
  # The cursor shows, then hides, each 1/3 second.
  CURSOR_CHANGES_PER_SECOND = 3.0
  LINE_BACKDROP_ALPHA = 0.4
  ERROR_RED = 1.0
  ERROR_GREEN = 0.35
  ERROR_BLUE = 0.3

  # The size of the chat is its base size times scale. The HUD sets it
  # each frame.
  attr_writer :scale

  def initialize(ui, chat)
    @ui = ui
    @chat = chat
    @scale = 1.0
  end

  # The chat lines at the left, above the hotbar and the bars, the newest
  # at the bottom. Each line fades out after a while.
  def draw_lines(frame_width, hotbar_top)
    draw_lines_with_alpha(frame_width, hotbar_top) { |index| @chat.fade(index) }
  end

  # The chat lines while the player types, with no fade.
  def draw_all_lines(frame_width, hotbar_top)
    draw_lines_with_alpha(frame_width, hotbar_top) { 1.0 }
  end

  # The line that the player types, at the bottom of the screen, and the
  # names that Tab can complete above it. A line wider than the screen
  # shows its end.
  def draw_input(frame_width, frame_height, time)
    @ui.rect(EDGE_MARGIN * @scale, frame_height - INPUT_TOP * @scale, frame_width - 2.0 * EDGE_MARGIN * @scale, INPUT_HEIGHT * @scale, Ui::CHAT_INPUT_BACKDROP)
    cursor = (time * CURSOR_CHANGES_PER_SECOND).to_i.even? ? "_" : ""
    shown = @chat.text.upcase + cursor
    fit = ((frame_width - 2.0 * INPUT_TEXT_LEFT * @scale) / (Ui::CHARACTER_WIDTH * text_scale)).to_i
    shown = shown[shown.size - fit, fit] if shown.size > fit
    @ui.text(INPUT_TEXT_LEFT * @scale, frame_height - INPUT_TEXT_TOP * @scale, shown, text_scale, Color::WHITE)
    draw_matches(frame_height)
  end

  private

  def text_scale = TEXT_SCALE * @scale
  def row_height = ROW_HEIGHT * @scale

  # The block gives the alpha of the line at each index. A line that does
  # not fit in a row wraps.
  def draw_lines_with_alpha(frame_width, hotbar_top)
    row_size = [(frame_width * WRAP_PART_OF_WIDTH / (Ui::CHARACTER_WIDTH * text_scale)).to_i, FEWEST_CHARACTERS_IN_A_ROW].max
    y = hotbar_top - NEWEST_LINE_ABOVE_HOTBAR * @scale
    (@chat.lines.size - 1).downto(0) do |index|
      alpha = yield index
      next unless alpha > 0.0

      line = @chat.lines[index]
      rows = (line.size + row_size - 1) / row_size
      (rows - 1).downto(0) do |row|
        part = line[row * row_size, row_size]
        width = @ui.text_width(part, text_scale) + (BACKDROP_PADDING + LINE_BACKDROP_RIGHT_PADDING) * @scale
        @ui.rect(EDGE_MARGIN * @scale, y - BACKDROP_PADDING * @scale, width, row_height, Color.new(0.0, 0.0, 0.0, LINE_BACKDROP_ALPHA * alpha))
        @ui.text((EDGE_MARGIN + BACKDROP_PADDING) * @scale, y, part, text_scale, line_color(index, alpha))
        y -= row_height
      end
    end
  end

  def line_color(index, alpha)
    return Color.new(ERROR_RED, ERROR_GREEN, ERROR_BLUE, alpha) if @chat.error?(index)

    Color.new(1.0, 1.0, 1.0, alpha)
  end

  # The names that Tab can complete, above the input line, as the
  # suggestions of Minecraft. The name on the line is yellow.
  def draw_matches(frame_height)
    names = @chat.matches
    return if names.empty?

    shown = [names.size, Chat::MATCHES].min
    current = @chat.current_match
    first = current >= shown ? current - shown + 1 : 0
    x = (INPUT_TEXT_LEFT + Ui::CHARACTER_WIDTH * Command.last_word_at(@chat.text) * TEXT_SCALE) * @scale
    widest = names.map { |name| @ui.text_width(name, text_scale) }.max
    y = frame_height - INPUT_TOP * @scale - shown * row_height
    padding = BACKDROP_PADDING * @scale
    @ui.rect(x - padding, y - padding, widest + 2.0 * padding, shown * row_height, Ui::CHAT_MATCHES_BACKDROP)
    shown.times do |row|
      index = first + row
      color = index == current ? Ui::MATCH_CURRENT : Ui::MATCH_OTHER
      @ui.text(x, y + row * row_height, names[index].upcase, text_scale, color)
    end
  end
end
