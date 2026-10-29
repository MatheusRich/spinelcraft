require_relative "test_helper"

# The mesher makes a face for each side of a block that a block next to it
# does not cover. Leaves do not cover, so FAST graphics drop
# the faces between two blocks of leaves.
class MesherTest < Minitest::Test
  CUBE_X = 6
  CUBE_Z = 6
  SEABED_Y = SKY_Y - 30

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
    @mesher.graphics = GraphicsMode::FAST
    assert_equal 6 * 9, faces_added_by(Block::OAK_LEAVES, 3)
  end

  def test_a_single_leaf_block_keeps_all_six_faces_in_fast_graphics
    @mesher.graphics = GraphicsMode::FAST
    assert_equal 6, faces_added_by(Block::OAK_LEAVES, 1)
  end

  def test_fast_leaves_also_hide_the_faces_between_leaves_of_another_kind_and_placed_leaves
    @mesher.graphics = GraphicsMode::FAST
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::BIRCH_LEAVES)
    @world.set(CUBE_X + 2, SKY_Y, CUBE_Z, Block::PLACED_SPRUCE_LEAVES)
    assert_equal 3 * 6 - 4, faces - before
  end

  def test_fast_leaves_keep_the_faces_between_leaves_and_another_block
    @mesher.graphics = GraphicsMode::FAST
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::GLASS)
    @world.set(CUBE_X + 2, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    assert_equal 18, faces - before
  end

  def test_a_block_next_to_leaves_keeps_its_face_in_fast_graphics
    @mesher.graphics = GraphicsMode::FAST
    before = faces
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::STONE)
    @world.set(CUBE_X + 1, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    assert_equal 6 + 5, faces - before
  end

  # The second words of the faces of the blocks that the test put at CUBE_X, SKY_Y, CUBE_Z.
  def face_words(y = SKY_Y)
    @mesher.build(0, 0)
    words = []
    (0...@mesher.opaque.size).step(2) do |k|
      w0 = @mesher.opaque[k]
      next unless Mesher.face_x(w0) == CUBE_X && Mesher.face_y(w0) == y && Mesher.face_z(w0) == CUBE_Z

      words << @mesher.opaque[k + 1]
    end
    words
  end

  def test_fast_leaves_draw_the_solid_layer_of_their_leaves_and_keep_the_tint
    {Block::OAK_LEAVES => Tex::OAK_LEAVES_SOLID, Block::SPRUCE_LEAVES => Tex::SPRUCE_LEAVES_SOLID,
     Block::BIRCH_LEAVES => Tex::BIRCH_LEAVES_SOLID, Block::PLACED_OAK_LEAVES => Tex::OAK_LEAVES_SOLID}.each do |block, solid|
      setup
      @mesher.graphics = GraphicsMode::FAST
      @world.set(CUBE_X, SKY_Y, CUBE_Z, block)
      words = face_words
      assert_equal 6, words.size
      assert(words.all? { |w1| Mesher.field(w1, Mesher::TEX_AT, Mesher::TEX_BITS) == solid })
      assert(words.all? { |w1| Mesher.face_tint(w1) == Tex.tint(solid) })
    end
  end

  def test_fancy_leaves_draw_their_own_layer
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::OAK_LEAVES)
    assert(face_words.all? { |w1| Mesher.field(w1, Mesher::TEX_AT, Mesher::TEX_BITS) == Tex::OAK_LEAVES })
  end

  def test_fast_graphics_draw_other_blocks_with_their_own_layers
    @mesher.graphics = GraphicsMode::FAST
    @world.set(CUBE_X, SKY_Y, CUBE_Z, Block::STONE)
    assert(face_words.all? { |w1| Mesher.field(w1, Mesher::TEX_AT, Mesher::TEX_BITS) == Block::SIDE[Block::STONE] })
  end

  def test_other_blocks_make_the_same_faces_in_both_graphics
    fancy = faces_added_by(Block::STONE, 3)
    setup
    @mesher.graphics = GraphicsMode::FAST
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

  # The faces that a stone block adds at CUBE_X, SEABED_Y, CUBE_Z, with
  # blocks of water in a column of height cells that begins at dx and dy
  # from the stone.
  def faces_added_by_stone_beside_water(height, dx: 0, dy: 1)
    height.times { |up| @world.set(CUBE_X + dx, SEABED_Y + dy + up, CUBE_Z, Block::WATER) }
    before = faces
    @world.set(CUBE_X, SEABED_Y, CUBE_Z, Block::STONE)
    faces - before
  end

  # The water step that the second word of the faces of a stone block at
  # SEABED_Y has, with depth cells of water above it.
  def water_step_under(depth)
    depth.times { |up| @world.set(CUBE_X, SEABED_Y + 1 + up, CUBE_Z, Block::WATER) }
    @world.set(CUBE_X, SEABED_Y, CUBE_Z, Block::STONE)
    face_words(SEABED_Y).map { |w1| Mesher.field(w1, Mesher::WATER_STEP_AT, Mesher::WATER_STEP_BITS) }.max
  end

  def test_the_water_step_of_a_face_grows_by_one_for_every_two_blocks_of_water
    steps = (0..Mesher::DEEP_WATER).map do |depth|
      setup
      water_step_under(depth)
    end
    assert_equal [0, 0, 1, 1, 2, 2, 3], steps
  end

  def test_more_water_than_the_deep_water_adds_no_step
    assert_equal Mesher::WATER_STEP_MAX, water_step_under(Mesher::DEEP_WATER + 4)
  end

  def test_a_face_that_does_not_touch_water_has_step_0
    assert_equal 0, water_step_under(0)
  end

  def test_the_water_step_of_a_side_face_counts_the_water_beside_it
    Mesher::DEEP_WATER.times { |up| @world.set(CUBE_X + 1, SEABED_Y + up, CUBE_Z, Block::WATER) }
    @world.set(CUBE_X, SEABED_Y, CUBE_Z, Block::STONE)
    steps = face_words(SEABED_Y).map { |w1| Mesher.field(w1, Mesher::WATER_STEP_AT, Mesher::WATER_STEP_BITS) }
    assert_equal [0, 0, 0, 0, 0, Mesher::WATER_STEP_MAX], steps.sort
  end

  def test_the_shaders_know_the_layer_of_every_fluid_block
    water_layers = []
    lava_layers = []
    Block::COUNT.times do |block|
      layers = [Block::TOP[block], Block::SIDE[block], Block::BOTTOM[block]]
      water_layers.concat(layers) if Mesher.fluid(block) == 1
      lava_layers.concat(layers) if Mesher.fluid(block) == 2
    end
    assert_equal [Tex::WATER], water_layers.uniq
    assert_equal [Tex::LAVA], lava_layers.uniq
    assert_includes Mesher.shader_defines, "#define WATER_LAYER #{Tex::WATER}u"
    assert_includes Mesher.shader_defines, "#define LAVA_LAYER #{Tex::LAVA}u"
  end

  def test_fancy_graphics_keep_the_floor_under_deep_water
    assert_equal 6, faces_added_by_stone_beside_water(Mesher::DEEP_WATER)
  end

  def test_fast_graphics_hide_the_face_of_a_block_under_deep_water
    @mesher.graphics = GraphicsMode::FAST
    assert_equal 5, faces_added_by_stone_beside_water(Mesher::DEEP_WATER)
  end

  def test_fast_graphics_hide_the_face_toward_deep_water_at_the_side
    @mesher.graphics = GraphicsMode::FAST
    assert_equal 5, faces_added_by_stone_beside_water(Mesher::DEEP_WATER, dx: 1, dy: 0)
  end

  def test_fast_graphics_keep_the_floor_under_shallow_water
    @mesher.graphics = GraphicsMode::FAST
    assert_equal 6, faces_added_by_stone_beside_water(Mesher::DEEP_WATER - 1)
  end

  def test_fast_graphics_keep_the_floor_under_water_with_a_gap
    @mesher.graphics = GraphicsMode::FAST
    Mesher::DEEP_WATER.times { |up| @world.set(CUBE_X, SEABED_Y + 1 + up, CUBE_Z, Block::WATER) unless up == 3 }
    before = faces
    @world.set(CUBE_X, SEABED_Y, CUBE_Z, Block::STONE)
    assert_equal 6, faces - before
  end

  def test_fast_graphics_keep_the_faces_of_a_block_in_open_air
    @mesher.graphics = GraphicsMode::FAST
    assert_equal 6, faces_added_by_stone_beside_water(0)
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

