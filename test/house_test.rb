require_relative "test_helper"

# House: the house of the demo reel goes on flat dry ground, and its floor
# rests on the highest ground under it.
class HouseTest < Minitest::Test
  # A flat stone pad high in the sky, from -7 to 13 along x and z, so that
  # the ground is the same in each run.
  GROUND = SKY_Y - 10

  def setup
    @world = World.new(1337)
    [-1, 0].each { |cx| [-1, 0].each { |cz| @world.load_chunk(cx, cz) } }
    (-7..13).each { |x| (-7..13).each { |z| @world.set(x, GROUND, z, Block::STONE) } }
  end

  def test_the_floor_rests_on_the_highest_ground_under_the_house
    assert_equal GROUND + 1, House.new(@world, 0, 0).floor_y
    @world.set(2, GROUND + 1, 3, Block::STONE)
    assert_equal GROUND + 2, House.new(@world, 0, 0).floor_y
    # Blocks under the eaves, out of the walls, do not lift the floor.
    @world.set(7, GROUND + 2, 0, Block::STONE)
    @world.set(0, GROUND + 2, 7, Block::STONE)
    assert_equal GROUND + 2, House.new(@world, 0, 0).floor_y
  end

  def test_the_middle_is_the_middle_of_the_floor
    house = House.new(@world, 2, -3)
    assert_equal [5.5, 0.5], [house.middle_x, house.middle_z]
  end

  # Cobblestone fills each column from the ground up to the floor, and
  # comes first, before the walls.
  def test_cobblestone_fills_the_ground_up_to_the_floor
    @world.set(6, GROUND + 1, 6, Block::STONE)
    blocks = House.new(@world, 0, 0).blocks
    assert_equal [GROUND + 1, GROUND + 2], cobble_under(blocks, 0, 0)
    assert_equal [GROUND + 2], cobble_under(blocks, 6, 6)
    assert_equal [], cobble_under(blocks, 7, 7)
    assert_equal Block::COBBLE, blocks[3]
    # The walls stand on the floor, so the floor stays whole.
    cells = cells_of(blocks)
    (0..6).each { |x| (0..6).each { |z| assert_equal Block::COBBLE, cells[[x, GROUND + 2, z]] } }
  end

  # The house and its eaves need flat ground, a block wider than the walls.
  def test_bumps_count_the_ground_under_the_eaves_too
    assert_equal 0, House.bumps(@world, 0, 0)
    @world.set(-1, GROUND + 1, 3, Block::STONE)
    assert_equal 1, House.bumps(@world, 0, 0)
    @world.set(7, GROUND + 1, 7, Block::STONE)
    @world.set(7, GROUND + 2, 7, Block::STONE)
    assert_equal 2, House.bumps(@world, 0, 0)
    assert_equal 0, House.bumps(@world, 1, -6)
  end

  def test_water_or_leaves_under_the_house_rule_the_place_out
    @world.set(3, GROUND + 1, 3, Block::WATER)
    assert_equal WY, House.bumps(@world, 0, 0)
    @world.set(3, GROUND + 1, 3, Block::OAK_LEAVES)
    assert_equal WY, House.bumps(@world, 0, 0)
  end

  # Steps all over the pad, but for one flat place: the house goes there.
  def test_the_house_goes_on_the_flattest_place
    (-7..13).each { |x| (-7..13).each { |z| @world.set(x, GROUND + 1, z, Block::STONE) if (x + z).even? } }
    (2..10).each { |x| (2..10).each { |z| @world.set(x, GROUND + 1, z, Block::AIR) } }
    house = House.flattest(@world, 6)
    assert_equal [3, 3], [house.corner_x, house.corner_z]
  end

  # The walls close the house on its four sides, up to the roof, but for a
  # door in the middle of the front (+z). Nothing stands in the middle
  # layer inside.
  def test_the_walls_close_the_house_but_for_the_door
    house = House.new(@world, 2, -3)
    cells = cells_of(house.blocks)
    floor = house.floor_y
    doors = []
    (1..House::WALL).each do |up|
      (0..6).each do |along|
        [[along, 0], [along, 6], [0, along], [6, along]].each do |x, z|
          block = cells[[2 + x, floor + up, z - 3]]
          assert block && block != Block::AIR, "no wall at #{x}, #{up}, #{z}"
          doors << [x, up, z] if Block.door?(block)
        end
      end
    end
    assert_equal [[3, 1, 6], [3, 2, 6]], doors
    # A closed door that faces the front: its lower half, then its upper half.
    assert_equal [Block.door_id(2, false, false), Block.door_id(2, true, false)], [cells[[5, floor + 1, 3]], cells[[5, floor + 2, 3]]]
    (3..7).each { |x| (-2..2).each { |z| assert_nil cells[[x, floor + 2, z]] } }
  end

  # Each side has a window in the middle layer, and no window is at a
  # corner or in another layer.
  def test_each_side_has_windows_in_the_middle_layer
    house = House.new(@world, 2, -3)
    windows = cells_of(house.blocks).select { |_cell, block| block == Block::GLASS }.keys
    assert_equal [house.floor_y + 2], windows.map { |_x, y, _z| y }.uniq
    assert(windows.none? { |x, _y, z| [2, 8].include?(x) && [-3, 3].include?(z) })
    assert(windows.any? { |_x, _y, z| z == -3 })
    assert(windows.any? { |_x, _y, z| z == 3 })
    assert(windows.any? { |x, _y, _z| x == 2 })
    assert(windows.any? { |x, _y, _z| x == 8 })
  end

  # The roof covers the house and its eaves, one block wider on each side,
  # and the ends under the roof have no gap.
  def test_the_roof_covers_the_house_and_closes_its_ends
    house = House.new(@world, 0, 0)
    cells = cells_of(house.blocks)
    top = house.floor_y + House::WALL
    (-1..7).each do |x|
      (-1..7).each do |z|
        assert(cells.keys.any? { |cell_x, y, cell_z| cell_x == x && cell_z == z && y > top }, "no roof over #{x}, #{z}")
      end
    end
    [0, 6].each do |x|
      (0..6).each do |z|
        roof = top_at(cells, x, z)
        (house.floor_y + 1..roof).each { |y| assert cells[[x, y, z]], "a gap at #{x}, #{y}, #{z}" }
      end
    end
    # The roof has the same height along the whole house, also over the ends.
    (-1..7).each { |z| assert_equal [top_at(cells, 3, z)], (-1..7).map { |x| top_at(cells, x, z) }.uniq }
    assert(cells.keys.all? { |x, _y, z| x.between?(-1, 7) && z.between?(-1, 7) })
  end

  # Each torch hangs on a block of the house behind it.
  def test_each_torch_hangs_on_a_block_of_the_house
    cells = cells_of(House.new(@world, 0, 0).blocks)
    torches = cells.select { |_cell, block| Block.wall_torch?(block) }
    assert_equal 3, torches.size
    torches.each do |(x, y, z), block|
      facing = Block::FACING[block]
      support = cells[[x - Block::DIR_DX[facing], y, z - Block::DIR_DZ[facing]]]
      assert support && Block::SOLID[support], "the torch at #{x}, #{y}, #{z} hangs on nothing"
    end
  end

  # Each block of the house by its cell. A later block in the list takes the
  # place of an earlier one.
  def cells_of(blocks)
    blocks.each_slice(4).to_h { |x, y, z, block| [[x, y, z], block] }
  end

  # The height of the highest block of the house at x, z.
  def top_at(cells, x, z) = cells.keys.select { |cell_x, _y, cell_z| cell_x == x && cell_z == z }.map { |_x, y, _z| y }.max

  def cobble_under(blocks, x, z)
    blocks.each_slice(4).select { |cell_x, _y, cell_z, block| cell_x == x && cell_z == z && block == Block::COBBLE }.map { |cell| cell[1] }
  end
end
