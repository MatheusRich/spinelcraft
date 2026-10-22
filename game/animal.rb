# Pigs, sheep, cows and chickens: they wander, panic after a hit, follow
# their food, breed and grow up. A sheep grazes and grows its wool back,
# and a chicken lays eggs and beats its wings.
class Animal < Mob
  # A chicken lays an egg each 5 to 10 minutes. minecraft.wiki/w/Chicken
  EGG_MIN = 300.0
  EGG_MORE = 300.0
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
  # A tempted animal stops 2.5 blocks from the player, and walks at its
  # TEMPT_PACE (Mob.define_mob). The wiki does not give this value; it is
  # that of the game code (TemptGoal).
  TEMPT_NEAR = 2.5
  # After damage an animal panics for PANIC seconds: it runs at
  # PANIC_SPEED, first away from a hit and then to a new side about each
  # second. The wiki says only that a pig "flees for a short time when
  # harmed" (minecraft.wiki/w/Pig), so it does not confirm these values.
  PANIC = 5.0
  PANIC_SPEED = 2.6
  # An animal that a wall stops for this many seconds turns to a new side.
  STUCK = 0.5
  # An animal despawns farther than this many blocks along x and z from
  # the player. minecraft.wiki does not give this value.
  DESPAWN = 160.0
  # A sheep eats for 40 ticks, and it takes its bite 4 ticks before the end:
  # then the grass goes and the wool grows back. A panic stops the eating
  # before the bite. The wiki does not give these times or the panic rule;
  # they are those of the game code (EatBlockGoal, and PanicGoal, which
  # runs first).
  GRAZE_TIME = 2.0
  BITE_LEFT = 0.2
  # How far a grazing sheep turns its head down, in radians.
  GRAZE_NOD = 0.9

  # Seconds that the animal still panics.
  attr_reader :panic
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
  # Seconds until a baby grows up; 0.0 for a grown animal.
  attr_reader :grow_left
  # The love mode of the animal.
  attr_reader :love
  # True while the animal follows a player who holds its food.
  attr_reader :tempted

  def initialize(kind, x, y, z, seed)
    super
    @think = 0.0
    @walking = false
    @panic = 0.0
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
    @love = Love.new
    @tempted = false
  end

  def baby? = @grow_left > 0.0

  # Makes this animal a baby that grows up after GROW_TIME.
  def make_baby
    @grow_left = GROW_TIME
    @half = HALF[@kind] / 2.0
    @tall = TALL[@kind] / 2.0
  end

  # dt more seconds of growing up. A grown animal takes its full size.
  def grow_up(dt)
    return unless baby?

    @grow_left -= dt
    return if baby?

    @grow_left = 0.0
    @half = HALF[@kind]
    @tall = TALL[@kind]
  end

  # True when block is the breeding food of this animal: wheat for a cow, a
  # sheep and a pig, and seeds for a chicken. minecraft.wiki/w/Breeding
  # Minecraft breeds pigs with carrots since 1.4.2. From Beta 1.9
  # Prerelease 2 until then, wheat bred them (minecraft.wiki/w/Pig). The
  # game has no carrots, so pigs take wheat. A chicken also takes pumpkin
  # seeds. minecraft.wiki/w/Chicken
  def food?(block)
    return block == Block::SEEDS || block == Block::PUMPKIN_SEEDS if @kind == CHICKEN

    block == Block::WHEAT
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

  # A baby sheep has wool, but shears do not take it. The wiki shows a
  # sheared baby sheep as one that only commands make
  # (minecraft.wiki/w/Sheep); the game code checks for a baby
  # (Sheep.readyForShearing).
  def shearable? = @kind == SHEEP && !@sheared && !dying? && !baby?

  # The sheep starts to eat grass: it stands still with its head down.
  def start_graze
    @graze = GRAZE_TIME
  end

  # The wool of a sheared sheep grows back after its bite of grass.
  # minecraft.wiki/w/Sheep
  def regrow
    @sheared = false
  end

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

  # True when the animal despawns, far from the player along x and z.
  def despawn?(player, _dt)
    dx = @x - player.x
    dz = @z - player.z
    dx * dx + dz * dz > DESPAWN * DESPAWN
  end

  # The clocks of the grazing, the growth, the eggs and the love mode run
  # before the step of Mob#update_mob.
  def update_mob(world, dt, player, held)
    if @graze > 0.0
      @graze = 0.0 if @panic > 0.0 || dying?
      @grass_bite = true if @graze > BITE_LEFT && @graze - dt <= BITE_LEFT
      @graze -= dt
    end
    grow_up(dt)
    lay_eggs(dt)
    @love.clock(dt)
    super
  end

  # The animal wanders, and after a hit it panics. A lover walks to its
  # mate, and else an animal that does not panic follows a player who
  # holds its food (held), as the order of the goals in the game code. A
  # panicking animal has no mate: the hit ended its love mode (Love#reset).
  def act(_world, dt, player, held)
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

  # An animal that a wall stopped for STUCK seconds turns to a new side
  # (act), and a chicken beats its wings.
  def after_move(dt)
    if @stuck > STUCK
      @think = 0.0
      @stuck = 0.0
    end
    flap_wings(dt) if @kind == CHICKEN
    nil
  end

  def wound(damage)
    return false unless super

    @panic = PANIC
    @love.reset
    true
  end

  # A hit animal runs away from the hit.
  def hit(damage, from_x, from_z)
    return false unless super

    face(@x - from_x, @z - from_z)
    @walking = true
    @think = 1.0
    true
  end

  # The animal as the boxes of its Minecraft model.
  def draw_model(mesh, swing, red, fall)
    if @kind == PIG
      draw_pig(mesh, swing, red)
    elsif @kind == SHEEP
      draw_sheep(mesh, swing, red)
    elsif @kind == COW
      draw_cow(mesh, swing, red)
    else
      draw_chicken(mesh, swing, red, fall)
    end
    # A nil return keeps Spinel from boxing it.
    nil
  end

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

  def draw_pig(mesh, swing, red)
    layer = Tex::SKINS + @kind
    part(mesh, layer, 0.0, 12.0, -6.0, 0.0, -4.0, -4.0, -8.0, 8.0, 8.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 12.0, -6.0, 0.0, -2.0, 0.0, -9.0, 4.0, 3.0, 1.0, 16.0, 16.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 11.0, 2.0, Math::PI / 2.0, -5.0, -10.0, -7.0, 10.0, 16.0, 8.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
    legs(mesh, layer, 3.0, 18.0, 7.0, -5.0, 6.0, 0.0, swing, 1.0, red)
  end

  # A grazing sheep bows its head to the ground, and a sheared sheep has no
  # fur.
  def draw_sheep(mesh, swing, red)
    layer = Tex::SKINS + @kind
    nod = @graze > 0.0 ? GRAZE_NOD : 0.0
    part(mesh, layer, 0.0, 6.0, -8.0, nod, -3.0, -4.0, -6.0, 6.0, 6.0, 8.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 0.0, false, 1.0, red, red)
    legs(mesh, layer, 3.0, 12.0, 7.0, -5.0, 12.0, 0.0, swing, 1.0, red)
    return if @sheared

    fur = Tex::SKINS + Tex::SKIN_FUR
    part(mesh, fur, 0.0, 6.0, -8.0, nod, -3.0, -4.0, -4.0, 6.0, 6.0, 6.0, 0.0, 0.0, 0.6, false, 1.0, red, red)
    part(mesh, fur, 0.0, 5.0, 2.0, Math::PI / 2.0, -4.0, -10.0, -7.0, 8.0, 16.0, 6.0, 28.0, 8.0, 1.75, false, 1.0, red, red)
    legs(mesh, fur, 3.0, 12.0, 7.0, -5.0, 6.0, 0.5, swing, 1.0, red)
  end

  # The head with its horns, the body with the udder under it, and legs 12
  # pixels long.
  def draw_cow(mesh, swing, red)
    layer = Tex::SKINS + @kind
    part(mesh, layer, 0.0, 4.0, -8.0, 0.0, -4.0, -4.0, -6.0, 8.0, 8.0, 6.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 4.0, -8.0, 0.0, -5.0, -5.0, -4.0, 1.0, 3.0, 1.0, 22.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 4.0, -8.0, 0.0, 4.0, -5.0, -4.0, 1.0, 3.0, 1.0, 22.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 5.0, 2.0, Math::PI / 2.0, -6.0, -10.0, -7.0, 12.0, 18.0, 10.0, 18.0, 4.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, 5.0, 2.0, Math::PI / 2.0, -2.0, 2.0, -8.0, 4.0, 6.0, 1.0, 52.0, 0.0, 0.0, false, 1.0, red, red)
    legs(mesh, layer, 4.0, 12.0, 7.0, -6.0, 12.0, 0.0, swing, 1.0, red)
  end

  # The ChickenModel of Minecraft. The wings turn around the axis from the
  # back to the front through their top edge: out and up as they beat.
  # fall is the angle of a dying mob (Mesh3#roll). A chick has the head of
  # a grown chicken, 5 pixels lower and 2 farther back, on a body half as
  # large (AgeableListModel).
  def draw_chicken(mesh, swing, red, fall)
    layer = Tex::SKINS + @kind
    part(mesh, layer, 0.0, 16.0, 0.0, Math::PI / 2.0, -3.0, -4.0, -3.0, 6.0, 8.0, 6.0, 0.0, 9.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, -2.0, 19.0, 1.0, swing, -1.0, 0.0, -3.0, 3.0, 5.0, 3.0, 26.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 1.0, 19.0, 1.0, -swing, -1.0, 0.0, -3.0, 3.0, 5.0, 3.0, 26.0, 0.0, 0.0, false, 1.0, red, red)
    beat = (Math.sin(@flap) + 1.0) * @flap_open
    wing(mesh, layer, -4.0, fall, beat, red)
    wing(mesh, layer, 4.0, fall, -beat, red)
    mesh.roll(fall)
    chick = baby?
    @size = 1.0
    py = chick ? 20.0 : 15.0
    pz = chick ? -2.0 : -4.0
    part(mesh, layer, 0.0, py, pz, 0.0, -2.0, -6.0, -2.0, 4.0, 6.0, 3.0, 0.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, py, pz, 0.0, -2.0, -4.0, -4.0, 4.0, 2.0, 2.0, 14.0, 0.0, 0.0, false, 1.0, red, red)
    part(mesh, layer, 0.0, py, pz, 0.0, -1.0, -2.0, -3.0, 2.0, 2.0, 2.0, 14.0, 4.0, 0.0, false, 1.0, red, red)
  end

  # A wing of a chicken: 1 x 4 x 6 pixels that hang from the pivot px, 13,
  # 0 (px -4 is the right wing, 4 the left), turned by beat around the axis
  # from the back to the front through the pivot. Mesh3#roll turns the
  # whole body by fall around the axis through its feet, so the turn by
  # fall + beat goes around that axis, and the box moves by the difference
  # to turn around the pivot instead.
  def wing(mesh, layer, px, fall, beat, red)
    scale = @size / 16.0
    cx = px * scale
    cy = 11.0 * scale
    turn = fall + beat
    mx = cx * Math.cos(fall) + cy * Math.sin(fall) - (cx * Math.cos(turn) + cy * Math.sin(turn))
    my = cy * Math.cos(fall) - cx * Math.sin(fall) - (cy * Math.cos(turn) - cx * Math.sin(turn))
    mesh.roll(turn)
    x0 = px < 0.0 ? px : px - 1.0
    # to_f: Spinel cannot type the position of a mob.
    mesh.skin_box(@x.to_f + mx * Math.cos(@yaw), @y.to_f + my, @z.to_f + mx * Math.sin(@yaw), @yaw, 0.0, 0.0, 0.0,
                  x0 * scale, 7.0 * scale, -3.0 * scale, (x0 + 1.0) * scale, 11.0 * scale, 3.0 * scale,
                  layer, 24.0, 13.0, 1.0, 4.0, 6.0, false, 1.0, red, red, 1.0)
  end
end
