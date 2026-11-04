# Disks of sand and gravel on a floor under water (minecraft.wiki/w/Disk).
# Each cell of 8 x 8 blocks (SHIFT) holds a disk with the chance CHANCE in
# 65536; the wiki gives no count.
class Disks
  SHIFT = 3
  MASK = (1 << SHIFT) - 1
  CHANCE = 40_960
  SALT = 5
  # Radii from minecraft.wiki/w/Disk: sand 2 to 6, gravel 2 to 5.
  SMALLEST = 2
  SAND_RADII = 5
  GRAVEL_RADII = 4

  # The block of a disk that covers column x, z, or ground. A disk reaches
  # the cells next to its own.
  def self.floor(x, z, ground)
    cell_x = x >> SHIFT
    cell_z = z >> SHIFT
    (cell_x - 1..cell_x + 1).each do |disk_x|
      (cell_z - 1..cell_z + 1).each do |disk_z|
        disk = Noise.hash3(disk_x, 0, disk_z, SALT)
        across = x - (disk_x << SHIFT) - (disk & MASK)
        along = z - (disk_z << SHIFT) - ((disk >> SHIFT) & MASK)
        block = block(disk, Noise.hash3(disk_x, 1, disk_z, SALT), across**2 + along**2)
        return block if block != Block::AIR
      end
    end
    ground
  end

  # The block of a disk at the square of the distance from its center, or
  # air. The hash disk gives the place and the chance, the hash pick the
  # block and the radius.
  def self.block(disk, pick, distance)
    return Block::AIR if disk >= CHANCE || distance > radius(pick)**2
    return Block::SAND if pick.even?

    Block::GRAVEL
  end

  def self.radius(pick)
    size = pick >> 1
    return SMALLEST + size % SAND_RADII if pick.even?

    SMALLEST + size % GRAVEL_RADII
  end
end
