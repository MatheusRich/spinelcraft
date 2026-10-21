# The contents of each chest in the world, by World.key, and the chest
# that is open on the screen (see Chest). A large chest is two chests side
# by side, and each half keeps its own contents.
class Chests
  # The chest that is open, or nil.
  attr_reader :current

  def initialize
    @by_key = {}
    @current = nil
    nil
  end

  def open? = !@current.nil?

  # The number of chests.
  def size = @by_key.size

  # Closes the open chest and forgets every chest.
  def clear
    close
    @by_key = {}
    nil
  end

  # Opens the chest at x, y, z of world in the place of the open chest.
  # When it is a half of a large chest, both halves open, the left half on
  # top.
  def open_at(world, x, y, z)
    if Block.chest_right?(world.get(x, y, z))
      dir = Block.chest_partner_dir(world.get(x, y, z))
      x += Block::DIR_DX[dir]
      z += Block::DIR_DZ[dir]
    end
    top_key = World.key(x, y, z)
    top = @by_key[top_key] ||= Slots.new(Chest::SLOTS)
    bottom_key = -1
    bottom = top
    block = world.get(x, y, z)
    if Block.chest_left?(block)
      dir = Block.chest_partner_dir(block)
      bottom_key = World.key(x + Block::DIR_DX[dir], y, z + Block::DIR_DZ[dir])
      bottom = @by_key[bottom_key] ||= Slots.new(Chest::SLOTS)
    end
    @current = Chest.new(top_key, top, bottom_key, bottom)
    nil
  end

  def close
    @current = nil
    nil
  end

  # Forgets the chest with the key, and gives its contents, or nil.
  def remove_at(key) = @by_key.delete(key)

  # The save fields: the number of chests, then the key and the slots of
  # each one.
  def to_a
    fields = [@by_key.size]
    @by_key.each do |key, chest|
      fields << key
      fields.concat(chest.to_a)
    end
    fields
  end

  # Reads the chests of to_a from fields at at, in the place of the
  # chests that it has, and closes the open chest. Gives the index after
  # them.
  def load(fields, at)
    close
    @by_key = {}
    count = fields[at].to_i
    at += 1
    count.times do
      chest = Slots.new(Chest::SLOTS)
      chest.load(fields, at + 1)
      @by_key[fields[at].to_i] = chest
      at += 1 + Chest::SLOTS * 2
    end
    at
  end
end
