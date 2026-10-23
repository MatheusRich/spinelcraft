require_relative "test_helper"

# The contents of the chests in the world, and the chest that is open.
class ChestsTest < Minitest::Test
  Y = SKY_Y - 20

  def setup
    @world = world_with_one_chunk
    @chests = Chests.new
  end

  # Puts a large chest that faces facing (0 to 3) with its left half at
  # x, Y, z, and gives the x and z of its right half.
  def large_chest(x, z, facing = 0)
    left = Block::CHEST_LEFT + facing
    dir = Block.chest_partner_dir(left)
    rx = x + Block::DIR_DX[dir]
    rz = z + Block::DIR_DZ[dir]
    @world.set(x, Y, z, left)
    @world.set(rx, Y, rz, Block::CHEST_RIGHT + facing)
    [rx, rz]
  end

  def test_a_chest_of_one_block_opens_with_27_cells_and_keeps_what_it_gets
    @world.set(8, Y, 8, Block::CHEST)
    refute @chests.open?
    @chests.open_at(@world, 8, Y, 8)
    assert @chests.open?
    refute @chests.current.large?
    assert_equal Chest::SLOTS, @chests.current.cells
    hand = Slots.new(1)
    hand.set(0, Block::DIRT, 10)
    @chests.current.store(hand, 0)
    assert hand.empty?(0)
    @chests.close
    refute @chests.open?
    @chests.open_at(@world, 8, Y, 8)
    assert_equal [Block::DIRT, 10], [@chests.current.slots_for(0).block(0), @chests.current.slots_for(0).count(0)]
    assert_equal 1, @chests.size
  end

  def test_a_large_chest_opens_from_either_half_with_the_left_half_on_top
    rx, rz = large_chest(8, 8)
    @chests.open_at(@world, 8, Y, 8)
    @chests.current.slots_for(Chest::SLOTS - 1).set(0, Block::DIRT, 1)
    @chests.current.slots_for(Chest::SLOTS).set(0, Block::SAND, 1)
    @chests.close
    @chests.open_at(@world, rx, Y, rz)
    assert @chests.current.large?
    assert_equal Chest::SLOTS * 2, @chests.current.cells
    assert_equal [Block::DIRT, Block::SAND], [@chests.current.slots_for(0).block(0), @chests.current.slots_for(Chest::SLOTS * 2 - 1).block(0)]
    assert_equal 2, @chests.size
    assert_equal Block::DIRT, @chests.remove_at(World.key(8, Y, 8)).block(0)
    assert_equal Block::SAND, @chests.remove_at(World.key(rx, Y, rz)).block(0)
  end

  def test_the_right_half_opens_the_left_half_on_top_in_each_facing
    4.times do |facing|
      chests = Chests.new
      x = 3 + facing * 3
      rx, rz = large_chest(x, 8, facing)
      chests.open_at(@world, rx, Y, rz)
      assert chests.current.large?
      chests.current.slots_for(0).set(0, Block::DIRT, 1)
      chests.current.slots_for(Chest::SLOTS).set(0, Block::SAND, 1)
      assert_equal Block::DIRT, chests.remove_at(World.key(x, Y, 8)).block(0), "facing #{facing}"
      assert_equal Block::SAND, chests.remove_at(World.key(rx, Y, rz)).block(0), "facing #{facing}"
    end
  end

  def test_a_chest_of_one_block_after_a_large_chest_has_27_cells
    large_chest(8, 8)
    @world.set(2, Y, 2, Block::CHEST)
    @chests.open_at(@world, 8, Y, 8)
    @chests.open_at(@world, 2, Y, 2)
    refute @chests.current.large?
    assert_equal Chest::SLOTS, @chests.current.cells
    refute @chests.current.shows?(World.key(8, Y, 8))
  end

  def test_close_leaves_no_current_chest_and_keeps_the_contents
    @world.set(8, Y, 8, Block::CHEST)
    @chests.open_at(@world, 8, Y, 8)
    @chests.current.slots_for(0).set(0, Block::DIRT, 10)
    @chests.close
    refute @chests.open?
    assert_nil @chests.current
    @chests.open_at(@world, 8, Y, 8)
    assert_equal 10, @chests.current.slots_for(0).count(0)
  end

  def test_a_large_chest_stores_into_its_top_half_first
    rx, rz = large_chest(8, 8)
    @chests.open_at(@world, 8, Y, 8)
    hand = Slots.new(1)
    hand.set(0, Block::DIRT, 10)
    @chests.current.store(hand, 0)
    assert_equal 10, @chests.current.slots_for(0).count(0)
    top = @chests.current.slots_for(0)
    Chest::SLOTS.times { |slot| top.set(slot, Block::STONE, 64) }
    hand.set(0, Block::DIRT, 10)
    @chests.current.store(hand, 0)
    assert hand.empty?(0)
    bottom = @chests.remove_at(World.key(rx, Y, rz))
    assert_equal [Block::DIRT, 10], [bottom.block(0), bottom.count(0)]
  end

  def test_a_large_chest_adds_onto_a_stack_in_its_bottom_half_before_an_empty_top_slot
    large_chest(8, 8)
    @chests.open_at(@world, 8, Y, 8)
    chest = @chests.current
    chest.slots_for(Chest::SLOTS).set(0, Block::DIRT, 60)
    hand = Slots.new(1)
    hand.set(0, Block::DIRT, 10)
    chest.store(hand, 0)
    assert_equal [6, 64], [chest.slots_for(0).count(0), chest.slots_for(Chest::SLOTS).count(0)]
    assert hand.empty?(0)
  end

  def test_a_large_chest_adds_onto_the_stacks_of_its_top_half_first
    large_chest(8, 8)
    @chests.open_at(@world, 8, Y, 8)
    chest = @chests.current
    chest.slots_for(0).set(0, Block::DIRT, 60)
    chest.slots_for(Chest::SLOTS).set(0, Block::DIRT, 60)
    hand = Slots.new(1)
    hand.set(0, Block::DIRT, 10)
    chest.store(hand, 0)
    top = chest.slots_for(0)
    assert_equal [64, 64, 2], [top.count(0), chest.slots_for(Chest::SLOTS).count(0), top.count(1)]
  end

  def test_a_full_chest_of_one_block_leaves_the_stack_in_the_hand
    @world.set(8, Y, 8, Block::CHEST)
    @chests.open_at(@world, 8, Y, 8)
    Chest::SLOTS.times { |slot| @chests.current.slots_for(0).set(slot, Block::STONE, 64) }
    hand = Slots.new(1)
    hand.set(0, Block::DIRT, 10)
    @chests.current.store(hand, 0)
    assert_equal 10, hand.count(0)
    assert_equal 1, @chests.size
  end

  def test_the_open_chest_shows_both_of_its_halves_and_no_other_chest
    rx, rz = large_chest(8, 8)
    @chests.open_at(@world, 8, Y, 8)
    assert @chests.current.shows?(World.key(8, Y, 8))
    assert @chests.current.shows?(World.key(rx, Y, rz))
    refute @chests.current.shows?(World.key(2, Y, 2))
  end

  def test_remove_at_gives_the_contents_and_forgets_the_chest
    @world.set(8, Y, 8, Block::CHEST)
    @chests.open_at(@world, 8, Y, 8)
    @chests.current.slots_for(0).set(3, Block::DIAMOND, 7)
    key = World.key(8, Y, 8)
    removed = @chests.remove_at(key)
    assert_equal [Block::DIAMOND, 7], [removed.block(3), removed.count(3)]
    assert_nil @chests.remove_at(key)
    assert_equal 0, @chests.size
  end

  def test_the_save_fields_load_back_in_the_place_of_the_old_chests
    rx, rz = large_chest(8, 8)
    @chests.open_at(@world, rx, Y, rz)
    @chests.current.slots_for(0).set(1, Block::DIRT, 5)
    @chests.current.slots_for(Chest::SLOTS).set(2, Block::DIAMOND, 3)
    @chests.current.slots_for(Chest::SLOTS).set(4, Block::SAND, 9)
    fields = ["header"] + @chests.to_a.map(&:to_s) + ["after"]
    loaded = Chests.new
    @world.set(2, Y, 2, Block::CHEST)
    loaded.open_at(@world, 2, Y, 2)
    after = loaded.load(fields, 1)
    assert_equal "after", fields[after]
    refute loaded.open?
    assert_equal 2, loaded.size
    assert_nil loaded.remove_at(World.key(2, Y, 2))
    left = loaded.remove_at(World.key(8, Y, 8))
    right = loaded.remove_at(World.key(rx, Y, rz))
    assert_equal [Block::DIRT, 5], [left.block(1), left.count(1)]
    assert_equal [Block::DIAMOND, 3, Block::SAND, 9], [right.block(2), right.count(2), right.block(4), right.count(4)]
  end

  def test_clear_forgets_every_chest
    @world.set(8, Y, 8, Block::CHEST)
    @chests.open_at(@world, 8, Y, 8)
    @chests.clear
    refute @chests.open?
    assert_equal 0, @chests.size
    assert_nil @chests.remove_at(World.key(8, Y, 8))
  end

  def test_keep_gives_a_chest_its_contents_in_the_place_of_the_old_ones
    @world.set(8, Y, 8, Block::CHEST)
    @chests.open_at(@world, 8, Y, 8)
    @chests.close
    slots = Slots.new(Chest::SLOTS)
    slots.set(3, Block::BONE, 2)
    @chests.keep(World.key(8, Y, 8), slots)
    @chests.open_at(@world, 8, Y, 8)
    assert_same slots, @chests.current.slots_for(0)
    assert_equal 1, @chests.size
  end
end
