# The light of a cell for the rules of the game: monster spawns and the
# cave sounds. Light comes from the open sky, torches, lava and jack
# o'lanterns. The Mesher has its own light for the faces of the chunks.
# minecraft.wiki/w/Light
class Light
  # Light in Minecraft: a torch has 14, lava and a jack o'lantern 15, and a
  # cell under the open sky 15 by day. Light goes down by 1 for each step
  # to a cell that is not opaque, so walls stop it. minecraft.wiki/w/Light
  # and /w/Jack_o'Lantern
  TORCH = 14
  LAVA = 15
  # The farthest that the search goes from its cell. Sky light at most 15
  # and lava light reach no farther.
  REACH = 15
  SIDE = REACH * 2 + 1

  # The sky light of Minecraft under the open sky by the time of day, in
  # clear weather and in rain. DUSK has the first tick of each level as it
  # goes down from the top level to 4, and DAWN the first tick of each level
  # as it goes up from 5 to the top level. A day has 24000 ticks, and tick
  # 6000 is noon. minecraft.wiki/w/Light
  SKY_TOP_CLEAR = 15
  SKY_DUSK_CLEAR = [12041, 12210, 12377, 12542, 12705, 12867, 13027, 13188, 13348, 13509, 13670]
  SKY_DAWN_CLEAR = [22331, 22492, 22653, 22813, 22974, 23135, 23297, 23460, 23624, 23791, 23961]
  SKY_TOP_RAIN = 12
  SKY_DUSK_RAIN = [12010, 12256, 12497, 12734, 12969, 13203, 13436, 13670]
  SKY_DAWN_RAIN = [22331, 22566, 22799, 23032, 23267, 23505, 23746, 23992]

  def initialize(world)
    @world = world
    # The search marks each cell of its cube that it has seen with the
    # stamp of the search, and keeps a queue of cells and steps.
    @seen = Array.new(SIDE * SIDE * SIDE, 0)
    @stamp = 0
    @queue = Array.new(0, 0)
    nil
  end

  # The sky light under the open sky at the tick of the day (Clock#ticks),
  # from SKY_DUSK and SKY_DAWN.
  def self.sky(tick, raining:)
    dawn = raining ? SKY_DAWN_RAIN : SKY_DAWN_CLEAR
    ticks = tick >= dawn[0] ? dawn : (raining ? SKY_DUSK_RAIN : SKY_DUSK_CLEAR)
    passed = 0
    ticks.size.times { |index| passed += 1 if tick >= ticks[index] }
    tick >= dawn[0] ? 4 + passed : (raining ? SKY_TOP_RAIN : SKY_TOP_CLEAR) - passed
  end

  # True when a torch or lava is close enough to light x, y, z if no wall
  # were in the way: the steps along x, y and z are a shortest path.
  def lamp_near?(x, y, z)
    cx = (x - LAVA) >> 4
    while cx <= (x + LAVA) >> 4
      cz = (z - LAVA) >> 4
      while cz <= (z + LAVA) >> 4
        list = @world.torches_of(cx, cz)
        (0...list.size).step(3) do |index|
          return true if (list[index] - x).abs + (list[index + 1] - y).abs + (list[index + 2] - z).abs < LAVA
        end
        cz += 1
      end
      cx += 1
    end
    false
  end

  # The sky light of the cell x, y, z, or -1 when a torch or lava lights it.
  # A search goes out from the cell through the cells that are not opaque,
  # the way that light comes in. The sky light is sky minus the steps to
  # the nearest cell under the open sky. It is 0 when no such cell is fewer
  # than sky_reach steps away. The search looks for torches and lava only
  # when lamp is true.
  def level(x, y, z, sky, lamp, sky_reach) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    reach = lamp ? REACH : sky_reach - 1
    return 0 if reach < 0
    @stamp += 1
    stamp = @stamp
    queue = @queue
    queue.clear
    area = SIDE * SIDE
    start = (REACH * SIDE + REACH) * SIDE + REACH
    @seen[start] = stamp
    queue << start << 0
    sky_steps = -1
    head = 0
    while head < queue.size
      # Spinel does not type the queue, so to_i gives the search Integers.
      cell = queue[head].to_i
      steps = queue[head + 1].to_i
      head += 2
      cx = x + cell / area - REACH
      cy = y + (cell / SIDE) % SIDE - REACH
      cz = z + cell % SIDE - REACH
      if sky_steps < 0 && steps < sky_reach && cy >= @world.height_at(cx, cz)
        sky_steps = steps
        break unless lamp
      end
      return -1 if lamp && steps < TORCH && Block.torch?(@world.get(cx, cy, cz))
      next if steps >= reach
      side = 0
      while side < 6
        nx = cx + (side == 0 ? 1 : (side == 1 ? -1 : 0))
        ny = cy + (side == 2 ? 1 : (side == 3 ? -1 : 0))
        nz = cz + (side == 4 ? 1 : (side == 5 ? -1 : 0))
        next_cell = ((nx - x + REACH) * SIDE + ny - y + REACH) * SIDE + nz - z + REACH
        if ny >= 0 && ny < WY && @seen[next_cell] != stamp
          @seen[next_cell] = stamp
          block = @world.get(nx, ny, nz)
          return -1 if lamp && (block == Block::LAVA || Block.jack_o_lantern?(block)) && steps + 1 < LAVA
          queue << next_cell << steps + 1 if Block::OPAQUE[block] == 0
        end
        side += 1
      end
    end
    sky_steps < 0 ? 0 : sky - sky_steps
  end
end
