# Pigs, sheep, zombies, skeletons and creepers: behavior, physics and box models.
class Mob
  PIG = 0
  ZOMBIE = 1
  SKELETON = 2
  SHEEP = 3
  CREEPER = 4
  # Seconds of a creeper's fuse. minecraft.wiki/w/Creeper
  FUSE = 1.5
  # A creeper lights its fuse when the player is this near, and the fuse
  # burns until the player is this far, as in Minecraft.
  # minecraft.wiki/w/Creeper
  LIGHT_REACH = 3.0
  FUSE_REACH = 7.0
  # Traits indexed by kind: pig, zombie, skeleton, sheep, creeper.
  # MOB_SOUND in game/combat.rb has the sounds.
  # minecraft.wiki/w/Pig, /w/Zombie, /w/Skeleton, /w/Sheep and /w/Creeper
  HP = [10.0, 20.0, 20.0, 8.0, 20.0]
  HALF = [0.45, 0.3, 0.3, 0.45, 0.3]
  TALL = [0.95, 1.9, 1.9, 1.2, 1.7]
  # Passive mobs wander, never attack, and do not count as monsters.
  PASSIVE = [1, 0, 0, 1, 0]
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

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :hp, :hurt, :alive, :shoot, :explode, :by_player
  # True for one step after a creeper lights its fuse.
  attr_accessor :hiss
  # True after a hit, until Game#update_mobs plays the hurt sound.
  attr_accessor :ouch
  # True after a step on the ground, until Game#update_mobs plays it.
  attr_accessor :step
  attr_reader :fuse
  # Seconds that the mob still burns.
  attr_reader :fire
  attr_reader :kind, :half, :tall
  # Seconds that a monster has been far from the player (Game#despawn?).
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

  def initialize(kind, x, y, z, seed)
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
  end

  def passive? = PASSIVE[@kind] == 1

  # A dying mob lies on the ground until DEATH_TIME. It does not move on its
  # own, attack or take hits.
  def dying? = @hp <= 0

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

  # Returns damage dealt to the player this step.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_mob(world, dt, player, day)
    @hurt -= dt
    @immune -= dt
    @attack_wait -= dt
    speed = 0.0
    damage = 0
    if dying?
      @death += dt
    elsif passive?
      speed = act_passive(dt)
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
      exposed = world.height_at(@x.floor, @z.floor) <= (@y + 1.6).floor
      @fire = SUN_FIRE if day > 0.65 && exposed && @kind != CREEPER && @fire < SUN_FIRE
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
    if @on_ground && !dying?
      @step_dist += moving * dt
      if @step_dist > Player::STEP
        @step_dist = 0.0
        @step = true
      end
    end
    @alive = false if @death >= DEATH_TIME || @y < -10.0
    damage
  end

  # The act_ methods are the AI of each kind. Each one can turn the mob,
  # and returns the speed that it walks at. dx, dz is the step to the
  # player, and dist is its length.

  # A passive mob wanders, and after a hit it panics.
  def act_passive(dt)
    @think -= dt
    @panic -= dt
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
    @walking ? (@panic > 0.0 ? PANIC_SPEED : WALK_SPEED) : 0.0
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
    i = 1
    while i < steps
      t = i / (len * 2.0)
      return false if Block.solid?(world.get((ox + dx * t).floor, (oy + dy * t).floor, (oz + dz * t).floor))
      i += 1
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

  # The mob as the boxes of its Minecraft model, with its skin (Tex::SKINS).
  # A hurt mob is red, and a creeper flashes white as its fuse burns down.
  def draw(mesh)
    swing = Math.sin(@phase) * 0.7 * @leg_swing
    red = @hurt > 0.0 || dying? ? 0.45 : 1.0
    # The fall follows the curve of the game's renderer, which the wiki does
    # not confirm: sqrt(1.6 * t / DEATH_TIME) of a right angle.
    mesh.roll(Math.sqrt((1.6 * @death / DEATH_TIME).clamp(0.0, 1.0)) * Math::PI * 0.5)
    if @kind == CREEPER
      draw_creeper(mesh, swing, red)
    elsif @kind == PIG
      draw_pig(mesh, swing, red)
    elsif @kind == SHEEP
      draw_sheep(mesh, swing, red)
    else
      draw_humanoid(mesh, swing, red)
    end
    mesh.roll(0.0)
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

  def draw_sheep(mesh, swing, red)
    l = Tex::SKINS + @kind
    part(mesh, l, 0.0, 6.0, -8.0, 0.0, -3.0, -4.0, -6.0, 6.0, 6.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, l, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
    legs(mesh, l, 3.0, 12.0, 7.0, -5.0, 12.0, 0.0, swing, 1.0, red)
    fur = Tex::SKINS + Tex::SKIN_FUR
    part(mesh, fur, 0.0, 6.0, -8.0, 0.0, -3.0, -4.0, -4.0, 6.0, 6.0, 6.0, 0.0, 0.0, 0.6, false, 1.0, red, red)
    part(mesh, fur, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 1.75, false, 1.0, red, red)
    legs(mesh, fur, 3.0, 12.0, 7.0, -5.0, 6.0, 0.5, swing, 1.0, red)
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
  # side, but not its skin, as for a hat or wool.
  def part(mesh, layer, px, py, pz, rot, bx, by, bz, w, h, d, u, v, grow, mirror, r, g, b)
    mesh.skin_box(@x, @y, @z, @yaw, (24.0 - py) / 16.0, -pz / 16.0, rot,
                  (px + bx - grow) / 16.0, (24.0 - py - by - h - grow) / 16.0, (-pz - bz - d - grow) / 16.0,
                  (px + bx + w + grow) / 16.0, (24.0 - py - by + grow) / 16.0, (-pz - bz + grow) / 16.0,
                  layer, u, v, w, h, d, mirror, r, g, b, 1.0)
  end

  # The four legs of a pig, a sheep or a creeper, in the numbers of part:
  # 4 pixels wide and h high, with pivots at x -dx and dx, height py, and
  # z hind and front. The legs on one diagonal swing one way, and the other
  # two the other way.
  def legs(mesh, layer, dx, py, hind, front, h, grow, swing, r, gb)
    i = 0
    while i < 4
      sw = (i == 0 || i == 3) ? swing : -swing
      part(mesh, layer, i % 2 == 0 ? -dx : dx, py, i / 2 == 0 ? hind : front, sw, -2.0, 0.0, -2.0, 4.0, h, 4.0, 0.0, 16.0, grow, false, r, gb, gb)
      i += 1
    end
  end
end
