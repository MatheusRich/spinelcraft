require_relative "test_helper"

# A command line splits into capital words, and its numbers, coordinates,
# times and names read as in Minecraft.
class CommandTest < Minitest::Test
  def test_a_command_splits_into_capital_words_without_the_slash
    assert_equal ["TP", "~", "~5", "-10"], Command.words("/tp  ~ ~5 -10")
  end

  def test_a_coordinate_is_a_number_or_a_tilde_with_a_number_or_nothing
    assert Command.coord?("~")
    assert Command.coord?("~-2.5")
    assert Command.coord?("-7")
    refute Command.coord?("1X")
    refute Command.coord?("~~")
    refute Command.coord?("-")
    refute Command.coord?("1.2.3")
  end

  def test_a_tilde_is_relative_and_a_whole_x_or_z_goes_to_the_center_of_its_block
    assert_equal 15.0, Command.coord("~5", 10.0, false)
    assert_equal 3.25, Command.coord("~", 3.25, true)
    assert_equal 10.5, Command.coord("10", 0.0, true)
    assert_equal 10.0, Command.coord("10", 0.0, false)
    assert_equal(-2.5, Command.coord("-3", 0.0, true))
    assert_equal 10.25, Command.coord("10.25", 0.0, true)
  end

  def test_a_time_is_a_name_or_a_number_of_days_seconds_or_ticks
    assert_equal 13000, Command.ticks("NIGHT")
    assert_equal 48000, Command.ticks("2D")
    assert_equal 400, Command.ticks("20S")
    assert_equal 100, Command.ticks("100")
    assert_equal 5, Command.ticks("5T")
    assert_equal(-1, Command.ticks("SOON"))
    assert_equal(-1, Command.ticks("-5"))
  end

  # As an int of Minecraft.
  def test_a_time_is_at_most_2_to_the_31_minus_1_ticks
    assert_equal 2147483647, Command.ticks("2147483647")
    assert_equal(-1, Command.ticks("2147483648"))
    assert_equal(-1, Command.ticks("99999999999999999999D"))
  end

  def test_an_item_name_is_its_name_with_an_underscore_for_each_space
    assert_equal Block::DIAMOND_PICK, Command.item_id("DIAMOND_PICKAXE")
    assert_equal Block::WHEAT, Command.item_id("MINECRAFT:WHEAT")
    assert_equal Block::WATER, Command.item_id("WATER")
    assert_equal(-1, Command.item_id("DIRTT"))
  end

  def test_only_the_creative_picker_has_items
    assert_equal(-1, Command.item_id("AIR"))
    assert_equal(-1, Command.item_id("WHEAT_CROPS"))
  end

  def test_the_boats_the_pumpkins_and_the_shears_have_ids_as_in_minecraft
    assert_equal Block::JACK_O_LANTERN, Command.item_id("JACK_O_LANTERN")
    assert_equal Block::CARVED_PUMPKIN, Command.item_id("CARVED_PUMPKIN")
    assert_equal Block::SPRUCE_BOAT, Command.item_id("SPRUCE_BOAT")
    assert_equal Block::SHEARS, Command.item_id("SHEARS")
    assert_equal Block::PUMPKIN_SEEDS, Command.item_id("PUMPKIN_SEEDS")
    assert_equal(-1, Command.item_id("PUMPKIN_STEM"))
  end

  def test_a_mob_name_gives_its_kind
    assert_equal Mob::CREEPER, Command.mob("CREEPER")
    assert_equal Mob::PIG, Command.mob("MINECRAFT:PIG")
    assert_equal(-1, Command.mob("GHAST"))
  end
end
