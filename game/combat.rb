# Mobs and combat: spawning, mob turns, damage, explosions, the bow, and arrows.
class Game
  # The sound that each mob kind makes now and then, indexed by kind.
  MOB_SOUND = [Sfx::OINK, Sfx::GROAN, Sfx::STEP, Sfx::OINK, Sfx::SPLASH]

  # Monsters spawn only where no torch or lava is this near (in steps along
  # x, y and z; walls do not count). A monster needs block light 0. The
  # light of a torch is 14 and drops by 1 for each step, so the edge of
  # this area has light 1. Lava has light 15, so near lava the area is 1
  # step too small. minecraft.wiki/w/Light and /w/Mob_spawning
  SAFE_REACH = 13
  # The sky light of Minecraft under the open sky by the time of day, in
  # clear weather and in rain. DUSK has the first tick of each level as it
  # goes down from the top level to 4, and DAWN the first tick of each level
  # as it goes up from 5 to the top level. A day has 24000 ticks, and tick
  # 6000 is noon. minecraft.wiki/w/Light
  SKY_TOP_CLEAR = 15
  SKY_DUSK_CLEAR = [12041, 12210, 12377, 12542, 12705, 12867, 13027, 13188, 13348, 13509, 13670]
  SKY_DAWN_CLEAR = [22331, 22492, 22653, 22813, 22974, 23135, 23297, 23460, 23624, 23791, 23961]
  SKY_TOP_RAIN = 12
  SKY_DUSK_RAIN = [12010, 12256, 12497, 12734, 12969, 13203, 13436, 13670]
  SKY_DAWN_RAIN = [22331, 22566, 22799, 23032, 23267, 23505, 23746, 23992]
  # A monster spawns only when the light is at most a random number from 0
  # to this. minecraft.wiki/w/Mob_spawning
  SPAWN_LIGHT = 7

  # Monster spawning and despawning as in Minecraft.
  # minecraft.wiki/w/Mob_spawning
  # The cap for the 17 x 17 chunks around the player. The game always loads
  # all of them, so the cap does not get smaller as in Minecraft.
  MONSTER_CAP = 70
  # Chunks on each side of the player's chunk where monsters spawn.
  SPAWN_CHUNKS = 8
  # Pack centers each second: one for each of the 17 x 17 chunks each tick.
  PACK_CENTERS = 289 * 20
  # Packs for each center, and monsters for each center at most.
  PACKS = 3
  PACK_SIZE = 4
  # Monsters spawn at least SPAWN_NEAR blocks from the player and at most
  # DESPAWN_FAR. A monster farther than DESPAWN_FAR despawns at once. A
  # monster that has been farther than DESPAWN_NEAR for IDLE_DESPAWN seconds
  # despawns with a chance of 1 in 800 each tick.
  SPAWN_NEAR = 24.0
  DESPAWN_FAR = 128.0
  DESPAWN_NEAR = 32.0
  IDLE_DESPAWN = 30.0
  DESPAWN_CHANCE = 20.0 / 800.0
  # The monster kinds and their spawn weights. minecraft.wiki/w/Plains
  MONSTER_KINDS = [Mob::ZOMBIE, Mob::SKELETON, Mob::CREEPER]
  MONSTER_WEIGHTS = [95.0, 100.0, 100.0]

  # The sky light under the open sky now, from SKY_DUSK and SKY_DAWN.
  def sky_light
    rain = @weather.raining?
    tick = (@time_of_day * 24000.0).to_i
    dawn = rain ? SKY_DAWN_RAIN : SKY_DAWN_CLEAR
    ticks = tick >= dawn[0] ? dawn : (rain ? SKY_DUSK_RAIN : SKY_DUSK_CLEAR)
    passed = 0
    i = 0
    while i < ticks.size
      passed += 1 if tick >= ticks[i]
      i += 1
    end
    tick >= dawn[0] ? 4 + passed : (rain ? SKY_TOP_RAIN : SKY_TOP_CLEAR) - passed
  end

  # True when a monster can spawn in the cell x, y, z by its light. Under
  # the open sky, the light is sky, the sky light now. Under an opaque
  # block, it is 0. (In Minecraft, sky light also spreads under the side of
  # a roof; here it does not.) Leaves and glass let the sky light through.
  # No torch or lava may be near, and the light must be at most a random
  # number from 0 to SPAWN_LIGHT.
  def dark?(x, y, z, sky)
    light = 0
    if sky > 0
      top = @world.height_at(x, z)
      cover = y + 1
      cover += 1 while cover < top && Block::OPAQUE[@world.get(x, cover, z)] == 0
      light = sky if cover >= top
    end
    return false if light > SPAWN_LIGHT
    cx = (x - SAFE_REACH) >> 4
    while cx <= (x + SAFE_REACH) >> 4
      cz = (z - SAFE_REACH) >> 4
      while cz <= (z + SAFE_REACH) >> 4
        list = @world.torches_of(cx, cz)
        k = 0
        while k < list.size
          return false if (list[k] - x).abs + (list[k + 1] - y).abs + (list[k + 2] - z).abs <= SAFE_REACH
          k += 3
        end
        cz += 1
      end
      cx += 1
    end
    light <= (@rng.rand01 * (SPAWN_LIGHT + 1)).to_i
  end

  # The pack centers of dt seconds, until the monsters reach the cap.
  def spawn_monsters(dt)
    monsters = @mobs.count { |m| !m.passive? }
    n = (dt * PACK_CENTERS + @rng.rand01).to_i
    sky = sky_light
    while n > 0 && monsters < MONSTER_CAP
      monsters += spawn_packs(sky, MONSTER_CAP - monsters)
      n -= 1
    end
  end

  # Picks a pack center in a random cell of a random chunk near the player,
  # at a random height up to the cell above the top of its column. Most
  # centers are in the ground, so most monsters spawn in caves. Then PACKS
  # packs walk from the center with steps of up to 5 on x and z, and each
  # step can spawn a monster of the pack's kind. Returns how many spawned.
  def spawn_packs(sky, room)
    span = SPAWN_CHUNKS * 2 + 1
    x0 = ((@player.x.floor >> 4) - SPAWN_CHUNKS + (@rng.rand01 * span).to_i) * 16 + (@rng.rand01 * 16.0).to_i
    z0 = ((@player.z.floor >> 4) - SPAWN_CHUNKS + (@rng.rand01 * span).to_i) * 16 + (@rng.rand01 * 16.0).to_i
    return 0 unless @world.loaded?(x0, z0)
    y = (@rng.rand01 * (@world.height_at(x0, z0) + 1)).to_i
    return 0 if Block::OPAQUE[@world.get(x0, y, z0)] == 1
    room = PACK_SIZE if room > PACK_SIZE
    spawned = 0
    pack = 0
    while pack < PACKS
      kind = pick_monster
      x = x0
      z = z0
      step = 0
      while step < PACK_SIZE
        x += (@rng.rand01 * 6.0).to_i - (@rng.rand01 * 6.0).to_i
        z += (@rng.rand01 * 6.0).to_i - (@rng.rand01 * 6.0).to_i
        if monster_fits?(x, y, z, sky)
          @mobs << Mob.new(kind, x + 0.5, y + 0.01, z + 0.5, (@rng.rand01 * 100000.0).to_i)
          spawned += 1
          return spawned if spawned >= room
        end
        step += 1
      end
      pack += 1
    end
    spawned
  end

  # A random monster kind by MONSTER_WEIGHTS.
  def pick_monster
    r = @rng.rand01 * MONSTER_WEIGHTS.sum
    i = 0
    while i < MONSTER_KINDS.size - 1
      r -= MONSTER_WEIGHTS[i]
      return MONSTER_KINDS[i] if r < 0.0
      i += 1
    end
    MONSTER_KINDS[i]
  end

  # True when a monster can spawn in the cell x, y, z: a loaded dark cell
  # with a solid floor and room for its body, between SPAWN_NEAR and
  # DESPAWN_FAR blocks from the player.
  def monster_fits?(x, y, z, sky)
    return false if y < 1 || !@world.loaded?(x, z)
    dx = x + 0.5 - @player.x
    dy = y - @player.y
    dz = z + 0.5 - @player.z
    d2 = dx * dx + dy * dy + dz * dz
    return false if d2 < SPAWN_NEAR * SPAWN_NEAR || d2 > DESPAWN_FAR * DESPAWN_FAR
    ground = @world.get(x, y - 1, z)
    return false unless Block.solid?(ground) && ground != Block::LEAVES
    return false if @world.get(x, y, z) != Block::AIR || @world.get(x, y + 1, z) != Block::AIR
    dark?(x, y, z, sky)
  end

  # True when the monster m despawns after dt seconds more.
  def despawn?(m, dt)
    dx = m.x - @player.x
    dy = m.y - @player.y
    dz = m.z - @player.z
    d2 = dx * dx + dy * dy + dz * dz
    return true if d2 > DESPAWN_FAR * DESPAWN_FAR
    m.idle = d2 > DESPAWN_NEAR * DESPAWN_NEAR ? m.idle + dt : 0.0
    m.idle > IDLE_DESPAWN && @rng.rand01 < dt * DESPAWN_CHANCE
  end

  # Puts a pig or a sheep on grass at a random distance from the player in [near, far).
  def spawn_mob(kind, near, far)
    tries = 0
    while tries < 20
      tries += 1
      ang = @rng.rand01 * 6.283
      dist = near + @rng.rand01 * (far - near)
      x = (@player.x + Math.cos(ang) * dist).floor
      z = (@player.z + Math.sin(ang) * dist).floor
      next unless @world.loaded?(x, z)
      h = @world.height_at(x, z)
      ground = @world.get(x, h - 1, z)
      next unless ground == Block::GRASS || ground == Block::SNOW_GRASS
      next if @world.get(x, h, z) != Block::AIR || @world.get(x, h + 1, z) != Block::AIR
      @mobs << Mob.new(kind, x + 0.5, h + 0.01, z + 0.5, (@rng.rand01 * 100000.0).to_i)
      return
    end
  end

  def hurt(amount)
    return if !@survival || @vitals.dead? || amount <= 0
    @vitals.hurt(amount)
    felt_hurt
  end

  # The sound and the red flash of a hit. At zero health the player dies
  # and drops the inventory.
  def felt_hurt
    play(Sfx::HURT, 0.8)
    @damage_flash = 0.35
    return unless @vitals.dead?
    toggle_inventory if @inventory_open
    drop_inventory
    @captured = false
    Gfx.in_capture(0)
  end

  def update_mobs(dt)
    # Rain dims the day, so monsters do not burn in it.
    day = daylight * (1.0 - 0.5 * @weather.rain)
    spawn_monsters(dt)
    @spawn_timer -= dt
    if @spawn_timer <= 0.0
      @spawn_timer = 2.0
      pigs = @mobs.count(&:passive?)
      spawn_mob(@rng.rand01 < 0.5 ? Mob::PIG : Mob::SHEEP, 40.0, 90.0) if pigs < PIGS / 2
    end
    @mobs.each do |m|
      if @rng.rand01 < dt * 0.08
        play(MOB_SOUND[m.kind], near_volume(m.x, m.z, 0.8))
      end
      if m.shoot
        m.shoot = false
        shoot_arrow(m)
      end
      if m.explode
        m.explode = false
        m.alive = false
        explode(m.x, m.y + 0.8, m.z)
      end
      m.douse if m.fire > 0.0 && @weather.rain > 0.5 && @world.under_sky?(m.x, m.y + m.tall, m.z)
      @particles.fire(m.x, m.y, m.z, m.half, m.tall, dt) if m.fire > 0.0
      steps = dt > 0.025 ? 2 : 1
      sdt = dt / steps
      k = 0
      while k < steps
        damage = m.update_mob(@world, sdt, @player, day)
        if damage > 0
          hurt(damage)
          if @survival
            dx = @player.x - m.x
            dz = @player.z - m.z
            len = Math.sqrt(dx * dx + dz * dz)
            len = 1.0 if len < 0.001
            @player.vx = dx / len * 8.0
            @player.vz = dz / len * 8.0
            @player.vy = 5.0
          end
        end
        k += 1
      end
    end
    if @survival
      @mobs.each { |m| drop_loot(m) if !m.alive && m.hp <= 0 && m.by_player }
    end
    steps = (dt * 180.0).ceil
    steps = 1 if steps < 1
    steps.times { update_arrows(dt / steps) }
    @mobs.reject! do |m|
      d2 = (m.x - @player.x) ** 2 + (m.z - @player.z) ** 2
      !m.alive || !@world.loaded?(m.x.floor, m.z.floor) || (m.passive? ? d2 > 160.0 * 160.0 : despawn?(m, dt))
    end
  end

  # What a mob that the player killed drops, as in Minecraft: a skeleton 0
  # to 2 arrows and now and then its bow, a sheep its wool, and a pig 1 to 3
  # porkchops. minecraft.wiki/w/Skeleton, /w/Sheep and /w/Pig
  def drop_loot(m)
    if m.kind == Mob::SKELETON
      loot(m, Block::ARROW, (@rng.rand01 * 3.0).to_i)
      loot(m, Block::BOW, 1) if @rng.rand01 < 0.085
    elsif m.kind == Mob::SHEEP
      loot(m, Block::WOOL, 1)
    elsif m.kind == Mob::PIG
      loot(m, Block::PORKCHOP, 1 + (@rng.rand01 * 3.0).to_i)
    end
  end

  # A tool drops new: its count is its uses.
  def loot(m, b, n)
    n = Block.uses(b) if Block.tool?(b)
    drop_item(b, n, m.x, m.y + 0.5, m.z, (@rng.rand01 - 0.5) * 2.0, 3.0, (@rng.rand01 - 0.5) * 2.0, PICKUP_WAIT)
  end

  # PIGS pigs and sheep around the player.
  def spawn_animals
    i = 0
    while i < PIGS
      spawn_mob(i % 2 == 0 ? Mob::PIG : Mob::SHEEP, 10.0, 120.0)
      i += 1
    end
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
    @swing = 0.25
    play(Sfx::SHOOT, 0.8)
    wear_tool(1)
  end

  # Removes blocks within the radius and hurts what is near, less with distance.
  # In survival, each block that an explosion breaks drops with this chance.
  # minecraft.wiki/w/Explosion
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

  def explode(cx, cy, cz)
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
          b = @world.get(x, y, z)
          if dx * dx + dy * dy + dz * dz < 9.5 - @rng.rand01 * 2.5 && b != Block::AIR && b != Block::BEDROCK && !Block.water?(b) && !Block.lava?(b)
            @particles.burst(x, y, z, b) if @rng.rand01 < 0.15
            set_block(x, y, z, Block::AIR)
            drop_from_block(Block::DROPS[b], 1, x, y, z) if @survival && @rng.rand01 < BLAST_DROP
          end
          z += 1
        end
        y += 1
      end
      x += 1
    end
    @particles.smoke(cx, cy, cz, 40, 3.0)
    play(Sfx::BREAK, 1.0)
    play(Sfx::HIT, 1.0)
    pdx = @player.x - cx
    pdy = @player.y + 0.9 - cy
    pdz = @player.z - cz
    dist = Math.sqrt(pdx * pdx + pdy * pdy + pdz * pdz)
    if dist < BLAST_REACH
      hurt(blast_damage(dist))
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
    play(Sfx::SHOOT, near_volume(sx, sz, 0.9))
  end

  def update_arrows(dt)
    @arrows.each do |a|
      next unless a.fly(@world, dt)
      if a.damage > 0
        m = @mobs.find { |mob| a.in_box?(mob.x, mob.y, mob.z, mob.half, mob.tall) }
        if m
          m.hit(a.damage.to_f, a.x - a.vx, a.z - a.vz)
          m.by_player = true
          play(Sfx::HIT, near_volume(a.x, a.z, 0.8))
          a.vanish
        end
      elsif a.in_box?(@player.x, @player.y, @player.z, Player::HALF, Player::TALL)
        # A skeleton's arrow does 3 to 5. minecraft.wiki/w/Skeleton
        hurt(3 + (@rng.rand01 * 3.0).to_i)
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

  def find_target_mob
    @target_mob = -1
    return if @mobs.empty?
    best = @player.hit ? @player.hit_t : Player::MOB_REACH
    best = Player::MOB_REACH if best > Player::MOB_REACH
    ox = @player.x
    oy = @player.eye_y
    oz = @player.z
    dx = @player.fx
    dy = @player.fy
    dz = @player.fz
    i = 0
    while i < @mobs.size
      m = @mobs[i]
      # Skip the mobs that are out of reach.
      if (m.x - ox) ** 2 + (m.z - oz) ** 2 < 25.0
        t = m.ray(ox, oy, oz, dx, dy, dz)
        if t >= 0.0 && t < best
          best = t
          @target_mob = i
        end
      end
      i += 1
    end
  end
end
