# Player input: keys, the mouse, mining, placing, beds, and food.
class Game
  def handle_input(dt)
    if @inventory_open
      handle_inventory
      return
    end
    if Gfx.in_key_pressed(Key::ESCAPE) != 0 || Gfx.in_focus_lost != 0
      # Saving takes tens of milliseconds, so it happens when the game pauses, not mid-play.
      save if @captured && @changed && @save_on_quit
      @captured = false
      Gfx.in_capture(0)
    end
    if @dead
      if Gfx.in_button_pressed(1) != 0 || Gfx.in_key_pressed(Key::R) != 0
        respawn
        @captured = true
        Gfx.in_capture(1)
      end
      return
    end
    if !@captured
      new_world if Gfx.in_key_pressed(Key::N) != 0
      if Gfx.in_button_pressed(1) != 0
        @captured = true
        Gfx.in_capture(1)
      end
      return
    end
    @player.look(Gfx.in_mouse_dx, Gfx.in_mouse_dy)
    i = 0
    while i < 9
      @slot = i if Gfx.in_key_pressed(Key::N1 + i) != 0
      i += 1
    end
    wheel = Gfx.in_wheel
    @slot = (@slot + 1) % 9 if wheel < 0.0
    @slot = (@slot + 8) % 9 if wheel > 0.0
    if Gfx.in_key_pressed(Key::E) != 0
      toggle_inventory
      return
    end
    if !@survival && Gfx.in_key_pressed(Key::Q) != 0
      at = PLACEABLE.index(@hotbar[@slot]) || 0
      @hotbar[@slot] = PLACEABLE[(at + 1) % PLACEABLE.size]
      say(Block::NAMES[@hotbar[@slot]])
    end
    if Gfx.in_key_pressed(Key::G) != 0
      @survival = !@survival
      @player.flying = false if @survival
      say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
    end
    if Gfx.in_key_pressed(Key::F) != 0 && !@survival
      @player.flying = !@player.flying
      say(@player.flying ? "FLYING" : "WALKING")
    end
    @show_debug = !@show_debug if Gfx.in_key_pressed(Key::F3) != 0
    save if Gfx.in_key_pressed(Key::F5) != 0
    if Gfx.in_key_pressed(Key::F4) != 0
      i = VIEWS.index { |v| v > @fog_end }
      @fog_end = i.nil? ? VIEWS[0] : VIEWS[i]
      say("VIEW DISTANCE #{@fog_end.to_i}")
    end
    if Gfx.in_key_pressed(Key::F11) != 0
      @fullscreen = !@fullscreen
      Gfx.gfx_fullscreen(@fullscreen ? 1 : 0)
    end
    craft if @survival && Gfx.in_key_pressed(Key::C) != 0
    @time_of_day += 0.25 if Gfx.in_key_pressed(Key::T) != 0

    @action_cooldown -= dt
    left = Gfx.in_button(1) != 0
    right = Gfx.in_button(3) != 0
    left_pressed = Gfx.in_button_pressed(1) != 0
    @action_cooldown = 0.0 if left_pressed || Gfx.in_button_pressed(3) != 0
    if Gfx.in_button_pressed(2) != 0 && @player.hit && !@survival
      picked = @world.get(@player.hx, @player.hy, @player.hz)
      @hotbar[@slot] = picked if picked != Block::BEDROCK
      say(Block::NAMES[@hotbar[@slot]])
    end

    if left && @target_mob >= 0
      if left_pressed
        mob = @mobs[@target_mob]
        mob.hit(@survival ? 4 : 10, @player.x, @player.z)
        mob.by_player = true
        play(Sfx::HIT, 0.8)
        @swing = 0.25
      end
      left = false
    end
    if left && @player.hit
      if @survival
        mine(dt)
      elsif @action_cooldown <= 0.0
        broken = @world.get(@player.hx, @player.hy, @player.hz)
        burst_particles(@player.hx, @player.hy, @player.hz, broken)
        play(Sfx::BREAK, 0.7)
        set_block(@player.hx, @player.hy, @player.hz, Block::AIR)
        @action_cooldown = 0.22
        @swing = 0.25
      end
    else
      @mining = false
    end
    target = @player.hit ? @world.get(@player.hx, @player.hy, @player.hz) : Block::AIR
    if current_block == Block::BOW && target != Block::CHEST && target != Block::BED
      if right
        @draw_time = 0.0 if @draw_time < 0.0
        @draw_time += dt
      elsif @draw_time >= 0.0
        shoot_bow(@draw_time)
        @draw_time = -1.0
      end
      return
    end
    @draw_time = -1.0
    if right && @action_cooldown <= 0.0
      if @survival && @player.hit && @world.get(@player.hx, @player.hy, @player.hz) == Block::CHEST
        open_chest(@player.hx, @player.hy, @player.hz)
        return
      elsif @player.hit && @world.get(@player.hx, @player.hy, @player.hz) == Block::BED
        use_bed(@player.hx, @player.hy, @player.hz)
      elsif current_block == Block::PORKCHOP
        eat
      elsif @player.hit
        place
      end
      @action_cooldown = 0.22
    end
  end

  def mine(dt)
    x = @player.hx
    y = @player.hy
    z = @player.hz
    if !@mining || x != @mine_x || y != @mine_y || z != @mine_z
      @mining = true
      @mine_x = x
      @mine_y = y
      @mine_z = z
      @mine_progress = 0.0
      @dig_wait = 0.0
    end
    b = @world.get(x, y, z)
    hardness = Block::HARDNESS[b]
    return if hardness < 0.0
    @dig_wait -= dt
    if @dig_wait <= 0.0 && hardness > 0.0
      play(dig_sound(b), 0.55)
      @dig_wait = 0.25
    end
    @swing = 0.25
    tier = Block::PICK_TIER[current_block]
    need = Block::NEEDS_PICK[b]
    # A good enough pickaxe speeds up stone; without one, stone is slow.
    speed = need == 0 ? 1.0 : (tier >= need ? 1.0 + tier * 1.2 : 0.3)
    @mine_progress += hardness == 0.0 ? 1.0 : dt * speed / hardness
    if @mine_progress >= 1.0 && b == Block::CHEST
      stored = @chests[World.key(x, y, z)]
      unless stored.nil? || chest_fits?(stored)
        say("EMPTY THE CHEST FIRST  INVENTORY FULL")
        @mine_progress = 0.0
        return
      end
    end
    if @mine_progress >= 1.0
      drop = tier >= need ? Block::DROPS[b] : Block::AIR
      if drop != Block::AIR && room_for(drop) == 0
        say("INVENTORY FULL")
        @mine_progress = 0.0
        return
      end
      burst_particles(x, y, z, b)
      play(Sfx::BREAK, 0.7)
      set_block(x, y, z, Block::AIR)
      give(drop)
      @mining = false
    end
  end

  def dig_sound(b)
    return Sfx::DIG_STONE if Block::NEEDS_PICK[b] > 0 || b == Block::GLASS || b == Block::BEDROCK
    return Sfx::DIG_WOOD if b == Block::LOG || b == Block::PLANKS || b == Block::CHEST || b == Block::BED
    Sfx::DIG_SOFT
  end

  # A bed sets the spawn point; at night with no monster close by, it skips to morning.
  def use_bed(x, y, z)
    @spawn_x = x + 0.5
    @spawn_z = z + 0.5
    if daylight > 0.35
      say("SPAWN SET  YOU CAN ONLY SLEEP AT NIGHT")
      return
    end
    near = @mobs.count { |m| m.kind != Mob::PIG && m.kind != Mob::SHEEP && (m.x - x) ** 2 + (m.z - z) ** 2 < 100.0 }
    if near > 0
      say("YOU CANNOT SLEEP NOW  MONSTERS ARE NEARBY")
      return
    end
    @time_of_day = 0.02
    say("GOOD MORNING")
  end

  def eat
    return unless @survival && @inv_count[@slot] > 0 && @hunger < MAX_HUNGER
    @hunger = [@hunger + 8, MAX_HUNGER].min
    @inv_count[@slot] -= 1
    @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
    play(Sfx::PLACE, 0.5)
    say("YUM")
  end

  def place
    b = current_block
    return if b == Block::AIR || Block.item?(b)
    return if @survival && @inv_count[@slot] <= 0
    x = @player.px
    y = @player.py
    z = @player.pz
    return unless @world.inside?(x, y, z)
    return if Block::SOLID[b] == 1 && @player.overlaps?(x, y, z)
    return if Block::PLANT[b] == 1 && (Block::SOLID[@world.get(x, y - 1, z)] == 0 || Block.water?(@world.get(x, y, z)))
    if Block::SOLID[b] == 1
      @mobs.each do |m|
        return if x + 1 > m.x - m.half && x < m.x + m.half && y + 1 > m.y && y < m.y + m.tall && z + 1 > m.z - m.half && z < m.z + m.half
      end
    end
    current = @world.get(x, y, z)
    return unless current == Block::AIR || Block.water?(current) || Block::PLANT[current] == 1
    set_block(x, y, z, b)
    play(Sfx::PLACE, 0.7)
    @swing = 0.25
    if @survival
      @inv_count[@slot] -= 1
      @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
    end
  end
end
