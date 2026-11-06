require_relative "test_helper"
require "rubocop"
require_relative "../tools/cops/day_ticks"
require_relative "../tools/cops/rain_strength"
require_relative "../tools/cops/simple_unless"

# The cops of tools/cops, on short pieces of code.
class CopsTest < Minitest::Test
  def test_a_literal_day_of_ticks_is_an_offense
    cop = RuboCop::Cop::Spinelcraft::DayTicks
    assert_equal 2, offenses(cop, "tick = (time * 24000.0).to_i\ndays = ticks / 24000\n").size
    assert_empty offenses(cop, "tick = (time * Clock::DAY_TICKS).to_i\nwait = 2400\n")
  end

  def test_a_comparison_with_the_strength_of_the_rain_is_an_offense
    cop = RuboCop::Cop::Spinelcraft::RainStrength
    assert_equal 2, offenses(cop, "douse if @weather.rain.strength > 0.5\nsplash if 0.0 < weather.rain.strength\n").size
    assert_empty offenses(cop, "fog = 1.0 - @weather.rain.strength\ndouse if @weather.wet_at?(world, x, z)\nrain = 1.0\nsplash if rain > 0.5\n")
  end

  def test_an_unless_with_more_than_one_simple_condition_is_an_offense
    cop = RuboCop::Cop::Spinelcraft::SimpleUnless
    compound = ["a && b", "a || b", "a and b", "(a && b)", "((a || b))", "(a; b && c)", "!a", "not a", "a ? b : c"]
    compound.each { |condition| assert_equal 1, offenses(cop, "return unless #{condition}\n").size, condition }
    assert_equal 1, offenses(cop, "unless a && b\n  c\nend\n").size
  end
  
  def test_an_unless_with_one_simple_condition_is_no_offense
    cop = RuboCop::Cop::Spinelcraft::SimpleUnless
    assert_empty offenses(cop, "return unless a\nreturn unless @a\nreturn unless a == b\nreturn unless (a)\nreturn unless list.any? { |x| x && y }\n")
    assert_empty offenses(cop, "return if !a && !b\nreturn if a ? b : c\n")
  end

  private

  def offenses(cop, source)
    config = RuboCop::Config.new(cop.cop_name => { "Enabled" => true })
    team = RuboCop::Cop::Team.mobilize([cop], config, raise_error: true)
    team.investigate(RuboCop::ProcessedSource.new(source, 3.4)).offenses
  end
end
