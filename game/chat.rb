# The chat line: T opens it, and / opens it with a slash typed. A line
# that starts with a slash runs a command (game/command.rb reads its
# words). minecraft.wiki/w/Chat and minecraft.wiki/w/Commands
class Game
  # The lines that the chat keeps, and the seconds that a new line shows
  # while the chat is closed.
  CHAT_LINES = 10
  CHAT_SHOW = 10.0
  # The longest line that the player can type. Minecraft allows 256
  # characters, but 100 fit on a small window.
  CHAT_MAX = 100
  # The most names of Tab completion that show at once.
  CHAT_MATCHES = 10
  # The lines that Up and Down walk through.
  CHAT_HISTORY = 50
  HELP = ["/TIME SET|ADD <TIME>  /TIME QUERY  /WEATHER CLEAR|RAIN", "/GAMEMODE SURVIVAL|CREATIVE  /TP <X> <Y> <Z>  /SPAWN",
          "/GIVE <ITEM> [COUNT]  /SUMMON <MOB> [X Y Z]", "/KILL  /SEED  /HELP"]

  # The names of the game modes in /gamemode: an even index is survival.
  GAME_MODES = ["SURVIVAL", "CREATIVE", "S", "C", "0", "1"]

  # The chat frees the mouse, as in Minecraft, and takes it again when it
  # closes.
  def open_chat(text)
    @chat_open = true
    @chat_text = text
    @chat_back = @chat_history.size
    @tab_matches.clear
    Gfx.in_text(1)
    Gfx.in_capture(0)
  end

  def close_chat
    @chat_open = false
    Gfx.in_text(0)
    Gfx.in_capture(1)
  end

  # The keys typed since the last frame edit the line. Enter runs it, Esc
  # closes the chat, and Tab completes the last word.
  def handle_chat
    n = Gfx.in_typed_count
    i = 0
    while i < n
      c = Gfx.in_typed(i)
      @tab_matches.clear if c != Key::TYPED_TAB
      if c == Key::TYPED_TAB
        tab_chat
      elsif c == Key::TYPED_ESCAPE
        close_chat
        return
      elsif c == Key::TYPED_ENTER
        close_chat
        run_chat(@chat_text)
        return
      elsif c == Key::TYPED_BACKSPACE
        @chat_text = @chat_text[0, @chat_text.size - 1].to_s if @chat_text.size > 0
      elsif c == Key::TYPED_UP || c == Key::TYPED_DOWN
        recall_chat(c == Key::TYPED_UP ? -1 : 1)
      elsif @chat_text.size < CHAT_MAX
        @chat_text += c.chr
      end
      i += 1
    end
  end

  # Tab puts the first name that completes the last word on the line, and
  # each next Tab the next name, as in Minecraft. The names come from
  # Command.complete when the first Tab comes.
  def tab_chat
    if @tab_matches.empty?
      @tab_matches = Command.complete(@chat_text)
      return if @tab_matches.empty?
      @tab_base = @chat_text[0, Command.last_word_at(@chat_text)].to_s
      @tab_at = 0
    end
    @chat_text = @tab_base + @tab_matches[@tab_at]
    @tab_at = (@tab_at + 1) % @tab_matches.size
  end

  # The names that Tab can put on the line now: the ones that it cycles
  # through, or the ones that complete the last word.
  def chat_matches = @tab_matches.empty? ? Command.complete(@chat_text) : @tab_matches

  # Puts the line step lines back or forward in the history on the line.
  # Past the newest line, the line is empty.
  def recall_chat(step)
    @chat_back = (@chat_back + step).clamp(0, @chat_history.size)
    @chat_text = @chat_back < @chat_history.size ? @chat_history[@chat_back].to_s : ""
  end

  def run_chat(line)
    line = line.to_s.strip
    return if line.empty?
    @chat_history << line
    @chat_history.shift if @chat_history.size > CHAT_HISTORY
    if line.start_with?("/")
      run_command(Command.words(line))
    else
      chat_print("<PLAYER> #{line}", false)
    end
  end

  def chat_print(text, error)
    @chat_lines << text.upcase
    @chat_errors << (error ? 1 : 0)
    @chat_ages << 0.0
    if @chat_lines.size > CHAT_LINES
      @chat_lines.shift
      @chat_errors.shift
      @chat_ages.shift
    end
  end

  def chat_error(text) = chat_print(text, true)

  def age_chat(dt)
    i = 0
    while i < @chat_ages.size
      @chat_ages[i] += dt
      i += 1
    end
  end

  # The words of a command, without the target @s or @p: there is only one
  # player.
  def command_args(words)
    args = words[1, words.size - 1]
    args = args[1, args.size - 1] if args.size > 0 && args[0].start_with?("@")
    args
  end

  def run_command(words)
    return chat_error("TYPE /HELP FOR THE COMMANDS") if words.empty?
    args = command_args(words)
    case words[0]
    when "TIME" then command_time(args)
    when "WEATHER" then command_weather(args)
    when "GAMEMODE" then command_gamemode(args)
    when "TP", "TELEPORT" then command_tp(args)
    when "GIVE" then command_give(args)
    when "SUMMON" then command_summon(args)
    when "KILL" then command_kill
    when "SEED" then chat_print("SEED: [#{@seed}]", false)
    when "SPAWN" then command_spawn
    when "HELP" then HELP.each { |line| chat_print(line, false) }
    else chat_error("UNKNOWN COMMAND: #{words[0]}")
    end
  end

  # /time set <time>, /time add <time> and /time query. The time of day
  # 0.0 is tick 0, at 6:00.
  def command_time(args)
    if args.size == 1 && args[0] == "QUERY" || args.size == 2 && args[0] == "QUERY"
      return chat_print("THE TIME IS #{(@time_of_day * Command::DAY_TICKS).to_i}, DAY #{@day + 1}", false)
    end
    return chat_error("USE /TIME SET <TIME> OR /TIME ADD <TIME>") if args.size != 2 || (args[0] != "SET" && args[0] != "ADD")
    t = Command.ticks(args[1])
    return chat_error("BAD TIME: #{args[1]}") if t < 0
    if args[0] == "SET"
      @time_of_day = (t % Command::DAY_TICKS) / Command::DAY_TICKS.to_f
      chat_print("SET THE TIME TO #{t}", false)
    else
      update_clock(t * DAY_SECONDS / Command::DAY_TICKS)
      chat_print("ADDED #{t} TICKS", false)
    end
  end

  def command_weather(args)
    return chat_error("USE /WEATHER CLEAR OR /WEATHER RAIN") if args.size != 1
    if args[0] == "CLEAR"
      @weather.set(false)
      chat_print("CHANGING TO CLEAR WEATHER", false)
    elsif args[0] == "RAIN" || args[0] == "THUNDER"
      @weather.set(true)
      chat_print("CHANGING TO RAIN", false)
    else
      chat_error("UNKNOWN WEATHER: #{args[0]}")
    end
  end

  def command_gamemode(args)
    mode = args.size == 1 ? Command.find(GAME_MODES, args[0]) : -1
    return chat_error("USE /GAMEMODE SURVIVAL OR /GAMEMODE CREATIVE") if mode < 0
    set_mode(mode % 2 == 0)
    chat_print("SET OWN GAME MODE TO #{@survival ? "SURVIVAL" : "CREATIVE"} MODE", false)
  end

  def command_tp(args)
    return chat_error("USE /TP X Y Z") if args.size != 3 || !args.all? { |a| Command.coord?(a) }
    teleport(Command.coord(args[0], @player.x.to_f, true), Command.coord(args[1], @player.y.to_f, false),
             Command.coord(args[2], @player.z.to_f, true))
  end

  # The chunks at the spawn point load first, as in respawn: before they
  # load, height_at reads the chunk that fills their slot of the ring.
  def command_spawn
    stream_around(@spawn_x.floor >> 4, @spawn_z.floor >> 4, -1, SYNC_R)
    teleport(@spawn_x, @world.height_at(@spawn_x.floor, @spawn_z.floor) + 0.01, @spawn_z)
  end

  # Moves the player to x, y, z, and loads the chunks there before the
  # next step, so the player does not fall through the ground.
  def teleport(x, y, z)
    @player.x = x
    @player.y = y.clamp(0.0, (WY - 2).to_f)
    @player.z = z
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    @player.fall_start = @player.y
    stream_around(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    chat_print("TELEPORTED TO #{@player.x.round(1)}, #{@player.y.round(1)}, #{@player.z.round(1)}", false)
  end

  # /give <item> [count]. In survival the items go to the inventory, and
  # what does not fit drops at the feet of the player. In creative the
  # item goes to the selected slot of the hotbar.
  def command_give(args)
    return chat_error("USE /GIVE ITEM [COUNT]") if args.size < 1 || args.size > 2
    b = Command.item(args[0])
    return chat_error("UNKNOWN ITEM: #{args[0]}") if b < 0
    n = args.size == 2 ? Command.whole(args[1]) : 1
    return chat_error("BAD COUNT: #{args[1]}") if n < 1 || n > INV * Slots::STACK
    if @survival
      give(b, n)
    else
      @hotbar[@slot] = b
    end
    chat_print("GAVE #{n} [#{Block::NAMES[b]}] TO PLAYER", false)
  end

  def give(b, n)
    left = n
    left -= 1 while left > 0 && @inv.add(b)
    x = @player.x.to_f
    y = @player.y.to_f
    z = @player.z.to_f
    if Block.tool?(b)
      left.times { drop_item(b, Block.uses(b), x, y, z, 0.0, 0.0, 0.0, PICKUP_WAIT) }
    else
      drop_item(b, left, x, y, z, 0.0, 0.0, 0.0, PICKUP_WAIT)
    end
    nil
  end

  # /summon <mob> [x y z]. Without a place, the mob comes 3 blocks in
  # front of the player.
  def command_summon(args)
    return chat_error("USE /SUMMON MOB [X Y Z]") if args.size != 1 && args.size != 4
    kind = Command.mob(args[0])
    return chat_error("UNKNOWN MOB: #{args[0]}") if kind < 0
    x = @player.x.to_f + Math.sin(@player.yaw) * 3.0
    y = @player.y.to_f
    z = @player.z.to_f - Math.cos(@player.yaw) * 3.0
    if args.size == 4
      return chat_error("USE /SUMMON MOB [X Y Z]") unless args[1, 3].all? { |a| Command.coord?(a) }
      x = Command.coord(args[1], @player.x.to_f, true)
      y = Command.coord(args[2], @player.y.to_f, false)
      z = Command.coord(args[3], @player.z.to_f, true)
    end
    @mobs << Mob.new(kind, x, y, z, (@rng.rand01 * 100000.0).to_i)
    chat_print("SUMMONED NEW #{Mob::NAMES[kind]}", false)
  end

  # /kill takes all health, also in creative, as in Minecraft.
  def command_kill
    @vitals.hurt(1000)
    felt_hurt(Sfx::HURT)
    chat_print("KILLED PLAYER", false)
  end
end
