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

  def set(i, b, n)
    @blocks[i] = n > 0 ? b : Block::AIR
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

  # How many of b still fit. Each empty slot fits one tool.
  def room_for(b)
    tool = Block.tool?(b)
    room = 0
    (0...@size).each do |i|
      if @counts[i] == 0
        room += tool ? 1 : Block.stack(b)
      elsif @blocks[i] == b && !tool
        room += Block.stack(b) - @counts[i]
      end
    end
    room
  end

  # Puts a stack of n of b into the first empty slot; false when none is
  # empty. For a tool, n is the uses that it has left.
  def put(b, n)
    i = @counts.index(0)
    return false if i.nil?
    set(i.to_i, b, n)
    true
  end

  # Adds one b (a new tool, if b is a tool); false when it does not fit.
  def add(b)
    return true if b == Block::AIR
    return put(b, Block.uses(b)) if Block.tool?(b)
    (0...@size).each do |i|
      if @blocks[i] == b && @counts[i] > 0 && @counts[i] < Block.stack(b)
        @counts[i] += 1
        return true
      end
    end
    put(b, 1)
  end

  # The number of b in all slots.
  def total(b)
    n = 0
    (0...@size).each { |i| n += @counts[i] if @blocks[i] == b }
    n
  end

  # Takes n of b, from the last slots first.
  def remove(b, n)
    i = @size - 1
    while i >= 0 && n > 0
      if @blocks[i] == b && @counts[i] > 0
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
      moved = [Block.stack(kind) - count, held_count].min
      set(index, kind, count + moved)
      hand.take(0, moved)
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

  # Moves the stack in slot i into the slots lo...hi of to: onto stacks of
  # the same kind first, then into empty slots. What does not fit stays in
  # slot i.
  def move_stack(i, to, lo, hi)
    b = @blocks[i]
    # A tool never stacks, so it only goes into an empty slot.
    unless Block.tool?(b)
      k = lo
      while k < hi && @counts[i] > 0
        n = to.count(k)
        if to.block(k) == b && n > 0 && n < Block.stack(b)
          moved = [Block.stack(b) - n, @counts[i]].min
          to.set(k, b, n + moved)
          take(i, moved)
        end
        k += 1
      end
    end
    k = lo
    while k < hi && @counts[i] > 0
      if to.empty?(k)
        to.set(k, b, @counts[i])
        set(i, b, 0)
      end
      k += 1
    end
    nil
  end
end
