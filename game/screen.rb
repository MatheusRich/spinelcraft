# What the player sees over the game, and what the input acts on. Game keeps
# one Screen in @screen, and each question below names one screen.
class Screen
  TITLE = 0
  DEAD = 1
  INVENTORY = 2
  CHAT = 3
  PAUSED = 4
  PLAYING = 5

  def initialize(id)
    @id = id
  end

  def title? = @id == TITLE

  def death_screen? = @id == DEAD

  def inventory? = @id == INVENTORY

  def typing? = @id == CHAT

  def pause_menu? = @id == PAUSED

  def playing? = @id == PLAYING

  # The player is in the game, not in a menu: playing, or typing in the chat.
  def in_game? = playing? || typing?

  # The title and the pause menu stop the world, as in Minecraft, but not
  # the death screen, the inventory or the chat.
  def stops_world? = title? || pause_menu?
end
