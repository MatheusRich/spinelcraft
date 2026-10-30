# The commands of the chat. A line that starts with a slash runs a command
# (game/command.rb reads its words). Console checks the words, asks the game
# to act, and posts the answer in the chat. A line without a slash is a
# message of the player.
# minecraft.wiki/w/Commands
class Console
  HELP = ["/TIME SET|ADD <TIME>  /TIME QUERY  /WEATHER CLEAR|RAIN|THUNDER", "/GAMEMODE SURVIVAL|CREATIVE  /TP <X> <Y> <Z>  /SPAWN",
          "/GIVE <ITEM> [COUNT]  /SUMMON <MOB> [X Y Z]", "/LOCATE TREASURE  /KILL  /SEED  /HELP"]

  # The blocks in front of the player where /summon puts a mob that has no place.
  SUMMON_DISTANCE = 3.0
  # The farthest x and z of /tp. Minecraft keeps them within 30,000,000,
  # but World.key holds x and z only from -World::KEY_OFF. The 8192
  # blocks leave room for the chunks and the far terrain around the player.
  TP_LIMIT = (World::KEY_OFF - 8192).to_f

  def initialize(game, chat, clock, weather)
    @game = game
    @chat = chat
    @clock = clock
    @weather = weather
  end

  # Runs a line of the chat: a command, or a message of the player.
  def submit(line)
    line = line.to_s.strip
    return if line.empty?

    @chat.remember(line)
    if line.start_with?("/")
      execute(Command.words(line))
    else
      @chat.post("<PLAYER> #{line}")
    end
  end

  # Moves the player to x, y, z, and loads the chunks there before the
  # next step, so the player does not fall through the ground.
  def teleport(x, y, z)
    player = @game.player
    player.move_to(x.clamp(-TP_LIMIT, TP_LIMIT), y.clamp(0.0, (WY - 2).to_f), z.clamp(-TP_LIMIT, TP_LIMIT))
    @game.chunk_meshes.stream(player.x.floor >> 4, player.z.floor >> 4, -1, Game::SYNC_R)
    nil
  end

  private

  # The words of a command, without the target @s or @p: there is only one
  # player.
  def command_args(words)
    args = words[1, words.size - 1]
    args = args[1, args.size - 1] if args.size > 0 && args[0].start_with?("@")
    args
  end

  def execute(words)
    return @chat.post_error("TYPE /HELP FOR THE COMMANDS") if words.empty?

    args = command_args(words)
    case words[0]
    when "TIME" then time(args)
    when "WEATHER" then weather(args)
    when "GAMEMODE" then gamemode(args)
    when "TP", "TELEPORT" then tp(args)
    when "GIVE" then give(args)
    when "SUMMON" then summon(args)
    when "KILL" then kill
    when "SEED" then @chat.post("SEED: [#{@game.seed}]")
    when "SPAWN" then spawn
    when "LOCATE" then args == ["TREASURE"] ? locate_treasure : @chat.post_error("USE /LOCATE TREASURE")
    when "HELP" then HELP.each { |line| @chat.post(line) }
    else @chat.post_error("UNKNOWN COMMAND: #{words[0]}")
    end
  end

  # /time set <time>, /time add <time> and /time query. The time of day
  # 0.0 is tick 0, at 6:00.
  def time(args)
    if args.size == 1 && args[0] == "QUERY" || args.size == 2 && args[0] == "QUERY"
      return @chat.post("THE TIME IS #{@clock.ticks}, DAY #{@clock.day + 1}")
    end
    return @chat.post_error("USE /TIME SET <TIME> OR /TIME ADD <TIME>") if args.size != 2 || (args[0] != "SET" && args[0] != "ADD")

    ticks = Command.ticks(args[1])
    return @chat.post_error("BAD TIME: #{args[1]}") if ticks < 0

    if args[0] == "SET"
      @clock.set_ticks(ticks)
      @chat.post("SET THE TIME TO #{ticks}")
    else
      @clock.add_ticks(ticks)
      @chat.post("ADDED #{ticks} TICKS")
    end
  end

  # Rain turns the thunder flag off, and thunder turns it on, as in Minecraft.
  def weather(args)
    return @chat.post_error("USE /WEATHER CLEAR, RAIN OR THUNDER") if args.size != 1

    if args[0] == "CLEAR"
      @weather.clear
      @chat.post("CHANGING TO CLEAR WEATHER")
    elsif args[0] == "RAIN"
      @weather.rain.start
      @weather.thunder.stop
      @chat.post("CHANGING TO RAIN")
    elsif args[0] == "THUNDER"
      @weather.rain.start
      @weather.thunder.start
      @chat.post("CHANGING TO RAIN AND THUNDER")
    else
      @chat.post_error("UNKNOWN WEATHER: #{args[0]}")
    end
  end

  def gamemode(args)
    game_mode = args.size == 1 ? GameMode.parse(args[0]) : nil
    return @chat.post_error("USE /GAMEMODE SURVIVAL OR /GAMEMODE CREATIVE") unless game_mode

    @game.set_mode(game_mode)
    @chat.post("SET OWN GAME MODE TO #{game_mode.name} MODE")
  end

  def tp(args)
    return @chat.post_error("USE /TP X Y Z") if args.size != 3 || !args.all? { |word| Command.coord?(word) }

    player = @game.player
    teleport(Command.coord(args[0], player.x.to_f, true), Command.coord(args[1], player.y.to_f, false),
             Command.coord(args[2], player.z.to_f, true))
    post_teleport
  end

  def spawn
    @game.teleport_to_spawn
    post_teleport
  end

  def post_teleport
    player = @game.player
    @chat.post("TELEPORTED TO #{player.x.round(1)}, #{player.y.round(1)}, #{player.z.round(1)}")
  end

  # /locate treasure: the nearest treasure chest that is not looted (see
  # Treasure#nearest), as /locate structure gives the nearest structure
  # (minecraft.wiki/w/Commands/locate).
  def locate_treasure
    player = @game.player
    site = @game.treasure.nearest(player.x.to_f, player.z.to_f)
    return @chat.post_error("NO TREASURE WITHIN #{Treasure::NEAR} BLOCKS") unless site.found?

    @chat.post("THE NEAREST TREASURE IS AT [#{site.chest_x}, #{site.chest_y}, #{site.chest_z}] (#{site.distance(player.x.to_f, player.z.to_f).round} BLOCKS AWAY)")
  end

  # /give <item> [count].
  def give(args)
    return @chat.post_error("USE /GIVE ITEM [COUNT]") if args.size < 1 || args.size > 2

    block = Command.item_id(args[0])
    return @chat.post_error("UNKNOWN ITEM: #{args[0]}") if block < 0

    count = args.size == 2 ? Command.whole(args[1]) : 1
    return @chat.post_error("BAD COUNT: #{args[1]}") if count < 1 || count > Game::INV * Slots::STACK

    give_items(block, count)
    @chat.post("GAVE #{count} [#{Block::NAMES[block]}] TO PLAYER")
  end

  # In survival the items go to the inventory, and what does not fit drops
  # at the feet of the player. In creative the item goes to the selected
  # slot of the hotbar.
  def give_items(block, count)
    unless @game.game_mode.survival?
      @game.hotbar[@game.slot] = block
      return
    end

    left = count
    left -= 1 while left > 0 && @game.inv.add(block)
    player = @game.player
    x = player.x.to_f
    y = player.y.to_f
    z = player.z.to_f
    if Block.tool?(block)
      left.times { @game.drop_item(block, Block.uses(block), x, y, z, 0.0, 0.0, 0.0, Game::PICKUP_WAIT) }
    else
      @game.drop_item(block, left, x, y, z, 0.0, 0.0, 0.0, Game::PICKUP_WAIT)
    end
    nil
  end

  # /summon <mob> [x y z]. Without a place, the mob comes SUMMON_DISTANCE
  # blocks in front of the player.
  def summon(args)
    return @chat.post_error("USE /SUMMON MOB [X Y Z]") if args.size != 1 && args.size != 4

    kind = Command.mob(args[0])
    return @chat.post_error("UNKNOWN MOB: #{args[0]}") if kind < 0

    player = @game.player
    if args.size == 4
      return @chat.post_error("USE /SUMMON MOB [X Y Z]") unless args[1, 3].all? { |word| Command.coord?(word) }

      x = Command.coord(args[1], player.x.to_f, true)
      y = Command.coord(args[2], player.y.to_f, false)
      z = Command.coord(args[3], player.z.to_f, true)
    else
      x = player.x.to_f + Math.sin(player.yaw) * SUMMON_DISTANCE
      y = player.y.to_f
      z = player.z.to_f - Math.cos(player.yaw) * SUMMON_DISTANCE
    end
    seed = (@game.rng.rand01 * 100000.0).to_i
    @game.mobs << (Mob::PASSIVE[kind] == 1 ? Animal.new(kind, x, y, z, seed) : Monster.new(kind, x, y, z, seed))
    @chat.post("SUMMONED NEW #{Mob::NAMES[kind]}")
  end

  # /kill takes all health, also in creative, as in Minecraft. Spinel armor
  # does not rescue the player from it, as the Totem of Undying does not.
  def kill
    @game.player.vitals.kill
    @game.show_hurt(Sfx::HURT)
    @game.die
    @chat.post("KILLED PLAYER")
  end
end
