# Weather: spells of rain between dry spells. Rain grays the sky, dims the
# light, brings the fog nearer, puts out fires under the open sky, and
# splashes on the ground. The rain itself is streaks on crossed quads in
# the columns around the player; the vrain shader moves them down.
#
# The thunder spell turns on and off on its own timer, as in Minecraft. Rain
# while the thunder spell is on is a thunderstorm. minecraft.wiki/w/Weather
class Weather
  # Rain falls in the columns within R blocks of the player, and FAST_R in
  # FAST graphics.
  R = 10
  FAST_R = 6
  # The drops that splash in a second at full strength, in the rain of R
  # blocks. A smaller rain has fewer, for the same drops in each block.
  SPLASH_RATE = 90.0
  # The drops splash within this share of the radius of the rain.
  SPLASH_REACH = 0.8
  # The color of a rain streak.
  RAIN_COLOR = Color.new(0.75, 0.8, 0.95, 0.45)
  # Seconds that a spell of rain lasts, and that the sky stays dry.
  RAIN_LASTS = 120.0..360.0
  RAIN_PAUSES = 300.0..900.0
  # Thunder stays on for 3600 to 15600 ticks, and off for 12000 to 180000
  # ticks. minecraft.wiki/w/Weather
  THUNDER_LASTS = 180.0..780.0
  THUNDER_PAUSES = 600.0..9000.0
  # The strength at which the rain wets: it puts out fires, and the sun
  # does not burn undead mobs. The wiki does not give it.
  WET = 0.5
  # Minecraft strikes lightning when the strength of the storm is above 0.9.
  # The wiki does not confirm this value (Level#isThundering in the code).
  STRIKING = 0.9

  # The spells of rain and of thunder.
  attr_reader :rain, :thunder
  # The rain quads, and the radius of the rain in blocks.
  attr_reader :mesh, :radius

  def initialize(seed)
    @rng = Rng.new(seed)
    @rain = Spell.new(@rng, RAIN_LASTS, RAIN_PAUSES)
    @thunder = Spell.new(@rng, THUNDER_LASTS, THUNDER_PAUSES)
    @mesh = Mesh3.new
    @radius = R
    @splash_rate = SPLASH_RATE
    # The block that the rain quads are for, and their age in seconds.
    @x = World::NONE
    @y = 0
    @z = World::NONE
    @age = 0.0
    clear
    settle
  end

  # Sets the radius of the rain and the drops that splash from the graphics
  # mode. The next build_quads makes the quads again.
  def graphics=(mode)
    @radius = mode.rain_radius
    @splash_rate = SPLASH_RATE * (@radius * @radius).to_f / (R * R)
    @x = World::NONE
  end

  # True when rain falls while the thunder spell is on.
  def thunderstorm? = @rain.on? && @thunder.on?

  # The strength of the thunderstorm: the thunder times the rain, as in
  # Java Edition (Level#getThunderLevel).
  def thunderstorm_strength = @rain.strength * @thunder.strength

  # True when the storm is strong enough for lightning.
  def striking? = thunderstorm_strength > STRIKING

  # True when the rain is strong enough to wet.
  def wet? = @rain.strength > WET

  # Stops the rain and the thunder.
  def clear
    @rain.stop
    @thunder.stop
  end

  # Moves the strength of each spell to its flag at once.
  def settle
    @rain.settle
    @thunder.settle
  end

  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_weather(dt)
    @rain.advance(dt)
    @thunder.advance(dt)
  end

  # The spells for the save: Spell#to_a of the rain, then of the thunder.
  def to_a = @rain.to_a + @thunder.to_a

  # Reads what to_a wrote from fields at at, and returns the place after it.
  def load(fields, at) = @thunder.load(fields, @rain.load(fields, at))

  # Drops that splash on the ground around the player.
  def splash(particles, world, player, dt)
    n = (dt * @splash_rate * @rain.strength + @rng.rand01).to_i
    reach = @radius * SPLASH_REACH
    n.times do
      x = player.x + (@rng.rand01 * 2.0 - 1.0) * reach
      z = player.z + (@rng.rand01 * 2.0 - 1.0) * reach
      h = world.height_at(x.floor, z.floor)
      if h > player.y - 8.0 && h < player.y + 6.0
        particles.add(Particle::DROP, x, h + 0.05, z, 0.0, 1.2 + @rng.rand01, 0.0, 0.2 + @rng.rand01 * 0.1, Tex::PUFF)
      end
    end
  end

  # The volume of the rain sound now. It follows the strength of the rain.
  # Under a roof it is quieter, and 10 blocks under the ground it stops.
  def sound(world, player)
    return 0.0 if @rain.strength <= 0.0

    cover = world.height_at(player.x.floor, player.z.floor) - player.eye_y
    (cover <= 0.0 ? 0.3 : (cover < 10.0 ? 0.1 : 0.0)) * @rain.strength
  end

  # Makes the rain quads again when the player moves to another block, and
  # every second for the blocks that change. Returns true when it did.
  def build_quads(world, player, dt) # rubocop:todo Metrics/MethodLength
    @age += dt
    return false if @rain.strength <= 0.0

    cx = player.x.floor
    cy = player.y.floor
    cz = player.z.floor
    return false if cx == @x && cy == @y && cz == @z && @age < 1.0

    @x = cx
    @y = cy
    @z = cz
    @age = 0.0
    @mesh.clear
    top = (cy + 14).to_f
    (-@radius..@radius).each do |dx|
      (-@radius..@radius).each do |dz|
        next if dx * dx + dz * dz > @radius * @radius

        x = cx + dx
        z = cz + dz
        ground = world.height_at(x, z)
        bottom = (ground > cy - 10 ? ground : cy - 10).to_f
        next if bottom >= top

        # Each column starts its streaks at another place, so the columns do
        # not fall in step. The texture repeats twice across a quad and every
        # 4 blocks down.
        v0 = ((x * 73856093) ^ (z * 19349663)) % 1024 / 256.0
        v1 = v0 + (top - bottom) / 4.0
        fx = x.to_f
        fz = z.to_f
        @mesh.wall(fx, fz, fx + 1.0, fz + 1.0, bottom, top, 2.0, v0, v1, Tex::RAIN, RAIN_COLOR)
        @mesh.wall(fx + 1.0, fz, fx, fz + 1.0, bottom, top, 2.0, v0 + 0.5, v1 + 0.5, Tex::RAIN, RAIN_COLOR)
      end
    end
    true
  end
end
