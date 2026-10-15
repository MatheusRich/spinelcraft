# Weather: spells of rain between dry spells. Rain grays the sky, dims the
# light, brings the fog nearer, puts out fires under the open sky, and
# splashes on the ground. The rain itself is streaks on crossed quads in
# the columns around the player; the vrain shader moves them down.
class Weather
  # Rain falls in the columns within R blocks of the player.
  R = 10
  # Seconds that the rain takes to start or to stop. In Java Edition the
  # rain level moves 0.01 each tick toward its target, so a full change takes
  # 100 ticks. The wiki does not give this value: minecraft.wiki/w/Rain and
  # minecraft.wiki/w/Commands/weather do not describe the change.
  FADE = 5.0

  # The strength of the rain, from 0 (none) to 1.
  attr_reader :rain
  # Seconds until the rain starts or stops.
  attr_accessor :timer
  # The rain quads.
  attr_reader :mesh

  def initialize(seed, raining)
    @rng = Rng.new(seed)
    @raining = false
    @rain = 0.0
    @timer = 0.0
    @mesh = Mesh3.new
    # The block that the rain quads are for, and their age in seconds.
    @x = World::NONE
    @y = 0
    @z = World::NONE
    @age = 0.0
    set_now(raining)
  end

  def raining? = @raining

  # Starts or stops the rain, and sets how long the new weather lasts. The
  # strength of the rain follows over FADE seconds.
  def set(on)
    @raining = on
    @timer = on ? 120.0 + @rng.rand01 * 240.0 : 300.0 + @rng.rand01 * 600.0
  end

  # Starts or stops the rain at full strength at once.
  def set_now(on)
    set(on)
    @rain = on ? 1.0 : 0.0
  end

  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_weather(dt)
    @timer -= dt
    set(!@raining) if @timer <= 0.0
    step = dt / FADE
    @rain = (@raining ? @rain + step : @rain - step).clamp(0.0, 1.0)
  end

  # Drops that splash on the ground around the player.
  def splash(particles, world, player, dt)
    n = (dt * 90.0 * @rain + @rng.rand01).to_i
    n.times do
      x = player.x + (@rng.rand01 * 2.0 - 1.0) * 8.0
      z = player.z + (@rng.rand01 * 2.0 - 1.0) * 8.0
      h = world.height_at(x.floor, z.floor)
      if h > player.y - 8.0 && h < player.y + 6.0
        particles.add(Particle::DROP, x, h + 0.05, z, 0.0, 1.2 + @rng.rand01, 0.0, 0.2 + @rng.rand01 * 0.1, Tex::PUFF)
      end
    end
  end

  # The volume of the rain sound now. It follows the strength of the rain.
  # Under a roof it is quieter, and 10 blocks under the ground it stops.
  def sound(world, player)
    return 0.0 if @rain <= 0.0
    cover = world.height_at(player.x.floor, player.z.floor) - player.eye_y
    (cover <= 0.0 ? 0.3 : (cover < 10.0 ? 0.1 : 0.0)) * @rain
  end

  # Makes the rain quads again when the player moves to another block, and
  # every second for the blocks that change. Returns true when it did.
  def build_quads(world, player, dt)
    @age += dt
    return false if @rain <= 0.0
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
    (-R..R).each do |dx|
      (-R..R).each do |dz|
        next if dx * dx + dz * dz > R * R
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
        @mesh.wall(fx, fz, fx + 1.0, fz + 1.0, bottom, top, 2.0, v0, v1, Tex::RAIN, 0.75, 0.8, 0.95, 0.45)
        @mesh.wall(fx + 1.0, fz, fx, fz + 1.0, bottom, top, 2.0, v0 + 0.5, v1 + 0.5, Tex::RAIN, 0.75, 0.8, 0.95, 0.45)
      end
    end
    true
  end
end
