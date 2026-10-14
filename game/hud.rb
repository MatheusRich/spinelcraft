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
    draw_debug(s) if @show_debug
    if @dead
      draw_death_screen(w, h, s)
    elsif @inventory_open && @survival
      draw_backpack(w, h, inventory_scale(w, h))
    elsif @inventory_open
      draw_block_picker(w, h, s)
    elsif !@captured
      draw_pause_screen(w, h, s)
    end
  end

  # Tints for water, lava and damage, flames while the player burns, the
  # crosshair, and the bow pull.
  def draw_view_overlays(w, h, s)
    eye_block = @world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor)
    if Block.water?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.1, 0.25, 0.6, 0.25)
    elsif Block.lava?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.9, 0.3, 0.05, 0.75)
    end
    if @fire_time > 0.0 && @survival && !@dead
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
      slot_block = @survival ? @inv_block[i] : @hotbar[i]
      if slot_block != Block::AIR
        @ui.icon(x + 5.0 * s, y0 + 5.0 * s, size - 10.0 * s, Block::SIDE[slot_block], 1.0)
        draw_count(slot_block, @inv_count[i], x, y0, size, 2.0 * s, s) if @survival
      end
      i += 1
    end
  end

  # Hearts on the left above the hotbar, food on the right, and air bubbles
  # above the food.
  def draw_survival_bars(x0, y0, total, s)
    hy = y0 - 26.0 * s
    i = 0
    while i < 10
      hx = x0 + i * 20.0 * s
      @ui.icon(hx, hy, 18.0 * s, Tex::HEART_EMPTY, 1.0)
      hp = @health - i * 2
      if hp >= 2
        @ui.icon(hx, hy, 18.0 * s, Tex::HEART, 1.0)
      elsif hp == 1
        @ui.quad(hx, hy, 9.0 * s, 18.0 * s, Tex::HEART, 0.5, 1.0, 1.0, 1.0, 1.0, 1.0)
      end
      i += 1
    end
    i = 0
    while i < 10
      fx = x0 + total - (i + 1) * 20.0 * s
      full = @hunger - i * 2 >= 1
      @ui.icon(fx, hy, 18.0 * s, Tex::PORKCHOP, full ? 1.0 : 0.22)
      i += 1
    end
    if @air < MAX_AIR
      bubbles = @air.ceil
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
    if @survival && !@dead && !@inventory_open && room_for(Block::DIRT) == INV * STACK
      hint = "HOLD LEFT CLICK ON A TREE FOR LOGS, THEN PRESS E TO CRAFT PLANKS"
      @ui.text((w - @ui.text_width(hint, 2.0 * s)) / 2.0, y0 - 92.0 * s, hint, 2.0 * s, 1.0, 1.0, 0.7, 0.9)
    end
    if @message_time > 0.0
      tw = @ui.text_width(@message, 3.0 * s)
      @ui.text((w - tw) / 2.0, y0 - 64.0 * s, @message, 3.0 * s, 1.0, 1.0, 1.0, @message_time > 1.0 ? 1.0 : @message_time)
    end
  end

  def draw_debug(s)
    ts = 2.0 * s
    @ui.text(8.0 * s, 8.0 * s, "FPS #{@fps.round}  CPU #{@cpu_ms.round(2)}MS", ts, 1.0, 1.0, 1.0, 1.0)
    @ui.text(8.0 * s, 22.0 * s, "XYZ #{@player.x.floor} #{@player.y.floor} #{@player.z.floor}  FACES #{@faces_drawn}", ts, 1.0, 1.0, 1.0, 1.0)
    @ui.text(8.0 * s, 36.0 * s, "CHUNKS #{@visible.size / 2}  REMESH #{@mesh_ms.round(2)}MS  MOBS #{@mobs.size}", ts, 1.0, 1.0, 1.0, 1.0)
    clock = ((@time_of_day * 24.0 + 6.0) % 24.0).floor
    mode = @survival ? "SURVIVAL  DAY #{(@alive_time / DAY_SECONDS).floor + 1}" : "CREATIVE"
    @ui.text(8.0 * s, 50.0 * s, "TIME #{clock}:00  #{mode}#{@raining ? "  RAIN" : ""}", ts, 1.0, 1.0, 1.0, 1.0)
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
      shade = i == hover ? 0.55 : 0.32
      @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
      if @inv_count[i] > 0
        @ui.icon(c[0] + 6.0 * s, c[1] + 6.0 * s, c[2] - 12.0 * s, Block::SIDE[@inv_block[i]], 1.0)
        draw_count(@inv_block[i], @inv_count[i], c[0], c[1], c[2], 2.0 * s, s)
      end
      i += 1
    end
    if @chest_key >= 0
      draw_chest_panel(w, h, s, pad)
    else
      draw_recipe_panel(w, h, s, pad)
    end
    tip = @chest_key >= 0 ? "CLICK TO MOVE STACKS BETWEEN THE CHEST AND YOUR INVENTORY" : "CLICK TO MOVE STACKS  CLICK A RECIPE TO CRAFT IT"
    label = hover >= 0 && @inv_count[hover] > 0 ? Block::NAMES[@inv_block[hover]] : tip
    mid = (top[0] + bottom[0] + bottom[2]) / 2.0
    @ui.text(mid - @ui.text_width(label, 2.0 * s) / 2.0, bottom[1] + bottom[2] + pad + 12.0 * s, label, 2.0 * s, 1.0, 1.0, 0.8, 1.0)
    if @held_count > 0
      mx = Gfx.in_mouse_x
      my = Gfx.in_mouse_y
      @ui.icon(mx - 20.0 * s, my - 20.0 * s, 40.0 * s, Block::SIDE[@held_block], 1.0)
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
      shade = k == chover ? 0.55 : 0.32
      @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
      if @chest_count[k] > 0
        @ui.icon(c[0] + 3.0 * s, c[1] + 3.0 * s, c[2] - 6.0 * s, Block::SIDE[@chest_block[k]], 1.0)
        draw_count(@chest_block[k], @chest_count[k], c[0], c[1], c[2], 1.5 * s, s)
      end
      k += 1
    end
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

  # The panel grows with the shown recipes: one column, then two.
  def draw_recipe_panel(w, h, s, pad)
    shown = shown_recipes
    n = shown.size
    first = recipe_cell(0, w, h, s)
    bottom = recipe_cell(n < 1 ? 0 : (n < RECIPE_ROWS ? n - 1 : RECIPE_ROWS - 1), w, h, s)
    right = recipe_cell(n > RECIPE_ROWS ? RECIPE_ROWS : 0, w, h, s)
    @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, right[0] + right[2] - first[0] + pad * 2.0, bottom[1] + bottom[3] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    table = station_near?(AT_TABLE)
    furnace = station_near?(AT_FURNACE)
    @ui.text(first[0], first[1] - 36.0 * s, "CRAFTING", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    rhover = recipe_hover(w, h, s)
    if shown.empty?
      @ui.text(first[0], first[1] + 4.0 * s, "PICK UP ITEMS TO FIND RECIPES", 2.0 * s, 0.8, 0.8, 0.8, 1.0)
    end
    j = 0
    while j < shown.size
      k = shown[j]
      r = RECIPES[k]
      c = recipe_cell(j, w, h, s)
      can = count_items(r[0]) >= r[1] && (r[4] == BY_HAND || (r[4] == AT_TABLE ? table : furnace))
      shade = k == rhover ? 0.5 : 0.28
      fresh = @recipe_new[k] == 1
      @ui.rect(c[0], c[1], c[2], c[3], fresh ? shade + 0.12 : shade, fresh ? shade + 0.08 : shade, shade, 1.0)
      @ui.text(c[0] + c[2] - @ui.text_width("NEW", 1.5 * s) - 4.0 * s, c[1] + 3.0 * s, "NEW", 1.5 * s, 1.0, 0.85, 0.2, 1.0) if fresh
      @ui.icon(c[0] + 2.0 * s, c[1] + 2.0 * s, 22.0 * s, Block::SIDE[r[2]], can ? 1.0 : 0.35)
      bright = can ? 1.0 : 0.45
      @ui.text(c[0] + 30.0 * s, c[1] + 4.0 * s, "#{r[3]} #{Block::NAMES[r[2]]}", 2.0 * s, bright, bright, bright, 1.0)
      need = "#{r[1]} #{Block::NAMES[r[0]]}#{r[4] == AT_FURNACE ? " + FURNACE" : (r[4] == AT_TABLE ? " + TABLE" : "")}"
      @ui.text(c[0] + c[2] - @ui.text_width(need, 1.5 * s) - 4.0 * s, c[1] + 15.0 * s, need, 1.5 * s, bright * 0.95, bright * 0.85, bright * 0.55, 1.0)
      j += 1
    end
  end

  # The creative inventory screen: every block that the player can place.
  def draw_block_picker(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.55)
    first = inventory_cell(0, w, h, s)
    last = inventory_cell(PLACEABLE.size - 1, w, h, s)
    pad = 18.0 * s
    right = inventory_cell(INV_COLS - 1, w, h, s)
    @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, right[0] + right[2] - first[0] + pad * 2.0, last[1] + last[2] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    @ui.text(first[0], first[1] - 36.0 * s, "BLOCKS", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    hover = inventory_hover(w, h, s)
    i = 0
    while i < PLACEABLE.size
      c = inventory_cell(i, w, h, s)
      shade = i == hover ? 0.55 : 0.32
      @ui.rect(c[0], c[1], c[2], c[2], shade, shade, shade, 1.0)
      @ui.icon(c[0] + 6.0 * s, c[1] + 6.0 * s, c[2] - 12.0 * s, Block::SIDE[PLACEABLE[i]], 1.0)
      i += 1
    end
    label = hover >= 0 ? Block::NAMES[PLACEABLE[hover]] : "CLICK A BLOCK TO PUT IT IN THE SELECTED SLOT"
    @ui.text((w - @ui.text_width(label, 2.0 * s)) / 2.0, last[1] + last[2] + pad + 12.0 * s, label, 2.0 * s, 1.0, 1.0, 0.8, 1.0)
  end

  def draw_pause_screen(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.45)
    msg = "PAUSED - CLICK TO PLAY  N NEW WORLD"
    @ui.text((w - @ui.text_width(msg, 4.0 * s)) / 2.0, h / 2.0 - 60.0 * s, msg, 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    lines = ["WASD MOVE  SPACE JUMP  CTRL SPRINT  SHIFT DOWN",
             "LEFT CLICK BREAK/ATTACK  RIGHT CLICK PLACE  MIDDLE PICK",
             "1-9 SLOT  E INVENTORY  Q NEXT BLOCK  F FLY  G GAME MODE  T TIME  R RAIN  F3 DEBUG  F4 VIEW  F5 SAVE  F11 FULLSCREEN",
             "SURVIVAL: E TO CRAFT  BY HAND ONLY PLANKS, TORCHES AND A CRAFTING TABLE",
             "TOOLS NEED A CRAFTING TABLE NEARBY  SMELTING NEEDS A FURNACE AND FUEL  STONE NEEDS A PICKAXE TO DROP"]
    i = 0
    while i < lines.size
      line = lines[i]
      @ui.text((w - @ui.text_width(line, 2.0 * s)) / 2.0, h / 2.0 + (i * 18.0) * s, line, 2.0 * s, 0.9, 0.9, 0.9, 1.0)
      i += 1
    end
  end
end
