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

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :hp, :hurt, :alive, :phase, :shoot, :explode, :by_player
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
      @think -= dt
      if @think <= 0.0
        @think = 2.0 + @rng.rand01 * 4.0
        @walking = @rng.rand01 < 0.6
        @yaw = @rng.rand01 * 6.283
      end
      speed = @walking ? 1.3 : 0.0
      speed = 4.0 if @hurt > 0.0
    else
      dx = player.x - @x
      dz = player.z - @z
      dist = Math.sqrt(dx * dx + dz * dz)
      if @kind == SKELETON
        # Keep a bow's distance and shoot when the player is in sight.
        if dist < 26.0
          face(dx, dz)
          speed = dist > 12.0 ? 2.0 : (dist < 7.0 ? -1.6 : 0.0)
          if @attack_wait <= 0.0 && dist < 18.0 && sees?(world, player)
            # About one shot each 3 seconds. minecraft.wiki/w/Skeleton
            @attack_wait = 3.0
            @shoot = true
          end
        end
      elsif @kind == CREEPER
        # Walk up to the player, then stand still while the fuse burns.
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
      else
        if dist < 28.0 && dist > 0.6
          face(dx, dz)
          speed = 2.4
        end
        if dist < 1.4 && (player.y - @y).abs < 1.8 && @attack_wait <= 0.0
          @attack_wait = 1.0
          # minecraft.wiki/w/Zombie
          damage = 3
        end
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
    moving = Math.sqrt(@vx * @vx + @vz * @vz)
    @phase += moving * dt * 3.5
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
    @walking = true
    @think = 3.0
  end

  # Distance along the ray to this mob's box, or -1.0 when the ray misses it.
  def ray(ox, oy, oz, dx, dy, dz)
    Ray.box_distance(ox, oy, oz, dx, dy, dz, @x - @half, @y, @z - @half, @x + @half, @y + @tall, @z + @half)
  end

  # The mob as the boxes of its Minecraft model, with its skin (Tex::SKINS).
  # A hurt mob is red, and a creeper flashes white as its fuse burns down.
  def draw(mesh)
    swing = Math.sin(@phase) * 0.7
    red = @hurt > 0.0 || dying? ? 0.45 : 1.0
    # The fall follows the curve of the game's renderer, which the wiki does
    # not confirm: sqrt(1.6 * t / DEATH_TIME) of a right angle.
    mesh.roll(Math.sqrt((1.6 * @death / DEATH_TIME).clamp(0.0, 1.0)) * Math::PI * 0.5)
    l = Tex::SKINS + @kind
    if @kind == CREEPER
      flash = @fuse > 0.0 && Math.sin(@fuse * @fuse * 18.0) > 0.0 ? 1.6 : 0.0
      c = 1.0 + flash
      grow = @fuse * 0.4
      part(mesh, l, 0.0, 6.0, 0.0, 0.0, -4.0, -8.0, -4.0, 8.0, 8.0, 8.0, 0.0, 0.0, grow, false, c, c * red, c * red)
      part(mesh, l, 0.0, 6.0, 0.0, 0.0, -4.0, 0.0, -2.0, 8.0, 12.0, 4.0, 16.0, 16.0, grow, false, c, c * red, c * red)
      legs(mesh, l, 2.0, 18.0, 4.0, -4.0, 6.0, 0.0, swing, c, c * red)
    elsif @kind == PIG
      part(mesh, l, 0.0, 12.0, -6.0, 0.0, -4.0, -4.0, -8.0, 8.0, 8.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
      part(mesh, l, 0.0, 12.0, -6.0, 0.0, -2.0, 0.0, -9.0, 4.0, 3.0, 1.0, 16.0, 16.0, 0.0, false, 1.0, red, red)
      part(mesh, l, 0.0, 11.0, 2.0, Math::PI / 2.0, -5.0, -10.0, -7.0, 10.0, 16.0, 8.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
      legs(mesh, l, 3.0, 18.0, 7.0, -5.0, 6.0, 0.0, swing, 1.0, red)
    elsif @kind == SHEEP
      part(mesh, l, 0.0, 6.0, -8.0, 0.0, -3.0, -4.0, -6.0, 6.0, 6.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
      part(mesh, l, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
      legs(mesh, l, 3.0, 12.0, 7.0, -5.0, 12.0, 0.0, swing, 1.0, red)
      fur = Tex::SKINS + Tex::SKIN_FUR
      part(mesh, fur, 0.0, 6.0, -8.0, 0.0, -3.0, -4.0, -4.0, 6.0, 6.0, 6.0, 0.0, 0.0, 0.6, false, 1.0, red, red)
      part(mesh, fur, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 1.75, false, 1.0, red, red)
      legs(mesh, fur, 3.0, 12.0, 7.0, -5.0, 6.0, 0.5, swing, 1.0, red)
    else
      # A zombie or a skeleton: a person with the arms out to the front. A
      # skeleton has thin arms and legs, and holds a bow.
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
    end
    mesh.roll(0.0)
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
