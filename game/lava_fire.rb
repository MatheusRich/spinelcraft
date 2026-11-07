# Lava that lights fires near it. LavaFire does not change the world. It
# adds its changes to the list of Game, four Integers for each block (x,
# y, z and the new block), and Game puts them in the world with
# Game#set_block. minecraft.wiki/w/Lava
class LavaFire
  # A block gets a random tick about each 68 seconds: 3 in each section of
  # 16 x 16 x 16 blocks in each tick. minecraft.wiki/w/Tick
  RANDOM_TICK = 4096.0 / 60.0
  # A random tick of lava lights up to 2 cells, each 1 up from the last
  # and 1 to a side at most, or tries 3 cells beside it. It stops at a
  # block that stops motion. minecraft.wiki/w/Lava gives the cells, but
  # not the tries, which are the ones of the Java code (LavaFluid).
  STEPS = 3
  SIDE_TRIES = 3
  # Lava lights fires in the chunks up to this many chunks from the
  # player. Minecraft gives random ticks to each chunk in the simulation
  # distance. The game keeps them near the player, as Plants does.
  REACH_CHUNKS = 2

  # changes is the list of Game that the changes go in.
  def initialize(world, changes, rng)
    @world = world
    @changes = changes
    @rng = rng
    nil
  end

  # The random ticks of dt seconds of the lava in the chunks up to
  # REACH_CHUNKS from the block x, z (see tick_lava).
  def tick_near(x, z, dt)
    chunk_x = x >> 4
    chunk_z = z >> 4
    (-REACH_CHUNKS..REACH_CHUNKS).each do |side_x|
      (-REACH_CHUNKS..REACH_CHUNKS).each { |side_z| tick_lava(@world.torches_of(chunk_x + side_x, chunk_z + side_z), dt) }
    end
    nil
  end

  # The random ticks of dt seconds of the lava in lamps, the lamp list of a
  # chunk (World#torches_of). Each lamp gets its share of the ticks, and a
  # tick on a lamp that is not lava does nothing. Lava is in the list only
  # where air touches it, and only that lava can light a fire.
  def tick_lava(lamps, dt)
    count = lamps.size / 3
    ticks = (count * dt / RANDOM_TICK + @rng.rand01).to_i
    ticks.times do
      lamp = (@rng.rand01 * count).to_i * 3
      x = lamps[lamp]
      y = lamps[lamp + 1]
      z = lamps[lamp + 2]
      light_from_lava(x, y, z) if Block.lava?(@world.get(x, y, z))
    end
    nil
  end

  private

  def light_from_lava(x, y, z)
    steps = (@rng.rand01 * STEPS).to_i
    return light_beside_lava(x, y, z) if steps == 0

    steps.times do
      x += @rng.between(-1, 1)
      y += 1
      z += @rng.between(-1, 1)
      return unless @world.inside?(x, y, z)

      block = @world.get(x, y, z)
      return light(x, y, z) if block == Block::AIR && @world.next_to_flammable?(x, y, z)
      return if Block.solid?(block)
    end
    nil
  end

  def light_beside_lava(x, y, z)
    SIDE_TRIES.times do
      side_x = x + @rng.between(-1, 1)
      side_z = z + @rng.between(-1, 1)
      next unless @world.inside?(side_x, y + 1, side_z)
      next unless @world.get(side_x, y + 1, side_z) == Block::AIR

      light(side_x, y + 1, side_z) if Block.flammable?(@world.get(side_x, y, side_z))
    end
    nil
  end

  def light(x, y, z)
    @changes << x << y << z << Block::FIRE
    nil
  end
end
