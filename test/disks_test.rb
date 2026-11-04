require_relative "test_helper"

class DisksTest < Minitest::Test
  CELLS = 160
  SIDE = CELLS << Disks::SHIFT

  # The floor of the columns from x = z = 0 to SIDE, with air for ground.
  def self.floor
    @floor ||= Array.new(SIDE * SIDE) { |k| Disks.floor(k % SIDE, k / SIDE, Block::AIR) }
  end

  # The centers of the disks of radius 2 that touch no other disk: patches
  # of 13 columns in a box of 5 x 5.
  def self.small_disk_centers
    floor = DisksTest.floor
    seen = Array.new(SIDE * SIDE, false)
    (0...SIDE * SIDE).filter_map do |start|
      next if seen[start] || floor[start] == Block::AIR

      seen[start] = true
      patch = [start]
      patch.each do |k|
        [k - 1, k + 1, k - SIDE, k + SIDE].each do |other|
          next if other.negative? || other >= SIDE * SIDE || seen[other] || floor[other] == Block::AIR
          next if (other % SIDE - k % SIDE).abs > 1

          seen[other] = true
          patch << other
        end
      end
      xs = patch.map { |k| k % SIDE }
      zs = patch.map { |k| k / SIDE }
      next unless patch.size == 13 && xs.max - xs.min == 4 && zs.max - zs.min == 4

      [(xs.min + 2) & Disks::MASK, (zs.min + 2) & Disks::MASK]
    end
  end

  # A pick that is even gives sand, and an odd pick gives gravel.
  def test_sand_disks_reach_2_to_6_blocks_and_gravel_disks_2_to_5
    radii = (0...256).group_by { |pick| Disks.block(0, pick, 0) }.transform_values { |picks| picks.map { |pick| Disks.radius(pick) }.uniq.sort }
    assert_equal({ Block::SAND => [2, 3, 4, 5, 6], Block::GRAVEL => [2, 3, 4, 5] }, radii)
  end

  def test_a_disk_covers_the_columns_within_its_radius
    sand = 2 * 3
    radius = Disks.radius(sand)
    assert_equal Block::SAND, Disks.block(Disks::CHANCE - 1, sand, radius**2)
    assert_equal Block::AIR, Disks.block(Disks::CHANCE - 1, sand, radius**2 + 1)
    assert_equal Block::AIR, Disks.block(Disks::CHANCE, sand, 0)
  end

  # The share of the columns that disks cover is alike at each place in a
  # cell, because a disk reaches from its center into the cells next to it.
  def test_disks_cover_each_place_in_a_cell_alike
    covered = Hash.new(0)
    DisksTest.floor.each_with_index do |block, k|
      covered[[k % SIDE & Disks::MASK, k / SIDE & Disks::MASK]] += 1 if block != Block::AIR
    end
    shares = covered.values.map { |count| count.to_f / (CELLS * CELLS) }
    assert_operator shares.max - shares.min, :<, 0.08
    assert_equal [Block::AIR, Block::SAND, Block::GRAVEL].sort, DisksTest.floor.uniq.sort
  end

  def test_a_disk_center_can_take_each_place_in_its_cell
    assert_equal 64, DisksTest.small_disk_centers.uniq.size
  end
end
