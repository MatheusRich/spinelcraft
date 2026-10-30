# One flake of the Snowfall: it falls and sways until it lands or leaves the
# box around the player. A negative age means that it does not fall.
class Flake
  FALL_SPEED = 0.9
  FALL_SPEED_SPREAD = 0.6
  SWAY = 0.25
  SWAY_SPEED = 0.8
  SWAY_SPEED_SPREAD = 0.6
  FADE_IN_SECONDS = 0.5

  attr_reader :x, :y, :z

  def initialize
    @x = 0.0
    @y = 0.0
    @z = 0.0
    @age = -1.0
  end

  def falling? = @age >= 0.0

  def start(x, y, z)
    @x = x
    @y = y
    @z = z
    @age = 0.0
  end

  def stop
    @age = -1.0
  end

  def fall(dt, pace)
    @y -= (FALL_SPEED + FALL_SPEED_SPREAD * pace) * dt
    @age += dt
  end

  def sway(pace) = SWAY * Math.sin(@age * (SWAY_SPEED + SWAY_SPEED_SPREAD * pace))

  def grown = @age >= FADE_IN_SECONDS ? 1.0 : @age / FADE_IN_SECONDS

  def landed?(world) = @y <= world.height_at(@x.floor, @z.floor)

  def outside?(player, radius) = (@x - player.x).abs > radius || (@z - player.z).abs > radius
end

# Snowfall: flakes that fall in the air around the player, over the columns
# where World#precipitation says snow. Each flake is a square that faces the camera.
class Snowfall
  FLAKES = 300
  REFILLS_PER_FRAME = 8
  CEILING = 14.0
  FLOOR = 10.0
  HALF = 0.09
  COLOR = Color.new(1.0, 1.0, 1.0, 0.9)
  LAYERS = [Tex::SNOWFLAKE_1, Tex::SNOWFLAKE_2]
  PIECE_U = [2 / 16.0, 9 / 16.0]
  PIECE_V = [3 / 16.0, 10 / 16.0]
  PIECE_SIZE = 5 / 16.0
  PACES = 10

  attr_writer :strength

  def self.pace(index) = (index * 7 % PACES).to_f / PACES

  def initialize(seed)
    @rng = Rng.new(seed)
    @flakes = Array.new(FLAKES) { Flake.new }
    @strength = 0.0
    @radius = Weather::R.to_f
  end

  def graphics=(mode)
    @radius = mode.rain_radius.to_f
  end

  def update(world, player, dt)
    wanted = (FLAKES * @strength * @radius * @radius / (Weather::R * Weather::R)).to_i
    refills = 0
    @flakes.each_with_index do |flake, index|
      if index >= wanted
        flake.stop
      elsif flake.falling?
        flake.fall(dt, Snowfall.pace(index))
        flake.stop if flake.landed?(world) || flake.outside?(player, @radius)
      elsif refills < REFILLS_PER_FRAME
        refills += 1
        appear(flake, world, player)
      end
    end
    nil
  end

  def draw(mesh, player)
    right_x = Math.cos(player.yaw)
    right_z = Math.sin(player.yaw)
    up_x = -right_z * player.fy
    up_y = right_z * player.fx - right_x * player.fz
    up_z = right_x * player.fy
    @flakes.each_with_index do |flake, index|
      next unless flake.falling?

      piece = index % LAYERS.size
      mesh.billboard(flake.x + flake.sway(Snowfall.pace(index)), flake.y, flake.z, HALF * flake.grown, right_x, right_z, up_x, up_y, up_z,
                     PIECE_U[piece], PIECE_V[piece], PIECE_SIZE, LAYERS[piece], COLOR)
    end
    nil
  end

  private

  def appear(flake, world, player)
    x = player.x + (@rng.rand01 * 2.0 - 1.0) * @radius
    z = player.z + (@rng.rand01 * 2.0 - 1.0) * @radius
    return unless world.precipitation(x.floor, z.floor) == Biome::SNOW

    ground = world.height_at(x.floor, z.floor).to_f
    low = ground > player.y - FLOOR ? ground : player.y - FLOOR
    flake.start(x, low + @rng.rand01 * (player.y + CEILING - low), z)
  end
end
