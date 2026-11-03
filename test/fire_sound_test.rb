require_relative "test_helper"

# The loop of the crackle of the fires near the player (FireSound), as
# Minetest Game plays it.
class FireSoundTest < Minitest::Test
  X = 8
  # Low enough for a fire RANGE above the player.
  Y = SKY_Y - 60
  Z = 8

  def setup
    @fires = Fires.new(FireSpread.new(world_with_one_chunk, Weather.new(1), Rolls.new(0.0)))
    @player = Player.new(X + 0.5, Y.to_f, Z + 0.5)
    @furnaces = Furnaces.new
    @sound = FireSound.new
  end

  def light(x, y, z) = @fires.add(World.key(x, y, z), 0)

  def test_no_fire_near_is_silent
    far = FireSound::RANGE.to_i + 1
    light(X + far, Y, Z)
    light(X, Y - far, Z)
    light(X, Y, Z - far)
    light(X + 20, Y - 20, Z + 20)
    @sound.update_sound(@fires, @furnaces, @player)
    assert_equal 0.0, @sound.gain
  end

  # The player stands at the middle of a cell, so each of these fires is
  # exactly RANGE away, where the loop fades to silence.
  def test_a_fire_at_the_range_is_not_heard
    player = Player.new(X + 0.5, Y + 0.5, Z + 0.5)
    far = FireSound::RANGE.to_i
    light(X + far, Y, Z)
    light(X, Y + far, Z)
    light(X, Y, Z + far)
    @sound.update_sound(@fires, @furnaces, player)
    assert_equal 0.0, @sound.gain
  end

  # One fire plays at (1 + 0.125) / 3 of the full volume, in the middle of
  # its cell.
  def test_one_fire_plays_in_its_cell
    light(X + 18, Y - 18, Z - 18)
    @sound.update_sound(@fires, @furnaces, @player)
    assert_in_delta 1.125 / 3.0 * FireSound::VOLUME, @sound.gain, 1e-9
    assert_equal [X + 18.5, Y - 17.5, Z - 17.5], [@sound.x, @sound.y, @sound.z]
  end

  # The loop plays in the middle of the box around the fires, louder with
  # each fire up to 16 fires.
  def test_more_fires_play_louder_from_the_middle_of_their_box
    light(X - 2, Y, Z + 1)
    light(X + 4, Y + 3, Z - 5)
    light(X, Y + 1, Z)
    @sound.update_sound(@fires, @furnaces, @player)
    assert_in_delta 1.375 / 3.0 * FireSound::VOLUME, @sound.gain, 1e-9
    assert_equal [X + 1.5, Y + 2.0, Z - 1.5], [@sound.x, @sound.y, @sound.z]
    17.times { |fire| light(X + fire - 8, Y + 2, Z + 2) }
    @sound.update_sound(@fires, @furnaces, @player)
    assert_equal FireSound::VOLUME, @sound.gain
  end

  # A furnace counts as a fire while it burns.
  def test_a_lit_furnace_crackles_as_a_fire
    furnace = @furnaces.furnace_at(X + 3, Y, Z)
    @sound.update_sound(@fires, @furnaces, @player)
    assert_equal 0.0, @sound.gain
    furnace.burn = 100
    light(X - 3, Y, Z)
    @sound.update_sound(@fires, @furnaces, @player)
    assert_in_delta 1.25 / 3.0 * FireSound::VOLUME, @sound.gain, 1e-9
    assert_equal [X + 0.5, Y + 0.5, Z + 0.5], [@sound.x, @sound.y, @sound.z]
  end

  def test_the_loop_stops_when_the_fires_go
    light(X, Y, Z)
    @sound.update_sound(@fires, @furnaces, @player)
    @fires.update_fires(FireSpread::WAIT, [])
    @sound.update_sound(@fires, @furnaces, @player)
    assert_equal 0.0, @sound.gain
  end
end
