# The chat: the line that the player types, the lines typed before, Tab
# completion, and the lines that show above the hotbar. T opens it, and /
# opens it with a slash typed. Game runs each line that the player enters
# (game/commands.rb). minecraft.wiki/w/Chat
class Chat
  # The lines that the chat keeps, and the seconds that a new line shows
  # while the chat is closed.
  LINES = 10
  SHOW = 10.0
  # The longest line that the player can type. Minecraft allows 256
  # characters, but 100 fit on a small window.
  MAX = 100
  # The most names of Tab completion that show at once.
  MATCHES = 10
  # The lines that Up and Down walk through.
  HISTORY = 50

  attr_reader :text, :lines

  def initialize
    @open = false
    # The line that the player types, the lines typed before, and the
    # place in them that Up and Down reached.
    @text = ""
    @history = [""]
    @history.clear
    @back = 0
    # The lines shown, with their color (1 for an error) and age.
    @lines = [""]
    @lines.clear
    @errors = Array.new(0, 0)
    @ages = Array.new(0, 0.0)
    # Tab completion: the names that Tab cycles through, the next one, and
    # the line before the word that they replace.
    @tab_matches = [""]
    @tab_matches.clear
    @tab_at = 0
    @tab_base = ""
  end

  def open? = @open

  # Opens the chat with text on the line, after the newest line of the
  # history.
  def open(text)
    @open = true
    @text = text
    @back = @history.size
    @tab_matches.clear
    nil
  end

  def close
    @open = false
    nil
  end

  # Puts the character c at the end of the line, up to MAX characters.
  # Each key but Tab stops the names that Tab cycles through.
  def type(c)
    @tab_matches.clear
    @text += c if @text.size < MAX
    nil
  end

  def backspace
    @tab_matches.clear
    @text = @text[0, @text.size - 1].to_s if @text.size > 0
    nil
  end

  def paste(clipboard)
    @tab_matches.clear
    @text = Command.paste(@text, clipboard, MAX)
    nil
  end

  # Puts the line step lines back or forward in the history on the line.
  # Past the newest line, the line is empty.
  def recall(step)
    @tab_matches.clear
    @back = (@back + step).clamp(0, @history.size)
    @text = @back < @history.size ? @history[@back].to_s : ""
    nil
  end

  # Tab puts the first name that completes the last word on the line, and
  # each next Tab the next name, as in Minecraft. The names come from
  # Command.complete when the first Tab comes.
  def tab
    if @tab_matches.empty?
      @tab_matches = Command.complete(@text)
      return if @tab_matches.empty?
      @tab_base = @text[0, Command.last_word_at(@text)].to_s
      @tab_at = 0
    end
    @text = @tab_base + @tab_matches[@tab_at]
    @tab_at = (@tab_at + 1) % @tab_matches.size
    nil
  end

  # The names that Tab can put on the line now: the ones that it cycles
  # through, or the ones that complete the last word. Empty when the only
  # name that completes the word is on the line already.
  def matches
    return @tab_matches unless @tab_matches.empty?
    names = Command.complete(@text)
    names.clear if names.size == 1 && @text.end_with?(names[0])
    names
  end

  # The index in matches of the name that the last Tab put on the line,
  # or -1 before the first Tab.
  def current_match
    return -1 if @tab_matches.empty?
    (@tab_at + @tab_matches.size - 1) % @tab_matches.size
  end

  # Keeps line in the history. The oldest line goes after HISTORY lines.
  def remember(line)
    @history << line
    @history.shift if @history.size > HISTORY
    nil
  end

  def post(text) = push_line(text, 0)
  def post_error(text) = push_line(text, 1)

  # Shows text as a new line, red when error is 1. The oldest line goes
  # after LINES lines.
  def push_line(text, error)
    @lines << text.upcase
    @errors << error
    @ages << 0.0
    if @lines.size > LINES
      @lines.shift
      @errors.shift
      @ages.shift
    end
    nil
  end

  def error?(i) = @errors[i] == 1

  # How much line i shows: all lines while the chat is open, and else a
  # line fades out in the last second of SHOW seconds.
  def opacity(i)
    return 1.0 if @open
    (SHOW - @ages[i]).clamp(0.0, 1.0)
  end

  def age(dt)
    @ages.size.times { |i| @ages[i] += dt }
    nil
  end
end
