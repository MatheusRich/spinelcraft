# The commands of the chat and the keys of the open chat. A line that
# starts with a slash runs a command (game/command.rb reads its words).
# minecraft.wiki/w/Commands
class Game
  HELP = ["/TIME SET|ADD <TIME>  /TIME QUERY  /WEATHER CLEAR|RAIN", "/GAMEMODE SURVIVAL|CREATIVE  /TP <X> <Y> <Z>  /SPAWN",
          "/GIVE <ITEM> [COUNT]  /SUMMON <MOB> [X Y Z]", "/LOCATE TREASURE  /KILL  /SEED  /HELP"]

  # The farthest x and z of /tp. Minecraft keeps them within 30,000,000,
  # but World.key holds x and z only from -World::KEY_OFF. The 8192
  # blocks leave room for the chunks and the far terrain around the player.
  TP_LIMIT = (World::KEY_OFF - 8192).to_f
  # The names of the game modes in /gamemode: an even index is survival.
  GAME_MODES = ["SURVIVAL", "CREATIVE", "S", "C", "0", "1"]

  # The chat frees the mouse, as in Minecraft, and takes it again when it
  # closes.
  def open_chat(text)
    @chat.start(text)
    show_screen(Screen::CHAT)
    Gfx.in_text(1)
    Gfx.in_capture(0)
  end

  def close_chat
    show_screen(Screen::PLAYING)
    Gfx.in_text(0)
    Gfx.in_capture(1)
  end

  # The keys typed since the last frame edit the line. Enter runs it, Esc
  # closes the chat, Tab completes the last word, and Cmd+V (Ctrl+V on
  # other systems) pastes the clipboard.
  def handle_chat
    n = Gfx.in_typed_count
    n.times do |i|
      c = Gfx.in_typed(i)
      if c == Key::TYPED_ESCAPE
        close_chat
        return
      elsif c == Key::TYPED_ENTER
        close_chat
        run_chat(@chat.text)
        return
      elsif c == Key::TYPED_TAB
        @chat.tab
      elsif c == Key::TYPED_BACKSPACE
        @chat.backspace
      elsif c == Key::TYPED_UP || c == Key::TYPED_DOWN
        @chat.recall(c == Key::TYPED_UP ? -1 : 1)
      elsif c == Key::TYPED_PASTE
        @chat.paste(Gfx.in_clipboard)
      else
        @chat.type(c.chr)
      end
    end
  end

  def run_chat(line)
    line = line.to_s.strip
    return if line.empty?

    @chat.remember(line)
    if line.start_with?("/")
      run_command(Command.words(line))
    else
      @chat.post("<PLAYER> #{line}")
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
    return @chat.post_error("TYPE /HELP FOR THE COMMANDS") if words.empty?

    args = command_args(words)
    case words[0]
    when "TIME" then command_time(args)
    when "WEATHER" then command_weather(args)
    when "GAMEMODE" then command_gamemode(args)
    when "TP", "TELEPORT" then command_tp(args)
    when "GIVE" then command_give(args)
    when "SUMMON" then command_summon(args)
    when "KILL" then command_kill
    when "SEED" then @chat.post("SEED: [#{@seed}]")
    when "SPAWN" then command_spawn
    when "LOCATE" then args == ["TREASURE"] ? locate_treasure : @chat.post_error("USE /LOCATE TREASURE")
    when "HELP" then HELP.each { |line| @chat.post(line) }
    else @chat.post_error("UNKNOWN COMMAND: #{words[0]}")
    end
  end

  # /time set <time>, /time add <time> and /time query. The time of day
  # 0.0 is tick 0, at 6:00.
  def command_time(args)
    if args.size == 1 && args[0] == "QUERY" || args.size == 2 && args[0] == "QUERY"
      return @chat.post("THE TIME IS #{@clock.ticks}, DAY #{@clock.day + 1}")
    end
    return @chat.post_error("USE /TIME SET <TIME> OR /TIME ADD <TIME>") if args.size != 2 || (args[0] != "SET" && args[0] != "ADD")

    t = Command.ticks(args[1])
    return @chat.post_error("BAD TIME: #{args[1]}") if t < 0

    if args[0] == "SET"
      @clock.set_ticks(t)
      @chat.post("SET THE TIME TO #{t}")
    else
      @clock.add_ticks(t)
      @chat.post("ADDED #{t} TICKS")
    end
  end

  def command_weather(args)
    return @chat.post_error("USE /WEATHER CLEAR OR /WEATHER RAIN") if args.size != 1

    if args[0] == "CLEAR"
      @weather.set(false)
      @chat.post("CHANGING TO CLEAR WEATHER")
    elsif args[0] == "RAIN" || args[0] == "THUNDER"
      @weather.set(true)
      @chat.post("CHANGING TO RAIN")
    else
      @chat.post_error("UNKNOWN WEATHER: #{args[0]}")
    end
  end

  def command_gamemode(args)
    mode = args.size == 1 ? Command.find(GAME_MODES, args[0]) : -1
    return @chat.post_error("USE /GAMEMODE SURVIVAL OR /GAMEMODE CREATIVE") if mode < 0

    set_mode(mode % 2 == 0)
    @chat.post("SET OWN GAME MODE TO #{@survival ? "SURVIVAL" : "CREATIVE"} MODE")
  end

  def command_tp(args)
    return @chat.post_error("USE /TP X Y Z") if args.size != 3 || !args.all? { |a| Command.coord?(a) }

    teleport(Command.coord(args[0], @player.x.to_f, true), Command.coord(args[1], @player.y.to_f, false),
             Command.coord(args[2], @player.z.to_f, true))
  end

  # The chunks at the spawn point load first, as in respawn: before they
  # load, height_at reads the chunk that fills their slot of the ring.
  def command_spawn
    @chunk_meshes.stream(@spawn_x.floor >> 4, @spawn_z.floor >> 4, -1, SYNC_R)
    teleport(@spawn_x, @world.height_at(@spawn_x.floor, @spawn_z.floor) + 0.01, @spawn_z)
  end

  # /locate treasure: the nearest treasure chest that is not looted (see
  # Treasure#nearest), as /locate structure gives the nearest structure
  # (minecraft.wiki/w/Commands/locate).
  def locate_treasure
    site = @treasure.nearest(@player.x.to_f, @player.z.to_f)
    return @chat.post_error("NO TREASURE WITHIN #{Treasure::NEAR} BLOCKS") unless site.found?

    @chat.post("THE NEAREST TREASURE IS AT [#{site.chest_x}, #{site.chest_y}, #{site.chest_z}] (#{site.distance(@player.x.to_f, @player.z.to_f).round} BLOCKS AWAY)")
  end

  # Moves the player to x, y, z, and loads the chunks there before the
  # next step, so the player does not fall through the ground.
  def teleport(x, y, z)
    @player.move_to(x.clamp(-TP_LIMIT, TP_LIMIT), y.clamp(0.0, (WY - 2).to_f), z.clamp(-TP_LIMIT, TP_LIMIT))
    @chunk_meshes.stream(@player.x.floor >> 4, @player.z.floor >> 4, -1, SYNC_R)
    @chat.post("TELEPORTED TO #{@player.x.round(1)}, #{@player.y.round(1)}, #{@player.z.round(1)}")
  end

  # /give <item> [count]. In survival the items go to the inventory, and
  # what does not fit drops at the feet of the player. In creative the
  # item goes to the selected slot of the hotbar.
  def command_give(args)
    return @chat.post_error("USE /GIVE ITEM [COUNT]") if args.size < 1 || args.size > 2

    block = Command.item_id(args[0])
    return @chat.post_error("UNKNOWN ITEM: #{args[0]}") if block < 0

    n = args.size == 2 ? Command.whole(args[1]) : 1
    return @chat.post_error("BAD COUNT: #{args[1]}") if n < 1 || n > INV * Slots::STACK

    if @survival
      give(block, n)
    else
      @hotbar[@slot] = block
    end
    @chat.post("GAVE #{n} [#{Block::NAMES[block]}] TO PLAYER")
  end

  def give(block, n)
    left = n
    left -= 1 while left > 0 && @inv.add(block)
    x = @player.x.to_f
    y = @player.y.to_f
    z = @player.z.to_f
    if Block.tool?(block)
      left.times { drop_item(block, Block.uses(block), x, y, z, 0.0, 0.0, 0.0, PICKUP_WAIT) }
    else
      drop_item(block, left, x, y, z, 0.0, 0.0, 0.0, PICKUP_WAIT)
    end
    nil
  end

  # /summon <mob> [x y z]. Without a place, the mob comes 3 blocks in
  # front of the player.
  def command_summon(args)
    return @chat.post_error("USE /SUMMON MOB [X Y Z]") if args.size != 1 && args.size != 4

    kind = Command.mob(args[0])
    return @chat.post_error("UNKNOWN MOB: #{args[0]}") if kind < 0

    x = @player.x.to_f + Math.sin(@player.yaw) * 3.0
    y = @player.y.to_f
    z = @player.z.to_f - Math.cos(@player.yaw) * 3.0
    if args.size == 4
      return @chat.post_error("USE /SUMMON MOB [X Y Z]") unless args[1, 3].all? { |a| Command.coord?(a) }

      x = Command.coord(args[1], @player.x.to_f, true)
      y = Command.coord(args[2], @player.y.to_f, false)
      z = Command.coord(args[3], @player.z.to_f, true)
    end
    seed = (@rng.rand01 * 100000.0).to_i
    @mobs << (Mob::PASSIVE[kind] == 1 ? Animal.new(kind, x, y, z, seed) : Monster.new(kind, x, y, z, seed))
    @chat.post("SUMMONED NEW #{Mob::NAMES[kind]}")
  end

  # /kill takes all health, also in creative, as in Minecraft.
  def command_kill
    @vitals.hurt(1000)
    felt_hurt(Sfx::HURT)
    @chat.post("KILLED PLAYER")
  end
end
