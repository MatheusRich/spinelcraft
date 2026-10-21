# A row of item slots: the inventory or a chest. Each slot holds a stack of
# one block or item kind, or nothing (the count 0). A tool never stacks,
# and its count is the uses that it has left.
class Slots
  STACK = 64

  def initialize(size)
    @size = size
    @blocks = Array.new(size, 0)
    @counts = Array.new(size, 0)
  end

  def block(i) = @blocks[i]
  def count(i) = @counts[i]
  def empty?(i) = @counts[i] == 0

  def set(i, block, n)
    @blocks[i] = n > 0 ? block : Block::AIR
    @counts[i] = n
  end

  # Takes n from the stack in slot i.
  def take(i, n)
    set(i, @blocks[i], @counts[i] - n)
  end

  def clear
    @blocks.fill(0)
    @counts.fill(0)
  end

  def copy
    c = Slots.new(@size)
    (0...@size).each { |i| c.set(i, @blocks[i], @counts[i]) }
    c
  end

  # The blocks of all slots, then the counts: the form in the save.
  def to_a = @blocks + @counts

  # Reads the slots from fields at index at, in the form of to_a.
  def load(fields, at)
    (0...@size).each { |i| set(i, fields[at + i].to_i, fields[at + @size + i].to_i) }
  end

  # How many of block still fit. Each empty slot fits one tool.
  def room_for(block)
    tool = Block.tool?(block)
    room = 0
    (0...@size).each do |i|
      if @counts[i] == 0
        room += tool ? 1 : Block.stack(block)
      elsif @blocks[i] == block && !tool
        room += Block.stack(block) - @counts[i]
      end
    end
    room
  end

  # Puts a stack of n of block into the first empty slot; false when none is
  # empty. For a tool, n is the uses that it has left.
  def put(block, n)
    i = @counts.index(0)
    return false if i.nil?

    set(i.to_i, block, n)
    true
  end

  # Adds one block (a new tool, if block is a tool); false when it does not fit.
  def add(block)
    return true if block == Block::AIR
    return put(block, Block.uses(block)) if Block.tool?(block)

    (0...@size).each do |i|
      if @blocks[i] == block && @counts[i] > 0 && @counts[i] < Block.stack(block)
        @counts[i] += 1
        return true
      end
    end
    put(block, 1)
  end

  # The number of block in all slots.
  def total(block)
    n = 0
    (0...@size).each { |i| n += @counts[i] if @blocks[i] == block }
    n
  end

  # Takes n of block, from the last slots first.
  def remove(block, n)
    i = @size - 1
    while i >= 0 && n > 0
      if @blocks[i] == block && @counts[i] > 0
        taken = @counts[i] < n ? @counts[i] : n
        take(i, taken)
        n -= taken
      end
      i -= 1
    end
  end

  # A click on slot index with the stack in slot 0 of hand: the hand picks
  # up the stack, puts its stack down, merges its stack into the stack of
  # the same kind, or swaps the two stacks.
  def click(index, hand)
    kind = @blocks[index]
    count = @counts[index]
    held_kind = hand.block(0)
    held_count = hand.count(0)
    if held_count == 0
      return if count == 0

      hand.set(0, kind, count)
      set(index, kind, 0)
    elsif count == 0
      set(index, held_kind, held_count)
      hand.set(0, held_kind, 0)
    elsif kind == held_kind && !Block.tool?(kind)
      hand.set(0, held_kind, add_stack(held_kind, held_count, index..index))
    else
      set(index, held_kind, held_count)
      hand.set(0, kind, count)
    end
    nil
  end

  # A right-click on slot index with the stack in slot 0 of hand. An empty
  # hand takes half the stack, and a tool goes whole. A hand with a stack
  # puts one item into an empty slot or onto the same kind, and it swaps
  # otherwise.
  def click_half(index, hand)
    kind = @blocks[index]
    count = @counts[index]
    held_kind = hand.block(0)
    if hand.empty?(0)
      return if count == 0

      taken = Block.tool?(kind) ? count : (count + 1) / 2
      hand.set(0, kind, taken)
      take(index, taken)
    elsif Block.tool?(held_kind) || (count > 0 && kind != held_kind)
      click(index, hand)
    elsif count < Block.stack(held_kind)
      set(index, held_kind, count + 1)
      hand.take(0, 1)
    end
    nil
  end

  # Moves the stack in slot into the slots of range in to. What does not
  # fit stays in slot.
  def move_stack(slot, to, range)
    rest = to.add_stack(@blocks[slot], @counts[slot], range)
    set(slot, @blocks[slot], rest)
    nil
  end

  # Adds count of block to the slots of range: onto the stacks of its kind
  # first, so that it splits into as few stacks as it can, then the rest
  # into the first empty slot. Gives the count that does not fit.
  def add_stack(block, count, range)
    rest = stack_onto_existing(block, count, range)
    move_to_empty(block, rest, range)
  end

  # Adds what fits of count of block onto the stacks of its kind in range,
  # and gives the rest. A tool never stacks.
  def stack_onto_existing(block, count, range)
    return count if Block.tool?(block)

    range.each do |index|
      next if @blocks[index] != block

      moved = [Block.stack(block) - @counts[index], count].min
      next if moved <= 0

      @counts[index] += moved
      count -= moved
    end
    count
  end

  # Puts count of block into the first empty slot of range, and gives what
  # does not fit: 0, or all of it when no slot is empty.
  def move_to_empty(block, count, range)
    range.each do |index|
      next unless empty?(index)

      set(index, block, count)
      return 0
    end
    count
  end
end
