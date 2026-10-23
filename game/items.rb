# Items on the ground (game/item.rb): what breaks, dies or gets thrown
# drops here. Items burn in lava, a cactus destroys them, and they go to
# the inventory when the player walks over them.
class Game
  MAX_ITEMS = 256
  # Seconds before an item can go to the inventory. A thrown item waits
  # longer, so the player does not pick it up again at once.
  PICKUP_WAIT = 0.4
  THROW_WAIT = 1.5

  # Drops n of block at x, y, z (the bottom of the item) with a velocity.
  def drop_item(block, n, x, y, z, vx, vy, vz, wait)
    return if block == Block::AIR || n <= 0

    @items.shift if @items.size >= MAX_ITEMS
    @items << Item.new(block, n, x, y, z, vx, vy, vz, wait, 0.0)
  end

  # Drops n of block from the block cell x, y, z with a small random push.
  def drop_from_block(block, n, x, y, z)
    drop_item(block, n, x + 0.5, y + 0.3, z + 0.5, (@rng.rand01 - 0.5) * 2.0, 3.0, (@rng.rand01 - 0.5) * 2.0, PICKUP_WAIT)
  end

  # Q in survival throws one of the selected stack where the player looks.
  def throw_selected
    block = @inv.block(@slot)
    return if @inv.empty?(@slot)

    # A tool goes with the uses that it has left.
    n = Block.tool?(block) ? @inv.count(@slot) : 1
    @inv.take(@slot, n)
    throw_stack(block, n)
  end

  def throw_stack(block, n)
    p = @player
    drop_item(block, n, p.x + p.fx * 0.3, p.eye_y - 0.3, p.z + p.fz * 0.3, p.fx * 6.0 + p.vx, p.fy * 6.0 + 2.0, p.fz * 6.0 + p.vz, THROW_WAIT)
    @swing = SWING
  end

  # At death the player drops each stack of the inventory, and the stack in
  # the mouse, where they died.
  def drop_inventory
    p = @player
    INV.times do |i|
      unless @inv.empty?(i)
        drop_item(@inv.block(i), @inv.count(i), p.x, p.y + 0.5, p.z, (@rng.rand01 - 0.5) * 4.0, 3.0, (@rng.rand01 - 0.5) * 4.0, PICKUP_WAIT)
        @inv.set(i, Block::AIR, 0)
      end
    end
    drop_item(@held.block(0), @held.count(0), p.x, p.y + 0.5, p.z, 0.0, 3.0, 0.0, PICKUP_WAIT)
    @held.clear
  end

  # The number of block on the ground.
  def ground_count(block) = @items.sum { |item| item.block == block ? item.count : 0 }

  def update_items(dt)
    @items.each do |item|
      # An item in a chunk that is not loaded waits there: it would fall
      # through the missing blocks.
      next unless @world.loaded?(item.x.floor, item.z.floor)

      if !item.update(@world, dt)
        burn_item(item)
      elsif @world.cactus_in_box?(item.x, item.y, item.z, Item::HALF, Item::TALL)
        # A cactus destroys an item that touches it. minecraft.wiki/w/Cactus
        item.count = 0
      elsif item.ready? && !@vitals.dead? && item.near?(@player)
        pick_up(item)
      end
    end
    merge_items
    @items.reject!(&:gone?)
  end

  # Moves as much of the item as fits into the inventory.
  def pick_up(item)
    block = item.block
    n = item.count
    if Block.tool?(block)
      return unless @inv.put(block, n)

      item.count = 0
      play(Sfx::POP, 0.5)
      say("+1 #{Block::NAMES[block]}")
      return
    end
    room = @inv.room_for(block)
    n = room if room < n
    return if n <= 0

    n.times { @inv.add(block) }
    item.count -= n
    play(Sfx::POP, 0.5)
    say("+#{n} #{Block::NAMES[block]}") if Block.item?(block)
  end

  # Lava destroys an item with a puff of smoke.
  def burn_item(item)
    item.count = 0
    @particles.smoke(item.x, item.y + 0.3, item.z, 4, 0.3)
    play_at(Sfx::FIZZ, item.x, item.y, item.z, 0.6)
  end

  # Joins items of one kind that touch, up to a stack.
  def merge_items
    @items.each_with_index do |a, i|
      next if a.count <= 0 || Block.tool?(a.block)

      ((i + 1)...@items.size).each do |j|
        b = @items[j]
        a.absorb(b) if b.block == a.block && b.count > 0 && a.count + b.count <= Block.stack(a.block) && a.touches?(b)
      end
    end
  end
end
