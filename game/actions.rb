# Player input: keys, the mouse, mining, placing, beds, and food.
class Game
  def handle_input(dt)
    if @inventory_open
      handle_inventory
      return
    end
    if Gfx.in_key_pressed(Key::ESCAPE) || Gfx.in_focus_lost
      # Saving takes tens of milliseconds, so it happens when the game pauses, not mid-play.
      save if @captured && @changed && @save_on_quit
      @captured = false
      Gfx.in_capture(0)
    end
    if @dead
      if Gfx.in_button_pressed(1) || Gfx.in_key_pressed(Key::R)
        respawn
        @captured = true
        Gfx.in_capture(1)
      end
      return
    end
    if !@captured
      new_world if Gfx.in_key_pressed(Key::N)
      if Gfx.in_button_pressed(1)
        @captured = true
        Gfx.in_capture(1)
      end
      return
    end
    @player.look(Gfx.in_mouse_dx, Gfx.in_mouse_dy)
    select_slot
    if Gfx.in_key_pressed(Key::E)
      toggle_inventory
      return
    end
    handle_keys
    @action_cooldown -= dt
    left = Gfx.in_button(1)
    right = Gfx.in_button(3)
    left_pressed = Gfx.in_button_pressed(1)
    @action_cooldown = 0.0 if left_pressed || Gfx.in_button_pressed(3)
    if Gfx.in_button_pressed(2) && @player.hit && !@survival
      picked = @world.get(@player.hx, @player.hy, @player.hz)
      @hotbar[@slot] = picked if picked != Block::BEDROCK
      say(Block::NAMES[@hotbar[@slot]])
    end
    left_button(dt, left, left_pressed)
    right_button(dt, right)
  end

  # Number keys and the wheel.
  def select_slot
    i = 0
    while i < HOTBAR
      @slot = i if Gfx.in_key_pressed(Key::N1 + i)
      i += 1
    end
    wheel = Gfx.in_wheel
    @slot = (@slot + 1) % HOTBAR if wheel < 0.0
    @slot = (@slot + HOTBAR - 1) % HOTBAR if wheel > 0.0
  end

  # Keys that switch a mode or a setting, save, craft, or skip time.
  def handle_keys
    if Gfx.in_key_pressed(Key::Q)
      if @survival
        throw_selected
      else
        at = PLACEABLE.index(@hotbar[@slot]) || 0
        @hotbar[@slot] = PLACEABLE[(at + 1) % PLACEABLE.size]
        say(Block::NAMES[@hotbar[@slot]])
      end
    end
    if Gfx.in_key_pressed(Key::G)
      @survival = !@survival
      @player.flying = false if @survival
      say(@survival ? "SURVIVAL MODE" : "CREATIVE MODE")
    end
    if Gfx.in_key_pressed(Key::F) && !@survival
      @player.flying = !@player.flying
      say(@player.flying ? "FLYING" : "WALKING")
    end
    @show_debug = !@show_debug if Gfx.in_key_pressed(Key::F3)
    save if Gfx.in_key_pressed(Key::F5)
    if Gfx.in_key_pressed(Key::F4)
      i = VIEWS.index { |v| v > @fog_end }
      @fog_end = i.nil? ? VIEWS[0] : VIEWS[i]
      say("VIEW DISTANCE #{@fog_end.to_i}")
    end
    if Gfx.in_key_pressed(Key::F11)
      @fullscreen = !@fullscreen
      Gfx.gfx_fullscreen(@fullscreen ? 1 : 0)
    end
    @time_of_day += 0.25 if Gfx.in_key_pressed(Key::T)
    if !@survival && Gfx.in_key_pressed(Key::R)
      @weather.set(!@weather.raining?)
      say(@weather.raining? ? "RAIN" : "CLEAR SKY")
    end
  end

  # The left button hits the mob in the crosshair, or else breaks the block:
  # at once in creative, over time in survival.
  def left_button(dt, held, pressed)
    if held && @target_mob >= 0
      if pressed
        mob = @mobs[@target_mob]
        mob.hit(@survival ? Block.damage(current_block.to_i) : 10, @player.x, @player.z)
        wear_tool
        mob.by_player = true
        play(Sfx::HIT, 0.8)
        @swing = 0.25
      end
      @mining = false
    elsif held && @player.hit
      if @survival
        mine(dt)
      elsif @action_cooldown <= 0.0
        broken = @world.get(@player.hx, @player.hy, @player.hz)
        @particles.burst(@player.hx, @player.hy, @player.hz, broken)
        play(Sfx::BREAK, 0.7)
        set_block(@player.hx, @player.hy, @player.hz, Block::AIR)
        @action_cooldown = 0.22
        @swing = 0.25
      end
    else
      @mining = false
    end
  end

  # The right button draws the bow, opens a chest, uses a bed, eats, or
  # places a block.
  def right_button(dt, held)
    target = @player.hit ? @world.get(@player.hx, @player.hy, @player.hz) : Block::AIR
    if current_block == Block::BOW && target != Block::CHEST && !Block.bed?(target) && !Block.door?(target)
      if held
        @draw_time = 0.0 if @draw_time < 0.0
        @draw_time += dt
      elsif @draw_time >= 0.0
        shoot_bow(@draw_time)
        @draw_time = -1.0
      end
      return
    end
    @draw_time = -1.0
    if held && @action_cooldown <= 0.0
      if @survival && @player.hit && @world.get(@player.hx, @player.hy, @player.hz) == Block::CHEST
        open_chest(@player.hx, @player.hy, @player.hz)
        return
      elsif @survival && (target == Block::CRAFTING_TABLE || target == Block::FURNACE)
        toggle_inventory
        return
      elsif Block.bed?(target)
        use_bed(@player.hx, @player.hy, @player.hz)
      elsif Block.door?(target)
        toggle_door(@player.hx, @player.hy, @player.hz)
      elsif @survival && Block.bucket?(current_block.to_i)
        use_bucket
      elsif Block.food(current_block.to_i) > 0
        eat
      elsif @player.hit
        place
      end
      @action_cooldown = 0.22
    end
  end

  # An empty bucket takes the first water or lava source in view. A full
  # bucket pours its source into the cell where a block would go.
  def use_bucket
    b = current_block.to_i
    if b == Block::BUCKET
      return unless fluid_in_view
      fluid = @world.get(@fluid_x, @fluid_y, @fluid_z)
      set_block(@fluid_x, @fluid_y, @fluid_z, Block::AIR)
      swap_bucket(fluid == Block::WATER ? Block::WATER_BUCKET : Block::LAVA_BUCKET)
    else
      return unless @player.hit
      x = @player.px
      y = @player.py
      z = @player.pz
      if @world.get(@player.hx, @player.hy, @player.hz) == Block::TALL_GRASS
        x = @player.hx
        y = @player.hy
        z = @player.hz
      end
      return unless @world.inside?(x, y, z)
      current = @world.get(x, y, z)
      return if Block.solid?(current) || Block.door?(current)
      set_block(x, y, z, b == Block::WATER_BUCKET ? Block::WATER : Block::LAVA)
      swap_bucket(Block::BUCKET)
    end
    play(Sfx::SPLASH, 0.5)
  end

  # Finds the first water or lava source on the line of sight within reach,
  # and keeps its cell in @fluid_x, @fluid_y and @fluid_z. A solid block
  # ends the line.
  def fluid_in_view
    t = 0.0
    while t < Player::REACH
      x = (@player.x + @player.fx * t).floor
      y = (@player.eye_y + @player.fy * t).floor
      z = (@player.z + @player.fz * t).floor
      b = @world.get(x, y, z)
      if b == Block::WATER || b == Block::LAVA
        @fluid_x = x
        @fluid_y = y
        @fluid_z = z
        return true
      end
      return false if Block.solid?(b)
      t += 0.05
    end
    false
  end

  # Takes one bucket from the selected slot and gives b for it. An emptied
  # slot gets b, so b stays in the hand.
  def swap_bucket(b)
    @inv_count[@slot] -= 1
    if @inv_count[@slot] == 0
      @inv_block[@slot] = b
      @inv_count[@slot] = 1
    elsif !give(b)
      throw_stack(b, 1)
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
    # A held button swings again when the last swing ends.
    @swing = SWING if @swing <= 0.0
    tool = current_block.to_i
    # The tier of the tool when it is the kind that digs b fast, else 0.
    tier = Block::DIG_KIND[b] != 0 && Block.tool_kind(tool) == Block::DIG_KIND[b] ? Block.tool_tier(tool) : 0
    need = Block::NEEDS_PICK[b]
    # The right tool speeds up digging. Without a good enough pickaxe, stone is slow.
    speed = need > 0 && tier < need ? 0.3 : 1.0 + tier * 1.2
    @mine_progress += hardness == 0.0 ? 1.0 : dt * speed / hardness
    if @mine_progress >= 1.0
      @particles.burst(x, y, z, b)
      play(Sfx::BREAK, 0.7)
      set_block(x, y, z, Block::AIR)
      drop_from_block(Block::DROPS[b], 1, x, y, z) if tier >= need
      drop_extra(b, x, y, z)
      wear_tool if hardness > 0.0
      @mining = false
    end
  end

  def dig_sound(b)
    return Sfx::DIG_STONE if Block::NEEDS_PICK[b] > 0 || b == Block::GLASS || b == Block::BEDROCK
    return Sfx::DIG_STONE if b == Block::FURNACE
    return Sfx::DIG_WOOD if b == Block::LOG || b == Block::PLANKS || b == Block::CHEST || Block.bed?(b) || Block.door?(b) || b == Block::CRAFTING_TABLE || b == Block::LADDER
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
    near = @mobs.count { |m| !m.passive? && (m.x - x) ** 2 + (m.z - z) ** 2 < 100.0 }
    if near > 0
      say("YOU CANNOT SLEEP NOW  MONSTERS ARE NEARBY")
      return
    end
    @time_of_day = 0.02
    say("GOOD MORNING")
  end

  # What a broken block drops besides Block::DROPS: leaves now and then a
  # sapling and more rarely an apple, tall grass now and then seeds, and
  # ripe wheat 1 or 2 seeds.
  def drop_extra(b, x, y, z)
    r = rand01
    if b == Block::LEAVES
      if r < 0.1
        drop_from_block(Block::SAPLING, 1, x, y, z)
      elsif r < 0.15
        drop_from_block(Block::APPLE, 1, x, y, z)
      end
    elsif b == Block::TALL_GRASS
      drop_from_block(Block::SEEDS, 1, x, y, z) if r < 0.125
    elsif b == Block::WHEAT_RIPE
      drop_from_block(Block::SEEDS, r < 0.5 ? 1 : 2, x, y, z)
    end
  end

  # Opens or closes the door at x, y, z and the other half above or below it.
  def toggle_door(x, y, z)
    b = @world.get(x, y, z) == Block::DOOR ? Block::DOOR_OPEN : Block::DOOR
    other = door_partner(x, y, z)
    # A closed door must not close on the player or a mob.
    if b == Block::DOOR
      return if @player.overlaps?(x, y, z) || @player.overlaps?(x, other, z)
      return if mob_in?(x, y < other ? y : other, z, 2)
    end
    @world.set(x, y, z, b)
    @world.set(x, other, z, b) if Block.door?(@world.get(x, other, z))
    mark_dirty(x, z)
    play(b == Block::DOOR ? Sfx::DIG_WOOD : Sfx::PLACE, 0.6)
    @swing = SWING
  end

  # True when a mob overlaps the column of tall cells from x, y, z up.
  def mob_in?(x, y, z, tall)
    @mobs.each do |m|
      return true if x + 1 > m.x - m.half && x < m.x + m.half && y + tall > m.y && y < m.y + m.tall && z + 1 > m.z - m.half && z < m.z + m.half
    end
    false
  end

  # A door is two blocks tall. It stands on a solid block that is not a
  # door, and no door stands right above it, so each half has one partner.
  def door_fits?(x, y, z)
    below = @world.get(x, y - 1, z)
    Block.solid?(below) && !Block.door?(below) && @world.get(x, y + 1, z) == Block::AIR && !Block.door?(@world.get(x, y + 2, z))
  end

  # The four directions on the ground, for the two halves of a bed.
  BED_DX = [1, -1, 0, 0]
  BED_DZ = [0, 0, 1, -1]

  # The direction from the foot of a new bed to its head: the direction on
  # the ground that the player looks in most.
  def bed_direction
    fx = @player.fx
    fz = @player.fz
    if fx.abs > fz.abs
      fx > 0.0 ? 0 : 1
    else
      fz > 0.0 ? 2 : 3
    end
  end

  # A bed has its foot at x, y, z and its head at hx, y, hz. Both stand on
  # solid blocks. No other bed may touch either half, so that each half has
  # one partner.
  def bed_fits?(x, y, z, hx, hz)
    head = @world.get(hx, y, hz)
    return false unless head == Block::AIR || head == Block::TALL_GRASS
    return false unless Block.solid?(@world.get(x, y - 1, z)) && Block.solid?(@world.get(hx, y - 1, hz))
    return false if @player.overlaps?(hx, y, hz) || mob_in?(hx, y, hz, 1)
    d = 0
    while d < 4
      return false if Block.bed?(@world.get(x + BED_DX[d], y, z + BED_DZ[d]))
      return false if Block.bed?(@world.get(hx + BED_DX[d], y, hz + BED_DZ[d]))
      d += 1
    end
    true
  end

  # The direction from the bed half at x, y, z to its other half, or -1.
  def bed_partner(x, y, z)
    d = 0
    while d < 4
      return d if Block.bed?(@world.get(x + BED_DX[d], y, z + BED_DZ[d]))
      d += 1
    end
    -1
  end

  # The y of the other half of the door at x, y, z.
  def door_partner(x, y, z) = Block.door?(@world.get(x, y + 1, z)) ? y + 1 : y - 1

  def eat
    food = Block.food(current_block.to_i)
    return unless @survival && @inv_count[@slot] > 0 && @hunger < MAX_HUNGER && food > 0
    @hunger = [@hunger + food, MAX_HUNGER].min
    @inv_count[@slot] -= 1
    @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
    play(Sfx::PLACE, 0.5)
    say("YUM")
  end

  def place
    # Spinel types an Array read as Integer or nil. A plain Integer here keeps
    # the parameters of Block.solid?, plant? and emits? unboxed.
    b = current_block.to_i
    return if b == Block::AIR || Block.item?(b)
    return if @survival && @inv_count[@slot] <= 0
    x = @player.px
    y = @player.py
    z = @player.pz
    # A block placed on tall grass takes its cell, as in Minecraft.
    if @world.get(@player.hx, @player.hy, @player.hz) == Block::TALL_GRASS
      x = @player.hx
      y = @player.hy
      z = @player.hz
    end
    return unless @world.inside?(x, y, z)
    return if Block.solid?(b) && @player.overlaps?(x, y, z)
    return if Block.plant?(b) && (!Block.solid?(@world.get(x, y - 1, z)) || Block.water?(@world.get(x, y, z)))
    return if Block.solid?(b) && mob_in?(x, y, z, b == Block::DOOR ? 2 : 1)
    current = @world.get(x, y, z)
    # The view ray can pass a flower, so a block only replaces tall grass.
    return unless current == Block::AIR || Block.water?(current) || current == Block::TALL_GRASS
    if b == Block::DOOR
      return unless door_fits?(x, y, z)
      return if @player.overlaps?(x, y + 1, z)
      set_block(x, y + 1, z, b)
    end
    if b == Block::BED
      d = bed_direction
      return unless bed_fits?(x, y, z, x + BED_DX[d], z + BED_DZ[d])
      set_block(x + BED_DX[d], y, z + BED_DZ[d], Block::BED_HEAD)
    end
    set_block(x, y, z, b)
    play(Sfx::PLACE, 0.7)
    @swing = 0.25
    if @survival
      @inv_count[@slot] -= 1
      @inv_block[@slot] = Block::AIR if @inv_count[@slot] == 0
    end
  end
end
