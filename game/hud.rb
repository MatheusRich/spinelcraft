# The 2D overlay: crosshair, hotbar, health and hunger, messages, and menus.
class Game
  # The HUD scale: 1 for each 720 pixels of frame height, and at least 1.
  def ui_scale(h)
    s = (h / 720.0).round.to_f
    s < 1.0 ? 1.0 : s
  end

  def build_ui(w, h)
    @ui.clear
    s = ui_scale(h)
    draw_view_overlays(w, h, s)
    size = 44.0 * s
    gap = 4.0 * s
    total = size * HOTBAR + gap * (HOTBAR - 1)
    x0 = (w - total) / 2.0
    y0 = h - size - 12.0 * s
    draw_hotbar(x0, y0, size, gap, s)
    draw_survival_bars(x0, y0, total, s) if @survival
    draw_messages(w, y0, s)
    draw_chat_lines(w, y0, s)
    draw_chat_line(w, h, s) if @chat.open?
    draw_debug(s) if @options.debug
    if @vitals.dead?
      draw_death_screen(w, h, s)
    elsif @inventory_open && @survival
      draw_backpack(w, h, inventory_scale(w, h))
    elsif @inventory_open
      draw_block_picker(w, h, s)
    elsif paused?
      draw_pause_screen(w, h, s)
    end
  end

  # Tints for water, lava and damage, flames while the player burns, the
  # crosshair, and the bow pull or the attack cooldown.
  def draw_view_overlays(w, h, s)
    eye_block = @world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor)
    if Block.water?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.1, 0.25, 0.6, 0.25)
    elsif Block.lava?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.9, 0.3, 0.05, 0.75)
    end
    if @vitals.burning? && @survival && !@vitals.dead?
      # Two flames at the bottom corners that flicker.
      size = h * 0.42
      k = 0
      while k < 2
        flick = Math.sin(@anim_time * 23.0 + k * 2.0) * 0.04 * size
        x = k == 0 ? -size * 0.15 : w - size * 0.85
        @ui.quad(x, h - size * 0.8 + flick, size, size, Tex::FIRE, 1.0, 1.0, 1.0, 1.0, 1.0, 0.85)
        k += 1
      end
    end
    if @damage_flash > 0.0
      @ui.rect(0.0, 0.0, w, h, 0.8, 0.0, 0.0, @damage_flash)
    end
    # crosshair
    @ui.rect(w / 2.0 - 9.0 * s, h / 2.0 - 1.0 * s, 18.0 * s, 2.0 * s, 1.0, 1.0, 1.0, 0.8)
    @ui.rect(w / 2.0 - 1.0 * s, h / 2.0 - 9.0 * s, 2.0 * s, 18.0 * s, 1.0, 1.0, 1.0, 0.8)
    if @draw_time >= 0.0
      pull = @draw_time > 1.0 ? 1.0 : @draw_time
      @ui.rect(w / 2.0 - 20.0 * s, h / 2.0 + 16.0 * s, 40.0 * s, 4.0 * s, 0.0, 0.0, 0.0, 0.5)
      @ui.rect(w / 2.0 - 20.0 * s, h / 2.0 + 16.0 * s, 40.0 * s * pull, 4.0 * s, 1.0, pull, 0.2, 0.9)
    elsif @survival && attack_charge < 1.0
      charge = attack_charge
      @ui.rect(w / 2.0 - 10.0 * s, h / 2.0 + 16.0 * s, 20.0 * s, 3.0 * s, 0.0, 0.0, 0.0, 0.5)
      @ui.rect(w / 2.0 - 10.0 * s, h / 2.0 + 16.0 * s, 20.0 * s * charge, 3.0 * s, 1.0, 1.0, 1.0, 0.8)
    end
  end

  def draw_hotbar(x0, y0, size, gap, s)
    total = size * HOTBAR + gap * (HOTBAR - 1)
    @ui.rect(x0 - gap, y0 - gap, total + gap * 2.0, size + gap * 2.0, 0.0, 0.0, 0.0, 0.45)
    i = 0
    while i < HOTBAR
      x = x0 + i * (size + gap)
      if i == @slot
        @ui.rect(x - 3.0 * s, y0 - 3.0 * s, size + 6.0 * s, size + 6.0 * s, 1.0, 1.0, 1.0, 0.95)
      end
      @ui.rect(x, y0, size, size, 0.25, 0.25, 0.25, 0.9)
      slot_block = @survival ? @inv.block(i) : @hotbar[i]
      if slot_block != Block::AIR
        @ui.item(x + 5.0 * s, y0 + 5.0 * s, size - 10.0 * s, slot_block, 1.0)
        draw_count(slot_block, @inv.count(i), x, y0, size, 2.0 * s, s) if @survival
      end
      i += 1
    end
  end

  # Hearts on the left above the hotbar, food on the right, and up to 10 air
  # bubbles above the food.
  def draw_survival_bars(x0, y0, total, s)
    hy = y0 - 26.0 * s
    i = 0
    while i < 10
      hx = x0 + i * 20.0 * s
      p = Tex::ICON_PART
      @ui.quad(hx, hy, 18.0 * s, 18.0 * s, Tex::HEART_EMPTY, p, p, 1.0, 1.0, 1.0, 1.0)
      # A part of a half heart shows as a half heart, as in Minecraft. A half
      # heart is the left 5 of the 9 columns.
      hp = @vitals.health.ceil - i * 2
      if hp >= 2
        @ui.quad(hx, hy, 18.0 * s, 18.0 * s, Tex::HEART, p, p, 1.0, 1.0, 1.0, 1.0)
      elsif hp == 1
        @ui.quad(hx, hy, 10.0 * s, 18.0 * s, Tex::HEART, 5.0 / 16.0, p, 1.0, 1.0, 1.0, 1.0)
      end
      i += 1
    end
    # The Hunger effect turns the food yellow-green. minecraft.wiki/w/Hunger_(effect)
    full = @vitals.hunger_effect? ? Tex::HUNGER_EFFECT : Tex::HUNGER
    i = 0
    while i < 10
      fx = x0 + total - (i + 1) * 20.0 * s
      p = Tex::ICON_PART
      @ui.quad(fx, hy, 18.0 * s, 18.0 * s, Tex::HUNGER_EMPTY, p, p, 1.0, 1.0, 1.0, 1.0)
      if @vitals.hunger - i * 2 >= 1
        @ui.quad(fx, hy, 18.0 * s, 18.0 * s, full, p, p, 1.0, 1.0, 1.0, 1.0)
      end
      i += 1
    end
    if @vitals.air < Vitals::MAX_AIR
      bubbles = (@vitals.air / Vitals::MAX_AIR * 10.0).ceil
      i = 0
      while i < bubbles
        bx = x0 + total - (i + 1) * 20.0 * s
        @ui.rect(bx + 3.0 * s, hy - 22.0 * s + 3.0 * s, 13.0 * s, 13.0 * s, 0.6, 0.85, 1.0, 0.9)
        i += 1
      end
    end
  end

  # The first-steps hint for an empty survival inventory, and the last message.
  def draw_messages(w, y0, s)
    if @survival && !@vitals.dead? && !@inventory_open && @inv.room_for(Block::DIRT) == INV * Slots::STACK
      hint = "HOLD LEFT CLICK ON A TREE FOR LOGS, THEN PRESS E TO CRAFT PLANKS"
      @ui.text((w - @ui.text_width(hint, 2.0 * s)) / 2.0, y0 - 92.0 * s, hint, 2.0 * s, 1.0, 1.0, 0.7, 0.9)
    end
    if @message_time > 0.0
      tw = @ui.text_width(@message, 3.0 * s)
      @ui.text((w - tw) / 2.0, y0 - 64.0 * s, @message, 3.0 * s, 1.0, 1.0, 1.0, @message_time > 1.0 ? 1.0 : @message_time)
    end
  end

  # The chat lines at the left, above the hotbar and the bars, the newest
  # at the bottom. A long line wraps at half the width of the screen. While
  # the chat is open, all lines show.
  def draw_chat_lines(w, y0, s)
    ts = 2.0 * s
    row = 12.0 * s
    per = (w * 0.5 / (4.0 * ts)).to_i
    per = 20 if per < 20
    y = y0 - 120.0 * s
    i = @chat.lines.size - 1
    while i >= 0
      a = @chat.opacity(i)
      if a > 0.0
        line = @chat.lines[i]
        rows = (line.size + per - 1) / per
        k = rows - 1
        while k >= 0
          part = line[k * per, per]
          @ui.rect(4.0 * s, y - 2.0 * s, @ui.text_width(part, ts) + 6.0 * s, row, 0.0, 0.0, 0.0, 0.4 * a)
          if @chat.error?(i)
            @ui.text(6.0 * s, y, part, ts, 1.0, 0.35, 0.3, a)
          else
            @ui.text(6.0 * s, y, part, ts, 1.0, 1.0, 1.0, a)
          end
          y -= row
          k -= 1
        end
      end
      i -= 1
    end
  end

  # The line that the player types, at the bottom of the screen, and the
  # names that Tab can complete above it.
  def draw_chat_line(w, h, s)
    ts = 2.0 * s
    @ui.rect(4.0 * s, h - 18.0 * s, w - 8.0 * s, 14.0 * s, 0.0, 0.0, 0.0, 0.6)
    cursor = (@anim_time * 3.0).to_i % 2 == 0 ? "_" : ""
    shown = @chat.text.upcase + cursor
    # A line wider than the screen shows its end.
    fit = ((w - 16.0 * s) / (4.0 * ts)).to_i
    shown = shown[shown.size - fit, fit] if shown.size > fit
    @ui.text(8.0 * s, h - 15.0 * s, shown, ts, 1.0, 1.0, 1.0, 1.0)
    draw_chat_matches(h, s, ts)
  end

  # The names that Tab can complete, above the chat line, as the
  # suggestions of Minecraft. The name on the line is yellow.
  def draw_chat_matches(h, s, ts)
    names = @chat.matches
    return if names.empty?
    shown = names.size < Chat::MATCHES ? names.size : Chat::MATCHES
    current = @chat.current_match
    first = current >= shown ? current - shown + 1 : 0
    x = (8.0 + 4.0 * Command.last_word_at(@chat.text) * 2.0) * s
    wide = 0.0
    names.each { |n| wide = @ui.text_width(n, ts) if @ui.text_width(n, ts) > wide }
    y = h - 18.0 * s - shown * 12.0 * s
    @ui.rect(x - 2.0 * s, y - 2.0 * s, wide + 4.0 * s, shown * 12.0 * s, 0.0, 0.0, 0.0, 0.75)
    k = 0
    while k < shown
      i = first + k
      name = names[i].upcase
      if i == current
        @ui.text(x, y + k * 12.0 * s, name, ts, 1.0, 1.0, 0.3, 1.0)
      else
        @ui.text(x, y + k * 12.0 * s, name, ts, 0.65, 0.65, 0.65, 1.0)
      end
      k += 1
    end
  end

  def draw_debug(s)
    ts = 2.0 * s
    @ui.text(8.0 * s, 8.0 * s, "FPS #{@fps.round}  CPU #{@cpu_ms.round(2)}MS", ts, 1.0, 1.0, 1.0, 1.0)
    @ui.text(8.0 * s, 22.0 * s, "XYZ #{@player.x.floor} #{@player.y.floor} #{@player.z.floor}  FACES #{@faces_drawn}", ts, 1.0, 1.0, 1.0, 1.0)
    @ui.text(8.0 * s, 36.0 * s, "CHUNKS #{@visible.size / 2}  REMESH #{@chunk_meshes.mesh_ms.round(2)}MS  MOBS #{@mobs.size}", ts, 1.0, 1.0, 1.0, 1.0)
    clock = ((@time_of_day * 24.0 + 6.0) % 24.0).floor
    mode = @survival ? "SURVIVAL" : "CREATIVE"
    @ui.text(8.0 * s, 50.0 * s, "DAY #{@day + 1}  TIME #{clock}:00  #{mode}#{@weather.raining? ? "  RAIN" : ""}", ts, 1.0, 1.0, 1.0, 1.0)
  end

  def draw_death_screen(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.5, 0.0, 0.0, 0.5)
    msg = "YOU DIED"
    @ui.text((w - @ui.text_width(msg, 8.0 * s)) / 2.0, h / 2.0 - 60.0 * s, msg, 8.0 * s, 1.0, 1.0, 1.0, 1.0)
    days = (@alive_time / DAY_SECONDS).floor
    lasted = "YOU LASTED #{days} #{days == 1 ? "DAY" : "DAYS"}"
    @ui.text((w - @ui.text_width(lasted, 3.0 * s)) / 2.0, h / 2.0 + 50.0 * s, lasted, 3.0 * s, 1.0, 0.85, 0.6, 1.0)
    sub = "CLICK OR PRESS R TO RESPAWN"
    @ui.text((w - @ui.text_width(sub, 3.0 * s)) / 2.0, h / 2.0 + 10.0 * s, sub, 3.0 * s, 1.0, 1.0, 1.0, 1.0)
  end

  # The survival inventory screen: the 36 slots, the chest or the recipes on
  # the side, and the stack that the mouse holds.
  def draw_backpack(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.55)
    top = pack_cell(HOTBAR, w, h, s)
    bottom = pack_cell(8, w, h, s)
    pad = 18.0 * s
    @ui.rect(top[0] - pad, top[1] - pad - 40.0 * s, bottom[0] + bottom[2] - top[0] + pad * 2.0, bottom[1] + bottom[2] - top[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    @ui.text(top[0], top[1] - 36.0 * s, "INVENTORY", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    hover = pack_hover(w, h, s)
    i = 0
    while i < INV
      c = pack_cell(i, w, h, s)
      if i == @slot
        @ui.rect(c[0] - 3.0 * s, c[1] - 3.0 * s, c[2] + 6.0 * s, c[2] + 6.0 * s, 1.0, 1.0, 1.0, 0.9)
      end
      draw_slot(c, i == hover, @inv, i, 6.0 * s, 2.0 * s, s)
      i += 1
    end
    if @chest_key >= 0
      draw_chest_panel(w, h, s, pad)
    else
      draw_recipe_panel(w, h, s, pad)
    end
    tip = @chest_key >= 0 ? "SHIFT-CLICK MOVES A STACK ACROSS  RIGHT-CLICK TAKES HALF" : "SHIFT-CLICK MOVES A STACK OR CRAFTS ALL  RIGHT-CLICK TAKES HALF"
    label = hover >= 0 && !@inv.empty?(hover) ? Block::NAMES[@inv.block(hover)] : tip
    mid = (top[0] + bottom[0] + bottom[2]) / 2.0
    @ui.text(mid - @ui.text_width(label, 2.0 * s) / 2.0, bottom[1] + bottom[2] + pad + 12.0 * s, label, 2.0 * s, 1.0, 1.0, 0.8, 1.0)
    if @held_count > 0
      mx = Gfx.in_mouse_x
      my = Gfx.in_mouse_y
      @ui.item(mx - 20.0 * s, my - 20.0 * s, 40.0 * s, @held_block, 1.0)
      draw_count(@held_block, @held_count, mx - 20.0 * s, my - 20.0 * s, 40.0 * s, 2.0 * s, s)
    end
  end

  def draw_chest_panel(w, h, s, pad)
    first = recipe_cell(0, w, h, s)
    last_c = chest_cell(CHEST_SLOTS - 1, w, h, s)
    @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, first[2] + pad * 2.0, last_c[1] + last_c[2] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    @ui.text(first[0], first[1] - 36.0 * s, "CHEST", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    chover = chest_hover(w, h, s)
    k = 0
    while k < CHEST_SLOTS
      c = chest_cell(k, w, h, s)
      draw_slot(c, k == chover, @chest, k, 3.0 * s, 1.5 * s, s)
      k += 1
    end
  end

  # Slot i of slots in cell c (x, y, size), lighter under the mouse. The
  # item is inset by margin, and its count has text of size ts.
  def draw_slot(c, hover, slots, i, margin, ts, s)
    shade = hover ? 0.55 : 0.32
    @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
    return if slots.empty?(i)
    @ui.item(c[0] + margin, c[1] + margin, c[2] - margin * 2.0, slots.block(i), 1.0)
    draw_count(slots.block(i), slots.count(i), c[0], c[1], c[2], ts, s)
  end

  # The count of a stack of b at the lower right of the cell at x, y, in
  # text of size ts. A tool has no count: a bar shows the uses that it has
  # left, from green to red, once it has been used.
  def draw_count(b, n, x, y, size, ts, s)
    if Block.tool?(b)
      left = n.to_f / Block.uses(b)
      return if left >= 1.0
      @ui.rect(x + 4.0 * s, y + size - 6.0 * s, size - 8.0 * s, 3.0 * s, 0.0, 0.0, 0.0, 1.0)
      @ui.rect(x + 4.0 * s, y + size - 6.0 * s, (size - 8.0 * s) * left, 3.0 * s, 1.0 - left, left, 0.1, 1.0)
      return
    end
    t = n.to_s
    @ui.text(x + size - @ui.text_width(t, ts) - 1.0 * s, y + size - 6.0 * ts, t, ts, 1.0, 1.0, 1.0, 1.0)
  end

  # The panel grows with the shown recipes, up to RecipeBook::ROWS rows. A bar
  # at the right shows where the view is when the list is longer. A furnace
  # shows its slots above its recipes.
  def draw_recipe_panel(w, h, s, pad)
    shown = @recipe_book.shown(active_station)
    view = @recipe_book.in_view(active_station)
    furnace = station_makes?(Recipe::AT_FURNACE)
    skip = recipe_skip
    rows = (shown.size + 1) / 2
    first = recipe_cell(0, w, h, s)
    bottom = recipe_cell(skip + (rows < 1 ? 0 : ((rows < RecipeBook::ROWS ? rows : RecipeBook::ROWS) - 1) * 2), w, h, s)
    right = recipe_cell(shown.size > 1 || furnace ? 1 : 0, w, h, s)
    @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, right[0] + right[2] - first[0] + pad * 2.0, bottom[1] + bottom[3] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    @ui.text(first[0], first[1] - 36.0 * s, furnace ? "FURNACE" : "CRAFTING", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    draw_furnace(w, h, s) if furnace
    rhover = recipe_hover(w, h, s)
    if shown.empty?
      @ui.text(first[0], recipe_cell(skip, w, h, s)[1] + 4.0 * s, "PICK UP ITEMS TO FIND RECIPES", 2.0 * s, 0.8, 0.8, 0.8, 1.0)
    end
    if rows > RecipeBook::ROWS
      track = bottom[1] + bottom[3] - first[1]
      bx = right[0] + right[2] + 7.0 * s
      @ui.rect(bx, first[1], 4.0 * s, track, 0.1, 0.1, 0.12, 1.0)
      @ui.rect(bx, first[1] + track * @recipe_book.top.to_f / rows.to_f, 4.0 * s, track * RecipeBook::ROWS.to_f / rows.to_f, 0.6, 0.6, 0.65, 1.0)
    end
    place = 0
    while place < view.size
      index = view[place]
      c = recipe_cell(place + skip, w, h, s)
      recipe = @recipe_book.recipe(index)
      can = recipe.craftable(@inv) > 0
      shade = index == rhover ? 0.5 : 0.28
      fresh = @recipe_book.fresh?(index)
      @ui.rect(c[0], c[1], c[2], c[3], fresh ? shade + 0.12 : shade, fresh ? shade + 0.08 : shade, shade, 1.0)
      @ui.text(c[0] + c[2] - @ui.text_width("NEW", 1.5 * s) - 8.0 * s, c[1] + 6.0 * s, "NEW", 1.5 * s, 1.0, 0.85, 0.2, 1.0) if fresh
      @ui.item(c[0] + 6.0 * s, c[1] + 6.0 * s, 28.0 * s, recipe.result, can ? 1.0 : 0.35)
      bright = can ? 1.0 : 0.45
      @ui.text(c[0] + 42.0 * s, c[1] + 6.0 * s, "#{recipe.result_count} #{Block::NAMES[recipe.result]}", 2.5 * s, bright, bright, bright, 1.0)
      @ui.text(c[0] + 42.0 * s, c[1] + 23.0 * s, recipe.need, 2.0 * s, bright * 0.95, bright * 0.85, bright * 0.55, 1.0)
      place += 1
    end
  end

  # The slots of the open furnace. Between the input and the fuel, a flame
  # burns down with the fuel item that burns, a pixel row of the texture at
  # a time, as in Minecraft. An arrow to the output fills while an item
  # smelts.
  def draw_furnace(w, h, s)
    f = open_furnace
    hover = furnace_hover(w, h, s)
    i = 0
    while i < 3
      c = furnace_cell(i, w, h, s)
      if i == Furnace::FUEL
        @ui.text(c[0] + c[2] + 16.0 * s, c[1] + 21.0 * s, "FUEL", 2.0 * s, 1.0, 1.0, 1.0, 1.0)
      else
        @ui.text(c[0], c[1] - 14.0 * s, i == Furnace::INPUT ? "IN" : "OUT", 2.0 * s, 1.0, 1.0, 1.0, 1.0)
      end
      draw_slot(c, i == hover, f.slots, i, 6.0 * s, 2.0 * s, s)
      i += 1
    end
    # The flame is 2 pixels to a texture pixel, on whole pixels: a texture
    # pixel that is not a whole number of pixels shimmers as it burns down.
    input = furnace_cell(Furnace::INPUT, w, h, s)
    fx = (input[0] + 10.0 * s).floor.to_f
    fy = (input[1] + input[2] + 16.0 * s).floor.to_f
    @ui.icon(fx, fy, 32.0 * s, Tex::FIRE, 0.25)
    if f.lit?
      rows = (f.burn * 16 + f.burn_total - 1) / f.burn_total
      @ui.icon_bottom(fx, fy, 32.0 * s, Tex::FIRE, rows.to_f / 16.0)
    end
    out = furnace_cell(Furnace::OUTPUT, w, h, s)
    ax = input[0] + input[2] + 16.0 * s
    ay = out[1] + 18.0 * s
    aw = out[0] - 16.0 * s - ax
    @ui.rect(ax, ay, aw, 16.0 * s, 0.1, 0.1, 0.12, 1.0)
    @ui.rect(ax, ay, aw * f.progress.to_f / Furnace::SMELT_TICKS.to_f, 16.0 * s, 1.0, 1.0, 1.0, 1.0) if f.progress > 0
  end

  # The creative inventory screen: every block and item (see CREATIVE_ITEMS).
  def draw_block_picker(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.55)
    first = inventory_cell(0, w, h, s)
    last = inventory_cell(CREATIVE_ITEMS.size - 1, w, h, s)
    pad = 18.0 * s
    right = inventory_cell(INV_COLS - 1, w, h, s)
    @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, right[0] + right[2] - first[0] + pad * 2.0, last[1] + last[2] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    @ui.text(first[0], first[1] - 36.0 * s, "ITEMS", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    hover = inventory_hover(w, h, s)
    i = 0
    while i < CREATIVE_ITEMS.size
      c = inventory_cell(i, w, h, s)
      shade = i == hover ? 0.55 : 0.32
      @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
      @ui.item(c[0] + 6.0 * s, c[1] + 6.0 * s, c[2] - 12.0 * s, CREATIVE_ITEMS[i], 1.0)
      i += 1
    end
    label = hover >= 0 ? Block::NAMES[CREATIVE_ITEMS[hover]] : "CLICK AN ITEM TO PUT IT IN THE SELECTED SLOT"
    @ui.text((w - @ui.text_width(label, 2.0 * s)) / 2.0, last[1] + last[2] + pad + 12.0 * s, label, 2.0 * s, 1.0, 1.0, 0.8, 1.0)
  end
end
