require_relative "test_helper"

class GraphicsModeTest < Minitest::Test
  def test_only_fast_has_opaque_leaves
    assert_predicate GraphicsMode::FAST, :opaque_leaves?
    refute_predicate GraphicsMode::FANCY, :opaque_leaves?
  end

  def test_the_next_mode_goes_around
    assert_same GraphicsMode::FAST, GraphicsMode::FANCY.next_mode
    assert_same GraphicsMode::FANCY, GraphicsMode::FAST.next_mode
  end

  def test_parse_takes_the_name_in_lower_case
    assert_same GraphicsMode::FAST, GraphicsMode.parse("fast")
    assert_same GraphicsMode::FANCY, GraphicsMode.parse("fancy")
  end

  def test_parse_gives_nil_for_another_word
    assert_nil GraphicsMode.parse("FAST")
    assert_nil GraphicsMode.parse("ultra")
    assert_nil GraphicsMode.parse("")
  end
end
