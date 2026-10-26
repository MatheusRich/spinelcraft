require_relative "test_helper"

class ScreenTest < Minitest::Test
  def test_each_screen_answers_only_its_own_question
    names = %i[on_title? on_death_screen? in_inventory? typing? on_pause_menu? playing?]
    [Screen::TITLE, Screen::DEAD, Screen::INVENTORY, Screen::CHAT, Screen::PAUSED, Screen::PLAYING].each_with_index do |id, own|
      answers = names.map { |name| Screen.new(id).public_send(name) }
      assert_equal names.each_index.map { |index| index == own }, answers
    end
  end

  def test_the_title_and_the_pause_menu_stop_the_world
    stops = [Screen::TITLE, Screen::PAUSED]
    [Screen::TITLE, Screen::DEAD, Screen::INVENTORY, Screen::CHAT, Screen::PAUSED, Screen::PLAYING].each do |id|
      assert_equal stops.include?(id), Screen.new(id).stops_world?
    end
  end
end
