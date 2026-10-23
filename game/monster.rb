# Zombies, skeletons and creepers: they walk to the player and attack,
# burn in the sun (but a creeper does not), and despawn far from the
# player.
class Monster < Mob
  # Seconds of a creeper's fuse. minecraft.wiki/w/Creeper
  FUSE = 1.5
  # A creeper lights its fuse when the player is this near, and the fuse
  # burns until the player is this far, as in Minecraft.
  # minecraft.wiki/w/Creeper
  LIGHT_REACH = 3.0
  FUSE_REACH = 7.0
  # Seconds of fire from the sun. minecraft.wiki/w/Fire
  SUN_FIRE = 8.0
  # The sun burns undead mobs while the sky light is at least this. In
  # clear weather, minecraft.wiki/w/Daylight_cycle gives the ticks: they
  # stop to burn at tick 12542 and begin again at tick 23460, which are
  # the ticks where the sky light goes below 12 and back. The wiki does
  # not give the light level itself.
  SUN_BURN_LIGHT = 12
  # A monster farther than DESPAWN_FAR blocks from the player despawns at
  # once. A monster that has been farther than DESPAWN_NEAR for
  # IDLE_DESPAWN seconds despawns with a chance of 1 in 800 each tick.
  # minecraft.wiki/w/Mob_spawning
  DESPAWN_FAR = 128.0
  DESPAWN_NEAR = 32.0
  IDLE_DESPAWN = 30.0
  DESPAWN_CHANCE = 20.0 / 800.0

  # True for one step after a skeleton shoots, and after a creeper's fuse
  # burns down, until Game#update_mobs fires the arrow or the blast.
  attr_accessor :shoot, :explode
  # True for one step after a creeper lights its fuse.
  attr_accessor :hiss
  attr_reader :fuse
  # Seconds that the monster has been far from the player (despawn?).
  attr_accessor :idle
  # The block that the monster wears on its head (a carved pumpkin on
  # Halloween), or 0.
  attr_accessor :head

  def initialize(kind, x, y, z, seed)
    super
    @shoot = false
    @explode = false
    @hiss = false
    @fuse = 0.0
    @attack_wait = 0.0
    @idle = 0.0
    @head = 0
    # The damage that the monster deals to the player in this step.
    @bite = 0
    # The walk along the line to the player (sees?).
    @sight = VoxelWalk.new
  end

  # Returns the bite of a zombie in this step, or 0.
  def update_mob(world, dt, player, held)
    @attack_wait -= dt
    @bite = 0
    super
    @bite
  end

  # True when the monster despawns after dt seconds more, with player
  # where it is now.
  def despawn?(player, dt)
    dx = @x - player.x
    dy = @y - player.y
    dz = @z - player.z
    distance_sq = dx * dx + dy * dy + dz * dz
    return true if distance_sq > DESPAWN_FAR * DESPAWN_FAR

    @idle = distance_sq > DESPAWN_NEAR * DESPAWN_NEAR ? @idle + dt : 0.0
    @idle > IDLE_DESPAWN && @rng.rand01 < dt * DESPAWN_CHANCE
  end

  # The AI of the monster: it walks to the player and attacks. It returns
  # the speed that the monster walks at, and a zombie sets @bite.
  def act(world, dt, player, _held)
    # to_f: Spinel cannot type the positions, and the act_ methods need Floats.
    dx = (player.x - @x).to_f
    dz = (player.z - @z).to_f
    dist = Math.sqrt(dx * dx + dz * dz)
    if @kind == SKELETON
      speed = act_skeleton(world, player, dx, dz, dist)
    elsif @kind == CREEPER
      speed = act_creeper(dt, player, dx, dz, dist)
    else
      speed = act_zombie(dx, dz, dist)
      @bite = bite(player, dist)
    end
    speed
  end

  # In the sun, a monster under the open sky catches fire, but a creeper
  # does not. Something on the head stops the sun. The wiki names head
  # armor (minecraft.wiki/w/Zombie). That a carved pumpkin also counts
  # comes from the game code, which checks for any head item; the wiki
  # does not confirm it.
  def burn_in_sun(world)
    return if @kind == CREEPER || @head > 0 || dying? || @fire >= SUN_FIRE

    @fire = SUN_FIRE if world.under_sky?(@x, @y + @tall, @z)
  end

  # dx, dz is the step to the player, and dist is its length.

  # A skeleton keeps a bow's distance and shoots when the player is in sight.
  def act_skeleton(world, player, dx, dz, dist)
    return 0.0 unless dist < 26.0

    face(dx, dz)
    if @attack_wait <= 0.0 && dist < 18.0 && sees?(world, player)
      # About one shot each 3 seconds. minecraft.wiki/w/Skeleton
      @attack_wait = 3.0
      @shoot = true
    end
    dist > 12.0 ? 2.0 : (dist < 7.0 ? -1.6 : 0.0)
  end

  # A creeper walks up to the player, then stands still while the fuse burns.
  def act_creeper(dt, player, dx, dz, dist)
    speed = 0.0
    if dist < 24.0
      face(dx, dz)
      speed = dist > 2.2 && @fuse == 0.0 ? 2.2 : 0.0
    end
    lit = @fuse > 0.0 ? dist < FUSE_REACH : dist < LIGHT_REACH && (player.y - @y).abs < 2.5
    if lit
      @hiss = true if @fuse == 0.0
      @fuse += dt
      @explode = true if @fuse >= FUSE
    else
      @fuse -= dt
      @fuse = 0.0 if @fuse < 0.0
    end
    speed
  end

  # A zombie walks up to the player.
  def act_zombie(dx, dz, dist)
    return 0.0 unless dist < 28.0 && dist > 0.6

    face(dx, dz)
    2.4
  end

  # The damage of a zombie's bite when the player is in reach, else 0.
  def bite(player, dist)
    return 0 unless dist < 1.4 && (player.y - @y).abs < 1.8 && @attack_wait <= 0.0

    @attack_wait = 1.0
    # minecraft.wiki/w/Zombie
    3
  end

  # True when no solid block stands on the line from the eyes of the
  # monster to the eyes of the player. The walk checks each cell that the
  # line crosses, so two blocks that touch at an edge hide the player.
  def sees?(world, player)
    # to_f: Spinel cannot type the positions of the mob and the player.
    @sight.from(@x.to_f, (@y + 1.6).to_f, @z.to_f).to(player.x.to_f, player.eye_y.to_f, player.z.to_f) do |x, y, z|
      return false if Block.solid?(world.get(x, y, z))
    end
    true
  end

  # The monster as the boxes of its Minecraft model. A creeper flashes
  # white as its fuse burns down.
  def draw_model(mesh, swing, red, _fall)
    if @kind == CREEPER
      draw_creeper(mesh, swing, red)
    else
      draw_humanoid(mesh, swing, red)
    end
    # A nil return keeps Spinel from boxing it.
    nil
  end

  def draw_creeper(mesh, swing, red)
    layer = Tex::SKINS + @kind
    flash = @fuse > 0.0 && Math.sin(@fuse * @fuse * 18.0) > 0.0 ? 1.6 : 0.0
    glow = 1.0 + flash
    grow = @fuse * 0.4
    part(mesh, layer, 0.0, 6.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 0.0, 0.0, grow, false, glow, glow * red, glow * red)
    part(mesh, layer, 0.0, 6.0, 0.0, 0.0, -4.0, 0.0, -2.0, 8.0, 12.0, 4.0, 16.0, 16.0, grow, false, glow, glow * red, glow * red)
    legs(mesh, layer, 2.0, 18.0, 4.0, -4.0, 6.0, 0.0, swing, glow, glow * red)
  end

  # A zombie or a skeleton: a person with the arms out to the front. A
  # skeleton has thin arms and legs, and holds a bow.
  def draw_humanoid(mesh, swing, red)
    layer = Tex::SKINS + @kind
    thin = @kind == SKELETON
    width = thin ? 2.0 : 4.0
    part(mesh, layer, 0.0, 0.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 0.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 32.0, 0.0, 0.5, false, 1.0, red, red)
    part(mesh, layer, 0.0, 0.0, 0.0, 0.0, -4.0, 0.0, -2.0, 8.0, 12.0, 4.0, 16.0, 16.0, 0.0, false, 1.0, red, red)
    arm = thin ? -1.45 : -1.5 + swing * 0.2
    part(mesh, layer, -5.0, 2.0, 0.0, arm, thin ? -1.0 : -3.0, -2.0, -width / 2.0, width, 12.0, width, 40.0, 16.0, 0.0, false, 1.0, red, red)
    arm = thin ? -1.45 : -1.5 - swing * 0.2
    part(mesh, layer, 5.0, 2.0, 0.0, arm, -1.0, -2.0, -width / 2.0, width, 12.0, width, 40.0, 16.0, 0.0, true, 1.0, red, red)
    leg = thin ? 2.0 : 1.9
    part(mesh, layer, -leg, 12.0, 0.0, swing, -width / 2.0, 0.0, -width / 2.0, width, 12.0, width, 0.0, 16.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, leg, 12.0, 0.0, -swing, -width / 2.0, 0.0, -width / 2.0, width, 12.0, width, 0.0, 16.0, 0.0, true, 1.0, red, red)
    mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.04, 1.05, 0.55, 0.04, 1.75, 0.62, Tex::WHITE, 0.4, 0.26, 0.12, 1.0) if thin
    # A block on the head is 1 pixel larger on each side than the head.
    if @head > 0
      mesh.block_box(@x, @y, @z, @yaw, -0.3125, 1.4375, -0.3125, 0.3125, 2.0625, 0.3125,
                     Block::TOP[@head], Block::SIDE[@head], Block::BOTTOM[@head], Block::FRONT[@head], 1.0, red, red, 1.0)
    end
  end
end
