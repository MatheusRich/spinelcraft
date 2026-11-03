# The crackle of the fires near the player, as Minetest Game plays it (the
# flame sound of its fire mod): one loop of the crackle at the middle of
# the box around the fires that the player hears, louder with each fire.
# Minecraft plays a crackle now and then from each fire
# (minecraft.wiki/w/Fire). The crackle of the game is the loop of Minetest
# Game, so it plays as there. Minetest Game counts only the fires up to 8
# blocks away, so the loop stops at once past them. This loop counts the
# fires up to RANGE, so it fades out.
class FireSound
  # The loop plays at (1 + fires * PER_FIRE) / MOST of VOLUME, at most at
  # VOLUME, as the gain min(0.06 * (1 + fires * 0.125), 0.18) of Minetest
  # Game. VOLUME is the volume of the crackle of a lit furnace
  # (Game::AMBIENT_VOLUME).
  PER_FIRE = 0.125
  MOST = 3.0
  VOLUME = 0.5
  # The crackle fades to silence at this distance, as in Minetest Game.
  RANGE = 32.0

  # The middle of the box around the fires near the player, and the volume
  # of the loop there before the distance: 0.0 with no fire near.
  attr_reader :x, :y, :z, :gain

  def initialize
    @x = 0.0
    @y = 0.0
    @z = 0.0
    @gain = 0.0
    nil
  end

  # Counts the fires (Fires#keys) near the player again.
  def update_sound(fires, player)
    near = fires.keys.select { |key| near?(key, player) }
    @gain = near.empty? ? 0.0 : [(1.0 + near.size * PER_FIRE) / MOST, 1.0].min * VOLUME
    return if near.empty?

    @x = middle(near.map { |key| World.key_x(key) })
    @y = middle(near.map { |key| World.key_y(key) })
    @z = middle(near.map { |key| World.key_z(key) })
    nil
  end

  private

  # True when the middle of the cell of key is less than RANGE from the
  # player.
  def near?(key, player)
    x = World.key_x(key) + 0.5 - player.x
    y = World.key_y(key) + 0.5 - player.y
    z = World.key_z(key) + 0.5 - player.z
    x * x + y * y + z * z < RANGE * RANGE
  end

  # The middle of the cells from the least to the most of cells.
  def middle(cells) = (cells.min + cells.max) / 2.0 + 0.5
end
