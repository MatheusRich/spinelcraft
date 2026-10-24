# Mobs and combat: mob turns, damage, explosions, the bow, and arrows.
class Game
  # The bite of a grazing sheep: the tall grass goes, or else the grass
  # block turns into dirt, and the sheep ate (Animal#ate_grass). With the
  # grass gone, nothing happens. minecraft.wiki/w/Sheep
  def bite_grass(m)
    m.grass_bite = false
    eaten = m.grass_under(@world)
    return if eaten == 0

    x = m.x.floor
    y = (m.y + 0.01).floor
    z = m.z.floor
    eaten == 1 ? set_block(x, y, z, Block::AIR) : set_block(x, y - 1, z, Block::DIRT)
    m.ate_grass
  end

  # Takes amount of health and plays sound: Sfx::HURT, or Sfx::FALL for a
  # fall, as in Minecraft.
  def hurt(amount, sound)
    return if !@survival || @vitals.dead? || amount <= 0

    @vitals.hurt(amount)
    felt_hurt(sound)
  end

  # The sound and the red flash of a hit. At zero health the player dies
  # and drops the inventory.
  def felt_hurt(sound)
    @sfx.play(sound, 0.8)
    @damage_flash = 0.35
    return unless @vitals.dead?

    toggle_inventory if @inventory_open
    drop_inventory
    @captured = false
    Gfx.in_capture(0)
  end

  def update_mobs(dt)
    @spawner.spawn_monsters(@mobs, @player, @sky.light, dt)
    guard_treasure
    @breeding.pair_lovers(@mobs, @particles)
    push_mobs(dt)
    held = current_block.to_i
    @spawner.refill_animals(@mobs, @player, dt)
    @mobs.each { |mob| mob_turn(mob, dt, held) }
    steps = (dt * 180.0).ceil
    steps = 1 if steps < 1
    steps.times { update_arrows(dt / steps) }
    update_eggs(dt)
    remove_gone_mobs(dt)
  end

  # A treasure chest sends its guards when the player comes near it (see
  # Treasure#call_guards), while the chest is there. The guards of its
  # last visit that still live, also those that chased the player, count
  # toward the pack, so it has NaturalSpawner::GUARDS guards at most.
  def guard_treasure
    site = @treasure.call_guards(@player.x.to_f, @player.y.to_f, @player.z.to_f)
    x = site.chest_x
    y = site.chest_y
    z = site.chest_z
    return unless site.found? && Block::BASE[@world.get(x, y, z)] == Block::CHEST

    living = @mobs.count { |mob| mob.guard && mob.alive && site.distance(mob.x.to_f, mob.z.to_f) <= Treasure::REARM }
    @spawner.spawn_guards(@mobs, x, z, NaturalSpawner::GUARDS - living, @player)
    nil
  end

  # The turn of a mob in a frame: its sounds and the weather, the turn of
  # an animal or a monster, and then its death or its cry of pain.
  def mob_turn(mob, dt, held)
    before_step(mob, dt)
    lived = mob.death == 0.0
    if mob.passive?
      update_animal(mob, dt, held)
    else
      update_monster(mob, dt, held)
    end
    # A mob drops its loot when it dies, and its body goes up in smoke
    # when it is gone. minecraft.wiki/w/Death
    if lived && mob.dying?
      mob_died(mob)
    elsif mob.ouch
      play_from(mob, voice(mob, Mob::HURT_SOUND), 1.0)
    end
    mob.ouch = false
    @particles.smoke(mob.x, mob.y + mob.tall * 0.3, mob.z, 12, mob.tall * 0.6) if !mob.alive && mob.dying?
    # A nil return keeps Spinel from boxing it.
    nil
  end

  # Plays the sounds of the mob, and lets the weather act on it.
  def before_step(mob, dt)
    if Mob::SOUND[mob.kind] >= 0 && @rng.rand01 < dt * 0.08
      play_from(mob, voice(mob, Mob::SOUND), 0.8)
    end
    if mob.step
      # A mob steps with the sound of the block under it, as the player
      # does. A creeper has no step sound of its own
      # (minecraft.wiki/w/Creeper), and VoxeLibre has none for the others.
      mob.step = false
      ground = MATERIAL_STEP[material(@world.get(mob.x.floor, (mob.y - 0.1).floor, mob.z.floor))]
      @sfx.play_at(ground, mob.x, mob.y, mob.z, 0.35)
    end
    mob.douse if mob.fire > 0.0 && @weather.wet? && @world.under_sky?(mob.x, mob.y + mob.tall, mob.z)
    @particles.fire(mob.x, mob.y, mob.z, mob.half, mob.tall, dt) if mob.fire > 0.0
  end

  # The hiss of a creeper, the arrow of a skeleton, and the blast of a
  # creeper whose fuse burned down.
  def attack(monster)
    if monster.hiss
      monster.hiss = false
      play_from(monster, Sfx::FUSE, 1.0)
    end
    if monster.shoot
      monster.shoot = false
      shoot_arrow(monster)
    end
    return unless monster.explode

    monster.explode = false
    monster.alive = false
    explode(monster.x, monster.y + 0.8, monster.z)
    # A nil return keeps Spinel from boxing it.
    nil
  end

  # The sun burns undead mobs while the sky light is at least
  # Monster::SUN_BURN_LIGHT and they are not wet. The wiki does not confirm
  # that rain stops the burning.
  def sun_burns? = !@weather.wet? && @sky.light >= Monster::SUN_BURN_LIGHT

  # The turn of a monster: what it asked for in its last step, the sun
  # burn, and its step.
  def update_monster(monster, dt, held)
    attack(monster)
    monster.burn_in_sun(@world) if sun_burns?
    step_mob(monster, dt, held)
  end

  # The turn of an animal: its step can leave a bite of grass, an egg or
  # a heart.
  def update_animal(animal, dt, held)
    step_mob(animal, dt, held)
    bite_grass(animal) if animal.grass_bite
    lay_egg(animal) if animal.lay
    show_heart(animal) if animal.love.heart
    nil
  end

  # Moves the mob, in two steps when the frame takes more than 0.025
  # seconds. A hit on the player hurts and, in survival, throws the
  # player back.
  def step_mob(mob, dt, held)
    steps = dt > 0.025 ? 2 : 1
    sdt = dt / steps
    steps.times do
      damage = mob.update_mob(@world, sdt, @player, held)
      next if damage <= 0

      hurt(damage, Sfx::HURT)
      # to_f: Spinel cannot type the mob.
      @player.knock_back(mob.x.to_f, mob.z.to_f) if @survival
    end
  end

  # A heart over a mob in love mode, now and then (see Love#clock).
  def show_heart(mob)
    mob.love.heart = false
    # to_f: Spinel cannot type the mob, and the particles need Floats.
    @particles.heart(mob.x.to_f, mob.y.to_f, mob.z.to_f, mob.half.to_f, mob.tall.to_f)
    nil
  end

  # The loot of a mob, and the death cry. A mob drops its loot whatever
  # kills it, as in Minecraft. Only experience and the bow of a skeleton
  # need the player (Monster#drops). minecraft.wiki/w/Pig, /w/Skeleton
  def mob_died(mob)
    drop_loot(mob) if @survival
    play_from(mob, voice(mob, Mob::DEATH_SOUND), 1.0)
  end

  # Removes the mobs that are dead, that are in a chunk that is not loaded,
  # or that despawn.
  def remove_gone_mobs(dt)
    @mobs.reject! do |mob|
      gone = mob.gone?(@world, @player, dt)
      Log.debug(Log::MOBS) { "#{Mob::NAMES[mob.kind]} at #{mob.x.floor} #{mob.y.floor} #{mob.z.floor} #{mob.gone_reason(@world)}" } if gone
      gone
    end
    nil
  end

  # The sound of the mob m from sounds: a chick peeps for all of them, as
  # in VoxeLibre.
  def voice(m, sounds) = m.baby? && m.kind == Mob::CHICKEN ? Sfx::CHICK : sounds[m.kind]

  def play_from(m, id, gain)
    @sfx.play_at(id, m.x, m.y + m.tall * 0.5, m.z, gain)
  end

  # Drops what a mob drops when it dies (Animal#drops, Monster#drops).
  def drop_loot(mob)
    drops = mob.drops(@rng)
    (drops.size / 2).times { |pair| loot(mob, drops[pair * 2].to_i, drops[pair * 2 + 1].to_i) }
  end

  # A tool drops new: its count is its uses.
  def loot(m, block, n)
    n = Block.uses(block) if Block.tool?(block)
    drop_item(block, n, m.x, m.y + 0.5, m.z, (@rng.rand01 - 0.5) * 2.0, 3.0, (@rng.rand01 - 0.5) * 2.0, PICKUP_WAIT)
  end

  # A chicken lays an egg where it stands, with a plop.
  def lay_egg(m)
    m.lay = false
    drop_item(Block::EGG, 1, m.x, m.y.to_f + 0.2, m.z, 0.0, 1.0, 0.0, PICKUP_WAIT)
    play_from(m, Sfx::LAY_EGG, 1.0)
  end

  # Mobs push each other apart where their boxes overlap, as entities do in
  # Minecraft (minecraft.wiki/w/Entity, 15w36a, and the entity cramming
  # of minecraft.wiki/w/Damage). The wiki gives no strength. In the game
  # code (Entity.push), each tick gives each of the two mobs 0.05 blocks
  # each tick of speed along the step between them, divided by the larger
  # of its x and z parts (for a step under 1 block, as for all mobs here).
  # Each of the two runs the push
  # (LivingEntity.pushEntities), so a pair gets it twice each tick. That
  # is 0.05 * 2 * 20 * 20 = 40 blocks each second, each second.
  MOB_PUSH = 40.0

  # dt seconds of pushes between the mobs whose boxes overlap. A dying mob
  # does not push. The positions go into Float arrays first, so the check
  # of each pair is cheap.
  def push_mobs(dt) # rubocop:todo Metrics/MethodLength
    n = @mobs.size
    return if n < 2

    xs = Array.new(n, 0.0)
    ys = Array.new(n, 0.0)
    zs = Array.new(n, 0.0)
    halves = Array.new(n, 0.0)
    talls = Array.new(n, 0.0)
    dvx = Array.new(n, 0.0)
    dvz = Array.new(n, 0.0)
    i = 0
    while i < n
      m = @mobs[i]
      # to_f: Spinel cannot type the mob. A dying mob gets no box.
      xs[i] = m.x.to_f
      ys[i] = m.y.to_f
      zs[i] = m.z.to_f
      halves[i] = m.dying? ? -1.0 : m.half.to_f
      talls[i] = m.tall.to_f
      i += 1
    end
    k = MOB_PUSH * dt
    n.times do |i|
      (i + 1...n).each do |j|
        reach = halves[i] + halves[j]
        dx = xs[j] - xs[i]
        dz = zs[j] - zs[i]
        if halves[i] > 0.0 && halves[j] > 0.0 && dx.abs < reach && dz.abs < reach &&
           ys[i] < ys[j] + talls[j] && ys[j] < ys[i] + talls[i]
          big = dx.abs > dz.abs ? dx.abs : dz.abs
          # The game code does not push two mobs less than 0.01 apart.
          # Here they go apart along x, so that two mobs on one spot part.
          if big < 0.01
            dx = 1.0
            dz = 0.0
            big = 1.0
          end
          px = dx / big * k
          pz = dz / big * k
          dvx[i] -= px
          dvz[i] -= pz
          dvx[j] += px
          dvz[j] += pz
        end
      end
    end
    n.times { |i| @mobs[i].nudge(dvx[i], dvz[i]) if dvx[i] != 0.0 || dvz[i] != 0.0 }
    # A nil return keeps Spinel from boxing the loop.
    nil
  end

  # Draw time (seconds) sets speed and damage; a full draw takes one second.
  # The damage is as in Minecraft: 1 for a short draw, 5 for a medium draw,
  # 6 for a draw of 0.9 seconds, and 6 to 11 for a full draw, which is a
  # critical hit. minecraft.wiki/w/Bow
  def shoot_bow(held)
    pull = held > 1.0 ? 1.0 : held
    return if pull < 0.1

    if @survival
      if @inv.total(Block::ARROW) == 0
        say("NO ARROWS")
        return
      end
      @inv.remove(Block::ARROW, 1)
    end
    speed = 12.0 + pull * 30.0
    damage = pull < 0.2 ? 1 : (pull < 0.9 ? 5 : 6)
    damage += (@rng.rand01 * 6.0).to_i if pull >= 1.0
    @arrows << Arrow.new(@player.x, @player.eye_y - 0.1, @player.z,
                         @player.fx * speed, @player.fy * speed, @player.fz * speed, 5.0, damage)
    @swing = SWING
    @sfx.play(Sfx::SHOOT, 0.8)
    wear_tool(1)
  end

  # Removes blocks within the radius and hurts what is near, less with distance.
  # In survival, each block that an explosion breaks drops with this chance,
  # as if it broke with no tool (see drop_broken). minecraft.wiki/w/Explosion
  BLAST_DROP = 1.0 / 3.0
  # A creeper's blast hurts what is this near, as in Minecraft.
  # minecraft.wiki/w/Explosion
  BLAST_REACH = 6.0

  # The damage of a creeper's blast at dist blocks, as in Minecraft:
  # 43 at the center, and 1 at the edge. minecraft.wiki/w/Explosion
  def blast_damage(dist)
    impact = 1.0 - dist / BLAST_REACH
    ((impact * impact + impact) / 2.0 * 7.0 * BLAST_REACH + 1.0).to_i
  end

  def explode(cx, cy, cz) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    r = 3
    x = cx.floor - r
    while x <= cx.floor + r
      y = cy.floor - r
      while y <= cy.floor + r
        z = cz.floor - r
        while z <= cz.floor + r
          dx = x + 0.5 - cx
          dy = y + 0.5 - cy
          dz = z + 0.5 - cz
          block = @world.get(x, y, z)
          if dx * dx + dy * dy + dz * dz < 9.5 - @rng.rand01 * 2.5 && block != Block::AIR && block != Block::BEDROCK && !Block.water?(block) && !Block.lava?(block)
            @particles.burst(x, y, z, block) if @rng.rand01 < 0.15
            set_block(x, y, z, Block::AIR)
            drop_broken(block, x, y, z, Block::AIR) if @survival && @rng.rand01 < BLAST_DROP
          end
          z += 1
        end
        y += 1
      end
      x += 1
    end
    @particles.blast(cx, cy, cz)
    @particles.smoke(cx, cy, cz, 40, 3.0)
    @sfx.play_at(Sfx::EXPLODE, cx, cy, cz, 1.0)
    pdx = @player.x - cx
    pdy = @player.y + 0.9 - cy
    pdz = @player.z - cz
    dist = Math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz)
    if dist < BLAST_REACH
      hurt(blast_damage(dist), Sfx::HURT)
      len = dist < 0.1 ? 1.0 : dist
      @player.vx += pdx / len * (BLAST_REACH - dist) * 2.0
      @player.vz += pdz / len * (BLAST_REACH - dist) * 2.0
      @player.vy += 4.0 + (BLAST_REACH - dist)
    end
    @mobs.each do |m|
      next unless m.alive

      mdx = m.x - cx
      mdz = m.z - cz
      d = Math.sqrt(mdx * mdx + mdz * mdz)
      m.hit(blast_damage(d).to_f, cx, cz) if d < BLAST_REACH
    end
  end

  def shoot_arrow(m)
    sx = m.x
    sy = m.y + 1.5
    sz = m.z
    dx = @player.x - sx
    dy = @player.y + 1.2 - sy
    dz = @player.z - sz
    dist = Math.sqrt(dx * dx + dy * dy + dz * dz)
    return if dist < 0.5

    speed = 22.0
    t = dist / speed
    @arrows << Arrow.new(sx, sy, sz, dx / t, dy / t + 9.0 * t, dz / t, 4.0, 0)
    @sfx.play_at(Sfx::SHOOT, sx, sy, sz, 0.9)
  end

  def update_arrows(dt) # rubocop:todo Metrics/MethodLength
    @arrows.each do |a|
      unless a.fly(@world, dt)
        # An arrow makes the same sound when it hits a block as when it
        # hits a mob. minecraft.wiki/w/Arrow
        if a.landed
          a.landed = false
          @sfx.play_at(Sfx::HIT, a.x, a.y, a.z, 0.8)
        end
        next
      end
      if a.damage > 0
        m = @mobs.find { |mob| !mob.dying? && mob.contains?(a.x, a.y, a.z) }
        if m
          m.hit(a.damage.to_f, a.x - a.vx, a.z - a.vz)
          m.by_player = true
          @sfx.play_at(Sfx::HIT, a.x, a.y, a.z, 0.8)
          a.vanish
        end
      elsif a.in_box?(@player.x, @player.y, @player.z, Player::HALF, Player::TALL)
        # A skeleton's arrow does 3 to 5. minecraft.wiki/w/Skeleton
        hurt(3 + (@rng.rand01 * 3.0).to_i, Sfx::HURT)
        if @survival
          len = Math.sqrt(a.vx * a.vx + a.vz * a.vz)
          len = 1.0 if len < 0.001
          @player.vx += a.vx / len * 5.0
          @player.vz += a.vz / len * 5.0
        end
        a.vanish
      end
    end
    @arrows.select!(&:alive?)
  end

  # Throws an egg where the player looks. Creative keeps the egg.
  def throw_egg
    @inv.take(@slot, 1) if @survival
    p = @player
    @eggs << Egg.new(p.x, p.eye_y.to_f - 0.1, p.z, p.fx * Egg::SPEED, p.fy * Egg::SPEED, p.fz * Egg::SPEED)
    @swing = SWING
    @sfx.play(Sfx::SHOOT, 0.5)
  end

  # Each egg flies, and breaks on a block or a mob. A mob that it hits
  # takes a hit of 0 damage: it flashes red and gets a push. Then the egg
  # can hatch chicks where it broke.
  def update_eggs(dt)
    @eggs.each do |e|
      steps = (dt * 120.0).ceil
      k = 0
      while k < steps && !e.broken?
        e.fly(@world, dt / steps)
        m = @mobs.find { |mob| !mob.dying? && mob.contains?(e.x, e.y, e.z) }
        if m
          m.hit(0.0, e.x - e.vx, e.z - e.vz)
          e.break_open
        end
        k += 1
      end
      next unless e.broken?

      @particles.splat(e.x, e.y, e.z, Block::EGG)
      chicks(@rng.rand01, @rng.rand01).times do
        chick = Animal.new(Mob::CHICKEN, e.x, e.y, e.z, (@rng.rand01 * 100000.0).to_i)
        chick.make_baby
        @mobs << chick
      end
    end
    @eggs.reject!(&:broken?)
  end

  # The chicks that hatch from a broken egg, by two random numbers: 1 in 8
  # eggs hatches a chick, and 1 in 32 of those hatches 4 chicks.
  # minecraft.wiki/w/Egg
  def chicks(r1, r2) = r1 < 1.0 / 8.0 ? (r2 < 1.0 / 32.0 ? 4 : 1) : 0

  def find_target_mob
    @target_mob = -1
    return if @mobs.empty?

    best = @target_block.hit? ? @target_block.distance : Player::MOB_REACH
    best = Player::MOB_REACH if best > Player::MOB_REACH
    # A boat in front of the mobs hides them.
    best = @target_boat_t if @target_boat >= 0 && @target_boat_t < best
    ox = @player.x
    oy = @player.eye_y
    oz = @player.z
    dx = @player.fx
    dy = @player.fy
    dz = @player.fz
    i = 0
    while i < @mobs.size
      m = @mobs[i]
      # Skip the mobs that are out of reach, and the dying mobs.
      if !m.dying? && (m.x - ox) ** 2 + (m.z - oz) ** 2 < 25.0
        t = m.ray(ox, oy, oz, dx, dy, dz)
        if t >= 0.0 && t < best
          best = t
          @target_mob = i
        end
      end
      i += 1
    end
    @target_boat = -1 if @target_mob >= 0
  end
end
