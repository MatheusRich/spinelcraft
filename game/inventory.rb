# Items: the hotbar, the backpack, chests, crafting, and the inventory screen.
class Game
  RECIPE_W = 320.0
  # The distance from one recipe row to the next. A row is 4 less high.
  RECIPE_H = 44.0

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

  # Crafts the recipe at index up to want times from items anywhere in the
  # inventory.
  # A click asks for 1, and a Shift-click for CRAFT_ALL. A smelting recipe
  # puts its ingredient into the furnace instead, and the furnace smelts it
  # in time.
  def craft_recipe(index, want = 1)
    recipe = @recipe_book.recipe(index)
    where = recipe.where
    if recipe.craftable(@inv) == 0
      say("NEED #{recipe.need}")
      return
    end
    unless station_makes?(where)
      say(where == Recipe::AT_TABLE ? "NEED A CRAFTING TABLE" : "NEED A FURNACE")
      return
    end
    if where == Recipe::AT_FURNACE
      load_furnace(recipe.ingredient, want)
      return
    end
    n = recipe.craft(want, @inv)
    if n == 0
      say("INVENTORY FULL")
      return
    end
    say("CRAFTED #{n} #{Block::NAMES[recipe.result]}")
    play(Sfx::PLACE, 0.6)
  end

  # What a Shift-click on a recipe asks for: all that the inventory holds.
  CRAFT_ALL = Slots::STACK * INV

  # The furnace whose screen is open.
  def open_furnace
    @furnaces[World.key(@station_x, @station_y, @station_z)] ||= Furnace.new(@station_x, @station_y, @station_z)
  end

  # Moves up to want of b from the inventory into the input slot of the
  # open furnace.
  def load_furnace(b, want)
    slots = open_furnace.slots
    if !slots.empty?(Furnace::INPUT) && slots.block(Furnace::INPUT) != b
      say("THE FURNACE HOLDS #{Block::NAMES[slots.block(Furnace::INPUT)]}")
      return
    end
    n = Block.stack(b) - slots.count(Furnace::INPUT)
    n = want if want < n
    n = @inv.total(b) if @inv.total(b) < n
    return if n == 0
    @inv.remove(b, n)
    slots.set(Furnace::INPUT, b, slots.count(Furnace::INPUT) + n)
    play(Sfx::PLACE, 0.4)
  end

  # Furnaces work while their chunk is loaded, as in Minecraft. A furnace
  # is lit while it burns.
  def update_furnaces(dt)
    @furnace_clock += dt
    ticks = (@furnace_clock * Furnace::TICKS_PER_SECOND).to_i
    @furnace_clock -= ticks.to_f / Furnace::TICKS_PER_SECOND
    return if ticks == 0
    @furnaces.each do |key, f|
      if @world.loaded?(f.x, f.z)
        recipe = @recipe_book.smelt_recipe(f.slots.block(Furnace::INPUT))
        out = recipe.nil? ? 0 : recipe.result
        out_n = recipe.nil? ? 0 : recipe.result_count
        ticks.times { f.tick(out, out_n, Furnace.fuel_ticks(f.slots.block(Furnace::FUEL))) }
        b = @world.get(f.x, f.y, f.z)
        lit = Block.furnace_id(Block::FACING[b], f.lit?)
        set_block(f.x, f.y, f.z, lit) if Block::BASE[b] == Block::FURNACE && lit != b
      end
    end
  end

  # A click on slot i of the open furnace. The input slot takes only what
  # the furnace smelts, and the fuel slot only fuel. The output slot only
  # gives: a click takes its stack, or adds it to the same kind in the hand.
  def click_furnace(i, left)
    slots = open_furnace.slots
    held = @held.block(0)
    if i == Furnace::OUTPUT && !@held.empty?(0)
      return if held != slots.block(i) || slots.empty?(i)
      moved = [Block.stack(held) - @held.count(0), slots.count(i)].min
      @held.set(0, held, @held.count(0) + moved)
      slots.take(i, moved)
      return
    end
    if !@held.empty?(0) && i == Furnace::FUEL && !Furnace.fuel?(held)
      say("NOT A FUEL")
      return
    end
    if !@held.empty?(0) && i == Furnace::INPUT && !@recipe_book.smelts?(held)
      say("THE FURNACE DOES NOT SMELT THAT")
      return
    end
    if left
      slots.click(i, @held)
    else
      slots.click_half(i, @held)
    end
  end

  # A broken furnace drops what it holds (in survival).
  def drop_furnace(x, y, z)
    furnace = @furnaces.delete(World.key(x, y, z))
    return if furnace.nil? || !@survival
    (0...3).each { |i| drop_from_block(furnace.slots.block(i), furnace.slots.count(i), x, y, z) }
  end

  # The station whose recipes the open screen makes: @station, or BY_HAND
  # when the block of the station is gone. Then the screen works as the E
  # screen.
  def active_station
    return Recipe::BY_HAND if @station == Recipe::BY_HAND
    b = @station == Recipe::AT_TABLE ? Block::CRAFTING_TABLE : Block::FURNACE
    return Recipe::BY_HAND if Block::BASE[@world.get(@station_x, @station_y, @station_z)] != b
    @station
  end

  # True when the open screen makes the recipes for where (BY_HAND, AT_TABLE
  # or AT_FURNACE of Recipe).
  def station_makes?(where) = Recipe.makes?(active_station, where)

  # Opens the screen of the crafting table or the furnace at x, y, z.
  def open_station(x, y, z, where)
    @station = where
    @station_x = x
    @station_y = y
    @station_z = z
    toggle_inventory
  end

  # Pixel rectangle of inventory cell i: x, y, size.
  def inventory_cell(i, w, h, s)
    size = 56.0 * s
    gap = 8.0 * s
    cols = INV_COLS
    rows = (CREATIVE_ITEMS.size + cols - 1) / cols
    x0 = (w - (cols * size + (cols - 1) * gap)) / 2.0
    y0 = (h - (rows * size + (rows - 1) * gap)) / 2.0
    [x0 + (i % cols) * (size + gap), y0 + (i / cols) * (size + gap), size]
  end

  # True when the mouse is over the box at x, y that is w wide and h high.
  def mouse_in?(x, y, w, h)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    mx >= x && my >= y && mx < x + w && my < y + h
  end

  def inventory_hover(w, h, s)
    CREATIVE_ITEMS.size.times do |i|
      c = inventory_cell(i, w, h, s)
      return i if mouse_in?(c[0], c[1], c[2], c[2])
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
      last = recipe_cell(RecipeBook::ROWS * 2 - 1, w, h, s)
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
    y0 = (h - (RecipeBook::ROWS * RECIPE_H - 4.0) * s) / 2.0 + 20.0 * s
    [x0 + col * (size + gap), y0 + row * (size + gap) + (row == 3 ? 14.0 * s : 0.0), size]
  end

  # Place j of the recipe list beside the grid, two to a row: x, y, width,
  # height.
  def recipe_cell(j, w, h, s)
    last = pack_cell(INV - 1, w, h, s)
    top = pack_cell(HOTBAR, w, h, s)
    [last[0] + last[2] + 60.0 * s + (j % 2) * (RECIPE_W + 8.0) * s, top[1] + (j / 2) * RECIPE_H * s, RECIPE_W * s, (RECIPE_H - 4.0) * s]
  end

  # The places that the recipe list skips: a furnace shows its slots in the
  # first five rows.
  def recipe_skip = station_makes?(Recipe::AT_FURNACE) ? 10 : 0

  # Slot i of the open furnace, in the place of the first recipe rows, as in
  # Minecraft: the input on top, the flame under it, the fuel at the bottom,
  # and the output at the right, between them. x, y, size.
  def furnace_cell(i, w, h, s)
    first = recipe_cell(0, w, h, s)
    x = i == Furnace::OUTPUT ? first[0] + 244.0 * s : first[0]
    [x, first[1] + (i == Furnace::INPUT ? 14.0 : (i == Furnace::FUEL ? 130.0 : 72.0)) * s, 52.0 * s]
  end

  # The slot of the open furnace under the mouse, or -1.
  def furnace_hover(w, h, s)
    3.times do |i|
      c = furnace_cell(i, w, h, s)
      return i if mouse_in?(c[0], c[1], c[2], c[2])
    end
    -1
  end

  # True when the mouse is over the rows of the recipe list.
  def over_recipes?(w, h, s)
    mx = Gfx.in_mouse_x
    my = Gfx.in_mouse_y
    first = recipe_cell(0, w, h, s)
    last = recipe_cell(RecipeBook::ROWS * 2 - 1, w, h, s)
    mx >= first[0] && my >= first[1] && mx < last[0] + last[2] && my < last[1] + last[3]
  end

  # Marks what is in the inventory or in the hand as seen, and tells the
  # player about the new recipes.
  def note_seen
    INV.times { |i| tell_recipes(@inv.block(i)) unless @inv.empty?(i) }
    tell_recipes(@held.block(0)) unless @held.empty?(0)
  end

  def tell_recipes(b)
    text = @recipe_book.see(b)
    say(text) unless text.empty?
  end

  # The recipe under the mouse, or -1.
  def recipe_hover(w, h, s)
    view = @recipe_book.in_view(active_station)
    skip = recipe_skip
    view.size.times do |place|
      c = recipe_cell(place + skip, w, h, s)
      return view[place] if mouse_in?(c[0], c[1], c[2], c[3])
    end
    -1
  end

  def pack_hover(w, h, s)
    INV.times do |i|
      c = pack_cell(i, w, h, s)
      return i if mouse_in?(c[0], c[1], c[2], c[2])
    end
    -1
  end

  # A Shift-click on inventory slot i moves the stack into the open chest,
  # or into the input or the fuel slot of the open furnace, or else between
  # the hotbar and the backpack.
  def quick_move_slot(i)
    return if @inv.empty?(i) || !@held.empty?(0)
    furnace = station_makes?(Recipe::AT_FURNACE)
    if @chest_key >= 0
      @inv.move_stack(i, @chest, 0, CHEST_SLOTS)
    elsif furnace && @recipe_book.smelts?(@inv.block(i))
      @inv.move_stack(i, open_furnace.slots, Furnace::INPUT, Furnace::INPUT + 1)
    elsif furnace && Furnace.fuel?(@inv.block(i))
      @inv.move_stack(i, open_furnace.slots, Furnace::FUEL, Furnace::FUEL + 1)
    elsif i < HOTBAR
      @inv.move_stack(i, @inv, HOTBAR, INV)
    else
      @inv.move_stack(i, @inv, 0, HOTBAR)
    end
  end

  # A Shift-click on chest cell k moves the stack into the inventory.
  def quick_move_chest(k)
    return if @chest.empty?(k) || !@held.empty?(0)
    @chest.move_stack(k, @inv, 0, INV)
  end

  # Chest cell k, in the place of the recipe list: x, y, size.
  def chest_cell(k, w, h, s)
    first = recipe_cell(0, w, h, s)
    size = 31.0 * s
    [first[0] + (k % 9) * (size + 2.0 * s), first[1] + (k / 9) * (size + 2.0 * s), size]
  end

  def chest_hover(w, h, s)
    CHEST_SLOTS.times do |k|
      c = chest_cell(k, w, h, s)
      return k if mouse_in?(c[0], c[1], c[2], c[2])
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

  # The stack in the hand goes back into the inventory, onto stacks of its
  # kind first, and then into the open chest.
  def return_held
    @held.move_stack(0, @inv, 0, INV)
    @held.move_stack(0, @chest, 0, CHEST_SLOTS) if @chest_key >= 0
  end

  def toggle_inventory
    # The player saw the NEW tags in the recipe list.
    @recipe_book.close_list(active_station) if @inventory_open && @chest_key < 0
    if @inventory_open
      return_held
      # What does not fit falls to the ground.
      unless @held.empty?(0)
        throw_stack(@held.block(0), @held.count(0))
        @held.clear
      end
    end
    if @inventory_open && @chest_key >= 0
      play(Sfx::CHEST_CLOSE, 0.5)
      close_chest
    end
    @station = Recipe::BY_HAND if @inventory_open
    @inventory_open = !@inventory_open
    @recipe_book.open_list if @inventory_open
    @captured = !@inventory_open
    Gfx.in_capture(@inventory_open ? 0 : 1)
  end

  def handle_inventory # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    if Gfx.in_key_pressed(Key::E) || Gfx.in_key_pressed(Key::ESCAPE)
      toggle_inventory
      return
    end
    w = Gfx.gfx_width.to_f
    h = Gfx.gfx_height.to_f
    s = inventory_scale(w, h)
    if @survival && @chest_key < 0 && Gfx.in_wheel != 0.0 && over_recipes?(w, h, s)
      @recipe_book.turn_wheel(Gfx.in_wheel, active_station)
    else
      select_slot
    end
    left = Gfx.in_button_pressed(1)
    if @survival && (left || Gfx.in_button_pressed(3))
      shift = left && Gfx.in_key(Key::LSHIFT)
      hover = pack_hover(w, h, s)
      if hover >= 0
        if shift
          quick_move_slot(hover)
        elsif left
          @inv.click(hover, @held)
        else
          @inv.click_half(hover, @held)
        end
      end
      if @chest_key >= 0
        cell = chest_hover(w, h, s)
        if cell >= 0
          if shift
            quick_move_chest(cell)
          elsif left
            @chest.click(cell, @held)
          else
            @chest.click_half(cell, @held)
          end
        end
      elsif station_makes?(Recipe::AT_FURNACE) && furnace_hover(w, h, s) >= 0
        cell = furnace_hover(w, h, s)
        if shift
          open_furnace.slots.move_stack(cell, @inv, 0, INV)
        else
          click_furnace(cell, left)
        end
      elsif left
        recipe = recipe_hover(w, h, s)
        craft_recipe(recipe, shift ? CRAFT_ALL : 1) if recipe >= 0 && @held.empty?(0)
      end
    elsif Gfx.in_button_pressed(1)
      hover = inventory_hover(w, h, ui_scale(h))
      if hover >= 0
        @hotbar[@slot] = CREATIVE_ITEMS[hover]
        say(Block::NAMES[CREATIVE_ITEMS[hover]])
        play(Sfx::PLACE, 0.4)
      end
    end
  end
end
