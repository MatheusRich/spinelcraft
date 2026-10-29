# The armor that the player wears: one piece in each of the four slots, for
# the head, the chest, the legs and the feet. Worn armor lowers the damage
# of most hits, and each of those hits wears it down.
# minecraft.wiki/w/Armor
class Armor
  # Each armor point takes 4% of a hit: 1 of these 25 parts. The 20 points of
  # a full diamond set take 80%, the most that armor takes.
  # minecraft.wiki/w/Armor (Damage protection)
  POINT_SHARE = 25.0
  # A hard hit takes points away from the cut, but never below this share of
  # the points. The cut is the points minus HARD_HIT_FACTOR times the damage,
  # divided by the toughness plus TOUGHNESS_BASE. The wiki gives the formula
  # min(20, max(points / 5, points - 4 * damage / (toughness + 8))) / 25.
  # minecraft.wiki/w/Armor (Damage protection)
  MIN_CUT_SHARE = 1.0 / 5.0
  HARD_HIT_FACTOR = 4.0
  TOUGHNESS_BASE = 8.0
  # Each worn piece loses 1 use for each this much damage of the hit, and at
  # least 1. minecraft.wiki/w/Armor (Durability)
  DAMAGE_PER_USE = 4.0

  # The slots, as a Slots. A piece in a slot is a stack of one, and its count
  # is the uses that it has left.
  attr_reader :slots

  def initialize
    @slots = Slots.new(Block::ARMOR_SLOTS)
  end

  def points = worn_total(Block::ARMOR_POINTS)
  def toughness = worn_total(Block::ARMOR_TOUGHNESS)

  # The part of a hit of amount that gets through the worn armor.
  def reduce(amount)
    armor = points.to_f
    cut = armor - HARD_HIT_FACTOR * amount / (toughness + TOUGHNESS_BASE)
    cut = [cut, armor * MIN_CUT_SHARE].max
    amount * (1.0 - cut / POINT_SHARE)
  end

  # Wears each worn piece for a hit of amount, before the armor lowers it.
  # Gives the pieces that broke.
  def wear(amount)
    uses = [(amount / DAMAGE_PER_USE).floor, 1].max
    broken = []
    worn_slots.each do |slot|
      piece = @slots.block(slot)
      @slots.take(slot, [uses, @slots.count(slot)].min)
      broken << piece if @slots.empty?(slot)
    end
    broken
  end

  # Puts the piece of block with uses on, in its slot. Gives the slot.
  def put_on(block, uses)
    slot = Block.armor_slot(block)
    @slots.set(slot, block, uses)
    slot
  end

  # Swaps the piece in slot index of from with the piece worn in its slot.
  def swap_with(from, index)
    piece = from.block(index)
    slot = Block.armor_slot(piece)
    uses = from.count(index)
    from.set(index, @slots.block(slot), @slots.count(slot))
    @slots.set(slot, piece, uses)
  end

  # A click on slot with the stack in slot 0 of hand. Only the piece for
  # that slot goes in. True when the click puts a piece on.
  def click(slot, hand)
    piece = hand.block(0)
    putting_on = !hand.empty?(0)
    return false if putting_on && (!Block.armor?(piece) || Block.armor_slot(piece) != slot)

    @slots.click(slot, hand)
    putting_on
  end

  # Moves the piece in slot index of from to its armor slot, when that slot
  # is empty. True when it moves.
  def quick_put_on(from, index)
    piece = from.block(index)
    return false unless Block.armor?(piece) && @slots.empty?(Block.armor_slot(piece))

    slot = Block.armor_slot(piece)
    from.move_stack(index, @slots, slot..slot)
    true
  end

  private

  # The sum of the entries of table (one for each piece, from
  # Block::IRON_HELMET) for the worn pieces.
  def worn_total(table)
    worn_slots.sum { |slot| table[@slots.block(slot) - Block::IRON_HELMET] }
  end

  # The slots that hold a piece.
  def worn_slots = (0...Block::ARMOR_SLOTS).reject { |slot| @slots.empty?(slot) }
end
