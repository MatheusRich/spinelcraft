# Pigs, sheep, cows, chickens, zombies, skeletons and creepers: behavior,
# physics and box models.
class Mob
  PIG = 0
  ZOMBIE = 1
  SKELETON = 2
  SHEEP = 3
  CREEPER = 4
  COW = 5
  CHICKEN = 6
  # Seconds of a creeper's fuse. minecraft.wiki/w/Creeper
  FUSE = 1.5
  # A creeper lights its fuse when the player is this near, and the fuse
  # burns until the player is this far, as in Minecraft.
  # minecraft.wiki/w/Creeper
  LIGHT_REACH = 3.0
  FUSE_REACH = 7.0
  # Traits indexed by kind: pig, zombie, skeleton, sheep, creeper, cow,
  # chicken. MOB_SOUND in game/combat.rb has the sounds.
  # minecraft.wiki/w/Pig, /w/Zombie, /w/Skeleton, /w/Sheep, /w/Creeper,
  # /w/Cow and /w/Chicken
  NAMES = ["PIG", "ZOMBIE", "SKELETON", "SHEEP", "CREEPER", "COW", "CHICKEN"]
  HP = [10.0, 20.0, 20.0, 8.0, 20.0, 10.0, 4.0]
  HALF = [0.45, 0.3, 0.3, 0.45, 0.3, 0.45, 0.2]
  TALL = [0.95, 1.9, 1.9, 1.2, 1.7, 1.4, 0.7]
  # Passive mobs wander, never attack, and do not count as monsters.
  PASSIVE = [1, 0, 0, 1, 0, 1, 1]
  # A chicken lays an egg each 5 to 10 minutes. minecraft.wiki/w/Chicken
  EGG_MIN = 300.0
  EGG_MORE = 300.0
  # A chicken in the air falls no faster than this, in blocks each second.
  # The wiki says only that chickens fall slowly (minecraft.wiki/w/Chicken).
  # This is the speed where Minecraft's gravity and the chicken's slowdown
  # of 0.6 for each tick meet, which the wiki does not confirm.
  CHICKEN_FALL = -2.3
  # A baby animal is half as wide and half as tall, and grows up after 20
  # minutes. minecraft.wiki/w/Breeding and /w/Chicken
  GROW_TIME = 1200.0
  # Each feeding takes 10% off the time that a baby has left to grow up,
  # and does nothing when less than 9 seconds are left.
  # minecraft.wiki/w/Breeding
  FEED_GROWTH = 0.1
  FEED_MIN = 9.0
  # An animal starts to follow a player who holds its food within 6
  # blocks (minecraft.wiki/w/Cow, /w/Pig and /w/Sheep; /w/Chicken says a
  # 6x4x6 area). It stops when the player is 10 blocks away
  # (minecraft.wiki/w/Cow and /w/Chicken, Java Edition).
  TEMPT_REACH = 6.0
  TEMPT_KEEP = 10.0
  # A tempted animal stops 2.5 blocks from the player, and walks at this
  # part of WALK_SPEED, by kind as in Mob::NAMES. The wiki does not give
  # these values; they are those of the game code (TemptGoal, and the
  # registerGoals of Pig, Sheep, Cow and Chicken).
  TEMPT_NEAR = 2.5
  TEMPT_PACE = [1.2, 0.0, 0.0, 1.1, 0.0, 1.25, 1.0]
  # A passive mob walks at WALK_SPEED. After damage it panics for PANIC
  # seconds: it runs at PANIC_SPEED, first away from a hit and then to a
  # new side about each second. The wiki says only that a pig "flees for a
  # short time when harmed" (minecraft.wiki/w/Pig), so it does not confirm
  # these values.
  WALK_SPEED = 1.3
  PANIC = 5.0
  PANIC_SPEED = 2.6
  # A passive mob that a wall stops for this many seconds turns to a new side.
  STUCK = 0.5
  # After a hit, the mob takes for this many seconds only the part of a new
  # hit that is above the last one, as in Minecraft. minecraft.wiki/w/Damage
  IMMUNE = 0.5
  # Seconds of fire from the sun, and from lava. minecraft.wiki/w/Fire and
  # /w/Lava
  SUN_FIRE = 8.0
  LAVA_FIRE = 15.0
  # A dead mob falls on its left side for 20 ticks, then its body goes up
  # in smoke. minecraft.wiki/w/Death
  DEATH_TIME = 1.0
  # A monster farther than DESPAWN_FAR blocks from the player despawns at
  # once. A monster that has been farther than DESPAWN_NEAR for
  # IDLE_DESPAWN seconds despawns with a chance of 1 in 800 each tick.
  # minecraft.wiki/w/Mob_spawning
  DESPAWN_FAR = 128.0
  DESPAWN_NEAR = 32.0
  IDLE_DESPAWN = 30.0
  DESPAWN_CHANCE = 20.0 / 800.0
  # An animal despawns farther than this many blocks along x and z from
  # the player. minecraft.wiki does not give this value.
  ANIMAL_DESPAWN = 160.0

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :hp, :alive, :shoot, :explode, :by_player
  # True for one step after a creeper lights its fuse.
  attr_accessor :hiss
  # True after a hit, until Game#update_mobs plays the hurt sound.
  attr_accessor :ouch
  # True after a step on the ground, until Game#update_mobs plays it.
  attr_accessor :step
  attr_reader :fuse
  # Seconds that the mob still burns.
  attr_reader :fire
  attr_reader :kind, :half, :tall, :hurt
  # Seconds that a monster has been far from the player (despawn?).
  attr_accessor :idle
  # Seconds since the mob died; 0.0 while it lives.
  attr_reader :death
  # Seconds that a passive mob still panics.
  attr_reader :panic
  # How far the legs swing, from 0 at rest to 1 at a walk or faster.
  attr_reader :leg_swing
  # The block that the mob wears on its head (a carved pumpkin on
  # Halloween), or 0.
  attr_accessor :head
  # True for a sheep that shears took the wool of, until it eats grass.
  attr_accessor :sheared
  # Seconds that a sheep still eats grass, with its head down.
  attr_reader :graze
  # True for one step when a grazing sheep takes its bite (Game#bite_grass).
  attr_accessor :grass_bite
  # Seconds until a chicken lays its next egg.
  attr_accessor :egg_time
  # True after a chicken lays an egg, until Game#update_mobs drops it.
  attr_accessor :lay
  # Seconds until a baby grows up; 0.0 for a grown mob.
  attr_reader :grow_left
  # The love mode of the animal.
  attr_reader :love
  # True while the animal follows a player who holds its food.
  attr_reader :tempted

  def initialize(kind, x, y, z, seed) # rubocop:todo Metrics/MethodLength
    @kind = kind
    @x = x
    @y = y
    @z = z
    @vx = 0.0
    @vy = 0.0
    @vz = 0.0
    @yaw = (seed % 628) / 100.0
    @hp = HP[kind]
    @shoot = false
    @explode = false
    @hiss = false
    @ouch = false
    @step = false
    @step_dist = 0.0
    @by_player = false
    @fuse = 0.0
    @hurt = 0.0
    @alive = true
    @phase = 0.0
    @half = HALF[kind]
    @tall = TALL[kind]
    @think = 0.0
    @walking = false
    @rng = Rng.new(seed)
    @attack_wait = 0.0
    @on_ground = false
    @burn = 0.0
    @fire = 0.0
    @immune = 0.0
    @last_damage = 0.0
    @idle = 0.0
    @death = 0.0
    @panic = 0.0
    @leg_swing = 0.0
    @stuck = 0.0
    @head = 0
    @sheared = false
    @graze = 0.0
    @grass_bite = false
    @egg_time = EGG_MIN + @rng.rand01 * EGG_MORE
    @lay = false
    # The angle of a chicken's wings (Minecraft's flap), and how far they
    # open: 1 in the air, and down to 0 on the ground (flapSpeed).
    @flap = 0.0
    @flap_open = 0.0
    @grow_left = 0.0
    # The scale of the next parts of the model (see part).
    @size = 1.0
    @love = Love.new
    @tempted = false
  end

  def baby? = @grow_left > 0.0

  # Makes this mob a baby that grows up after GROW_TIME.
  def make_baby
    @grow_left = GROW_TIME
    @half = HALF[@kind] / 2.0
    @tall = TALL[@kind] / 2.0
  end

  # dt more seconds of growing up. A grown mob takes its full size.
  def grow_up(dt)
    return unless baby?

    @grow_left -= dt
    return if baby?

    @grow_left = 0.0
    @half = HALF[@kind]
    @tall = TALL[@kind]
  end

  def passive? = PASSIVE[@kind] == 1

  # True when block is the breeding food of this animal: wheat for a cow, a
  # sheep and a pig, and seeds for a chicken. minecraft.wiki/w/Breeding
  # Minecraft breeds pigs with carrots since 1.4.2. From Beta 1.9
  # Prerelease 2 until then, wheat bred them (minecraft.wiki/w/Pig). The
  # game has no carrots, so pigs take wheat. A chicken also takes pumpkin
  # seeds. minecraft.wiki/w/Chicken
  def food?(block)
    return block == Block::SEEDS || block == Block::PUMPKIN_SEEDS if @kind == CHICKEN

    block == Block::WHEAT && (@kind == COW || @kind == SHEEP || @kind == PIG)
  end

  # The animal eats its food from the player's hand, and returns true when
  # it takes the item. An adult enters love mode (Love#feed), and a baby
  # grows up faster. The rules come from the game code
  # (Animal.mobInteract); the wiki does not give them all.
  def feed
    return @love.feed unless baby?

    grow_up(@grow_left * FEED_GROWTH) if @grow_left >= FEED_MIN
    true
  end

  def burning? = @fire > 0.0

  # A sheep eats for 40 ticks, and it takes its bite 4 ticks before the end:
  # then the grass goes and the wool grows back. A panic stops the eating
  # before the bite. The wiki does not give these times or the panic rule;
  # they are those of the game code (EatBlockGoal, and PanicGoal, which
  # runs first).
  GRAZE_TIME = 2.0
  BITE_LEFT = 0.2
  # How far a grazing sheep turns its head down, in radians.
  GRAZE_NOD = 0.9

  # A baby sheep has wool, but shears do not take it. The wiki shows a
  # sheared baby sheep as one that only commands make
  # (minecraft.wiki/w/Sheep); the game code checks for a baby
  # (Sheep.readyForShearing).
  def shearable? = @kind == SHEEP && !@sheared && !dying? && !baby?

  # dt more seconds of laying for a grown chicken: it sets lay when an egg
  # is due. A chick lays no eggs. minecraft.wiki/w/Chicken
  def lay_eggs(dt)
    return if @kind != CHICKEN || baby? || dying?

    @egg_time -= dt
    return if @egg_time > 0.0

    @egg_time = EGG_MIN + @rng.rand01 * EGG_MORE
    @lay = true
    # A nil return, as on the other paths, keeps Spinel from boxing it.
    nil
  end

  # A chicken opens its wings in the air and beats them, and folds them
  # on the ground, as Minecraft's Chicken.aiStep: flapSpeed goes up 1.2
  # each tick in the air and down 0.3 on the ground, and flap goes up about
  # 1.8 each tick in the air. The wiki does not give these values.
  def flap_wings(dt)
    @flap_open = (@flap_open + (@on_ground ? -6.0 : 24.0) * dt).clamp(0.0, 1.0)
    @flap += 36.0 * dt unless @on_ground
  end

  # The sheep starts to eat grass: it stands still with its head down.
  def start_graze
    @graze = GRAZE_TIME
  end

  # The wool of a sheared sheep grows back after its bite of grass.
  # minecraft.wiki/w/Sheep
  def regrow
    @sheared = false
  end

  # A dying mob lies on the ground until DEATH_TIME. It does not move on its
  # own, attack or take hits.
  def dying? = @hp <= 0

  # A sheep starts to eat when it has grass to eat and does not panic.
  def can_graze?(world) = @kind == SHEEP && !dying? && @graze <= 0.0 && @panic <= 0.0 && grass_under(world) > 0

  # What the sheep can eat: 1 for the tall grass in its cell, 2 for the
  # grass block under it, or 0. minecraft.wiki/w/Sheep
  def grass_under(world)
    x = @x.floor
    y = (@y + 0.01).floor
    z = @z.floor
    return 1 if world.get(x, y, z) == Block::TALL_GRASS

    world.get(x, y - 1, z) == Block::GRASS ? 2 : 0
  end

  # True when Game#update_mobs takes the mob out: it is dead, it is out of
  # the loaded chunks, or it despawns. despawn? comes last, so only a live
  # mob in a loaded chunk moves its idle time on. Ask once each frame.
  def gone?(world, player, dt) = !@alive || !world.loaded?(@x.floor, @z.floor) || despawn?(player, dt)

  # Why Game#update_mobs takes the mob out, for Log::MOBS.
  def gone_reason(world)
    return "dies" unless @alive
    return "is out of the loaded chunks" unless world.loaded?(@x.floor, @z.floor)

    "despawns"
  end

  # True when the mob despawns after dt seconds more, with player where it
  # is now.
  def despawn?(player, dt)
    dx = @x - player.x
    dy = @y - player.y
    dz = @z - player.z
    return dx * dx + dz * dz > ANIMAL_DESPAWN * ANIMAL_DESPAWN if passive?

    distance2 = dx * dx + dy * dy + dz * dz
    return true if distance2 > DESPAWN_FAR * DESPAWN_FAR

    @idle = distance2 > DESPAWN_NEAR * DESPAWN_NEAR ? @idle + dt : 0.0
    @idle > IDLE_DESPAWN && @rng.rand01 < dt * DESPAWN_CHANCE
  end

  # Rain or water puts out the fire.
  def douse
    @fire = 0.0
  end

  def blocked?(world) = world.solid_in_box?(@x, @y, @z, @half, @tall)

  # Moves and returns true when a wall stopped the horizontal motion.
  def move(world, dx, dy, dz)
    bumped = false
    @x += dx
    if blocked?(world)
      @x -= dx
      @vx = 0.0
      bumped = true
    end
    @z += dz
    if blocked?(world)
      @z -= dz
      @vz = 0.0
      bumped = true
    end
    @y += dy
    @on_ground = false
    if blocked?(world)
      if dy < 0.0
        @y = world.box_edge(@x, @y, @z, @half, @tall, 1, -1)
        @on_ground = true
      else
        @y -= dy
      end
      @vy = 0.0
    end
    bumped
  end

  def face(dx, dz)
    @yaw = Math.atan2(-dx, dz)
  end

  # Adds dvx, dvz to the velocity: a push from another mob (Game#push_mobs).
  def nudge(dvx, dvz)
    @vx += dvx
    @vz += dvz
    # A nil return keeps Spinel from boxing it.
    nil
  end

  # Returns damage dealt to the player this step. held is the item in the
  # player's hand, and sun is true when the sun burns undead mobs.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_mob(world, dt, player, held, sun:) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    @hurt -= dt
    if @graze > 0.0
      @graze = 0.0 if @panic > 0.0 || dying?
      @grass_bite = true if @graze > BITE_LEFT && @graze - dt <= BITE_LEFT
      @graze -= dt
    end
    @immune -= dt
    @attack_wait -= dt
    grow_up(dt)
    lay_eggs(dt)
    @love.clock(dt)
    speed = 0.0
    damage = 0
    if dying?
      @death += dt
    elsif passive?
      speed = act_passive(dt, player, held)
    else
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
        damage = bite(player, dist)
      end
      exposed = world.under_sky?(@x, @y + @tall, @z)
      # Something on the head stops the sun. The wiki names head armor
      # (minecraft.wiki/w/Zombie). That a carved pumpkin also counts comes
      # from the game code, which checks for any head item; the wiki does
      # not confirm it.
      @fire = SUN_FIRE if sun && exposed && @kind != CREEPER && @head == 0 && @fire < SUN_FIRE
    end
    fx = -Math.sin(@yaw)
    fz = Math.cos(@yaw)
    k = (8.0 * dt).clamp(0.0, 1.0)
    @vx += (fx * speed - @vx) * k
    @vz += (fz * speed - @vz) * k
    feet = world.get(@x.floor, (@y + 0.3).floor, @z.floor)
    in_water = Block.water?(feet) || Block.lava?(feet)
    # A mob burns on for a while after the sun or the lava, and water puts
    # the fire out. Fire takes 1 health each second, and lava 4 each half
    # second (IMMUNE stops the hits in between). minecraft.wiki/w/Damage
    @fire = LAVA_FIRE if Block.lava?(feet)
    @fire = 0.0 if Block.water?(feet)
    wound(4.0) if Block.lava?(feet)
    # A cactus takes 1 each half second. minecraft.wiki/w/Cactus
    wound(1.0) if world.cactus_in_box?(@x, @y, @z, @half, @tall)
    if @fire > 0.0
      @fire -= dt
      @burn -= dt
      if @burn <= 0.0
        @burn = 1.0
        wound(1.0)
      end
    else
      @burn = 0.0
    end
    if in_water
      @vy += (2.0 - @vy) * (4.0 * dt).clamp(0.0, 1.0)
    else
      @vy -= 28.0 * dt
    end
    @vy = -38.0 if @vy < -38.0
    @vy = CHICKEN_FALL if @kind == CHICKEN && !in_water && @vy < CHICKEN_FALL
    if blocked?(world)
      @y = @y.floor + 1.0
      @vy = 0.0
    end
    bumped = move(world, @vx * dt, @vy * dt, @vz * dt)
    @vy = 8.2 if bumped && @on_ground && !dying?
    @stuck = bumped ? @stuck + dt : 0.0
    if passive? && @stuck > STUCK
      @think = 0.0
      @stuck = 0.0
    end
    moving = Math.sqrt(@vx * @vx + @vz * @vz)
    @phase += moving * dt * 3.5
    # The legs swing as far as the mob goes fast, and come to rest when it
    # stops, as in Minecraft.
    @leg_swing += ((moving / WALK_SPEED).clamp(0.0, 1.0) - @leg_swing) * (8.0 * dt).clamp(0.0, 1.0)
    flap_wings(dt) if @kind == CHICKEN
    if @on_ground && !dying?
      @step_dist += moving * dt
      if @step_dist > Player::STEP
        @step_dist = 0.0
        @step = true
      end
    end
    # A mob that died in this step, in fire or in lava, starts its death
    # clock now. So Game#update_mobs sees it die once, and drops its loot once.
    @death = dt if dying? && @death == 0.0
    @alive = false if @death >= DEATH_TIME || @y < -10.0
    damage
  end

  # The act_ methods are the AI of each kind. Each one can turn the mob,
  # and returns the speed that it walks at. dx, dz is the step to the
  # player, and dist is its length.

  # A passive mob wanders, and after a hit it panics. A lover walks to its
  # mate, and else a mob that does not panic follows a player who holds
  # its food (held), as the order of the goals in the game code. A
  # panicking mob has no mate: the hit ended its love mode (Love#reset).
  def act_passive(dt, player, held)
    @think -= dt
    @panic -= dt
    @tempted = false if @panic > 0.0
    return walk_to_mate(dt) if @love.courting?
    return follow(player) if @panic <= 0.0 && tempted_by?(player, held)

    if @think <= 0.0
      if @panic > 0.0
        @think = 0.7 + @rng.rand01 * 0.8
        @walking = true
      else
        @think = 2.0 + @rng.rand01 * 4.0
        @walking = @rng.rand01 < 0.6
      end
      @yaw = @rng.rand01 * 6.283
    end
    # A grazing sheep stands still.
    return 0.0 if @graze > 0.0

    @walking ? (@panic > 0.0 ? PANIC_SPEED : WALK_SPEED) : 0.0
  end

  # The lover walks to its mate at the walk speed, as in the game code
  # (BreedGoal, speed 1.0), until the two touch. The wiki does not say.
  def walk_to_mate(dt)
    @love.walk(dt)
    @graze = 0.0
    dx = @love.mate_x - @x.to_f
    dz = @love.mate_z - @z.to_f
    face(dx, dz)
    dx * dx + dz * dz > 4.0 * @half * @half ? WALK_SPEED : 0.0
  end

  # True when the player holds the food of this animal (held) in reach.
  # It keeps @tempted.
  def tempted_by?(player, held)
    # to_f: Spinel cannot type the positions.
    dx = (player.x - @x).to_f
    dy = (player.y - @y).to_f
    dz = (player.z - @z).to_f
    reach = @tempted ? TEMPT_KEEP : TEMPT_REACH
    @tempted = food?(held) && dx * dx + dy * dy + dz * dz < reach * reach
  end

  # The tempted animal turns to the player and walks up to TEMPT_NEAR.
  def follow(player)
    @graze = 0.0
    dx = (player.x - @x).to_f
    dz = (player.z - @z).to_f
    face(dx, dz)
    dx * dx + dz * dz > TEMPT_NEAR * TEMPT_NEAR ? WALK_SPEED * TEMPT_PACE[@kind] : 0.0
  end

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

  # True when no solid block lies between this mob's eyes and the player's.
  def sees?(world, player)
    ox = @x
    oy = @y + 1.6
    oz = @z
    dx = player.x - ox
    dy = player.eye_y - oy
    dz = player.z - oz
    len = Math.sqrt(dx * dx + dy * dy + dz * dz)
    steps = (len * 2.0).to_i
    (1...steps).each do |i|
      t = i / (len * 2.0)
      return false if Block.solid?(world.get((ox + dx * t).floor, (oy + dy * t).floor, (oz + dz * t).floor))
    end
    true
  end

  # Takes damage, or the part of it above the last hit while the mob is
  # immune. Returns false when nothing is left to take, or the mob is dying.
  def wound(damage)
    return false if dying?

    if @immune > 0.0
      return false if damage <= @last_damage

      @hp -= damage - @last_damage
    else
      @hp -= damage
      @immune = IMMUNE
    end
    @last_damage = damage
    @hurt = 0.35
    @panic = PANIC if passive?
    @love.reset
    @ouch = true
    true
  end

  def hit(damage, from_x, from_z)
    return unless wound(damage)

    dx = @x - from_x
    dz = @z - from_z
    len = Math.sqrt(dx * dx + dz * dz)
    len = 1.0 if len < 0.001
    @vx = dx / len * 7.0
    @vz = dz / len * 7.0
    @vy = 5.5
    return unless passive?

    face(dx, dz)
    @walking = true
    @think = 1.0
  end

  # Distance along the ray to this mob's box, or -1.0 when the ray misses it.
  def ray(ox, oy, oz, dx, dy, dz)
    Ray.box_distance(ox, oy, oz, dx, dy, dz, @x - @half, @y, @z - @half, @x + @half, @y + @tall, @z + @half)
  end

  # True when the point x, y, z is in this mob's box.
  def contains?(x, y, z)
    x > @x - @half && x < @x + @half && y > @y && y < @y + @tall && z > @z - @half && z < @z + @half
  end

  # True when the column of height block cells from x, y, z up overlaps this
  # mob's box.
  def overlaps?(x, y, z, height)
    x + 1 > @x - @half && x < @x + @half && y + height > @y && y < @y + @tall && z + 1 > @z - @half && z < @z + @half
  end

  # The mob as the boxes of its Minecraft model, with its skin (Tex::SKINS).
  # A hurt mob is red, and a creeper flashes white as its fuse burns down.
  def draw(mesh)
    swing = Math.sin(@phase) * 0.7 * @leg_swing
    red = @hurt > 0.0 || dying? ? 0.45 : 1.0
    # The fall follows the curve of the game's renderer, which the wiki does
    # not confirm: sqrt(1.6 * t / DEATH_TIME) of a right angle.
    fall = Math.sqrt((1.6 * @death / DEATH_TIME).clamp(0.0, 1.0)) * Math::PI * 0.5
    mesh.roll(fall)
    @size = baby? ? 0.5 : 1.0
    if @kind == CREEPER
      draw_creeper(mesh, swing, red)
    elsif @kind == PIG
      draw_pig(mesh, swing, red)
    elsif @kind == SHEEP
      draw_sheep(mesh, swing, red)
    elsif @kind == COW
      draw_cow(mesh, swing, red)
    elsif @kind == CHICKEN
      draw_chicken(mesh, swing, red, fall)
    else
      draw_humanoid(mesh, swing, red)
    end
    mesh.roll(0.0)
    @size = 1.0
  end

  # The draw_ methods are the model of each kind. swing is the angle of the
  # legs, and red is the green and blue of a hurt mob.
  def draw_creeper(mesh, swing, red)
    l = Tex::SKINS + @kind
    flash = @fuse > 0.0 && Math.sin(@fuse * @fuse * 18.0) > 0.0 ? 1.6 : 0.0
    c = 1.0 + flash
    grow = @fuse * 0.4
    part(mesh, l, 0.0, 6.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 0.0, 0.0, grow, false, c, c * red, c * red)
    part(mesh, l, 0.0, 6.0, 0.0, 0.0, -4.0, 0.0, -2.0, 8.0, 12.0, 4.0, 16.0, 16.0, grow, false, c, c * red, c * red)
    legs(mesh, l, 2.0, 18.0, 4.0, -4.0, 6.0, 0.0, swing, c, c * red)
  end

  def draw_pig(mesh, swing, red)
    l = Tex::SKINS + @kind
    part(mesh, l, 0.0, 12.0, -6.0, 0.0, -4.0, -4.0, -8.0, 8.0, 8.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 12.0, -6.0, 0.0, -2.0, 0.0, -9.0, 4.0, 3.0, 1.0, 16.0, 16.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 11.0, 2.0, Math::PI / 2.0, -5.0, -10.0, -7.0, 10.0, 16.0, 8.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
    legs(mesh, l, 3.0, 18.0, 7.0, -5.0, 6.0, 0.0, swing, 1.0, red)
  end

  # A grazing sheep bows its head to the ground, and a sheared sheep has no
  # fur.
  def draw_sheep(mesh, swing, red)
    l = Tex::SKINS + @kind
    nod = @graze > 0.0 ? GRAZE_NOD : 0.0
    part(mesh, l, 0.0, 6.0, -8.0, nod, -3.0, -4.0, -6.0, 6.0, 6.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
    legs(mesh, l, 3.0, 12.0, 7.0, -5.0, 12.0, 0.0, swing, 1.0, red)
    return if @sheared

    fur = Tex::SKINS + Tex::SKIN_FUR
    part(mesh, fur, 0.0, 6.0, -8.0, nod, -3.0, -4.0, -4.0, 6.0, 6.0, 6.0, 0.0, 0.0, 0.6, false, 1.0, red, red)
    part(mesh, fur, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 1.75, false, 1.0, red, red)
    legs(mesh, fur, 3.0, 12.0, 7.0, -5.0, 6.0, 0.5, swing, 1.0, red)
  end

  # The head with its horns, the body with the udder under it, and legs 12
  # pixels long.
  def draw_cow(mesh, swing, red)
    l = Tex::SKINS + @kind
    part(mesh, l, 0.0, 4.0, -8.0, 0.0, -4.0, -4.0, -6.0, 8.0, 8.0, 6.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 4.0, -8.0, 0.0, -5.0, -5.0, -4.0, 1.0, 3.0, 1.0, 22.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 4.0, -8.0, 0.0, 4.0, -5.0, -4.0, 1.0, 3.0, 1.0, 22.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 5.0, 2.0, Math::PI / 2.0, -6.0, -10.0, -7.0, 12.0, 18.0, 10.0, 18.0, 4.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 5.0, 2.0, Math::PI / 2.0, -2.0, 2.0, -8.0, 4.0, 6.0, 1.0, 52.0, 0.0, 0.0, false, 1.0, red, red)
    legs(mesh, l, 4.0, 12.0, 7.0, -6.0, 12.0, 0.0, swing, 1.0, red)
  end

  # The ChickenModel of Minecraft. The wings turn around the axis from the
  # back to the front through their top edge: out and up as they beat.
  # fall is the angle of a dying mob (Mesh3#roll). A chick has the head of
  # a grown chicken, 5 pixels lower and 2 farther back, on a body half as
  # large (AgeableListModel).
  def draw_chicken(mesh, swing, red, fall)
    l = Tex::SKINS + @kind
    part(mesh, l, 0.0, 16.0, 0.0, Math::PI / 2.0, -3.0, -4.0, -3.0, 6.0, 8.0, 6.0, 0.0, 9.0, 0.0, false, 1.0, red, red)
    part(mesh, l, -2.0, 19.0, 1.0, swing, -1.0, 0.0, -3.0, 3.0, 5.0, 3.0, 26.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 1.0, 19.0, 1.0, -swing, -1.0, 0.0, -3.0, 3.0, 5.0, 3.0, 26.0, 0.0, 0.0, false, 1.0, red, red)
    beat = (Math.sin(@flap) + 1.0) * @flap_open
    wing(mesh, l, -4.0, fall, beat, red)
    wing(mesh, l, 4.0, fall, -beat, red)
    mesh.roll(fall)
    chick = baby?
    @size = 1.0
    py = chick ? 20.0 : 15.0
    pz = chick ? -2.0 : -4.0
    part(mesh, l, 0.0, py, pz, 0.0, -2.0, -6.0, -2.0, 4.0, 6.0, 3.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, py, pz, 0.0, -2.0, -4.0, -4.0, 4.0, 2.0, 2.0, 14.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, py, pz, 0.0, -1.0, -2.0, -3.0, 2.0, 2.0, 2.0, 14.0, 4.0, 0.0, false, 1.0, red, red)
  end

  # A wing of a chicken: 1 x 4 x 6 pixels that hang from the pivot px, 13,
  # 0 (px -4 is the right wing, 4 the left), turned by beat around the axis
  # from the back to the front through the pivot. Mesh3#roll turns the
  # whole body by fall around the axis through its feet, so the turn by
  # fall + beat goes around that axis, and the box moves by the difference
  # to turn around the pivot instead.
  def wing(mesh, l, px, fall, beat, red)
    k = @size / 16.0
    cx = px * k
    cy = 11.0 * k
    t = fall + beat
    mx = cx * Math.cos(fall) + cy * Math.sin(fall) - (cx * Math.cos(t) + cy * Math.sin(t))
    my = cy * Math.cos(fall) - cx * Math.sin(fall) - (cy * Math.cos(t) - cx * Math.sin(t))
    mesh.roll(t)
    x0 = px < 0.0 ? px : px - 1.0
    # to_f: Spinel cannot type the position of a mob.
    mesh.skin_box(@x.to_f + mx * Math.cos(@yaw), @y.to_f + my, @z.to_f + mx * Math.sin(@yaw), @yaw, 0.0, 0.0, 0.0,
                  x0 * k, 7.0 * k, -3.0 * k, (x0 + 1.0) * k, 11.0 * k, 3.0 * k,
                  l, 24.0, 13.0, 1.0, 4.0, 6.0, false, 1.0, red, red, 1.0)
  end

  # A zombie or a skeleton: a person with the arms out to the front. A
  # skeleton has thin arms and legs, and holds a bow.
  def draw_humanoid(mesh, swing, red)
    l = Tex::SKINS + @kind
    thin = @kind == SKELETON
    t = thin ? 2.0 : 4.0
    part(mesh, l, 0.0, 0.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 0.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 32.0, 0.0, 0.5, false, 1.0, red, red)
    part(mesh, l, 0.0, 0.0, 0.0, 0.0, -4.0, 0.0, -2.0, 8.0, 12.0, 4.0, 16.0, 16.0, 0.0, false, 1.0, red, red)
    arm = thin ? -1.45 : -1.5 + swing * 0.2
    part(mesh, l, -5.0, 2.0, 0.0, arm, thin ? -1.0 : -3.0, -2.0, -t / 2.0, t, 12.0, t, 40.0, 16.0, 0.0, false, 1.0, red, red)
    arm = thin ? -1.45 : -1.5 - swing * 0.2
    part(mesh, l, 5.0, 2.0, 0.0, arm, -1.0, -2.0, -t / 2.0, t, 12.0, t, 40.0, 16.0, 0.0, true, 1.0, red, red)
    leg = thin ? 2.0 : 1.9
    part(mesh, l, -leg, 12.0, 0.0, swing, -t / 2.0, 0.0, -t / 2.0, t, 12.0, t, 0.0, 16.0, 0.0, false, 1.0, red, red)
    part(mesh, l, leg, 12.0, 0.0, -swing, -t / 2.0, 0.0, -t / 2.0, t, 12.0, t, 0.0, 16.0, 0.0, true, 1.0, red, red)
    mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.04, 1.05, 0.55, 0.04, 1.75, 0.62, Tex::WHITE, 0.4, 0.26, 0.12, 1.0) if thin
    # A block on the head is 1 pixel larger on each side than the head.
    if @head > 0
      mesh.block_box(@x, @y, @z, @yaw, -0.3125, 1.4375, -0.3125, 0.3125, 2.0625, 0.3125,
                     Block::TOP[@head], Block::SIDE[@head], Block::BOTTOM[@head], Block::FRONT[@head], 1.0, red, red, 1.0)
    end
  end

  # One box of the Minecraft model: w x h x d pixels at bx, by, bz from the
  # pivot px, py, pz, turned by rot around the x axis through the pivot.
  # The numbers are those of the Minecraft model: 16 pixels to a block, y
  # down from 24 pixels above the feet, and the front to -z. The box takes
  # the skin at u, v (Mesh3#skin_box). grow makes the box larger on each
  # side, but not its skin, as for a hat or wool. The model has the scale
  # @size, from the feet: a baby is half as large.
  def part(mesh, layer, px, py, pz, rot, bx, by, bz, w, h, d, u, v, grow, mirror, r, g, b)
    k = @size / 16.0
    mesh.skin_box(@x, @y, @z, @yaw, (24.0 - py) * k, -pz * k, rot,
                  (px + bx - grow) * k, (24.0 - py - by - h - grow) * k, (-pz - bz - d - grow) * k,
                  (px + bx + w + grow) * k, (24.0 - py - by + grow) * k, (-pz - bz + grow) * k,
                  layer, u, v, w, h, d, mirror, r, g, b, 1.0)
  end

  # The four legs of a pig, a sheep, a cow or a creeper, in the numbers of part:
  # 4 pixels wide and h high, with pivots at x -dx and dx, height py, and
  # z hind and front. The legs on one diagonal swing one way, and the other
  # two the other way.
  def legs(mesh, layer, dx, py, hind, front, h, grow, swing, r, gb)
    4.times do |i|
      sw = (i == 0 || i == 3) ? swing : -swing
      part(mesh, layer, i % 2 == 0 ? -dx : dx, py, i / 2 == 0 ? hind : front, sw, -2.0, 0.0, -2.0, 4.0, h, 4.0, 0.0, 16.0, grow, false, r, gb, gb)
    end
  end
end
