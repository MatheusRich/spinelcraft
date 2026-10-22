# The body of a mob: its box, its moves, its damage, fire and death, and
# the parts of its box model. Animal (game/animal.rb) and Monster
# (game/monster.rb) give it its behavior.
class Mob
  PIG = 0
  ZOMBIE = 1
  SKELETON = 2
  SHEEP = 3
  CREEPER = 4
  COW = 5
  CHICKEN = 6
  # The traits of each kind, indexed by kind. Mob.define_mob fills them,
  # and each kind is one call to it, below the method.
  NAMES = []
  # The health of a new mob.
  HP = []
  # Half the width of the box, and its height, in blocks.
  HALF = []
  TALL = []
  # 1 for an animal (see Animal), which wanders, never attacks, and does
  # not count as a monster; 0 for a monster (see Monster).
  PASSIVE = []
  # A tempted animal walks at this part of WALK_SPEED; 0.0 for a monster.
  # The wiki does not give these values; they are those of the game code
  # (the registerGoals of Pig, Sheep, Cow and Chicken).
  TEMPT_PACE = []
  # The sounds of each kind. They follow VoxeLibre. SOUND plays now and
  # then, HURT_SOUND after a hit, and DEATH_SOUND when the mob dies. -1 is
  # no sound.
  SOUND = []
  HURT_SOUND = []
  DEATH_SOUND = []
  # A chicken in the air falls no faster than this, in blocks each second.
  # The wiki says only that chickens fall slowly (minecraft.wiki/w/Chicken).
  # This is the speed where Minecraft's gravity and the chicken's slowdown
  # of 0.6 for each tick meet, which the wiki does not confirm.
  CHICKEN_FALL = -2.3
  # An animal walks at WALK_SPEED, and the legs of a mob swing at their
  # widest from this speed up. The wiki does not give this value.
  WALK_SPEED = 1.3
  # After a hit, the mob takes for this many seconds only the part of a new
  # hit that is above the last one, as in Minecraft. minecraft.wiki/w/Damage
  IMMUNE = 0.5
  # Seconds of fire from lava. minecraft.wiki/w/Lava
  LAVA_FIRE = 15.0
  # A dead mob falls on its left side for 20 ticks, then its body goes up
  # in smoke. minecraft.wiki/w/Death
  DEATH_TIME = 1.0

  # Adds kind to the tables above, which name its arguments. The kinds come
  # in the order of their numbers. A kind is a monster that tempting does
  # not move, unless the arguments say something else.
  def self.define_mob(kind, name, hp:, half:, tall:, sound:, hurt:, death:, passive: 0, tempt_pace: 0.0)
    abort "Mob.define_mob: kind #{kind} comes out of order" if kind != NAMES.size
    NAMES << name
    HP << hp
    HALF << half
    TALL << tall
    PASSIVE << passive
    TEMPT_PACE << tempt_pace
    SOUND << sound
    HURT_SOUND << hurt
    DEATH_SOUND << death
  end

  # minecraft.wiki/w/Pig
  define_mob PIG, "PIG", hp: 10.0, half: 0.45, tall: 0.95, passive: 1, tempt_pace: 1.2,
                         sound: Sfx::OINK, hurt: Sfx::OINK, death: Sfx::PIG_DEATH
  # minecraft.wiki/w/Zombie
  define_mob ZOMBIE, "ZOMBIE", hp: 20.0, half: 0.3, tall: 1.9,
                               sound: Sfx::GROAN, hurt: Sfx::ZOMBIE_HURT, death: Sfx::ZOMBIE_DEATH
  # minecraft.wiki/w/Skeleton
  define_mob SKELETON, "SKELETON", hp: 20.0, half: 0.3, tall: 1.9,
                                   sound: Sfx::RATTLE, hurt: Sfx::SKELETON_HURT, death: Sfx::SKELETON_DEATH
  # minecraft.wiki/w/Sheep
  define_mob SHEEP, "SHEEP", hp: 8.0, half: 0.45, tall: 1.2, passive: 1, tempt_pace: 1.1,
                             sound: Sfx::BAA, hurt: Sfx::BAA, death: Sfx::BAA
  # A creeper makes no sound now and then, as in Minecraft.
  # minecraft.wiki/w/Creeper
  define_mob CREEPER, "CREEPER", hp: 20.0, half: 0.3, tall: 1.7,
                                 sound: -1, hurt: Sfx::CREEPER_HURT, death: Sfx::CREEPER_DEATH
  # minecraft.wiki/w/Cow
  define_mob COW, "COW", hp: 10.0, half: 0.45, tall: 1.4, passive: 1, tempt_pace: 1.25,
                         sound: Sfx::MOO, hurt: Sfx::COW_HURT, death: Sfx::COW_HURT
  # minecraft.wiki/w/Chicken
  define_mob CHICKEN, "CHICKEN", hp: 4.0, half: 0.2, tall: 0.7, passive: 1, tempt_pace: 1.0,
                                 sound: Sfx::CLUCK, hurt: Sfx::CHICKEN_HURT, death: Sfx::CHICKEN_HURT

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :hp, :alive, :by_player
  # True after a hit, until Game#update_mobs plays the hurt sound.
  attr_accessor :ouch
  # True after a step on the ground, until Game#update_mobs plays it.
  attr_accessor :step
  # Seconds that the mob still burns.
  attr_reader :fire
  attr_reader :kind, :half, :tall, :hurt
  # Seconds since the mob died; 0.0 while it lives.
  attr_reader :death
  # How far the legs swing, from 0 at rest to 1 at a walk or faster.
  attr_reader :leg_swing

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
    @ouch = false
    @step = false
    @step_dist = 0.0
    @by_player = false
    @hurt = 0.0
    @alive = true
    @phase = 0.0
    @half = HALF[kind]
    @tall = TALL[kind]
    @rng = Rng.new(seed)
    @on_ground = false
    @burn = 0.0
    @fire = 0.0
    @immune = 0.0
    @last_damage = 0.0
    @death = 0.0
    @leg_swing = 0.0
    # Seconds that a wall has stopped the mob.
    @stuck = 0.0
    # The scale of the next parts of the model (see part).
    @size = 1.0
  end

  # Only an Animal can be a baby, eat food from the hand or have wool to
  # shear.
  def baby? = false
  def food?(_block) = false
  def shearable? = false

  def passive? = PASSIVE[@kind] == 1

  def burning? = @fire > 0.0

  # A dying mob lies on the ground until DEATH_TIME. It does not move on its
  # own, attack or take hits.
  def dying? = @hp <= 0

  # True when Game#update_mobs takes the mob out: it is dead, it is out of
  # the loaded chunks, or it despawns (Animal#despawn?, Monster#despawn?).
  # despawn? comes last, so only a live monster in a loaded chunk moves its
  # idle time on. Ask once each frame.
  def gone?(world, player, dt) = !@alive || !world.loaded?(@x.floor, @z.floor) || despawn?(player, dt)

  # Why Game#update_mobs takes the mob out, for Log::MOBS.
  def gone_reason(world)
    return "dies" unless @alive
    return "is out of the loaded chunks" unless world.loaded?(@x.floor, @z.floor)

    "despawns"
  end

  # Rain or water puts out the fire.
  def douse
    @fire = 0.0
  end

  def blocked?(world) = world.solid_in_box?(@x, @y, @z, @half, @tall)

  # Moves and returns true when a wall stopped the horizontal motion.
  def move(world, dx, dy, dz)
    # to_f: Spinel cannot type the position and the speed of the mob.
    x = world.collide(@x.to_f, @y.to_f, @z.to_f, @half, @tall, 0, dx.to_f)
    bumped_x = x != @x + dx
    @vx = 0.0 if bumped_x
    @x = x
    z = world.collide(@x.to_f, @y.to_f, @z.to_f, @half, @tall, 2, dz.to_f)
    bumped_z = z != @z + dz
    @vz = 0.0 if bumped_z
    @z = z
    y = world.collide(@x.to_f, @y.to_f, @z.to_f, @half, @tall, 1, dy.to_f)
    @on_ground = dy < 0.0 && y != @y + dy
    @vy = 0.0 if y != @y + dy
    @y = y
    bumped_x || bumped_z
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

  # Returns the damage that the mob deals to the player in this step:
  # none, but Monster#update_mob returns the bite of a zombie. held is the
  # item in the player's hand.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_mob(world, dt, player, held) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    @hurt -= dt
    @immune -= dt
    speed = 0.0
    if dying?
      @death += dt
    else
      speed = act(world, dt, player, held)
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
    after_move(dt)
    moving = Math.sqrt(@vx * @vx + @vz * @vz)
    @phase += moving * dt * 3.5
    # The legs swing as far as the mob goes fast, and come to rest when it
    # stops, as in Minecraft.
    @leg_swing += ((moving / WALK_SPEED).clamp(0.0, 1.0) - @leg_swing) * (8.0 * dt).clamp(0.0, 1.0)
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
    0
  end

  # What the mob does after the move of a step: nothing, but
  # Animal#after_move turns a stuck animal and beats the wings of a
  # chicken. Each kind also has an act method (Animal#act, Monster#act):
  # its AI, which can turn the mob and returns the speed that it walks at.
  def after_move(_dt) = nil

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
    @ouch = true
    true
  end

  # The hit throws the mob back. Returns false when the hit takes nothing.
  def hit(damage, from_x, from_z)
    return false unless wound(damage)

    dx = @x - from_x
    dz = @z - from_z
    len = Math.sqrt(dx * dx + dz * dz)
    len = 1.0 if len < 0.001
    @vx = dx / len * 7.0
    @vz = dz / len * 7.0
    @vy = 5.5
    true
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
    # The model of each kind: Animal#draw_model and Monster#draw_model.
    # swing is the angle of the legs, red is the green and blue of a hurt
    # mob, and fall the angle of a dying mob.
    draw_model(mesh, swing, red, fall)
    mesh.roll(0.0)
    @size = 1.0
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
