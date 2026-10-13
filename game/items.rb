# Items on the ground: what breaks, dies or gets thrown drops here. Items
# fall, float in water, burn in lava, and go to the inventory when the player
# walks over them.
class Game
  # Seconds before the game removes an item that nobody picked up.
  ITEM_LIFE = 300.0
  MAX_ITEMS = 256
  # Seconds before an item can go to the inventory. A thrown item waits
  # longer, so the player does not pick it up again at once.
  PICKUP_WAIT = 0.4
  THROW_WAIT = 1.5
  # The player picks up items within this distance on x and z.
  PICKUP_REACH = 1.3

  def clear_items
    @it_block.clear
    @it_count.clear
    @it_x.clear
    @it_y.clear
    @it_z.clear
    @it_vx.clear
    @it_vy.clear
    @it_vz.clear
    @it_age.clear
    @it_wait.clear
  end

  # Drops n of b at x, y, z (the bottom of the item) with a velocity.
  def drop_item(b, n, x, y, z, vx, vy, vz, wait)
    return if b == Block::AIR || n <= 0
    remove_item(0) if @it_count.size >= MAX_ITEMS
    @it_block << b
    @it_count << n
    @it_x << x
    @it_y << y
    @it_z << z
    @it_vx << vx
    @it_vy << vy
    @it_vz << vz
    @it_age << 0.0
    @it_wait << wait
  end

  # Drops n of b from the block cell x, y, z with a small random push.
  def drop_from_block(b, n, x, y, z)
    drop_item(b, n, x + 0.5, y + 0.3, z + 0.5, (rand01 - 0.5) * 2.0, 3.0, (rand01 - 0.5) * 2.0, PICKUP_WAIT)
  end

  # Q in survival throws one of the selected stack where the player looks.
  def throw_selected
    b = @inv_block[@slot]
    return if @inv_count[@slot] <= 0
    # A tool goes with the uses that it has left.
    n = Block.tool?(b) ? @inv_count[@slot] : 1
    @inv_count[@slot] -= n
    @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
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
      if @inv_count[i] > 0
        drop_item(@inv_block[i], @inv_count[i], p.x, p.y + 0.5, p.z, (rand01 - 0.5) * 4.0, 3.0, (rand01 - 0.5) * 4.0, PICKUP_WAIT)
        @inv_block[i] = Block::AIR
        @inv_count[i] = 0
      end
      i += 1
    end
    drop_item(@held_block, @held_count, p.x, p.y + 0.5, p.z, 0.0, 3.0, 0.0, PICKUP_WAIT)
    @held_block = Block::AIR
    @held_count = 0
  end

  # The number of b on the ground.
  def ground_count(b)
    n = 0
    i = 0
    while i < @it_count.size
      n += @it_count[i] if @it_block[i] == b
      i += 1
    end
    n
  end

  def update_items(dt)
    i = 0
    while i < @it_count.size
      @it_age[i] += dt
      @it_wait[i] -= dt
      move_item(i, dt)
      pick_up(i) if @it_wait[i] <= 0.0 && !@dead && near_player?(i)
      i += 1
    end
    merge_items
    i = @it_count.size - 1
    while i >= 0
      remove_item(i) if @it_count[i] <= 0 || @it_age[i] > ITEM_LIFE
      i -= 1
    end
  end

  def move_item(i, dt)
    x = @it_x[i]
    y = @it_y[i]
    z = @it_z[i]
    at = @world.get(x.floor, y.floor, z.floor)
    if Block.lava?(at)
      burn_item(i)
      return
    end
    # A block placed on the item pushes it up.
    if Block.solid?(at)
      @it_y[i] = y.floor + 1.0
      @it_vy[i] = 0.0
      return
    end
    if Block.water?(at)
      @it_vy[i] += (1.2 - @it_vy[i]) * (3.0 * dt).clamp(0.0, 1.0)
    else
      @it_vy[i] -= 18.0 * dt
      @it_vy[i] = -30.0 if @it_vy[i] < -30.0
    end
    nx = x + @it_vx[i] * dt
    if Block.solid?(@world.get(nx.floor, y.floor, z.floor))
      @it_vx[i] = 0.0
    else
      x = nx
    end
    nz = z + @it_vz[i] * dt
    if Block.solid?(@world.get(x.floor, y.floor, nz.floor))
      @it_vz[i] = 0.0
    else
      z = nz
    end
    ny = y + @it_vy[i] * dt
    if Block.solid?(@world.get(x.floor, ny.floor, z.floor))
      y = ny.floor + 1.0 if @it_vy[i] < 0.0
      @it_vy[i] = 0.0
      # Ground friction.
      k = 1.0 - (8.0 * dt).clamp(0.0, 1.0)
      @it_vx[i] *= k
      @it_vz[i] *= k
    else
      y = ny
    end
    @it_x[i] = x
    @it_y[i] = y
    @it_z[i] = z
  end

  def near_player?(i)
    dx = @it_x[i] - @player.x
    dz = @it_z[i] - @player.z
    dy = @it_y[i] - @player.y
    dx * dx + dz * dz < PICKUP_REACH * PICKUP_REACH && dy > -0.8 && dy < Player::TALL + 0.5
  end

  # Moves as much of item i as fits into the inventory.
  def pick_up(i)
    b = @it_block[i]
    n = @it_count[i]
    if Block.tool?(b)
      return unless give_tool(b, n)
      @it_count[i] = 0
      play(Sfx::POP, 0.5)
      say("+1 #{Block::NAMES[b]}")
      return
    end
    room = room_for(b)
    n = room if room < n
    return if n <= 0
    n.times { give(b) }
    @it_count[i] -= n
    play(Sfx::POP, 0.5)
    say("+#{n} #{Block::NAMES[b]}#{Block.food(b) > 0 ? "  RIGHT CLICK TO EAT" : ""}") if Block.item?(b)
  end

  # Lava destroys an item with a puff of smoke.
  def burn_item(i)
    @it_count[i] = 0
    smoke_puff(@it_x[i], @it_y[i] + 0.3, @it_z[i], 4, 0.3)
    play(Sfx::FIZZ, near_volume(@it_x[i], @it_z[i], 0.6))
  end

  # Joins items of one kind that touch, up to a stack.
  def merge_items
    n = @it_count.size
    i = 0
    while i < n
      if @it_count[i] > 0 && @it_count[i] < STACK && !Block.tool?(@it_block[i])
        j = i + 1
        while j < n
          if @it_block[j] == @it_block[i] && @it_count[j] > 0 && @it_count[i] + @it_count[j] <= STACK
            dx = @it_x[j] - @it_x[i]
            dy = @it_y[j] - @it_y[i]
            dz = @it_z[j] - @it_z[i]
            if dx * dx + dy * dy + dz * dz < 0.5
              @it_count[i] += @it_count[j]
              @it_count[j] = 0
              @it_wait[i] = @it_wait[j] if @it_wait[j] > @it_wait[i]
            end
          end
          j += 1
        end
      end
      i += 1
    end
  end

  def remove_item(i)
    @it_block.delete_at(i)
    @it_count.delete_at(i)
    @it_x.delete_at(i)
    @it_y.delete_at(i)
    @it_z.delete_at(i)
    @it_vx.delete_at(i)
    @it_vy.delete_at(i)
    @it_vz.delete_at(i)
    @it_age.delete_at(i)
    @it_wait.delete_at(i)
  end

  # Items turn and bob above the ground. A stack of more than one shows a
  # second copy.
  def draw_items(ex, ez, reach)
    i = 0
    while i < @it_count.size
      x = @it_x[i]
      z = @it_z[i]
      dx = x - ex
      dz = z - ez
      if dx * dx + dz * dz < reach * reach
        b = @it_block[i]
        age = @it_age[i]
        size = flat_item?(b) ? 0.4 : 0.25
        y = @it_y[i] + size / 2.0 + 0.08 + Math.sin(age * 2.5 + i) * 0.06
        yaw = age * 1.6 + i
        c = Math.cos(yaw) * size
        s = Math.sin(yaw) * size
        @dyn.set_frame(x, y, z, c, 0.0, s, 0.0, size, 0.0, -s, 0.0, c)
        item_model(b)
        if @it_count[i] > 1 && !Block.tool?(b)
          @dyn.set_frame(x + 0.08, y + 0.06, z + 0.05, c, 0.0, s, 0.0, size, 0.0, -s, 0.0, c)
          item_model(b)
        end
      end
      i += 1
    end
  end

  # Items and plants are flat pictures; the other blocks are cubes.
  def flat_item?(b) = Block.item?(b) || Block.plant?(b)

  # Block or item b as a unit model around the origin of @dyn's frame.
  def item_model(b)
    if flat_item?(b)
      layer = Block::SIDE[b]
      @dyn.frame_box(-0.5, -0.5, 0.0, 0.5, 0.5, 0.0, 16, layer, layer, layer, 1.0, 1.0, 1.0, 1.0)
    else
      @dyn.frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 63, Block::TOP[b], Block::SIDE[b], Block::BOTTOM[b], 1.0, 1.0, 1.0, 1.0)
    end
  end
end
