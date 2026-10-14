# Items: the hotbar, the backpack, chests, crafting, and the inventory screen.
class Game
  RECIPE_W = 300.0
  # The recipe list has two columns of this many rows.
  RECIPE_ROWS = 16
  # A recipe that needs a crafting table or a furnace works when one is this
  # near the player.
  STATION_REACH = 4
  # What a furnace burns, and how many items one of each smelts. The list
  # goes from the weakest fuel to the strongest.
  FUEL_BLOCKS = [Block::PLANKS, Block::LOG, Block::COAL]
  FUEL_SMELTS = [1, 2, 8]

  def current_block
    @survival ? @inv.block(@slot) : @hotbar[@slot]
  end

  # Uses up n uses of the selected tool. A tool with no uses left breaks.
  def wear_tool(n)
    return unless @survival && n > 0
    b = @inv.block(@slot)
    return unless Block.tool?(b) && @inv.count(@slot) > 0
    @inv.take(@slot, n < @inv.count(@slot) ? n : @inv.count(@slot))
    return unless @inv.empty?(@slot)
    play(Sfx::TOOL_BREAK, 0.8)
    @particles.shatter(@player, b)
    say("#{Block::NAMES[b]} BROKE")
  end

  # Crafts recipe k up to want times from items anywhere in the inventory.
  # A click asks for 1, and a Shift-click for CRAFT_ALL. A smelt takes heat
  # from the furnace. When the heat runs out, the furnace burns fuel from
  # the inventory, and it keeps the heat that is left.
  def craft_recipe(k, want = 1)
    r = RECIPES[k]
    have = @inv.total(r[0]) / r[1]
    if have == 0
      say("NEED #{r[1]} #{Block::NAMES[r[0]]}")
      return
    end
    unless station_near?(r[4])
      say(r[4] == AT_TABLE ? "NEED A CRAFTING TABLE NEARBY" : "NEED A FURNACE NEARBY")
      return
    end
    smelt = r[4] == AT_FURNACE
    key = smelt ? World.key(@station_x, @station_y, @station_z) : 0
    if smelt && furnace_heat(key) == 0 && pick_fuel(1) < 0
      say("NEED FUEL: PLANKS, LOGS OR COAL ORE")
      return
    end
    times = want < have ? want : have
    heat = 0
    saved = @inv.copy
    # Fewer times when the results do not fit.
    while times > 0
      @inv = saved.copy
      heat = smelt ? furnace_heat(key) : 0
      while smelt && heat < times
        fuel = pick_fuel(times - heat)
        break if fuel < 0
        @inv.remove(FUEL_BLOCKS[fuel], 1)
        heat += FUEL_SMELTS[fuel]
      end
      times = heat if smelt && heat < times
      # Take the ingredients first: a slot that they empty is room for the result.
      @inv.remove(r[0], r[1] * times)
      break if @inv.room_for(r[2]) >= r[3] * times
      times -= 1
    end
    if times == 0
      @inv = saved
      say("INVENTORY FULL")
      return
    end
    n = r[3] * times
    n.times { @inv.add(r[2]) }
    if smelt
      set_furnace_heat(@station_x, @station_y, @station_z, heat - times)
      say("SMELTED #{n} #{Block::NAMES[r[2]]}  #{heat - times} HEAT LEFT")
    else
      say("CRAFTED #{n} #{Block::NAMES[r[2]]}")
    end
    play(Sfx::PLACE, 0.6)
  end

  # What a Shift-click on a recipe asks for: all that the inventory holds.
  CRAFT_ALL = Slots::STACK * INV

  # The smelts left in the furnace with the World.key key.
  def furnace_heat(key)
    heat = @furnace_heat[key]
    heat.nil? ? 0 : heat
  end

  # A furnace with heat is lit.
  def set_furnace_heat(x, y, z, heat)
    key = World.key(x, y, z)
    if heat > 0
      @furnace_heat[key] = heat
    else
      @furnace_heat.delete(key)
    end
    b = @world.get(x, y, z)
    lit = Block.furnace_id(Block::FACING[b], heat > 0)
    set_block(x, y, z, lit) if lit != b
  end

  # The fuel to burn for want smelts: the weakest fuel in the inventory that
  # covers them all, or else the strongest one. -1 when there is no fuel.
  def pick_fuel(want)
    best = -1
    i = 0
    while i < FUEL_BLOCKS.size
      if @inv.total(FUEL_BLOCKS[i]) > 0
        return i if FUEL_SMELTS[i] >= want
        best = i
      end
      i += 1
    end
    best
  end

  # True when the recipes for where (BY_HAND, AT_TABLE or AT_FURNACE) work.
  # A crafting table or a furnace must be within STATION_REACH blocks of the
  # player on each axis. @station_x, @station_y and @station_z keep the
  # cell of the one found.
  def station_near?(where)
    return true if where == BY_HAND
    b = where == AT_TABLE ? Block::CRAFTING_TABLE : Block::FURNACE
    px = @player.x.floor
    py = @player.y.floor
    pz = @player.z.floor
    x = px - STATION_REACH
    while x <= px + STATION_REACH
      y = py - STATION_REACH
      while y <= py + STATION_REACH
        z = pz - STATION_REACH
        while z <= pz + STATION_REACH
          if Block::BASE[@world.get(x, y, z)] == b
            @station_x = x
            @station_y = y
            @station_z = z
            return true
          end
          z += 1
        end
        y += 1
      end
      x += 1
    end
    false
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


  # The scale of the survival inventory screen: the HUD scale, or less when
  # the screen does not fit in the frame above the health bars.
  def inventory_scale(w, h)
    bars = h - 82.0 * ui_scale(h)
    s = ui_scale(h)
    while s > 1.0
      first = pack_cell(HOTBAR, w, h, s)
      last = recipe_cell(RECIPE_ROWS * 2 - 1, w, h, s)
      break if first[0] >= 18.0 * s && last[0] + last[2] + 18.0 * s <= w && last[1] + last[3] + 18.0 * s <= bars
      s -= 1.0
    end
    s
  end

  # Survival inventory cell i: backpack rows on top, the hotbar row below.
  # The grid and the recipe list start at one height, and the recipe list is
  # in the middle of the frame.
  def pack_cell(i, w, h, s)
    size = 52.0 * s
    gap = 6.0 * s
    row = i < HOTBAR ? 3 : (i - HOTBAR) / HOTBAR
    col = i < HOTBAR ? i : (i - HOTBAR) % HOTBAR
    x0 = (w - (HOTBAR * size + (HOTBAR - 1) * gap) - (RECIPE_W * 2.0 + 8.0) * s - 60.0 * s) / 2.0
    y0 = (h - (RECIPE_ROWS * 30.0 - 4.0) * s) / 2.0 + 20.0 * s
    [x0 + col * (size + gap), y0 + row * (size + gap) + (row == 3 ? 14.0 * s : 0.0), size]
  end

  # Recipe k beside the grid, in two columns: x, y, width, height.
  def recipe_cell(k, w, h, s)
    last = pack_cell(INV - 1, w, h, s)
    top = pack_cell(HOTBAR, w, h, s)
    col = k / RECIPE_ROWS
    [last[0] + last[2] + 60.0 * s + col * (RECIPE_W + 8.0) * s, top[1] + (k % RECIPE_ROWS) * 30.0 * s, RECIPE_W * s, 26.0 * s]
  end

  # Marks what is in the inventory or in the hand as seen. @seen stays
  # through death and goes into the save.
  def note_seen
    (0...INV).each { |i| see(@inv.block(i)) unless @inv.empty?(i) }
    see(@held_block) if @held_count > 0
  end

  # Marks b as seen. Each recipe that b unlocks gets the NEW tag until the
  # recipe list closes, and a message tells the player.
  def see(b)
    return if @seen[b] == 1
    @seen[b] = 1
    found = 0
    last = 0
    k = 0
    while k < RECIPES.size
      if RECIPES[k][0] == b
        @recipe_new[k] = 1
        found += 1
        last = k
      end
      k += 1
    end
    return if found == 0
    say(found == 1 ? "NEW RECIPE: #{Block::NAMES[RECIPES[last][2]]}" : "#{found} NEW RECIPES - PRESS E")
  end

  # The recipes that the list shows, in the order of RECIPES: those whose
  # ingredient the player has seen. Other recipes stay a surprise.
  def shown_recipes
    shown = []
    k = 0
    while k < RECIPES.size
      shown << k if @seen[RECIPES[k][0]] == 1
      k += 1
    end
    shown
  end

  # The recipe under the mouse, or -1.
  def recipe_hover(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    shown = shown_recipes
    j = 0
    while j < shown.size
      c = recipe_cell(j, w, h, s)
      return shown[j] if mx >= c[0] && my >= c[1] && mx < c[0] + c[2] && my < c[1] + c[3]
      j += 1
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

  # A click picks up a stack, puts it down, merges it, or swaps it.
  def click_cell(slots, i)
    b = slots.block(i)
    n = slots.count(i)
    if @held_count == 0
      return if n == 0
      @held_block = b
      @held_count = n
      slots.set(i, b, 0)
    elsif n == 0
      slots.set(i, @held_block, @held_count)
      @held_count = 0
      @held_block = Block::AIR
    elsif b == @held_block && !Block.tool?(b)
      moved = [Slots::STACK - n, @held_count].min
      slots.set(i, b, n + moved)
      @held_count -= moved
      @held_block = Block::AIR if @held_count == 0
    else
      slots.set(i, @held_block, @held_count)
      @held_block = b
      @held_count = n
    end
  end

  # A right-click with an empty hand takes half the stack; a tool goes
  # whole. With a stack in the hand, it puts one item into an empty cell or
  # onto the same kind, and it swaps otherwise.
  def split_cell(slots, i)
    b = slots.block(i)
    n = slots.count(i)
    if @held_count == 0
      return if n == 0
      taken = Block.tool?(b) ? n : (n + 1) / 2
      @held_block = b
      @held_count = taken
      slots.take(i, taken)
    elsif Block.tool?(@held_block) || (n > 0 && b != @held_block)
      click_cell(slots, i)
    elsif n < Slots::STACK
      slots.set(i, @held_block, n + 1)
      @held_count -= 1
      @held_block = Block::AIR if @held_count == 0
    end
  end

  # A Shift-click on inventory slot i moves the stack into the open chest,
  # or else between the hotbar and the backpack.
  def quick_move_slot(i)
    return if @inv.empty?(i) || @held_count > 0
    if @chest_key >= 0
      @inv.move_stack(i, @chest, 0, CHEST_SLOTS)
    elsif i < HOTBAR
      @inv.move_stack(i, @inv, HOTBAR, INV)
    else
      @inv.move_stack(i, @inv, 0, HOTBAR)
    end
  end

  # A Shift-click on chest cell k moves the stack into the inventory.
  def quick_move_chest(k)
    return if @chest.empty?(k) || @held_count > 0
    @chest.move_stack(k, @inv, 0, INV)
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
    @chest = @chests[@chest_key] ||= Slots.new(CHEST_SLOTS)
    play(Sfx::CHEST_OPEN, 0.5)
    toggle_inventory
  end

  def close_chest
    @chest_key = -1
  end

  # A broken chest drops what it held (in survival).
  def drop_chest(x, y, z)
    key = World.key(x, y, z)
    if key == @chest_key
      return_held
      close_chest
      @inventory_open = false
      @captured = true
      Gfx.in_capture(1)
    end
    chest = @chests.delete(key)
    return if chest.nil? || !@survival
    (0...CHEST_SLOTS).each { |k| drop_from_block(chest.block(k), chest.count(k), x, y, z) }
  end

  def return_held
    tool = Block.tool?(@held_block)
    @held_count = 0 if tool && @held_count > 0 && @inv.put(@held_block, @held_count)
    while @held_count > 0 && !tool && @inv.add(@held_block)
      @held_count -= 1
    end
    if @held_count > 0 && @chest_key >= 0
      k = 0
      while k < CHEST_SLOTS && @held_count > 0
        n = @chest.count(k)
        if n == 0 || (@chest.block(k) == @held_block && !tool)
          taken = tool || Slots::STACK - n >= @held_count ? @held_count : Slots::STACK - n
          @chest.set(k, @held_block, n + taken)
          @held_count -= taken
        end
        k += 1
      end
    end
    @held_block = Block::AIR if @held_count == 0
  end

  def toggle_inventory
    # The player saw the NEW tags in the recipe list.
    @recipe_new.fill(0) if @inventory_open && @chest_key < 0
    if @inventory_open
      return_held
      # What does not fit falls to the ground.
      if @held_count > 0
        throw_stack(@held_block, @held_count)
        @held_count = 0
        @held_block = Block::AIR
      end
    end
    if @inventory_open && @chest_key >= 0
      play(Sfx::CHEST_CLOSE, 0.5)
      close_chest
    end
    @inventory_open = !@inventory_open
    @captured = !@inventory_open
    Gfx.in_capture(@inventory_open ? 0 : 1)
  end

  def handle_inventory
    if Gfx.in_key_pressed(Key::E) || Gfx.in_key_pressed(Key::ESCAPE)
      toggle_inventory
      return
    end
    select_slot
    left = Gfx.in_button_pressed(1)
    if @survival && (left || Gfx.in_button_pressed(3))
      w = Gfx.gfx_width.to_f
      h = Gfx.gfx_height.to_f
      s = inventory_scale(w, h)
      shift = left && Gfx.in_key(Key::LSHIFT)
      hover = pack_hover(w, h, s)
      if hover >= 0
        if shift
          quick_move_slot(hover)
        elsif left
          click_cell(@inv, hover)
        else
          split_cell(@inv, hover)
        end
      end
      if @chest_key >= 0
        cell = chest_hover(w, h, s)
        if cell >= 0
          if shift
            quick_move_chest(cell)
          elsif left
            click_cell(@chest, cell)
          else
            split_cell(@chest, cell)
          end
        end
      elsif left
        recipe = recipe_hover(w, h, s)
        craft_recipe(recipe, shift ? CRAFT_ALL : 1) if recipe >= 0 && @held_count == 0
      end
    elsif Gfx.in_button_pressed(1)
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
