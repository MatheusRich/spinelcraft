# The pause menu: a column of buttons and sliders for the options.
class Game
  M_RESUME = 0
  M_BRIGHTNESS = 1
  M_VOLUME = 2
  M_MUSIC = 3
  M_VIEW = 4
  M_FOV = 5
  M_FULLSCREEN = 6
  M_DEBUG = 7
  M_NEW_WORLD = 8
  M_QUIT = 9
  MENU_ITEMS = 10

  # The buttons of the title screen. Each one does what its item of the
  # pause menu does (click_menu).
  TITLE_ITEMS = [M_RESUME, M_NEW_WORLD, M_QUIT]
  # How fast the view turns behind the title, in radians each second: one
  # turn in about two minutes.
  TITLE_TURN = 0.05

  def slider?(i) = i == M_BRIGHTNESS || i == M_VOLUME || i == M_MUSIC || i == M_VIEW || i == M_FOV

  # The input on the pause screen. Esc goes back to the game. A click on a
  # button acts at once, and a slider follows the mouse while the button is
  # down. Each button and slider clicks, as in Minecraft.
  def handle_menu(escape)
    if escape
      resume
      return
    end
    w = Gfx.gfx_width.to_f
    h = Gfx.gfx_height.to_f
    s = ui_scale(h)
    @menu_drag = -1 unless Gfx.in_button(1)
    if Gfx.in_button_pressed(1)
      i = menu_hover(w, h, s)
      play(Sfx::CLICK, 0.4) if i >= 0
      if slider?(i)
        @menu_drag = i
      else
        click_menu(i)
      end
    end
    if @menu_drag >= 0
      c = menu_cell(@menu_drag, w, h, s)
      set_slider(@menu_drag, ((Gfx.in_mouse_x - c[0]) / c[2]).clamp(0.0, 1.0))
    end
  end

  # The title screen at start. The world waits behind it, and the view
  # turns (update_game). PLAY, or a second click on NEW WORLD, starts the
  # game.
  def handle_title
    return unless Gfx.in_button_pressed(1)
    h = Gfx.gfx_height.to_f
    i = title_hover(Gfx.gfx_width.to_f, h, ui_scale(h))
    return if i < 0
    play(Sfx::CLICK, 0.4)
    click_title(i)
  end

  def click_title(i)
    click_menu(TITLE_ITEMS[i])
    @title_open = false if @captured
  end

  def resume
    @captured = true
    Gfx.in_capture(1)
    @menu_drag = -1
    @menu_confirm = false
  end

  # New world asks for a second click, because the old world is lost.
  def click_menu(i)
    confirm = @menu_confirm
    @menu_confirm = false
    if i == M_RESUME
      resume
    elsif i == M_FULLSCREEN
      toggle_fullscreen
    elsif i == M_DEBUG
      @options.debug = !@options.debug
    elsif i == M_NEW_WORLD
      if confirm
        new_world
        resume
      else
        @menu_confirm = true
      end
    elsif i == M_QUIT
      @quit = true
    end
  end

  # The value of slider i, from 0 to 1.
  def slider_value(i)
    if i == M_BRIGHTNESS
      @options.brightness
    elsif i == M_VOLUME
      @options.volume
    elsif i == M_MUSIC
      @options.music
    elsif i == M_VIEW
      @options.view_share
    else
      @options.fov_share
    end
  end

  # Sets slider i to t, from 0 to 1.
  def set_slider(i, t)
    if i == M_BRIGHTNESS
      @options.brightness = t
    elsif i == M_VOLUME
      @options.volume = t
    elsif i == M_MUSIC
      @options.music = t
    elsif i == M_VIEW
      @options.slide_view(t)
    else
      @options.slide_fov(t)
      # The world stops while the menu is open, so the view takes the new
      # angle here and does not ease to it.
      @fov = @options.half_fov
    end
  end

  def menu_label(i) # rubocop:todo Metrics/CyclomaticComplexity
    if i == M_RESUME
      "BACK TO GAME"
    elsif i == M_BRIGHTNESS
      b = (@options.brightness * 100.0).round
      "BRIGHTNESS: #{b == 0 ? "MOODY" : (b == 100 ? "BRIGHT" : "#{b}%")}"
    elsif i == M_VOLUME
      v = (@options.volume * 100.0).round
      "VOLUME: #{v == 0 ? "OFF" : "#{v}%"}"
    elsif i == M_MUSIC
      v = (@options.music * 100.0).round
      "MUSIC: #{v == 0 ? "OFF" : "#{v}%"}"
    elsif i == M_VIEW
      "RENDER DISTANCE: #{@options.view.to_i} BLOCKS"
    elsif i == M_FOV
      f = @options.fov_degrees.to_i
      "FIELD OF VIEW: #{f == Options::FOV_NORMAL.to_i ? "NORMAL" : (f == Options::FOV_MAX.to_i ? "QUAKE PRO" : f.to_s)}"
    elsif i == M_FULLSCREEN
      "FULLSCREEN: #{@options.fullscreen ? "ON" : "OFF"}"
    elsif i == M_DEBUG
      "DEBUG INFO: #{@options.debug ? "ON" : "OFF"}"
    elsif i == M_NEW_WORLD
      @menu_confirm ? "LOSE THIS WORLD? CLICK AGAIN" : "NEW WORLD"
    else
      "SAVE AND QUIT"
    end
  end

  # x, y, width and height of menu item i: a column in the middle of the
  # screen, with room for the title above and the controls below.
  def menu_cell(i, w, h, s)
    bw = 400.0 * s
    bh = 40.0 * s
    gap = 8.0 * s
    column = MENU_ITEMS * bh + (MENU_ITEMS - 1) * gap
    top = (h - column - 150.0 * s) / 2.0 + 50.0 * s
    [(w - bw) / 2.0, top + i * (bh + gap), bw, bh]
  end

  # x, y, width and height of button i of the title screen, below the middle
  # of the screen.
  def title_cell(i, w, h, s)
    c = menu_cell(0, w, h, s)
    [c[0], h * 0.5 + i * (c[3] + 8.0 * s), c[2], c[3]]
  end

  def title_label(i)
    item = TITLE_ITEMS[i]
    return "PLAY" if item == M_RESUME
    return "QUIT" if item == M_QUIT
    menu_label(item)
  end

  # The menu item under the mouse, or -1.
  def menu_hover(w, h, s)
    MENU_ITEMS.times do |i|
      c = menu_cell(i, w, h, s)
      return i if mouse_in?(c[0], c[1], c[2], c[3])
    end
    -1
  end

  # The button of the title screen under the mouse, or -1.
  def title_hover(w, h, s)
    TITLE_ITEMS.size.times do |i|
      c = title_cell(i, w, h, s)
      return i if mouse_in?(c[0], c[1], c[2], c[3])
    end
    -1
  end

  # SPINELCRAFT in blocks, as assets/logo.png, above the buttons. A glyph
  # pixel is 16 pixels on a screen 720 pixels high, and less on a narrow
  # screen.
  def draw_title_screen(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.25)
    cell = 16.0 * s
    fit = (w * 0.9 / (@ui.text_width("SPINELCRAFT", 1.0) - 1.0)).floor.to_f
    cell = fit if fit < cell
    x = (w - @ui.text_width("SPINELCRAFT", cell) + cell) / 2.0
    y = h * 0.5 - 5.0 * cell - 60.0 * s
    @ui.block_text(x, y, "SPINEL", cell, Tex::SPINEL_BLOCK)
    @ui.block_text(x + @ui.text_width("SPINEL", cell), y, "CRAFT", cell, Tex::COBBLE)
    hover = title_hover(w, h, s)
    TITLE_ITEMS.size.times do |i|
      c = title_cell(i, w, h, s)
      shade = i == hover ? 0.42 : 0.26
      @ui.rect(c[0], c[1], c[2], c[3], shade, shade, shade, 0.95)
      label = title_label(i)
      @ui.text(c[0] + (c[2] - @ui.text_width(label, 3.0 * s)) / 2.0, c[1] + (c[3] - 15.0 * s) / 2.0, label, 3.0 * s, 1.0, 1.0, 1.0, 1.0)
    end
  end

  def draw_pause_screen(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.45)
    first = menu_cell(0, w, h, s)
    title = "PAUSED"
    @ui.text((w - @ui.text_width(title, 6.0 * s)) / 2.0, first[1] - 46.0 * s, title, 6.0 * s, 1.0, 1.0, 1.0, 1.0)
    hover = @menu_drag >= 0 ? @menu_drag : menu_hover(w, h, s)
    MENU_ITEMS.times do |i|
      c = menu_cell(i, w, h, s)
      shade = i == hover ? 0.42 : 0.26
      @ui.rect(c[0], c[1], c[2], c[3], shade, shade, shade, 0.95)
      if slider?(i)
        t = slider_value(i)
        @ui.rect(c[0], c[1], c[2] * t, c[3], shade + 0.12, shade + 0.12, shade + 0.16, 0.95)
        @ui.rect(c[0] + (c[2] - 6.0 * s) * t, c[1], 6.0 * s, c[3], 0.9, 0.9, 0.9, 1.0)
      end
      label = menu_label(i)
      @ui.text(c[0] + (c[2] - @ui.text_width(label, 3.0 * s)) / 2.0, c[1] + (c[3] - 15.0 * s) / 2.0, label, 3.0 * s, 1.0, 1.0, 1.0, 1.0)
    end
    last = menu_cell(MENU_ITEMS - 1, w, h, s)
    lines = ["WASD MOVE  SPACE JUMP, TWICE TO FLY  CTRL SPRINT  SHIFT DOWN",
             "LEFT CLICK BREAK/ATTACK  RIGHT CLICK PLACE  MIDDLE PICK",
             "1-9 SLOT  E INVENTORY  Q NEXT BLOCK  T CHAT  F3 DEBUG  F5 SAVE  F11 FULLSCREEN",
             "SURVIVAL: E TO CRAFT  BY HAND ONLY PLANKS, TORCHES AND A CRAFTING TABLE",
             "RIGHT-CLICK A CRAFTING TABLE FOR TOOLS  PUT FUEL IN A FURNACE TO SMELT  STONE NEEDS A PICKAXE TO DROP"]
    lines.size.times do |i|
      line = lines[i]
      @ui.text((w - @ui.text_width(line, 2.0 * s)) / 2.0, last[1] + last[3] + (24.0 + i * 18.0) * s, line, 2.0 * s, 0.9, 0.9, 0.9, 1.0)
    end
  end
end
