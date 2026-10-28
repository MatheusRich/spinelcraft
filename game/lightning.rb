# A lightning bolt: a jagged line from the clouds to the ground, with
# branches. It flickers for a moment and lights the sky with a flash. Its
# thunder comes later, as long after as the sound takes to reach the
# player. Storm picks where it strikes.
class Lightning
  # Seconds that the bolt shows. The wiki does not give the time.
  LIFE = 0.4
  # Seconds that the flash takes to fade after the bolt.
  FLASH_FADE = 0.25
  # The flash while the bolt shows, when it is lit and when it flickers
  # dark, and the share of the flash that is left when the bolt ends.
  FLASH_LIT = 1.0
  FLASH_DARK = 0.4
  FLASH_AFTER = 0.6
  # The bolt flickers dark in one tick of each FLICKER_TICKS ticks.
  FLICKER_TICKS = 4
  FLICKER_DARK_TICK = 2
  TICKS_PER_SECOND = 20.0
  # Sound goes 343 meters each second in air, and a block is 1 meter.
  SOUND_SPEED = 343.0
  # Blocks down for each step of the main channel and of a branch.
  STEP = 5.0
  BRANCH_STEP = 4.0
  # How far a step of the main channel and of a branch walks to the side.
  WALK = 5.0
  BRANCH_REACH = 2.0
  BRANCH_WALK = 3.0
  # The main channel starts up to START_SPREAD blocks to the side of its
  # end, has at most MAX_BRANCHES branches, and forks with BRANCH_CHANCE at
  # each step that is not near its ends.
  START_SPREAD = 16.0
  MAX_BRANCHES = 4
  BRANCH_CHANCE = 0.3
  # A branch has BRANCH_MIN to BRANCH_MIN + BRANCH_EXTRA - 1 lines, and each
  # line is BRANCH_THIN thinner than the one before.
  BRANCH_MIN = 2
  BRANCH_EXTRA = 5
  BRANCH_THIN = 0.06
  # The bolt starts at the clouds, or at least MIN_HEIGHT blocks above its
  # end when the end is above the clouds.
  MIN_HEIGHT = 20.0
  # The floats of a thunder on its way (the seconds, then x, y and z), and
  # of a line of the bolt (the two ends, then the width scale).
  THUNDER_FIELDS = 4
  LINE_FIELDS = 7
  # A line shorter than this across the view has no side to draw.
  MIN_SIDE = 0.0001
  # The color of the pale glow around the bolt.
  GLOW_COLOR = Color.new(0.65, 0.75, 1.0, 0.25)
  # The width of the bright core, and of the pale glow around it.
  CORE = 0.5
  GLOW = 2.4

  # The light of the flash, from 0 to 1.
  attr_reader :flash
  # The cell that the last bolt struck.
  attr_reader :x, :y, :z
  # The bolt of the thunder that thunder_arrived? found.
  attr_reader :heard_x, :heard_y, :heard_z

  def initialize(seed)
    @rng = Rng.new(seed)
    # The lines of the bolt: x0, y0, z0, x1, y1, z1 and the width scale.
    @lines = []
    @age = LIFE + FLASH_FADE
    @flash = 0.0
    # The thunderclaps on their way: the seconds until it arrives and the bolt's
    # x, y and z, for each strike.
    @thunderclaps = []
    @heard_x = 0.0
    @heard_y = 0.0
    @heard_z = 0.0
    @x = 0
    @y = 0
    @z = 0
  end

  def visible? = @age < LIFE

  # A bolt from the clouds down to the cell x, y, z, seen from the eye.
  def strike(x, y, z, eye_x, eye_y, eye_z)
    @lines.clear
    @age = 0.0
    @flash = FLASH_LIT
    @x = x
    @y = y
    @z = z
    ground_x = x + 0.5
    ground_z = z + 0.5
    ground_y = y.to_f
    start_x = ground_x + (@rng.rand01 - 0.5) * START_SPREAD
    start_z = ground_z + (@rng.rand01 - 0.5) * START_SPREAD
    channel(start_x, [Clouds::HEIGHT, ground_y + MIN_HEIGHT].max, start_z, ground_x, ground_y, ground_z)
    away_x = ground_x - eye_x
    away_y = ground_y - eye_y
    away_z = ground_z - eye_z
    @thunderclaps << Math.sqrt(away_x * away_x + away_y * away_y + away_z * away_z) / SOUND_SPEED << ground_x << ground_y << ground_z
  end

  # The main channel from the top to the ground: steps of about STEP blocks,
  # each one off to a side by a random walk that ends at the ground, and a
  # few branches that fork off and end in the air.
  def channel(x0, y0, z0, x1, y1, z1)
    steps = [((y0 - y1) / STEP).to_i, 2].max
    walk_x = random_walk(steps)
    walk_z = random_walk(steps)
    branches = 0
    from_x = x0
    from_y = y0
    from_z = z0
    (1..steps).each do |step|
      progress = step.to_f / steps
      # Take away the end of the walk bit by bit, so the line ends at x1, z1.
      to_x = x0 + (x1 - x0) * progress + walk_x[step] - walk_x[steps] * progress
      to_y = y0 + (y1 - y0) * progress
      to_z = z0 + (z1 - z0) * progress + walk_z[step] - walk_z[steps] * progress
      @lines << from_x << from_y << from_z << to_x << to_y << to_z << 1.0
      if step > 1 && step < steps - 1 && branches < MAX_BRANCHES && @rng.rand01 < BRANCH_CHANCE
        branch(to_x, to_y, to_z)
        branches += 1
      end
      from_x = to_x
      from_y = to_y
      from_z = to_z
    end
  end

  # The sums of steps random steps to a side, from 0.
  def random_walk(steps)
    walk = [0.0]
    steps.times { walk << walk.last + (@rng.rand01 - 0.5) * WALK }
    walk
  end

  # A thinner line that goes off to one side and down, and ends in the air.
  def branch(x, y, z)
    angle = @rng.rand01 * Math::PI * 2.0
    out_x = Math.cos(angle) * BRANCH_REACH
    out_z = Math.sin(angle) * BRANCH_REACH
    (BRANCH_MIN + (@rng.rand01 * BRANCH_EXTRA).to_i).times do |index|
      to_x = x + out_x + (@rng.rand01 - 0.5) * BRANCH_WALK
      to_y = y - BRANCH_STEP * (0.5 + @rng.rand01)
      to_z = z + out_z + (@rng.rand01 - 0.5) * BRANCH_WALK
      @lines << x << y << z << to_x << to_y << to_z << 0.5 - index * BRANCH_THIN
      x = to_x
      y = to_y
      z = to_z
    end
  end

  # The bolt flickers: it shows in most ticks of its life and the flash
  # dims in the others. After its life, the flash fades.
  def update_lightning(dt)
    @age += dt
    @flash = visible? ? (lit? ? FLASH_LIT : FLASH_DARK) : (1.0 - (@age - LIFE) / FLASH_FADE).clamp(0.0, 1.0) * FLASH_AFTER
  end

  def lit? = (@age * TICKS_PER_SECOND).to_i % FLICKER_TICKS != FLICKER_DARK_TICK

  # Counts down the thunder on its way. Returns true when a thunder reaches
  # the player now; heard_x, heard_y and heard_z then hold its bolt.
  def thunder_arrived?(dt)
    return false if @thunderclaps.empty?

    arrived = false
    waiting = []
    @thunderclaps.each_slice(THUNDER_FIELDS) do |seconds, x, y, z|
      seconds -= dt
      if seconds <= 0.0 && !arrived
        arrived = true
        @heard_x = x
        @heard_y = y
        @heard_z = z
      else
        waiting << seconds << x << y << z
      end
    end
    @thunderclaps = waiting
    arrived
  end

  # The bolt as quads that face the camera at the eye: a bright core and a
  # pale glow around it. Lightning is as bright at night.
  def draw(mesh, eye_x, eye_y, eye_z)
    return unless visible? && lit?

    mesh.glow = 1.0
    line_quads(mesh, eye_x, eye_y, eye_z, CORE, Color::SOLID_WHITE)
    line_quads(mesh, eye_x, eye_y, eye_z, GLOW, GLOW_COLOR)
    mesh.glow = 0.0
  end

  def line_quads(mesh, eye_x, eye_y, eye_z, width, color)
    layer = Tex::WHITE.to_f
    @lines.each_slice(LINE_FIELDS) do |x0, y0, z0, x1, y1, z1, scale|
      # The side of the quad is across the line and across the view.
      along_x = x1 - x0
      along_y = y1 - y0
      along_z = z1 - z0
      view_x = (x0 + x1) * 0.5 - eye_x
      view_y = (y0 + y1) * 0.5 - eye_y
      view_z = (z0 + z1) * 0.5 - eye_z
      cross_x = along_y * view_z - along_z * view_y
      cross_y = along_z * view_x - along_x * view_z
      cross_z = along_x * view_y - along_y * view_x
      length = Math.sqrt(cross_x * cross_x + cross_y * cross_y + cross_z * cross_z)
      next if length <= MIN_SIDE

      half_width = width * scale * 0.5 / length
      side_x = cross_x * half_width
      side_y = cross_y * half_width
      side_z = cross_z * half_width
      mesh.vert(x0 - side_x, y0 - side_y, z0 - side_z, 0.0, 0.0, layer, color.red, color.green, color.blue, color.alpha)
      mesh.vert(x0 + side_x, y0 + side_y, z0 + side_z, 1.0, 0.0, layer, color.red, color.green, color.blue, color.alpha)
      mesh.vert(x1 + side_x, y1 + side_y, z1 + side_z, 1.0, 1.0, layer, color.red, color.green, color.blue, color.alpha)
      mesh.vert(x0 - side_x, y0 - side_y, z0 - side_z, 0.0, 0.0, layer, color.red, color.green, color.blue, color.alpha)
      mesh.vert(x1 + side_x, y1 + side_y, z1 + side_z, 1.0, 1.0, layer, color.red, color.green, color.blue, color.alpha)
      mesh.vert(x1 - side_x, y1 - side_y, z1 - side_z, 0.0, 1.0, layer, color.red, color.green, color.blue, color.alpha)
    end
  end
end
