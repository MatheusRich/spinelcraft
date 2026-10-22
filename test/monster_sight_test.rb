require_relative "test_helper"

# A skeleton at 8.5, 8.5 looks for the player. The eyes of both are in the
# cells at EYE_CELL, so the line between them is level.
class MonsterSightTest < Minitest::Test
  EYE_Y = SKY_Y + 1.6
  EYE_CELL = EYE_Y.floor

  def setup
    @world = world_with_one_chunk
    @skeleton = Monster.new(Mob::SKELETON, 8.5, SKY_Y.to_f, 8.5, 3)
  end

  def test_a_monster_sees_the_player_in_open_air
    assert @skeleton.sees?(@world, player_at(12.5, 8.5))
    assert @skeleton.sees?(@world, player_at(10.5, 13.5))
  end

  def test_a_solid_block_between_hides_the_player
    @world.set(10, EYE_CELL, 8, Block::STONE)
    refute @skeleton.sees?(@world, player_at(12.5, 8.5))
    assert @skeleton.sees?(@world, player_at(8.5, 12.5))
  end

  def test_a_block_that_is_not_solid_does_not_hide_the_player
    @world.set(10, EYE_CELL, 8, Block::WATER)
    @world.set(11, EYE_CELL, 8, Block::TALL_GRASS)
    assert @skeleton.sees?(@world, player_at(12.5, 8.5))
  end

  def test_a_block_beside_the_line_does_not_hide_the_player
    @world.set(10, EYE_CELL, 9, Block::STONE)
    @world.set(10, EYE_CELL + 1, 8, Block::STONE)
    assert @skeleton.sees?(@world, player_at(12.5, 8.5))
  end

  def test_a_block_over_the_line_hides_a_player_far_below
    @world.set(10, EYE_CELL - 2, 8, Block::STONE)
    player = player_at(12.5, 8.5)
    player.y -= 4.0
    refute @skeleton.sees?(@world, player)
  end

  # The line passes through the edge where the two blocks touch.
  def test_two_blocks_that_touch_at_an_edge_hide_the_player
    @world.set(9, EYE_CELL, 8, Block::STONE)
    @world.set(8, EYE_CELL, 9, Block::STONE)
    refute @skeleton.sees?(@world, player_at(10.5, 10.5))
  end

  private

  # A player whose eyes are as high as the eyes of the skeleton.
  def player_at(x, z) = Player.new(x, EYE_Y - Player::EYE, z)
end
