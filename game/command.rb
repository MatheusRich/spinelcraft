# The parts of a chat command that need no game: the words of a line,
# numbers, coordinates, times and names. minecraft.wiki/w/Commands
module Command
  # The ticks of a day, and the times that /time set takes by name.
  # minecraft.wiki/w/Commands/time
  DAY_TICKS = 24000
  TIME_NAMES = ["DAY", "NOON", "NIGHT", "MIDNIGHT"]
  TIME_TICKS = [1000, 6000, 13000, 18000]

  # The commands, in the order that Tab shows them.
  NAMES = ["GAMEMODE", "GIVE", "HELP", "KILL", "SEED", "SPAWN", "SUMMON", "TELEPORT", "TIME", "TP", "WEATHER"]

  # The names that complete the last word of a command line, in small
  # letters, with _ for each space: a command, or a name that the command
  # takes at that place. Empty when no name fits.
  def self.complete(line)
    out = [""]
    out.clear
    return out unless line.start_with?("/")
    at = last_word_at(line)
    word = line[at, line.size - at].to_s.upcase
    choices(words(line[0, at].to_s), at == 1).each do |name|
      typed = name.split(" ").join("_")
      out << typed.downcase if typed.start_with?(word)
    end
    out
  end

  # Where the last word of a line starts: after the last space, or after
  # the slash of a command.
  def self.last_word_at(line)
    i = line.size - 1
    i -= 1 while i >= 0 && line[i] != " "
    i < 0 && line.start_with?("/") ? 1 : i + 1
  end

  # The names that can come after the words before, or the commands when
  # the word is the first (first).
  def self.choices(before, first)
    return NAMES if first
    k = before.size - 1
    k -= 1 if before.size > 1 && before[1].start_with?("@")
    cmd = before.size > 0 ? before[0] : ""
    if k == 0
      return item_names if cmd == "GIVE"
      return Mob::NAMES if cmd == "SUMMON"
      return ["SURVIVAL", "CREATIVE"] if cmd == "GAMEMODE"
      return ["SET", "ADD", "QUERY"] if cmd == "TIME"
      return ["CLEAR", "RAIN"] if cmd == "WEATHER"
    elsif k == 1 && cmd == "TIME" && before[before.size - 1] == "SET"
      return TIME_NAMES
    end
    none = [""]
    none.clear
    none
  end

  # The name of each block and item once, without AIR.
  def self.item_names
    out = [""]
    out.clear
    i = 1
    while i < Block::NAMES.size
      out << Block::NAMES[i] if find(Block::NAMES, Block::NAMES[i]) == i
      i += 1
    end
    out
  end

  def self.words(line)
    s = line.start_with?("/") ? line[1, line.size - 1] : line
    s.upcase.split(" ")
  end

  # True when s is a number: digits with one dot at most and a minus sign
  # at the start.
  def self.number?(s)
    digits = 0
    dots = 0
    i = 0
    while i < s.size
      c = s[i]
      if c >= "0" && c <= "9"
        digits += 1
      elsif c == "."
        dots += 1
      elsif c != "-" || i > 0
        return false
      end
      i += 1
    end
    digits > 0 && dots <= 1
  end

  # True when s is a coordinate: a number, or ~ with a number or nothing
  # after it.
  def self.coord?(s)
    return number?(s) unless s.start_with?("~")
    s.size == 1 || number?(s[1, s.size - 1])
  end

  # The coordinate s. A ~ coordinate is relative to base. A whole x or z
  # goes to the center of its block (center), as in Minecraft.
  # minecraft.wiki/w/Coordinates
  def self.coord(s, base, center)
    return base + (s.size == 1 ? 0.0 : s[1, s.size - 1].to_f) if s.start_with?("~")
    v = s.to_f
    center && !s.include?(".") ? v + 0.5 : v
  end

  # The ticks in s: a name of TIME_NAMES, or a number with the unit d
  # (days), s (seconds) or t (ticks, the default). -1 when s is not a time.
  def self.ticks(s)
    named = find(TIME_NAMES, s)
    return TIME_TICKS[named] if named >= 0
    unit = 1
    n = s
    last = s.size > 0 ? s[s.size - 1] : ""
    if last == "D" || last == "S" || last == "T"
      unit = last == "D" ? DAY_TICKS : (last == "S" ? 20 : 1)
      n = s[0, s.size - 1]
    end
    return -1 unless number?(n) && !n.start_with?("-")
    (n.to_f * unit).to_i
  end

  # The block or item that a name means: its name in Block::NAMES with _
  # for each space, with or without "minecraft:". -1 when no block has it.
  def self.item(name)
    n = name.start_with?("MINECRAFT:") ? name[10, name.size - 10] : name
    i = find(Block::NAMES, n.split("_").join(" "))
    i == Block::AIR ? -1 : i
  end

  # The kind of mob with the name, or -1.
  def self.mob(name)
    n = name.start_with?("MINECRAFT:") ? name[10, name.size - 10] : name
    find(Mob::NAMES, n)
  end

  # The index of the first s in names, or -1. Array#index gives Spinel an
  # untyped result.
  def self.find(names, s)
    i = 0
    while i < names.size
      return i if names[i] == s
      i += 1
    end
    -1
  end

  # The whole number in s, or -1 when s is not one.
  def self.whole(s)
    return -1 unless number?(s) && !s.include?(".") && !s.start_with?("-")
    s.to_i
  end
end
