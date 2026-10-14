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
  HP = [10, 20, 20, 8, 20]
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

  attr_accessor :x, :y, :z, :vx, :vy, :vz, :yaw, :hp, :hurt, :alive, :phase, :shoot, :explode, :by_player
  attr_reader :fuse
  # Seconds that the mob still burns.
  attr_reader :fire
  attr_reader :kind, :half, :tall

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
    @last_damage = 0
  end

  def passive? = PASSIVE[@kind] == 1

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
        @y = @y.floor + 1.0
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
    if passive?
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
    take(4) if Block.lava?(feet)
    if @fire > 0.0
      @fire -= dt
      @burn -= dt
      if @burn <= 0.0
        @burn = 1.0
        take(1)
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
    @vy = 8.2 if bumped && @on_ground
    moving = Math.sqrt(@vx * @vx + @vz * @vz)
    @phase += moving * dt * 3.5
    @alive = false if @hp <= 0 || @y < -10.0
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
  # immune. Returns false when nothing is left to take.
  def take(damage)
    if @immune > 0.0
      return false if damage <= @last_damage
      @hp -= damage - @last_damage
    else
      @hp -= damage
      @immune = IMMUNE
    end
    @last_damage = damage
    @hurt = 0.35
    true
  end

  def hit(damage, from_x, from_z)
    return unless take(damage)
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

  def draw(mesh)
    swing = Math.sin(@phase) * 0.7
    red = @hurt > 0.0 ? 0.45 : 1.0
    s = Tex::SKIN
    if @kind == CREEPER
      # It flashes white faster as the fuse burns down.
      flash = @fuse > 0.0 && Math.sin(@fuse * @fuse * 18.0) > 0.0 ? 1.0 : 0.0
      cr = 0.3 + flash * 0.7
      cg = 0.72 * red + flash * 0.28
      cb = 0.3 + flash * 0.7
      grow = 1.0 + @fuse * 0.08
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.25 * grow, 1.2, -0.25 * grow, 0.25 * grow, 1.7, 0.25 * grow, s, cr, cg, cb, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.16, 1.45, 0.251 * grow, -0.05, 1.56, 0.26 * grow, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, 0.05, 1.45, 0.251 * grow, 0.16, 1.56, 0.26 * grow, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.06, 1.28, 0.251 * grow, 0.06, 1.42, 0.26 * grow, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.2 * grow, 0.4, -0.13 * grow, 0.2 * grow, 1.2, 0.13 * grow, s, cr * 0.9, cg * 0.9, cb * 0.9, 1.0)
      i = 0
      while i < 4
        lx = i % 2 == 0 ? -0.13 : 0.13
        lz = i / 2 == 0 ? -0.24 : 0.24
        sw = (i == 0 || i == 3) ? swing : -swing
        mesh.box(@x, @y, @z, @yaw, 0.4, lz, sw, lx - 0.11, 0.0, lz - 0.1, lx + 0.11, 0.4, lz + 0.1, s, cr * 0.8, cg * 0.8, cb * 0.8, 1.0)
        i += 1
      end
    elsif @kind == SHEEP
      wool = Tex::WOOL
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.45, 0.45, -0.6, 0.45, 1.15, 0.6, wool, red, red, red, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.22, 0.75, 0.55, 0.22, 1.15, 0.95, s, 0.55, 0.5 * red, 0.48 * red, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.18, 0.95, 0.951, -0.08, 1.03, 0.96, Tex::WHITE, 0.1, 0.1, 0.1, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, 0.08, 0.95, 0.951, 0.18, 1.03, 0.96, Tex::WHITE, 0.1, 0.1, 0.1, 1.0)
      i = 0
      while i < 4
        lx = i % 2 == 0 ? -0.22 : 0.22
        lz = i / 2 == 0 ? -0.38 : 0.38
        sw = (i == 0 || i == 3) ? swing : -swing
        mesh.box(@x, @y, @z, @yaw, 0.45, lz, sw, lx - 0.09, 0.0, lz - 0.09, lx + 0.09, 0.47, lz + 0.09, s, 0.55, 0.5 * red, 0.48 * red, 1.0)
        i += 1
      end
    elsif @kind == PIG
      r = 0.95
      g = 0.62 * red
      b = 0.62 * red
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.4, 0.4, -0.55, 0.4, 0.9, 0.55, s, r, g, b, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.28, 0.5, 0.5, 0.28, 1.0, 0.95, s, r, g, b, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.13, 0.55, 0.95, 0.13, 0.72, 1.02, s, 0.85, 0.45 * red, 0.5 * red, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.2, 0.8, 0.951, -0.1, 0.9, 0.96, Tex::WHITE, 0.1, 0.1, 0.1, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, 0.1, 0.8, 0.951, 0.2, 0.9, 0.96, Tex::WHITE, 0.1, 0.1, 0.1, 1.0)
      i = 0
      while i < 4
        lx = i % 2 == 0 ? -0.22 : 0.22
        lz = i / 2 == 0 ? -0.35 : 0.35
        sw = (i == 0 || i == 3) ? swing : -swing
        mesh.box(@x, @y, @z, @yaw, 0.4, lz, sw, lx - 0.1, 0.0, lz - 0.1, lx + 0.1, 0.42, lz + 0.1, s, r * 0.9, g * 0.9, b * 0.9, 1.0)
        i += 1
      end
    elsif @kind == SKELETON
      b = 0.86 * red + (1.0 - red) * 0.9
      c = 0.84 * red
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.24, 1.42, -0.24, 0.24, 1.9, 0.24, s, b, c, c, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.16, 1.6, 0.241, -0.05, 1.7, 0.25, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, 0.05, 1.6, 0.241, 0.16, 1.7, 0.25, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.2, 0.78, -0.08, 0.2, 1.42, 0.08, s, b * 0.8, c * 0.8, c * 0.8, 1.0)
      mesh.box(@x, @y, @z, @yaw, 1.35, 0.0, -1.45, -0.3, 0.8, -0.05, -0.2, 1.4, 0.05, s, b, c, c, 1.0)
      mesh.box(@x, @y, @z, @yaw, 1.35, 0.0, -1.45, 0.2, 0.8, -0.05, 0.3, 1.4, 0.05, s, b, c, c, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.04, 1.05, 0.55, 0.04, 1.75, 0.62, Tex::WHITE, 0.4, 0.26, 0.12, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.78, 0.0, swing, -0.17, 0.0, -0.05, -0.07, 0.78, 0.05, s, b, c, c, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.78, 0.0, -swing, 0.07, 0.0, -0.05, 0.17, 0.78, 0.05, s, b, c, c, 1.0)
    else
      skin_r = 0.35 * red + (1.0 - red)
      skin_g = 0.62 * red
      skin_b = 0.32 * red
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.25, 1.4, -0.25, 0.25, 1.9, 0.25, s, skin_r, skin_g, skin_b, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.17, 1.6, 0.251, -0.06, 1.68, 0.26, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, 0.06, 1.6, 0.251, 0.17, 1.68, 0.26, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.0, 0.0, 0.0, -0.25, 0.75, -0.13, 0.25, 1.4, 0.13, s, 0.15 + (1.0 - red), 0.55 * red, 0.6 * red, 1.0)
      mesh.box(@x, @y, @z, @yaw, 1.35, 0.0, -1.5 + swing * 0.2, -0.37, 0.75, -0.12, -0.25, 1.4, 0.12, s, skin_r, skin_g, skin_b, 1.0)
      mesh.box(@x, @y, @z, @yaw, 1.35, 0.0, -1.5 - swing * 0.2, 0.25, 0.75, -0.12, 0.37, 1.4, 0.12, s, skin_r, skin_g, skin_b, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.75, 0.0, swing, -0.24, 0.0, -0.12, -0.01, 0.75, 0.12, s, 0.25, 0.25 * red, 0.6 * red, 1.0)
      mesh.box(@x, @y, @z, @yaw, 0.75, 0.0, -swing, 0.01, 0.0, -0.12, 0.24, 0.75, 0.12, s, 0.25, 0.25 * red, 0.6 * red, 1.0)
    end
  end
end
