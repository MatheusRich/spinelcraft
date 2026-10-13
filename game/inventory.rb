# Items: the hotbar, the backpack, chests, crafting, and the inventory screen.
class Game
  RECIPE_W = 300.0

  def current_block
    @survival ? @inv_block[@slot] : @hotbar[@slot]
  end

  # How many of b still fit in the inventory.
  def room_for(b)
    room = 0
    i = 0
    while i < INV
      room += STACK - @inv_count[i] if @inv_block[i] == b || @inv_count[i] == 0
      i += 1
    end
    room
  end

  # Adds one b; false when it does not fit.
  def give(b)
    return true if b == Block::AIR
    i = 0
    while i < INV
      if @inv_block[i] == b && @inv_count[i] < STACK
        @inv_count[i] += 1
        return true
      end
      i += 1
    end
    i = 0
    while i < INV
      if @inv_count[i] == 0
        @inv_block[i] = b
        @inv_count[i] = 1
        return true
      end
      i += 1
    end
    false
  end

  # True when every stack of a chest's contents would fit in the inventory.
  def chest_fits?(stored)
    blocks = @inv_block.dup
    counts = @inv_count.dup
    k = 0
    while k < CHEST_SLOTS
      b = stored[k]
      n = stored[CHEST_SLOTS + k]
      i = 0
      while n > 0 && i < INV
        if counts[i] == 0 || blocks[i] == b
          take = STACK - counts[i] < n ? STACK - counts[i] : n
          blocks[i] = b
          counts[i] += take
          n -= take
        end
        i += 1
      end
      return false if n > 0
      k += 1
    end
    true
  end

  def count_items(b)
    n = 0
    i = 0
    while i < INV
      n += @inv_count[i] if @inv_block[i] == b
      i += 1
    end
    n
  end

  def remove_items(b, n)
    i = INV - 1
    while i >= 0 && n > 0
      if @inv_block[i] == b && @inv_count[i] > 0
        take = @inv_count[i] < n ? @inv_count[i] : n
        @inv_count[i] -= take
        n -= take
        @inv_block[i] = Block::AIR if @inv_count[i] == 0
      end
      i -= 1
    end
  end

  # Crafts recipe k from items anywhere in the inventory.
  def craft_recipe(k)
    r = RECIPES[k]
    if count_items(r[0]) < r[1]
      say("NEED #{r[1]} #{Block::NAMES[r[0]]}")
      return
    end
    # Take the ingredients first: a slot that they empty is room for the result.
    blocks = @inv_block.dup
    counts = @inv_count.dup
    remove_items(r[0], r[1])
    if room_for(r[2]) < r[3]
      @inv_block = blocks
      @inv_count = counts
      say("INVENTORY FULL")
      return
    end
    r[3].times { give(r[2]) }
    say("CRAFTED #{r[3]} #{Block::NAMES[r[2]]}")
    play(Sfx::PLACE, 0.6)
  end

  # The C key: crafts the first recipe that the selected stack can make.
  def craft
    b = @inv_block[@slot]
    k = 0
    while k < RECIPES.size
      if RECIPES[k][0] == b && @inv_count[@slot] >= RECIPES[k][1]
        craft_recipe(k)
        return
      end
      k += 1
    end
    say("NOTHING TO CRAFT FROM #{Block::NAMES[b]}") if b != Block::AIR
  end

  # Pixel rectangle of inventory cell i: x, y, size.
  def inventory_cell(i, w, h, s)
    size = 56.0 * s
    gap = 8.0 * s
    cols = INV_COLS
    rows = (PLACEABLE.size + cols - 1) / cols
    x0 = (w - (cols * size + (cols - 1) * gap)) / 2.0
    y0 = (h - (rows * size + (rows - 1) * gap)) / 2.0
    [x0 + (i % cols) * (size + gap), y0 + (i / cols) * (size + gap), size]
  end

  def inventory_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    i = 0
    while i < PLACEABLE.size
      c = inventory_cell(i, w, h, s)
      return i if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[2]
      i += 1
    end
    -1
  end


  # Survival inventory cell i: backpack rows on top, the hotbar row below.
  def pack_cell(i, w, h, s)
    size = 52.0 * s
    gap = 6.0 * s
    row = i < HOTBAR ? 3 : (i - HOTBAR) / HOTBAR
    col = i < HOTBAR ? i : (i - HOTBAR) % HOTBAR
    x0 = (w - (HOTBAR * size + (HOTBAR - 1) * gap) - RECIPE_W * s - 60.0 * s) / 2.0
    y0 = (h - (4 * size + 3 * gap + 14.0 * s)) / 2.0
    [x0 + col * (size + gap), y0 + row * (size + gap) + (row == 3 ? 14.0 * s : 0.0), size]
  end

  # Recipe row k beside the grid: x, y, width, height.
  def recipe_cell(k, w, h, s)
    last = pack_cell(INV - 1, w, h, s)
    top = pack_cell(HOTBAR, w, h, s)
    [last[0] + last[2] + 60.0 * s, top[1] + k * 30.0 * s, RECIPE_W * s, 26.0 * s]
  end

  def recipe_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    k = 0
    while k < RECIPES.size
      c = recipe_cell(k, w, h, s)
      return k if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[3]
      k += 1
    end
    -1
  end

  def pack_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    i = 0
    while i < INV
      c = pack_cell(i, w, h, s)
      return i if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[2]
      i += 1
    end
    -1
  end

  def click_slot(i) = click_cell(@inv_block, @inv_count, i)

  # A click picks up a stack, puts it down, merges it, or swaps it.
  def click_cell(blocks, counts, i)
    b = blocks[i]
    n = counts[i]
    if @held_count == 0
      return if n == 0
      @held_block = b
      @held_count = n
      blocks[i] = Block::AIR
      counts[i] = 0
    elsif n == 0
      blocks[i] = @held_block
      counts[i] = @held_count
      @held_count = 0
      @held_block = Block::AIR
    elsif b == @held_block
      moved = [STACK - n, @held_count].min
      counts[i] += moved
      @held_count -= moved
      @held_block = Block::AIR if @held_count == 0
    else
      blocks[i] = @held_block
      counts[i] = @held_count
      @held_block = b
      @held_count = n
    end
  end

  # Chest cell k, in the place of the recipe list: x, y, size.
  def chest_cell(k, w, h, s)
    first = recipe_cell(0, w, h, s)
    size = 31.0 * s
    [first[0] + (k % 9) * (size + 2.0 * s), first[1] + (k / 9) * (size + 2.0 * s), size]
  end

  def chest_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    k = 0
    while k < CHEST_SLOTS
      c = chest_cell(k, w, h, s)
      return k if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[2]
      k += 1
    end
    -1
  end

  def open_chest(x, y, z)
    @chest_key = World.key(x, y, z)
    stored = @chests[@chest_key]
    k = 0
    while k < CHEST_SLOTS
      @chest_block[k] = stored.nil? ? 0 : stored[k]
      @chest_count[k] = stored.nil? ? 0 : stored[CHEST_SLOTS + k]
      k += 1
    end
    toggle_inventory
  end

  def close_chest
    return if @chest_key < 0
    @chests[@chest_key] = @chest_block + @chest_count
    @chest_key = -1
  end

  # Breaking a chest gives back what it held (in survival).
  def drop_chest(x, y, z)
    key = World.key(x, y, z)
    if key == @chest_key
      return_held
      close_chest
      @inventory_open = false
      @captured = true
      Gfx.in_capture(1)
    end
    stored = @chests[key]
    return if stored.nil?
    if @survival
      k = 0
      while k < CHEST_SLOTS
        stored[CHEST_SLOTS + k].times { give(stored[k]) }
        k += 1
      end
    end
    @chests.delete(key)
  end

  def return_held
    while @held_count > 0 && give(@held_block)
      @held_count -= 1
    end
    if @held_count > 0 && @chest_key >= 0
      k = 0
      while k < CHEST_SLOTS && @held_count > 0
        if @chest_count[k] == 0 || @chest_block[k] == @held_block
          take = STACK - @chest_count[k] < @held_count ? STACK - @chest_count[k] : @held_count
          @chest_block[k] = @held_block
          @chest_count[k] += take
          @held_count -= take
        end
        k += 1
      end
    end
    @held_block = Block::AIR if @held_count == 0
  end

  def toggle_inventory
    if @inventory_open
      return_held
      if @held_count > 0
        say("NO ROOM FOR THE HELD STACK")
        return
      end
    end
    close_chest if @inventory_open
    @inventory_open = !@inventory_open
    @captured = !@inventory_open
    Gfx.in_capture(@inventory_open ? 0 : 1)
  end

  def handle_inventory
    if Gfx.in_key_pressed(Key::E) != 0 || Gfx.in_key_pressed(Key::ESCAPE) != 0
      toggle_inventory
      return
    end
    select_slot
    craft if @survival && Gfx.in_key_pressed(Key::C) != 0
    if @survival && Gfx.in_button_pressed(1) != 0
      w = Gfx.gfx_width.to_f
      h = Gfx.gfx_height.to_f
      hover = pack_hover(w, h, ui_scale(h))
      click_slot(hover) if hover >= 0
      if @chest_key >= 0
        cell = chest_hover(w, h, ui_scale(h))
        click_cell(@chest_block, @chest_count, cell) if cell >= 0
      else
        recipe = recipe_hover(w, h, ui_scale(h))
        craft_recipe(recipe) if recipe >= 0 && @held_count == 0
      end
    elsif Gfx.in_button_pressed(1) != 0
      w = Gfx.gfx_width.to_f
      h = Gfx.gfx_height.to_f
      hover = inventory_hover(w, h, ui_scale(h))
      if hover >= 0
        @hotbar[@slot] = PLACEABLE[hover]
        say(Block::NAMES[PLACEABLE[hover]])
        play(Sfx::PLACE, 0.4)
      end
    end
  end
end
