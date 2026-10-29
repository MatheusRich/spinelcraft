require_relative "test_helper"

# The mesher makes a face for each side of a block that a block next to it
# does not cover. Leaves do not cover, so FAST graphics (fast_leaves) drops
# the faces between two blocks of leaves.
class MesherTest < Minitest::Test
  CUBE_X = 6
  CUBE_Z = 6

  def setup
    @world = World.new(1337)
    (-1..1).each { |cx| (-1..1).each { |cz| @world.load_chunk(cx, cz) } }
    @mesher = Mesher.new(@world)
  end

  # The faces that the mesher makes for chunk 0, 0 now.
  def faces
    @mesher.build(0, 0)
    @mesher.opaque.size / 2
  end

  # Puts a block of side cells at CUBE_X, SKY_Y, CUBE_Z, in open air above the land.
  def place_cube(block, side)
    side.times do |dx|
      side.times do |dy|
        side.times { |dz| @world.set(CUBE_X + dx, SKY_Y + dy, CUBE_Z + dz, block) }
      end
    end
  end

  # The faces that placing the block adds to the chunk.
  def faces_added_by(block, side)
    before = faces
    place_cube(block, side)
    faces - before
  end

  def test_fancy_leaves_make_a_face_on_every_side_of_every_leaf_block
    assert_equal 6 * 9 + 108, faces_added_by(Block::OAK_LEAVES, 3)
  end

  def test_fast_leaves_make_only_the_faces_on_the_outside_of_a_group_of_leaves
    @mesher.fast_leaves = true
    assert_equal 6 * 9, faces_added_by(Block::OAK_LEAVES, 3)
  end

  def test_a_single_leaf_block_keeps_all_six_faces_in_fast_graphics
    @mesher.fast_leaves = true
    assert_equal 6, faces_added_by(Block::OAK_LEAVES, 1)
  end

  def test_fast_leaves_also_hide_the_faces_between_leaves_of_another_kind_and_placed_leaves
    @mesher.fast_leaves = true
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::BIRCH_LEAVES)
    @world.set(CUBE_X + 2, SKY_Y, CUBE_Z, Block::PLACED_SPRUCE_LEAVES)
    assert_equal 3 * 6 - 4, faces - before
  end

  def test_fast_leaves_keep_the_faces_between_leaves_and_another_block
    @mesher.fast_leaves = true
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::GLASS)
    @world.set(CUBE_X + 2, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    assert_equal 18, faces - before
  end

  def test_a_block_next_to_leaves_keeps_its_face_in_fast_graphics
    @mesher.fast_leaves = true
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::STONE)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    assert_equal 6 + 5, faces - before
  end

  def test_other_blocks_make_the_same_faces_in_both_graphics
    fancy = faces_added_by(Block::STONE, 3)
    setup
    @mesher.fast_leaves = true
    assert_equal fancy, faces_added_by(Block::STONE, 3)
  end

  def test_glass_makes_no_face_toward_glass_but_makes_one_toward_another_block
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::GLASS)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::GLASS)
    assert_equal 6 + 6 - 2, faces - before
    before = faces
    @world.set(CUBE_X + 4, SKY_Y, CUBE_Z, Block::GLASS)
    @world.set(CUBE_X + 5, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    assert_equal 6 + 6, faces - before
  end

  # The +x faces that a stone block at CUBE_X, SKY_Y, CUBE_Z adds, when lava
  # fills the cells of lava, given as offsets from the stone.
  def plus_x_faces_added_by_stone(lava)
    lava.each { |dx, dy| @world.set(CUBE_X + dx, SKY_Y + dy, CUBE_Z, Block::LAVA) }
    @mesher.build(0, 0)
    before = @mesher.offsets[1] - @mesher.offsets[0]
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::STONE)
    @mesher.build(0, 0)
    @mesher.offsets[1] - @mesher.offsets[0] - before
  end

  def test_a_face_toward_lava_that_has_lava_over_it_is_hidden
    assert_equal 0, plus_x_faces_added_by_stone([[1, 0], [1, 1]])
  end

  def test_a_face_toward_lava_with_air_over_it_shows_because_the_surface_sinks
    assert_equal 1, plus_x_faces_added_by_stone([[1, 0]])
  end

  def test_only_the_cell_over_the_lava_decides
    assert_equal 1, plus_x_faces_added_by_stone([[1, 0], [1, 2]])
    setup
    assert_equal 1, plus_x_faces_added_by_stone([[1, 0], [1, -1]])
    setup
    assert_equal 1, plus_x_faces_added_by_stone([[1, 0], [-1, 1]])
  end

  def test_a_face_toward_air_shows_when_lava_is_over_the_air
    assert_equal 1, plus_x_faces_added_by_stone([[1, 1]])
  end
end

