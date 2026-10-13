# The 2D overlay: crosshair, hotbar, health and hunger, messages, and menus.
class Game
  def build_ui(w, h)
    @ui.clear
    s = ui_scale(h)
    draw_view_overlays(w, h, s)
    size = 44.0 * s
    gap = 4.0 * s
    total = size * 9.0 + gap * 8.0
    x0 = (w - total) / 2.0
    y0 = h - size - 12.0 * s
    draw_hotbar(x0, y0, size, gap, s)
    draw_survival_bars(x0, y0, total, s) if @survival
    draw_messages(w, y0, s)
    draw_debug(s) if @show_debug
    if @dead
      draw_death_screen(w, h, s)
    elsif @inventory_open && @survival
      draw_backpack(w, h, s)
    elsif @inventory_open
      draw_block_picker(w, h, s)
    elsif !@captured
      draw_pause_screen(w, h, s)
    end
  end

  # Tints for water, lava and damage, the crosshair, the bow pull, and the
  # held block.
  def draw_view_overlays(w, h, s)
    eye_block = @world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor)
    if Block.water?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.1, 0.25, 0.6, 0.25)
    elsif Block.lava?(eye_block)
      @ui.rect(0.0, 0.0, w, h, 0.9, 0.3, 0.05, 0.75)
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
    # hand: the selected block, bobbing when used
    b = current_block
    if b != Block::AIR && @captured
      bob = @swing > 0.0 ? @swing * 120.0 * s : 0.0
      hs = 150.0 * s
      @ui.icon(w - hs - 90.0 * s - bob * 0.5, h - hs + 30.0 * s + bob, hs, Block::SIDE[b], 0.85)
    end
  end

  def draw_hotbar(x0, y0, size, gap, s)
    total = size * 9.0 + gap * 8.0
    @ui.rect(x0 - gap, y0 - gap, total + gap * 2.0, size + gap * 2.0, 0.0, 0.0, 0.0, 0.45)
    i = 0
    while i < 9
      x = x0 + i * (size + gap)
      if i == @slot
        @ui.rect(x - 3.0 * s, y0 - 3.0 * s, size + 6.0 * s, size + 6.0 * s, 1.0, 1.0, 1.0, 0.95)
      end
      @ui.rect(x, y0, size, size, 0.25, 0.25, 0.25, 0.9)
      slot_block = @survival ? @inv_block[i] : @hotbar[i]
      if slot_block != Block::AIR
        @ui.icon(x + 5.0 * s, y0 + 5.0 * s, size - 10.0 * s, Block::SIDE[slot_block], 1.0)
        if @survival
          n = @inv_count[i].to_s
          @ui.text(x + size - @ui.text_width(n, 2.0 * s) - 1.0 * s, y0 + size - 12.0 * s, n, 2.0 * s, 1.0, 1.0, 1.0, 1.0)
        end
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
    if @air < 10.0
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
      hint = "HOLD LEFT CLICK ON A TREE FOR LOGS, THEN PRESS C TO CRAFT PLANKS"
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
    @ui.text(8.0 * s, 50.0 * s, "TIME #{clock}:00  #{mode}", ts, 1.0, 1.0, 1.0, 1.0)
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
    top = pack_cell(9, w, h, s)
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
        n = @inv_count[i].to_s
        @ui.text(c[0] + c[2] - @ui.text_width(n, 2.0 * s) - 1.0 * s, c[1] + c[2] - 12.0 * s, n, 2.0 * s, 1.0, 1.0, 1.0, 1.0)
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
      n = @held_count.to_s
      @ui.text(mx + 20.0 * s - @ui.text_width(n, 2.0 * s), my + 8.0 * s, n, 2.0 * s, 1.0, 1.0, 1.0, 1.0)
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
        n = @chest_count[k].to_s
        @ui.text(c[0] + c[2] - @ui.text_width(n, 1.5 * s), c[1] + c[2] - 8.0 * s, n, 1.5 * s, 1.0, 1.0, 1.0, 1.0)
      end
      k += 1
    end
  end

  def draw_recipe_panel(w, h, s, pad)
    first = recipe_cell(0, w, h, s)
    last_r = recipe_cell(RECIPES.size - 1, w, h, s)
    @ui.rect(first[0] - pad, first[1] - pad - 40.0 * s, first[2] + pad * 2.0, last_r[1] + last_r[3] - first[1] + pad * 2.0 + 40.0 * s, 0.18, 0.18, 0.2, 0.95)
    @ui.text(first[0], first[1] - 36.0 * s, "CRAFTING", 4.0 * s, 1.0, 1.0, 1.0, 1.0)
    rhover = recipe_hover(w, h, s)
    k = 0
    while k < RECIPES.size
      r = RECIPES[k]
      c = recipe_cell(k, w, h, s)
      can = count_items(r[0]) >= r[1]
      shade = k == rhover ? 0.5 : 0.28
      @ui.rect(c[0], c[1], c[2], c[3], shade, shade, shade, 1.0)
      @ui.icon(c[0] + 2.0 * s, c[1] + 2.0 * s, 22.0 * s, Block::SIDE[r[2]], can ? 1.0 : 0.35)
      bright = can ? 1.0 : 0.45
      @ui.text(c[0] + 30.0 * s, c[1] + 4.0 * s, "#{r[3]} #{Block::NAMES[r[2]]}", 2.0 * s, bright, bright, bright, 1.0)
      need = "#{r[1]} #{Block::NAMES[r[0]]}"
      @ui.text(c[0] + c[2] - @ui.text_width(need, 1.5 * s) - 4.0 * s, c[1] + 15.0 * s, need, 1.5 * s, bright * 0.95, bright * 0.85, bright * 0.55, 1.0)
      k += 1
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
             "1-9 SLOT  E INVENTORY  Q NEXT BLOCK  F FLY  G GAME MODE  T TIME  F3 DEBUG  F4 VIEW  F5 SAVE  F11 FULLSCREEN",
             "SURVIVAL: C CRAFTS THE SELECTED STACK  LOG>PLANKS  COAL>TORCHES  SAND>GLASS",
             "3 PLANKS/COBBLE/IRON/DIAMOND > PICKAXE  STONE NEEDS A PICKAXE TO DROP"]
    i = 0
    while i < lines.size
      line = lines[i]
      @ui.text((w - @ui.text_width(line, 2.0 * s)) / 2.0, h / 2.0 + (i * 18.0) * s, line, 2.0 * s, 0.9, 0.9, 0.9, 1.0)
      i += 1
    end
  end
end
