# The house that the demo reel builds (game/demo.rb): 7 by 7 blocks of
# logs and planks on a floor of cobblestone, with a roof of spruce planks
# that steps up to a ridge, a door to +z, and a bed, a lit furnace, a
# crafting table, a chest and torches.
class House
  SIZE = 7
  # The walls are this many blocks high.
  WALL = 3


  # The house on the flattest dry ground within range blocks of x = z = 0,
  # where the ground under the house and its eaves goes up and down the
  # least. It looks at each third block.
  def self.flattest(world, range)
    best = WY
    best_x = 0
    best_z = 0
    (-range..range).step(3) do |x|
      (-range..range).step(3) do |z|
        bumps = bumps(world, x, z)
        next if bumps >= best

        best = bumps
        best_x = x
        best_z = z
      end
    end
    House.new(world, best_x, best_z)
  end

  # How far the ground goes up and down under the house with its corner at
  # x, z and under its eaves, or WY when a cell is not dry land.
  def self.bumps(world, x, z)
    low = WY
    high = 0
    (x - 1..x + SIZE).each do |cell_x|
      (z - 1..z + SIZE).each do |cell_z|
        return WY unless world.dry_land?(cell_x, cell_z)

        ground = world.height_at(cell_x, cell_z)
        low = ground if ground < low
        high = ground if ground > high
      end
    end
    high - low
  end

  # The floor goes on the highest ground under the house.
  def initialize(world, x, z)
    @world = world
    @x = x
    @z = z
    @floor = 0
    each_cell do |cell_x, cell_z|
      ground = world.height_at(cell_x, cell_z)
      @floor = ground if ground > @floor
    end
  end

  # The corner with the least x and z, and the height of the floor. The
  # names are not x, z and floor: Spinel would then look for a House in
  # each call of x, z or floor on a value that it cannot type.
  def corner_x = @x
  def corner_z = @z
  def floor_y = @floor
  def middle_x = @x + SIZE * 0.5
  def middle_z = @z + SIZE * 0.5

  # The blocks of the house in the order they go up, 4 numbers each: x, y,
  # z and the block. Cobblestone fills the ground up to the floor.
  def blocks
    list = []
    each_cell { |x, z| (@world.height_at(x, z)..@floor).each { |y| list.push(x, y, z, Block::COBBLE) } }
    (1..WALL).each { |up| walls(list, up) }
    roof(list)
    inside(list)
    list
  end

  def each_cell
    (@x...@x + SIZE).each { |x| (@z...@z + SIZE).each { |z| yield x, z } }
  end

  # The layer of the walls up blocks above the floor.
  def walls(list, up)
    each_cell do |x, z|
      list.push(x, @floor + up, z, wall_block(x, z, up)) if edge?(x, @x) || edge?(z, @z)
    end
  end

  def edge?(cell, corner) = cell == corner || cell == corner + SIZE - 1

  # Logs at the corners, a door in the middle of the front, windows of
  # glass in the middle layer, and planks.
  def wall_block(x, z, up)
    return Block::OAK_LOG if edge?(x, @x) && edge?(z, @z)

    front = z == @z + SIZE - 1
    # The place along the wall, from its corner.
    along = edge?(z, @z) ? x - @x : z - @z
    return Block.door_id(2, up == 2, false) if front && along == 3 && up < WALL
    return Block::GLASS if up == 2 && (front ? along == 1 || along == 5 : along.between?(2, 4))

    Block::OAK_PLANKS
  end

  # Spruce planks step up from the eaves in front and at the back to the
  # ridge, and oak planks close the ends.
  def roof(list)
    y = @floor + WALL + 1
    5.times do |step|
      (@x - 1..@x + SIZE).each do |x|
        list.push(x, y + step, @z - 1 + step, Block::SPRUCE_PLANKS)
        list.push(x, y + step, @z + SIZE - step, Block::SPRUCE_PLANKS) if step < 4
      end
      (@z + step..@z + SIZE - 1 - step).each do |z|
        list.push(@x, y + step, z, Block::OAK_PLANKS, @x + SIZE - 1, y + step, z, Block::OAK_PLANKS)
      end
    end
  end

  # A bed, a lit furnace, a crafting table and a chest by the walls, a
  # torch on the back wall, and two torches on the front beside the door.
  def inside(list)
    y = @floor + 1
    list.push(@x + 1, y, @z + 1, Block.bed_id(1, false), @x + 2, y, @z + 1, Block.bed_id(0, true))
    list.push(@x + 4, y, @z + 1, Block.furnace_id(2, true), @x + 5, y, @z + 1, Block::CRAFTING_TABLE)
    list.push(@x + 5, y, @z + 3, Block.facing_id(Block::CHEST, 1))
    list.push(@x + 3, y + 2, @z + 1, Block.facing_id(Block::TORCH, 2))
    list.push(@x + 2, y + 1, @z + SIZE, Block.facing_id(Block::TORCH, 2), @x + 4, y + 1, @z + SIZE, Block.facing_id(Block::TORCH, 2))
  end
end
