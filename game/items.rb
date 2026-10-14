# Items on the ground (game/item.rb): what breaks, dies or gets thrown
# drops here. Items burn in lava, and go to the inventory when the player
# walks over them.
class Game
  MAX_ITEMS = 256
  # Seconds before an item can go to the inventory. A thrown item waits
  # longer, so the player does not pick it up again at once.
  PICKUP_WAIT = 0.4
  THROW_WAIT = 1.5

  # Drops n of b at x, y, z (the bottom of the item) with a velocity.
  def drop_item(b, n, x, y, z, vx, vy, vz, wait)
    return if b == Block::AIR || n <= 0
    @items.shift if @items.size >= MAX_ITEMS
    @items << Item.new(b, n, x, y, z, vx, vy, vz, wait, 0.0)
  end

  # Drops n of b from the block cell x, y, z with a small random push.
  def drop_from_block(b, n, x, y, z)
    drop_item(b, n, x + 0.5, y + 0.3, z + 0.5, (rand01 - 0.5) * 2.0, 3.0, (rand01 - 0.5) * 2.0, PICKUP_WAIT)
  end

  # Q in survival throws one of the selected stack where the player looks.
  def throw_selected
    b = @inv.block(@slot)
    return if @inv.empty?(@slot)
    # A tool goes with the uses that it has left.
    n = Block.tool?(b) ? @inv.count(@slot) : 1
    @inv.take(@slot, n)
    throw_stack(b, n)
  end

  def throw_stack(b, n)
    p = @player
    drop_item(b, n, p.x + p.fx * 0.3, p.eye_y - 0.3, p.z + p.fz * 0.3, p.fx * 6.0 + p.vx, p.fy * 6.0 + 2.0, p.fz * 6.0 + p.vz, THROW_WAIT)
    @swing = 0.25
  end

  # At death the player drops each stack of the inventory, and the stack in
  # the mouse, where they died.
  def drop_inventory
    p = @player
    i = 0
    while i < INV
      unless @inv.empty?(i)
        drop_item(@inv.block(i), @inv.count(i), p.x, p.y + 0.5, p.z, (rand01 - 0.5) * 4.0, 3.0, (rand01 - 0.5) * 4.0, PICKUP_WAIT)
        @inv.set(i, Block::AIR, 0)
      end
      i += 1
    end
    drop_item(@held_block, @held_count, p.x, p.y + 0.5, p.z, 0.0, 3.0, 0.0, PICKUP_WAIT)
    @held_block = Block::AIR
    @held_count = 0
  end

  # The number of b on the ground.
  def ground_count(b) = @items.sum { |item| item.block == b ? item.count : 0 }

  def update_items(dt)
    @items.each do |item|
      # An item in a chunk that is not loaded waits there: it would fall
      # through the missing blocks.
      next unless @world.loaded?(item.x.floor, item.z.floor)
      if item.update(@world, dt)
        pick_up(item) if item.ready? && !@vitals.dead? && item.near?(@player)
      else
        burn_item(item)
      end
    end
    merge_items
    @items.reject!(&:gone?)
  end

  # Moves as much of the item as fits into the inventory.
  def pick_up(item)
    b = item.block
    n = item.count
    if Block.tool?(b)
      return unless @inv.put(b, n)
      item.count = 0
      play(Sfx::POP, 0.5)
      say("+1 #{Block::NAMES[b]}")
      return
    end
    room = @inv.room_for(b)
    n = room if room < n
    return if n <= 0
    n.times { @inv.add(b) }
    item.count -= n
    play(Sfx::POP, 0.5)
    say("+#{n} #{Block::NAMES[b]}#{Block.food(b) > 0 ? "  RIGHT CLICK TO EAT" : ""}") if Block.item?(b)
  end

  # Lava destroys an item with a puff of smoke.
  def burn_item(item)
    item.count = 0
    @particles.smoke(item.x, item.y + 0.3, item.z, 4, 0.3)
    play(Sfx::FIZZ, near_volume(item.x, item.z, 0.6))
  end

  # Joins items of one kind that touch, up to a stack.
  def merge_items
    @items.each_with_index do |a, i|
      next if a.count <= 0 || Block.tool?(a.block)
      ((i + 1)...@items.size).each do |j|
        b = @items[j]
        a.absorb(b) if b.block == a.block && b.count > 0 && a.count + b.count <= Slots::STACK && a.touches?(b)
      end
    end
  end
end
