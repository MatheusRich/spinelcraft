# Thunderstorms: lightning strikes near the player and hurts and burns what
# it hits. Lightning draws the bolt and times its thunder.
class Storm
  # Each chunk gets a strike with a chance of 1 in 100000 each tick of a
  # thunderstorm. minecraft.wiki/w/Lightning
  STRIKE_CHANCE = 1.0 / 100_000.0
  # Strikes fall in the chunks around the player where monsters spawn
  # (NaturalSpawner::SPAWN_CHUNKS), so about 3.5 strikes come each minute.
  STRIKE_CHUNKS = NaturalSpawner::SPAWN_CHUNKS
  # A strike does 5 damage. minecraft.wiki/w/Lightning
  STRIKE_DAMAGE = 5.0
  # Seconds that a struck mob or player burns. The wiki does not give the
  # time; Minecraft's code (Entity#thunderHit) sets 8 seconds.
  STRIKE_FIRE = 8.0
  # A strike hurts what is less than 3 blocks from it on x and z, from 3
  # below it to 9 above it. The wiki does not give the reach; it is the box
  # of LightningBolt in Minecraft's code.
  STRIKE_REACH = 3.0
  STRIKE_BELOW = 3.0
  STRIKE_ABOVE = 9.0
  # A body in the 3 x 3 columns around a strike draws it to itself.
  DRAW_REACH = 1
  TICKS_PER_SECOND = 20.0
  SMOKE_PUFFS = 12

  attr_reader :lightning

  def initialize(seed, world, weather, mobs)
    @rng = Rng.new(seed)
    @lightning = Lightning.new(seed + 1)
    @world = world
    @weather = weather
    @mobs = mobs
  end

  # The strikes of dt seconds, and the bolt that fades. Returns true when a
  # strike hit the player. Like a mob, the player draws a strike, also in
  # creative.
  def advance(dt, player, particles)
    @lightning.update_lightning(dt)
    return false unless @weather.striking?

    chunks = STRIKE_CHUNKS * 2 + 1
    return false if @rng.rand01 >= dt * TICKS_PER_SECOND * chunks * chunks * STRIKE_CHANCE

    chunk_x = (player.x.floor >> 4) + (@rng.rand01 * chunks).to_i - STRIKE_CHUNKS
    chunk_z = (player.z.floor >> 4) + (@rng.rand01 * chunks).to_i - STRIKE_CHUNKS
    strike(chunk_x * CHUNK + (@rng.rand01 * CHUNK).to_i, chunk_z * CHUNK + (@rng.rand01 * CHUNK).to_i, player, particles)
  end

  # Lightning strikes the top of the column x, z: the block above the
  # highest block that stops motion or holds a fluid. A mob or the player in
  # the 3 x 3 columns around it that sees the sky draws the strike to
  # itself. The strike does not happen when a block that stops motion is
  # above its cell, such as a glass roof. Returns true when it hit the
  # player. minecraft.wiki/w/Lightning
  def strike(x, z, player, particles)
    y = @world.motion_top(x, z)
    cells = targets(x, y, z, player)
    unless cells.empty?
      x, y, z = cells[(@rng.rand01 * cells.size).to_i]
    end
    return false if @world.motion_top(x, z) > y

    @lightning.strike(x, y, z, Clouds::HEIGHT, player.x.to_f, player.eye_y.to_f, player.z.to_f)
    particles.smoke(x + 0.5, y + 0.5, z + 0.5, SMOKE_PUFFS, 1.0)
    burn(x + 0.5, y.to_f, z + 0.5, player)
  end

  # The cell of each mob and the player that draws a strike at x, y, z.
  def targets(x, y, z, player)
    bodies = @mobs.reject(&:dying?) + [player]
    bodies.select { |body| draws?(body, x, y, z) }.map { |body| [body.x.floor, body.y.floor, body.z.floor] }
  end

  # True when the body is in the 3 x 3 columns around the strike at x, y, z
  # with its head at or above the strike, and sees the sky.
  def draws?(body, bolt_x, bolt_y, bolt_z)
    head = body.y + body.tall
    (body.x.floor - bolt_x).abs <= DRAW_REACH && (body.z.floor - bolt_z).abs <= DRAW_REACH &&
      head >= bolt_y && @world.under_sky?(body.x, head, body.z)
  end

  # Hurts and burns the mobs near the strike at x, y, z. Returns true when
  # the strike hit the player, and the game hurts and burns the player.
  def burn(x, y, z, player)
    @mobs.select { |mob| struck?(mob, x, y, z) }.each do |mob|
      mob.wound(STRIKE_DAMAGE)
      mob.ignite(STRIKE_FIRE)
    end
    struck?(player, x, y, z)
  end

  def struck?(body, x, y, z)
    (body.x - x).abs < STRIKE_REACH + body.half && (body.z - z).abs < STRIKE_REACH + body.half &&
      body.y > y - STRIKE_BELOW && body.y < y + STRIKE_ABOVE
  end
end
