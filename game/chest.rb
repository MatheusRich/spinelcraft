# A chest as the player sees it: one chest of 27 cells, or a large chest
# of 54 cells with its left half on top and its right half below, as in
# Minecraft. Its slots are those that Chests keeps for each half.
class Chest
  # The slots of a chest of one block.
  SLOTS = 27

  # A chest of one block has the bottom key -1, and its top slots also
  # stand for its bottom slots, which it never shows.
  def initialize(top_key, top, bottom_key, bottom)
    @top_key = top_key
    @top = top
    @bottom_key = bottom_key
    @bottom = bottom
    nil
  end

  def large? = @bottom_key >= 0

  # The cells: 27, or 54 for a large chest.
  def cells
    return SLOTS * 2 if large?
    SLOTS
  end

  # The slots that hold a cell. The cell is slot cell % SLOTS of them.
  def slots_for(cell)
    return @top if cell < SLOTS
    @bottom
  end

  # Moves the stack in a slot of from into the chest. The two halves of a
  # large chest are one row of 54 slots, as in Minecraft: the stack goes
  # onto the stacks of its kind in both halves first, then into the first
  # empty slot, top half first. What does not fit stays in from.
  def store(from, slot)
    block = from.block(slot)
    rest = @top.stack_onto_existing(block, from.count(slot), 0...SLOTS)
    rest = @bottom.stack_onto_existing(block, rest, 0...SLOTS) if large?
    rest = @top.move_to_empty(block, rest, 0...SLOTS)
    rest = @bottom.move_to_empty(block, rest, 0...SLOTS) if large?
    from.set(slot, block, rest)
    nil
  end

  # True when the key (see World.key) is that of the chest, or of a half
  # of it.
  def shows?(key) = key == @top_key || key == @bottom_key
end
