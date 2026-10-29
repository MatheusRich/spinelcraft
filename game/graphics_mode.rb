# How much the game draws: FANCY draws everything, and FAST leaves out or
# simplifies small things so that the game uses less memory and has less to
# draw. Each effect of FAST has a question here, and the code of that
# effect asks it.
class GraphicsMode
  attr_reader :name

  def initialize(name)
    @name = name
  end

  FANCY = new("FANCY")
  FAST = new("FAST")
  ALL = [FANCY, FAST]

  # Leaves draw as solid blocks, and no face lies between two of them.
  def opaque_leaves? = equal?(FAST)

  # No face of the floor under deep water (Mesher::DEEP_WATER).
  def hides_deep_seabed? = equal?(FAST)

  # Water that hides what is under it, with no blend.
  def opaque_water? = equal?(FAST)

  # The mode after this one in the pause menu.
  def next_mode = equal?(FANCY) ? FAST : FANCY

  # The mode that a word of the options file names, or nil.
  def self.parse(word) = ALL.find { |mode| word == mode.name.downcase }
end
