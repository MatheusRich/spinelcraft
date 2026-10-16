require_relative "test_helper"

# The chat line: typing, the history, Tab completion and the lines shown.
class ChatTest < Minitest::Test
  def test_the_chat_opens_with_its_text_on_the_line_and_closes
    chat = Chat.new
    refute chat.open?
    chat.open("/")
    assert chat.open?
    assert_equal "/", chat.text
    chat.close
    refute chat.open?
  end

  def test_typing_adds_to_the_end_of_the_line_up_to_the_longest_line
    chat = Chat.new
    chat.open("")
    (Chat::MAX - 1).times { chat.type("a") }
    chat.type("b")
    chat.type("c")
    assert_equal "a" * (Chat::MAX - 1) + "b", chat.text
  end

  def test_backspace_takes_the_last_character_and_does_nothing_on_an_empty_line
    chat = Chat.new
    chat.open("ab")
    chat.backspace
    assert_equal "a", chat.text
    chat.backspace
    chat.backspace
    assert_equal "", chat.text
  end

  def test_a_paste_goes_to_the_end_of_the_line_up_to_the_longest_line
    chat = Chat.new
    chat.open("/tp ")
    chat.paste("1 2\n3")
    assert_equal "/tp 1 23", chat.text
    chat.paste("x" * Chat::MAX)
    assert_equal Chat::MAX, chat.text.size
  end

  def test_up_and_down_walk_through_the_lines_typed_before
    chat = Chat.new
    chat.remember("one")
    chat.remember("two")
    chat.open("")
    chat.recall(-1)
    assert_equal "two", chat.text
    chat.recall(-1)
    assert_equal "one", chat.text
    chat.recall(-1)
    assert_equal "one", chat.text
    chat.recall(1)
    assert_equal "two", chat.text
    chat.recall(1)
    assert_equal "", chat.text
    chat.recall(1)
    assert_equal "", chat.text
  end

  def test_the_chat_opens_after_the_newest_line_of_the_history
    chat = Chat.new
    chat.remember("one")
    chat.open("")
    chat.recall(-1)
    chat.close
    chat.remember("two")
    chat.open("")
    chat.recall(-1)
    assert_equal "two", chat.text
  end

  def test_the_history_keeps_the_newest_lines
    chat = Chat.new
    (Chat::HISTORY + 1).times { |i| chat.remember("line #{i}") }
    chat.open("")
    Chat::HISTORY.times { chat.recall(-1) }
    assert_equal "line 1", chat.text
    chat.recall(-1)
    assert_equal "line 1", chat.text
  end

  def test_each_tab_puts_the_next_name_on_the_line_and_the_last_goes_back_to_the_first
    chat = Chat.new
    chat.open("/t")
    chat.tab
    assert_equal "/teleport", chat.text
    chat.tab
    assert_equal "/time", chat.text
    chat.tab
    assert_equal "/tp", chat.text
    chat.tab
    assert_equal "/teleport", chat.text
  end

  def test_tab_replaces_only_the_last_word
    chat = Chat.new
    chat.open("/summon c")
    chat.tab
    assert_equal "/summon creeper", chat.text
    chat.open("/summon ")
    chat.tab
    assert_equal "/summon pig", chat.text
    chat.tab
    assert_equal "/summon zombie", chat.text
  end

  def test_tab_with_no_name_leaves_the_line
    chat = Chat.new
    chat.open("/fly")
    chat.tab
    assert_equal "/fly", chat.text
    assert_empty chat.matches
  end

  def test_a_key_after_tab_completes_the_new_word
    chat = Chat.new
    chat.open("/t")
    chat.tab
    chat.backspace
    assert_equal ["teleport"], chat.matches
    chat.tab
    assert_equal "/teleport", chat.text
  end

  def test_tab_after_a_typed_word_completes_the_next_word
    chat = Chat.new
    chat.open("/tim")
    chat.tab
    chat.type(" ")
    chat.tab
    assert_equal "/time set", chat.text
  end

  def test_tab_after_a_paste_completes_the_pasted_word
    chat = Chat.new
    chat.open("/tim")
    chat.tab
    chat.paste(" q")
    chat.tab
    assert_equal "/time query", chat.text
  end

  def test_tab_after_up_completes_the_line_from_the_history
    chat = Chat.new
    chat.remember("/weathe")
    chat.open("/t")
    chat.tab
    chat.recall(-1)
    chat.tab
    assert_equal "/weather", chat.text
  end

  def test_a_new_chat_line_has_new_matches
    chat = Chat.new
    chat.open("/t")
    chat.tab
    chat.close
    chat.open("/w")
    assert_equal ["weather"], chat.matches
  end

  def test_the_matches_are_the_names_that_complete_the_last_word
    chat = Chat.new
    chat.open("/t")
    assert_equal ["teleport", "time", "tp"], chat.matches
    assert_equal(-1, chat.current_match)
  end

  def test_no_match_shows_when_the_only_name_is_on_the_line_already
    chat = Chat.new
    chat.open("/weather")
    assert_empty chat.matches
    chat.open("/weathe")
    assert_equal ["weather"], chat.matches
  end

  def test_while_tab_cycles_the_matches_stay_and_the_current_one_is_on_the_line
    chat = Chat.new
    chat.open("/t")
    chat.tab
    assert_equal ["teleport", "time", "tp"], chat.matches
    assert_equal 0, chat.current_match
    chat.tab
    chat.tab
    assert_equal 2, chat.current_match
    chat.tab
    assert_equal 0, chat.current_match
  end

  def test_a_line_shows_in_capitals_and_an_error_line_is_red
    chat = Chat.new
    chat.post("hello")
    chat.post_error("unknown command: fly")
    assert_equal ["HELLO", "UNKNOWN COMMAND: FLY"], chat.lines
    refute chat.error?(0)
    assert chat.error?(1)
  end

  def test_the_chat_keeps_the_newest_lines_with_their_colors
    chat = Chat.new
    chat.post_error("first")
    Chat::LINES.times { |i| chat.post("line #{i}") }
    assert_equal Chat::LINES, chat.lines.size
    assert_equal "LINE 0", chat.lines[0]
    refute chat.error?(0)
  end

  def test_a_line_shows_for_a_while_and_then_fades_out_while_the_chat_is_closed
    chat = Chat.new
    chat.post("old")
    chat.age(Chat::SHOW - 0.75)
    chat.post("new")
    assert_equal 0.75, chat.opacity(0)
    assert_equal 1.0, chat.opacity(1)
    chat.age(1.0)
    assert_equal 0.0, chat.opacity(0)
    assert_equal 1.0, chat.opacity(1)
    chat.age(Chat::SHOW)
    assert_equal 0.0, chat.opacity(1)
  end

  def test_all_lines_show_while_the_chat_is_open
    chat = Chat.new
    chat.post("old")
    chat.age(Chat::SHOW * 2.0)
    chat.open("")
    assert_equal 1.0, chat.opacity(0)
  end
end
