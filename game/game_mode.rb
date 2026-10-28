# How the player plays: in survival with health, hunger and a limited
# inventory, or in creative with the whole block picker and no harm.
class GameMode
  attr_reader :name, :number

  def initialize(name, number)
    @name = name
    @number = number
  end

  SURVIVAL = new("SURVIVAL", 0)
  CREATIVE = new("CREATIVE", 1)
  ALL = [SURVIVAL, CREATIVE]

  def survival? = equal?(SURVIVAL)

  def creative? = equal?(CREATIVE)

  # The mode that a word of /gamemode or a save names: its name, its first
  # letter or its number. The result is nil for another word.
  def self.parse(word)
    ALL.find { |mode| word == mode.name || word == mode.name[0] || word == mode.number.to_s }
  end
end
