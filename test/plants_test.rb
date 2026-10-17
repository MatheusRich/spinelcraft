require_relative "test_helper"

class PlantsTest < Minitest::Test
  # The height over the stone floor in the open air over the one loaded
  # chunk, with room for a tree, and the cell in its middle.
  Y = SKY_Y - 20
  X = 8
  Z = 8

  def setup
    @world = world_with_one_chunk
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::STONE) } }
    @plants = Plants.new(@world, 7)
    @changes = []
  end

  # Puts the changes in the world, as Game#apply_changes does, and gives
  # them as [x, y, z, block] lists.
  def apply
    blocks = @changes.each_slice(4).to_a
    blocks.each { |x, y, z, b| @world.set(x, y, z, b) }
    @changes.clear
    blocks
  end

  # The changes of count random ticks of growth around the middle of the
  # chunk, put in the world after each tick.
  def grow_ticks(count)
    grown = []
    count.times do
      @plants.grow_column(X, Z, @changes)
      grown.concat(apply)
    end
    grown
  end

  def test_the_random_ticks_of_a_frame_keep_the_part_of_a_tick_as_a_chance
    assert_includes [1100, 1101], @plants.random_ticks(1.0, 1100.0)
    ticks = Array.new(2000) { @plants.random_ticks(0.0005, 1100.0) }
    assert_equal [0, 1], ticks.uniq.sort
    assert_in_delta 0.55, ticks.sum / 2000.0, 0.05
  end

  def test_a_cactus_grows_up_to_three_blocks
    @world.set(X, Y - 1, Z, Block::SAND)
    @world.set(X, Y, Z, Block::CACTUS)
    @plants.grow_cactus(X, Y, Z, @changes)
    assert_equal [[X, Y + 1, Z, Block::CACTUS]], apply
    @plants.grow_cactus(X, Y + 1, Z, @changes)
    assert_equal [[X, Y + 2, Z, Block::CACTUS]], apply
    @plants.grow_cactus(X, Y + 2, Z, @changes)
    assert_empty apply
  end

  def test_a_cactus_does_not_grow_into_a_block_or_out_of_the_world
    @world.set(X, Y, Z, Block::CACTUS)
    @world.set(X, Y + 1, Z, Block::STONE)
    @plants.grow_cactus(X, Y, Z, @changes)
    assert_empty apply
    @world.set(X, WY - 1, Z, Block::CACTUS)
    @plants.grow_cactus(X, WY - 1, Z, @changes)
    assert_empty apply
  end

  def test_a_ripe_stem_grows_one_pumpkin_next_to_it_over_soil
    4.times { |d| @world.set(X + Block::DIR_DX[d], Y - 1, Z + Block::DIR_DZ[d], Block::DIRT) }
    @world.set(X, Y, Z, Block::PUMPKIN_STEM_RIPE)
    40.times do
      @plants.grow_pumpkin(X, Y, Z, @changes)
      apply
    end
    sides = (0...4).select { |d| @world.get(X + Block::DIR_DX[d], Y, Z + Block::DIR_DZ[d]) == Block::PUMPKIN }
    assert_equal 1, sides.size
  end

  def test_a_ripe_stem_grows_no_pumpkin_over_stone_or_into_a_block
    @world.set(X, Y, Z, Block::PUMPKIN_STEM_RIPE)
    @world.set(X + 1, Y - 1, Z, Block::DIRT)
    @world.set(X + 1, Y, Z, Block::STONE)
    40.times { @plants.grow_pumpkin(X, Y, Z, @changes) }
    assert_empty apply
  end

  def test_bone_meal_grows_a_crop_by_one_or_two_stages
    stages = Array.new(40) do
      @world.set(X, Y, Z, Block::SEEDS)
      assert @plants.fertilize(X, Y, Z, @changes)
      x, y, z, b = apply.first
      assert_equal [X, Y, Z], [x, y, z]
      b - Block::SEEDS
    end
    assert_equal [1, 2], stages.uniq.sort
  end

  def test_bone_meal_grows_a_pumpkin_stem_by_one_stage
    @world.set(X, Y, Z, Block::PUMPKIN_STEM)
    assert @plants.fertilize(X, Y, Z, @changes)
    assert_equal [[X, Y, Z, Block::PUMPKIN_STEM_RIPE]], apply
  end

  def test_bone_meal_on_ripe_wheat_or_stone_is_not_spent
    [Block::WHEAT_RIPE, Block::PUMPKIN_STEM_RIPE, Block::STONE].each do |b|
      @world.set(X, Y, Z, b)
      refute @plants.fertilize(X, Y, Z, @changes)
      assert_empty apply
    end
  end

  def test_bone_meal_on_a_sapling_is_spent_and_grows_a_tree_now_and_then
    trees = Array.new(40) do
      @world.set(X, Y - 1, Z, Block::DIRT)
      @world.set(X, Y, Z, Block::OAK_SAPLING)
      assert @plants.fertilize(X, Y, Z, @changes)
      grown = apply.include?([X, Y, Z, Block::OAK_LOG])
      (Y..Y + 12).each { |y| (X - 3..X + 3).each { |x| (Z - 3..Z + 3).each { |z| @world.set(x, y, z, Block::AIR) } } }
      grown
    end
    assert_includes 10..30, trees.count(true)
  end

  def test_bone_meal_on_grass_grows_plants_on_the_grass_around_it
    (X - 6..X + 6).each { |x| (Z - 6..Z + 6).each { |z| @world.set(x, Y - 1, z, Block::GRASS) } }
    @world.set(X + 2, Y - 1, Z, Block::DIRT)
    assert @plants.fertilize(X, Y - 1, Z, @changes)
    grown = apply
    cells = grown.map { |x, y, z, _| [x, y, z] }
    assert_operator grown.size, :>=, 10
    assert_equal cells.uniq, cells
    grown.each do |x, y, z, b|
      assert_includes [Block::TALL_GRASS, Block::ROSE, Block::DANDELION], b
      assert_equal Y, y
      assert_operator (x - X).abs, :<=, 7
      assert_operator (z - Z).abs, :<=, 7
    end
    refute_includes cells, [X + 2, Y, Z]
    assert_operator grown.count { |*, b| b == Block::TALL_GRASS }, :>, grown.size / 2
  end

  def test_bone_meal_on_grass_under_a_block_is_not_spent
    @world.set(X, Y - 1, Z, Block::GRASS)
    @world.set(X, Y, Z, Block::STONE)
    refute @plants.fertilize(X, Y - 1, Z, @changes)
  end

  def test_bone_meal_adds_two_to_five_of_the_eight_ages
    assert_equal([1, 1, 2, 2], [2, 3, 4, 5].map { |ages| Plants.meal_stage(0, ages, 3) })
    assert_equal 3, Plants.meal_stage(2, 5, 3)
    assert_equal([1, 1, 1, 1], [2, 3, 4, 5].map { |ages| Plants.meal_stage(0, ages, 2) })
  end

  def test_leaves_stay_up_to_six_steps_from_a_log_through_leaves
    @world.set(2, Y, Z, Block::OAK_LOG)
    (3..9).each { |x| @world.set(x, Y, Z, Block::OAK_LEAVES) }
    assert((3..8).all? { |x| @plants.held_by_log?(x, Y, Z) })
    refute @plants.held_by_log?(9, Y, Z)
    @world.set(12, Y, Z, Block::OAK_LEAVES)
    refute @plants.held_by_log?(12, Y, Z)
  end

  def test_leaves_with_no_log_near_decay_and_placed_leaves_stay
    @world.set(2, Y, 2, Block::OAK_LOG)
    @world.set(3, Y, 2, Block::OAK_LEAVES)
    @world.set(X, Y, Z, Block::OAK_LEAVES)
    @world.set(12, Y, 12, Block::PLACED_OAK_LEAVES)
    # Under a block that is not leaves, a log or air, the decay stops.
    @world.set(4, Y, 12, Block::OAK_LEAVES)
    @world.set(4, Y + 1, 12, Block::STONE)
    # Through the air under leaves, it goes on down.
    @world.set(12, Y, 4, Block::OAK_LEAVES)
    @world.set(12, Y + 2, 4, Block::OAK_LEAVES)
    decayed = []
    20_000.times do
      @plants.decay_column(X, Z, @changes)
      decayed.concat(@changes.each_slice(4).to_a)
      @changes.clear
    end
    cells = decayed.uniq
    assert_includes cells, [X, Y, Z, Block::AIR]
    assert_includes cells, [12, Y, 4, Block::AIR]
    assert_includes cells, [12, Y + 2, 4, Block::AIR]
    refute_includes cells, [3, Y, 2, Block::AIR]
    refute_includes cells, [12, Y, 12, Block::AIR]
    refute_includes cells, [4, Y, 12, Block::AIR]
    assert(cells.all? { |x, _, z, _| x.between?(0, 15) && z.between?(0, 15) })
  end

  def test_saplings_grow_into_trees_on_random_ticks
    saplings = [2, 8, 13].product([2, 8, 13])
    saplings.each do |x, z|
      @world.set(x, Y - 1, z, Block::DIRT)
      @world.set(x, Y, z, Block::OAK_SAPLING)
    end
    grow_ticks(60_000)
    assert(saplings.any? { |x, z| @world.get(x, Y, z) == Block::OAK_LOG })
  end

  # A random tick comes to each of the 81 x 81 columns of the reach, and a
  # crop on one grows with GROW_CHANCE. So 20 000 ticks grow the 256 crops
  # of the chunk about 20 000 * 256 / 6561 * 0.1 = 78 times.
  def test_a_crop_grows_a_stage_on_about_one_in_ten_random_ticks
    16.times { |x| 16.times { |z| @world.set(x, Y, z, Block::SEEDS) } }
    grown = grow_ticks(20_000)
    assert(grown.all? { |_, y, _, b| y == Y && b > Block::SEEDS && b <= Block::WHEAT_RIPE })
    assert_includes 55..100, grown.size
  end

  def test_ripe_stems_grow_pumpkins_on_random_ticks
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::DIRT) } }
    stems = []
    (1..15).step(3) { |x| (1..15).step(3) { |z| stems << [x, z] } }
    stems.each { |x, z| @world.set(x, Y, z, Block::PUMPKIN_STEM_RIPE) }
    grown = grow_ticks(20_000)
    refute_empty grown
    grown.each do |x, y, z, b|
      assert_equal [Y, Block::PUMPKIN], [y, b]
      assert(stems.any? { |sx, sz| (sx - x).abs + (sz - z).abs == 1 })
    end
  end

  def test_a_cactus_grows_on_a_random_tick
    (0..15).step(3) { |x| (0..15).step(3) { |z| @world.set(x, Y, z, Block::CACTUS) } }
    grown = grow_ticks(100_000)
    refute_empty grown
    assert(grown.all? { |_, y, _, b| y == Y + 1 && b == Block::CACTUS })
  end

  def test_a_log_holds_leaves_from_each_side_and_through_each_axis
    @world.set(10, Y, 2, Block::OAK_LOG)
    (4..9).each { |x| @world.set(x, Y, 2, Block::OAK_LEAVES) }
    assert @plants.held_by_log?(4, Y, 2)
    @world.set(2, Y, 12, Block::OAK_LOG)
    (6..11).each { |z| @world.set(2, Y, z, Block::OAK_LEAVES) }
    assert @plants.held_by_log?(2, Y, 6)
    @world.set(12, Y + 6, 12, Block::OAK_LOG)
    (Y..Y + 5).each { |y| @world.set(12, y, 12, Block::OAK_LEAVES) }
    assert @plants.held_by_log?(12, Y, 12)
  end

  def test_a_log_does_not_hold_leaves_through_air
    @world.set(2, Y, 2, Block::OAK_LOG)
    @world.set(4, Y, 2, Block::OAK_LEAVES)
    refute @plants.held_by_log?(4, Y, 2)
  end

  def test_leaves_decay_down_a_column_through_logs_and_stacked_leaves
    @world.set(4, Y + 3, 4, Block::OAK_LOG)
    @world.set(4, Y, 4, Block::OAK_LEAVES)
    @world.set(12, Y, 8, Block::OAK_LEAVES)
    @world.set(12, Y + 1, 8, Block::OAK_LEAVES)
    decayed = []
    20_000.times do
      @plants.decay_column(X, Z, @changes)
      decayed.concat(@changes.each_slice(4).to_a)
      @changes.clear
    end
    assert_includes decayed, [4, Y, 4, Block::AIR]
    assert_includes decayed, [12, Y, 8, Block::AIR]
    assert_includes decayed, [12, Y + 1, 8, Block::AIR]
  end

  # From x = -32, the reach of 40 columns ends at x = 8.
  def test_a_random_tick_reaches_forty_columns_and_no_more
    16.times { |x| 16.times { |z| @world.set(x, Y, z, Block::SEEDS) } }
    grown = []
    20_000.times do
      @plants.grow_column(-32, Z, @changes)
      grown.concat(apply)
    end
    assert(grown.any? { |x, *| x == 8 })
    assert(grown.none? { |x, *| x > 8 })
  end

  def test_a_cactus_just_under_the_top_of_the_world_grows
    @world.set(X, WY - 2, Z, Block::CACTUS)
    @plants.grow_cactus(X, WY - 2, Z, @changes)
    assert_equal [[X, WY - 1, Z, Block::CACTUS]], apply
  end

  def test_a_pumpkin_on_any_side_stops_the_stem
    4.times { |d| @world.set(X + Block::DIR_DX[d], Y - 1, Z + Block::DIR_DZ[d], Block::DIRT) }
    @world.set(X, Y, Z, Block::PUMPKIN_STEM_RIPE)
    4.times do |side|
      @world.set(X + Block::DIR_DX[side], Y, Z + Block::DIR_DZ[side], Block::PUMPKIN)
      40.times { @plants.grow_pumpkin(X, Y, Z, @changes) }
      assert_empty apply, "side #{side}"
      @world.set(X + Block::DIR_DX[side], Y, Z + Block::DIR_DZ[side], Block::AIR)
    end
  end

  def test_a_stem_grows_its_pumpkins_on_each_side_in_turn
    4.times { |d| @world.set(X + Block::DIR_DX[d], Y - 1, Z + Block::DIR_DZ[d], Block::DIRT) }
    @world.set(X, Y, Z, Block::PUMPKIN_STEM_RIPE)
    sides = Array.new(40) do
      @plants.grow_pumpkin(X, Y, Z, @changes)
      x, _, z, = apply.first
      @world.set(x, Y, z, Block::AIR)
      [x - X, z - Z]
    end
    assert_equal [[-1, 0], [0, -1], [0, 1], [1, 0]], sides.uniq.sort
  end

  # 25 stems with their pumpkins taken away after each tick grow about
  # 20 000 * 25 / 6561 * 0.1 = 7.6 pumpkins.
  def test_a_ripe_stem_grows_a_pumpkin_on_about_one_in_ten_random_ticks
    16.times { |x| 16.times { |z| @world.set(x, Y - 1, z, Block::DIRT) } }
    (1..15).step(3) { |x| (1..15).step(3) { |z| @world.set(x, Y, z, Block::PUMPKIN_STEM_RIPE) } }
    pumpkins = 0
    20_000.times do
      @plants.grow_column(X, Z, @changes)
      apply.each do |x, y, z, _|
        pumpkins += 1
        @world.set(x, y, z, Block::AIR)
      end
    end
    assert_includes 2..16, pumpkins
  end

  def test_bone_meal_grows_pumpkin_seeds_into_a_stem
    @world.set(X, Y, Z, Block::PUMPKIN_SEEDS)
    assert @plants.fertilize(X, Y, Z, @changes)
    assert_equal [[X, Y, Z, Block::PUMPKIN_STEM]], apply
  end

  def test_bone_meal_grows_a_sapling_into_a_tree_about_nine_times_in_twenty
    @world.set(X, Y - 1, Z, Block::DIRT)
    trees = 0
    200.times do
      @world.set(X, Y, Z, Block::OAK_SAPLING)
      @plants.fertilize(X, Y, Z, @changes)
      trees += 1 if @changes.each_slice(4).include?([X, Y, Z, Block::OAK_LOG])
      @changes.clear
    end
    assert_includes 75..105, trees
  end

  # A field of grass with the cell X, Y, Z above its middle.
  def grass_field(reach = 7)
    (X - reach..X + reach).each { |x| (Z - reach..Z + reach).each { |z| @world.set(x, Y - 1, z, Block::GRASS) } }
  end

  def test_bone_meal_on_grass_grows_plants_on_each_side
    grass_field
    @plants.fertilize(X, Y - 1, Z, @changes)
    grown = apply
    assert(grown.any? { |x, *| x < X })
    assert(grown.any? { |x, *| x > X })
    assert(grown.any? { |_, _, z, _| z < Z })
    assert(grown.any? { |_, _, z, _| z > Z })
  end

  def test_the_plants_of_bone_meal_do_not_walk_through_a_wall
    grass_field
    (X - 2..X + 2).each do |x|
      (Z - 2..Z + 2).each { |z| @world.set(x, Y, z, Block::STONE) if (x - X).abs == 2 || (z - Z).abs == 2 }
    end
    @plants.fertilize(X, Y - 1, Z, @changes)
    grown = apply
    refute_empty grown
    assert(grown.all? { |x, _, z, _| (x - X).abs <= 1 && (z - Z).abs <= 1 })
  end

  def test_the_plants_of_bone_meal_do_not_replace_a_plant
    grass_field
    (X - 1..X + 1).each { |x| (Z - 1..Z + 1).each { |z| @world.set(x, Y, z, Block::ROSE) unless x == X && z == Z } }
    @plants.fertilize(X, Y - 1, Z, @changes)
    grown = apply
    refute_empty grown
    assert(grown.none? { |x, _, z, _| (x - X).abs <= 1 && (z - Z).abs <= 1 && !(x == X && z == Z) })
  end

  def test_the_plants_of_bone_meal_climb_onto_grass_a_block_higher
    grass_field
    (X + 2..X + 7).each { |x| (Z - 7..Z + 7).each { |z| @world.set(x, Y, z, Block::GRASS) } }
    grown = []
    20.times do
      grown.each { |x, y, z, _| @world.set(x, y, z, Block::AIR) }
      @plants.fertilize(X, Y - 1, Z, @changes)
      grown.concat(apply)
    end
    assert(grown.any? { |_, y, *| y == Y + 1 })
    assert(grown.any? { |_, y, *| y == Y })
  end

  # A plant is a flower 1 time in 8, and a flower is a poppy 2 times in 3.
  def test_the_plants_of_bone_meal_are_flowers_now_and_then_and_mostly_poppies
    grass_field
    grown = []
    30.times do
      (X - 7..X + 7).each { |x| (Z - 7..Z + 7).each { |z| @world.set(x, Y, z, Block::AIR) } }
      @plants.fertilize(X, Y - 1, Z, @changes)
      grown.concat(apply)
    end
    flowers = grown.count { |*, b| b != Block::TALL_GRASS }
    poppies = grown.count { |*, b| b == Block::ROSE }
    assert_in_delta 0.125, flowers.to_f / grown.size, 0.04
    assert_in_delta 2.0 / 3.0, poppies.to_f / flowers, 0.12
  end

  def test_the_plants_of_bone_meal_step_down_onto_grass_a_block_lower
    grass_field
    (X - 7..X - 2).each { |x| (Z - 7..Z + 7).each { |z| @world.set(x, Y - 1, z, Block::AIR) } }
    (X - 7..X - 2).each { |x| (Z - 7..Z + 7).each { |z| @world.set(x, Y - 2, z, Block::GRASS) } }
    grown = []
    20.times do
      grown.each { |x, y, z, _| @world.set(x, y, z, Block::AIR) }
      @plants.fertilize(X, Y - 1, Z, @changes)
      grown.concat(apply)
    end
    assert(grown.any? { |_, y, *| y == Y - 1 })
  end

  # A try walks up to 7 steps, so the plants reach 7 blocks out.
  def test_the_plants_of_bone_meal_reach_far_from_the_grass_block
    grass_field
    grown = []
    20.times do
      grown.each { |x, y, z, _| @world.set(x, y, z, Block::AIR) }
      @plants.fertilize(X, Y - 1, Z, @changes)
      grown.concat(apply)
    end
    assert_operator grown.map { |x, _, z, _| [(x - X).abs, (z - Z).abs].max }.max, :>=, 5
  end
end
