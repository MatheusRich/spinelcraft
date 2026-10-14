# Mobs and combat: spawning, mob turns, damage, explosions, the bow, and arrows.
class Game
  # The sound that each mob kind makes now and then, indexed by kind.
  MOB_SOUND = [Sfx::OINK, Sfx::GROAN, Sfx::STEP, Sfx::OINK, Sfx::SPLASH]

  # Monsters spawn only where no torch or lava is this near (in steps along
  # x, y and z; walls do not count). The light of a torch drops by 1 for
  # each step from 14, so the edge of this area has light 6.
  SAFE_REACH = 8
  # Daylight under this value is night: monsters spawn under the open sky.
  NIGHT = 0.35

  # True when a monster can spawn in the cell x, y, z: the sky above it is
  # dark or an opaque block covers it, and no torch or lava is near. Leaves
  # and glass let the daylight through.
  def dark?(x, y, z, day)
    if day >= NIGHT
      top = @world.height_at(x, z)
      cover = y + 1
      cover += 1 while cover < top && Block::OPAQUE[@world.get(x, cover, z)] == 0
      return false if cover >= top
    end
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
    true
  end

  # Puts a monster in a dark cell with a solid floor and room for its body,
  # 16 to 40 blocks from the player on x and z. Half the tries look on the
  # surface, and half look in caves up to 16 blocks above or below the player.
  def spawn_monster(kind, day)
    tries = 0
    while tries < 20
      tries += 1
      ang = @rng.rand01 * 6.283
      dist = 16.0 + @rng.rand01 * 24.0
      x = (@player.x + Math.cos(ang) * dist).floor
      z = (@player.z + Math.sin(ang) * dist).floor
      next unless @world.loaded?(x, z)
      h = @world.height_at(x, z)
      y = @rng.rand01 < 0.5 ? h : (@player.y + @rng.rand01 * 32.0 - 16.0).floor
      y = h if y > h
      # Down to the first floor in the cave.
      floor = y - 16
      floor = 1 if floor < 1
      y -= 1 while y > floor && !Block.solid?(@world.get(x, y - 1, z))
      ground = @world.get(x, y - 1, z)
      next unless Block.solid?(ground) && ground != Block::LEAVES
      next if @world.get(x, y, z) != Block::AIR || @world.get(x, y + 1, z) != Block::AIR
      next unless dark?(x, y, z, day)
      @mobs << Mob.new(kind, x + 0.5, y + 0.01, z + 0.5, (@rng.rand01 * 100000.0).to_i)
      return
    end
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
    @spawn_timer -= dt
    if @spawn_timer <= 0.0
      @spawn_timer = 2.0
      zombies = 0
      pigs = 0
      @mobs.each { |m| m.passive? ? pigs += 1 : zombies += 1 }
      roll = @rng.rand01
      spawn_monster(roll < 0.3 ? Mob::SKELETON : (roll < 0.55 ? Mob::CREEPER : Mob::ZOMBIE), day) if zombies < MAX_ZOMBIES
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
      !m.alive || !@world.loaded?(m.x.floor, m.z.floor) || d2 > 160.0 * 160.0 ||
        (!m.passive? && d2 > 64.0 * 64.0)
    end
  end

  # What a mob that the player killed drops.
  def drop_loot(m)
    if m.kind == Mob::SKELETON
      loot(m, Block::ARROW, 1 + (@rng.rand01 * 3.0).to_i)
      loot(m, Block::BOW, 1) if @rng.rand01 < 0.3
    elsif m.kind == Mob::SHEEP
      loot(m, Block::WOOL, 2)
    elsif m.kind == Mob::PIG
      loot(m, Block::PORKCHOP, 1)
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
    @arrows << Arrow.new(@player.x, @player.eye_y - 0.1, @player.z,
                         @player.fx * speed, @player.fy * speed, @player.fz * speed, 5.0, 2 + (pull * 7.0).to_i)
    @swing = 0.25
    play(Sfx::SHOOT, 0.8)
    wear_tool
  end

  # Removes blocks within the radius and hurts what is near, less with distance.
  # In survival, each block that an explosion breaks drops with this chance.
  BLAST_DROP = 0.3

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
    if dist < 7.0
      hurt(((7.0 - dist) * 3.2).to_i)
      len = dist < 0.1 ? 1.0 : dist
      @player.vx += pdx / len * (7.0 - dist) * 2.0
      @player.vz += pdz / len * (7.0 - dist) * 2.0
      @player.vy += 4.0 + (7.0 - dist)
    end
    @mobs.each do |m|
      next unless m.alive
      mdx = m.x - cx
      mdz = m.z - cz
      d = Math.sqrt(mdx * mdx + mdz * mdz)
      m.hit(((7.0 - d) * 3.0).to_i, cx, cz) if d < 7.0
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
          m.hit(a.damage, a.x - a.vx, a.z - a.vz)
          m.by_player = true
          play(Sfx::HIT, near_volume(a.x, a.z, 0.8))
          a.vanish
        end
      elsif a.in_box?(@player.x, @player.y, @player.z, Player::HALF, Player::TALL)
        hurt(3)
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
    best = @player.hit ? @player.hit_t : 3.5
    best = 3.5 if best > 3.5
    ox = @player.x
    oy = @player.eye_y
    oz = @player.z
    dx = @player.fx
    dy = @player.fy
    dz = @player.fz
    i = 0
    while i < @mobs.size
      m = @mobs[i]
      # Mob#ray allocates; skip the mobs that are out of reach.
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
