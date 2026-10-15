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
      @show_debug = !@show_debug
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
      @brightness
    elsif i == M_VOLUME
      @volume
    elsif i == M_MUSIC
      @music_volume
    elsif i == M_VIEW
      (@fog_end - VIEW_MIN) / (VIEW_MAX - VIEW_MIN)
    else
      (@fov_degrees - FOV_MIN) / (FOV_MAX - FOV_MIN)
    end
  end

  # Sets slider i to t, from 0 to 1. The render distance goes in steps of
  # 100 blocks, and the field of view in steps of 1 degree.
  def set_slider(i, t)
    if i == M_BRIGHTNESS
      @brightness = t
    elsif i == M_VOLUME
      @volume = t
    elsif i == M_MUSIC
      @music_volume = t
    elsif i == M_VIEW
      @fog_end = ((VIEW_MIN + t * (VIEW_MAX - VIEW_MIN)) / 100.0).round * 100.0
    else
      @fov_degrees = (FOV_MIN + t * (FOV_MAX - FOV_MIN)).round.to_f
      # The world stops while the menu is open, so the view takes the new
      # angle here and does not ease to it.
      @fov = option_fov
    end
  end

  # The half angle of the view in radians for the field of view option.
  def option_fov = @fov_degrees * Math::PI / 360.0

  # Writes the options to @options_path, one "name:value" line each, as in
  # the options.txt of Minecraft.
  def save_options
    File.open(@options_path, "w") do |f|
      f.write("brightness:#{@brightness}\nvolume:#{@volume}\nmusic:#{@music_volume}\nview:#{@fog_end}\nfov:#{@fov_degrees}\nfullscreen:#{@fullscreen}\ndebug:#{@show_debug}\n")
    end
  end

  # Reads the options that save_options wrote. An option that is not in the
  # file keeps its default.
  def load_options
    return unless File.exist?(@options_path)
    File.binread(@options_path).split("\n").each do |line|
      parts = line.split(":")
      next if parts.size != 2
      name = parts[0]
      value = parts[1]
      if name == "brightness"
        @brightness = value.to_f.clamp(0.0, 1.0)
      elsif name == "volume"
        @volume = value.to_f.clamp(0.0, 1.0)
      elsif name == "music"
        @music_volume = value.to_f.clamp(0.0, 1.0)
      elsif name == "view"
        @fog_end = value.to_f.clamp(VIEW_MIN, VIEW_MAX)
      elsif name == "fov"
        @fov_degrees = value.to_f.clamp(FOV_MIN, FOV_MAX)
      elsif name == "fullscreen"
        @fullscreen = value == "true"
      elsif name == "debug"
        @show_debug = value == "true"
      end
    end
  end

  def menu_label(i)
    if i == M_RESUME
      "BACK TO GAME"
    elsif i == M_BRIGHTNESS
      b = (@brightness * 100.0).round
      "BRIGHTNESS: #{b == 0 ? "MOODY" : (b == 100 ? "BRIGHT" : "#{b}%")}"
    elsif i == M_VOLUME
      v = (@volume * 100.0).round
      "VOLUME: #{v == 0 ? "OFF" : "#{v}%"}"
    elsif i == M_MUSIC
      v = (@music_volume * 100.0).round
      "MUSIC: #{v == 0 ? "OFF" : "#{v}%"}"
    elsif i == M_VIEW
      "RENDER DISTANCE: #{@fog_end.to_i} BLOCKS"
    elsif i == M_FOV
      f = @fov_degrees.to_i
      "FIELD OF VIEW: #{f == FOV_NORMAL.to_i ? "NORMAL" : (f == FOV_MAX.to_i ? "QUAKE PRO" : f.to_s)}"
    elsif i == M_FULLSCREEN
      "FULLSCREEN: #{@fullscreen ? "ON" : "OFF"}"
    elsif i == M_DEBUG
      "DEBUG INFO: #{@show_debug ? "ON" : "OFF"}"
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

  # The menu item under the mouse, or -1.
  def menu_hover(w, h, s)
    i = 0
    while i < MENU_ITEMS
      c = menu_cell(i, w, h, s)
      return i if mouse_in?(c[0], c[1], c[2], c[3])
      i += 1
    end
    -1
  end

  def draw_pause_screen(w, h, s)
    @ui.rect(0.0, 0.0, w, h, 0.0, 0.0, 0.0, 0.45)
    first = menu_cell(0, w, h, s)
    title = "PAUSED"
    @ui.text((w - @ui.text_width(title, 6.0 * s)) / 2.0, first[1] - 46.0 * s, title, 6.0 * s, 1.0, 1.0, 1.0, 1.0)
    hover = @menu_drag >= 0 ? @menu_drag : menu_hover(w, h, s)
    i = 0
    while i < MENU_ITEMS
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
      i += 1
    end
    last = menu_cell(MENU_ITEMS - 1, w, h, s)
    lines = ["WASD MOVE  SPACE JUMP, TWICE TO FLY  CTRL SPRINT  SHIFT DOWN",
             "LEFT CLICK BREAK/ATTACK  RIGHT CLICK PLACE  MIDDLE PICK",
             "1-9 SLOT  E INVENTORY  Q NEXT BLOCK  T CHAT  F3 DEBUG  F5 SAVE  F11 FULLSCREEN",
             "SURVIVAL: E TO CRAFT  BY HAND ONLY PLANKS, TORCHES AND A CRAFTING TABLE",
             "RIGHT-CLICK A CRAFTING TABLE FOR TOOLS  PUT FUEL IN A FURNACE TO SMELT  STONE NEEDS A PICKAXE TO DROP"]
    i = 0
    while i < lines.size
      line = lines[i]
      @ui.text((w - @ui.text_width(line, 2.0 * s)) / 2.0, last[1] + last[3] + (24.0 + i * 18.0) * s, line, 2.0 * s, 0.9, 0.9, 0.9, 1.0)
      i += 1
    end
  end
end
