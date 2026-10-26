# What the player sees over the game, and what the input acts on. Game#screen
# works it out from the flags of the game, and each question below names one
# screen.
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

  def on_title? = @id == TITLE

  def on_death_screen? = @id == DEAD

  def in_inventory? = @id == INVENTORY

  def typing? = @id == CHAT

  def on_pause_menu? = @id == PAUSED

  def playing? = @id == PLAYING

  # The title and the pause menu stop the world, as in Minecraft, but not
  # the death screen, the inventory or the chat.
  def stops_world? = on_title? || on_pause_menu?
end
