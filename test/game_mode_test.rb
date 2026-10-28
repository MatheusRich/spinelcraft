require_relative "test_helper"

class GameModeTest < Minitest::Test
  def test_survival_is_not_creative
    assert_predicate GameMode::SURVIVAL, :survival?
    refute_predicate GameMode::SURVIVAL, :creative?
    assert_predicate GameMode::CREATIVE, :creative?
    refute_predicate GameMode::CREATIVE, :survival?
  end

  def test_a_word_names_a_mode_by_name_first_letter_or_number
    assert_same GameMode::SURVIVAL, GameMode.parse("SURVIVAL")
    assert_same GameMode::SURVIVAL, GameMode.parse("S")
    assert_same GameMode::SURVIVAL, GameMode.parse("0")
    assert_same GameMode::CREATIVE, GameMode.parse("CREATIVE")
    assert_same GameMode::CREATIVE, GameMode.parse("C")
    assert_same GameMode::CREATIVE, GameMode.parse("1")
  end

  def test_another_word_names_no_mode
    assert_nil GameMode.parse("ADVENTURE")
    assert_nil GameMode.parse("")
  end
end
