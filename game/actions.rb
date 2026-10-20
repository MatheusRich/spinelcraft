# Player input: keys, the mouse, mining, placing, beds, and food.
class Game
  def handle_input(dt) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    if @title_open
      handle_title
      return
    end
    if @inventory_open
      handle_inventory
      return
    end
    if @chat.open?
      unless Gfx.in_focus_lost
        handle_chat
        return
      end
      # The game pauses below, as with a closed chat.
      close_chat
    end
    escape = Gfx.in_key_pressed(Key::ESCAPE)
    if (escape && @captured) || Gfx.in_focus_lost
      # Saving takes tens of milliseconds, so it happens when the game pauses, not mid-play.
      save if @captured && @changed && @save_on_quit
      @captured = false
      Gfx.in_capture(0)
      return
    end
    if @vitals.dead?
      if Gfx.in_button_pressed(1) || Gfx.in_key_pressed(Key::R)
        respawn
        resume
      end
      return
    end
    if !@captured
      handle_menu(escape)
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
      picked = Block::BASE[picked]
      @hotbar[@slot] = picked if picked != Block::BEDROCK
      say(Block::NAMES[@hotbar[@slot]])
    end
    left_button(dt, left, left_pressed)
    right_button(dt, right)
  end

  # Number keys and the wheel.
  def select_slot
    HOTBAR.times { |i| @slot = i if Gfx.in_key_pressed(Key::N1 + i) }
    wheel = Gfx.in_wheel
    @slot = (@slot + 1) % HOTBAR if wheel < 0.0
    @slot = (@slot + HOTBAR - 1) % HOTBAR if wheel > 0.0
  end

  # Keys that switch a mode or a setting, save, craft, or open the chat.
  def handle_keys
    if Gfx.in_key_pressed(Key::Q)
      if @survival
        throw_selected
      else
        at = CREATIVE_ITEMS.index(@hotbar[@slot]) || 0
        @hotbar[@slot] = CREATIVE_ITEMS[(at + 1) % CREATIVE_ITEMS.size]
        say(Block::NAMES[@hotbar[@slot]])
      end
    end
    @options.debug = !@options.debug if Gfx.in_key_pressed(Key::F3)
    save if Gfx.in_key_pressed(Key::F5)
    toggle_fullscreen if Gfx.in_key_pressed(Key::F11)
    open_chat("") if Gfx.in_key_pressed(Key::T)
    open_chat("/") if Gfx.in_key_pressed(Key::SLASH)
  end

  def set_mode(survival)
    @survival = survival
    @player.flying = false if @survival
    nil
  end

  def toggle_fullscreen
    @options.fullscreen = !@options.fullscreen
    Gfx.gfx_fullscreen(@options.fullscreen ? 1 : 0)
  end

  # How full the attack cooldown is, from 0 to 1. A hit does 0.2 + 0.8 *
  # charge * charge of its damage. An attack, a broken block and a new item
  # in the hand start the cooldown again. The 0.025 seconds are half a
  # tick. minecraft.wiki/w/Melee_attack
  def attack_charge = ((@attack_time + 0.025) * Block.attack_speed(current_block.to_i)).clamp(0.0, 1.0)

  # The left button hits the mob in the crosshair, or else breaks the block:
  # at once in creative, over time in survival.
  def left_button(dt, held, pressed) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    if held && @target_mob >= 0
      if pressed
        mob = @mobs[@target_mob]
        charge = attack_charge
        damage = @survival ? Block.damage(current_block.to_i) * (0.2 + 0.8 * charge * charge) : 10.0
        # A falling attack with the cooldown at 84.8% or more is a critical
        # hit: 1.5 times the damage. minecraft.wiki/w/Damage
        crit = charge >= 0.848 && @player.falling_attack?
        damage *= 1.5 if crit
        mob.hit(damage, @player.x, @player.z)
        @particles.crit(mob.x, mob.y + mob.tall * 0.5, mob.z) if crit
        @attack_time = 0.0
        wear_tool(Block.wear(current_block.to_i, true))
        @vitals.exhaust(Vitals::ATTACK_COST) if @survival
        mob.by_player = true
        play(Sfx::HIT, 0.8)
        @swing = 0.25
      end
      @mining = false
    elsif held && @target_boat >= 0
      hit_boat(@target_boat) if pressed
      @mining = false
    elsif held && @player.hit
      if @survival
        mine(dt)
      elsif @action_cooldown <= 0.0
        broken = @world.get(@player.hx, @player.hy, @player.hz)
        @particles.burst(@player.hx, @player.hy, @player.hz, broken)
        play(MATERIAL_BREAK[material(broken)], 0.7)
        set_block(@player.hx, @player.hy, @player.hz, Block::AIR)
        @attack_time = 0.0
        @action_cooldown = 0.22
        @swing = 0.25
      end
    else
      @mining = false
    end
  end

  # The right button gets in a boat, feeds an animal, draws the bow, opens
  # a chest, uses a bed, eats, carves a pumpkin, or places a block or a boat.
  def right_button(dt, held) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    if @target_boat >= 0 && !riding?
      @eat_time = -1.0
      @draw_time = -1.0
      if held && @action_cooldown <= 0.0
        board_boat(@target_boat)
        @action_cooldown = 0.22
      end
      return
    end
    if current_block == Block::SHEARS && @target_mob >= 0 && @mobs[@target_mob].shearable?
      @eat_time = -1.0
      @draw_time = -1.0
      if held && @action_cooldown <= 0.0
        shear(@mobs[@target_mob])
        @action_cooldown = 0.22
      end
      return
    end
    if @target_mob >= 0 && @mobs[@target_mob].food?(current_block.to_i)
      @eat_time = -1.0
      @draw_time = -1.0
      if held && @action_cooldown <= 0.0
        feed_animal(@mobs[@target_mob])
        @action_cooldown = 0.22
      end
      return
    end
    target = @player.hit ? @world.get(@player.hx, @player.hy, @player.hz) : Block::AIR
    if edible? && !usable?(target)
      if held
        chew(dt)
      else
        @eat_time = -1.0
      end
      return
    end
    @eat_time = -1.0
    if current_block == Block::BOW && !usable?(target)
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
      if @survival && @player.hit && Block::BASE[target] == Block::CHEST
        open_chest(@player.hx, @player.hy, @player.hz)
        return
      elsif @survival && Block::BASE[target] == Block::CRAFTING_TABLE
        open_station(@player.hx, @player.hy, @player.hz, Recipe::AT_TABLE)
        return
      elsif @survival && Block::BASE[target] == Block::FURNACE
        open_station(@player.hx, @player.hy, @player.hz, Recipe::AT_FURNACE)
        return
      elsif Block.bed?(target)
        use_bed(@player.hx, @player.hy, @player.hz)
      elsif Block.door?(target)
        toggle_door(@player.hx, @player.hy, @player.hz)
      elsif @survival && Block.bucket?(current_block.to_i)
        use_bucket
      elsif Block.boat?(current_block.to_i)
        place_boat
      elsif current_block == Block::SHEARS && target == Block::PUMPKIN
        carve_pumpkin(@player.hx, @player.hy, @player.hz)
      elsif current_block == Block::BONE_MEAL && @player.hit
        use_bone_meal
      elsif current_block == Block::EGG && (!@survival || !@inv.empty?(@slot))
        throw_egg
      elsif @player.hit
        place
      end
      @action_cooldown = 0.22
    end
  end

  # Shears take the wool of a sheep without a hit: 1 to 3 wool
  # (minecraft.wiki/w/Sheep), for 1 use of the shears (minecraft.wiki/w/Shears).
  # The sound table has no sound for shears, so the wool sound plays.
  def shear(m)
    m.sheared = true
    loot(m, Block::WOOL, 1 + (@rng.rand01 * 3.0).to_i)
    play_from(m, Sfx::CLOTH, 1.0)
    @swing = 0.25
    wear_tool(1)
  end

  # The animal m eats the food in the hand. Survival uses one item, and
  # creative keeps it, as in the game code (ItemStack.consume); the wiki
  # does not say. An adult in love mode shows a burst of hearts, and a baby
  # green sparkles (the game code: entity event 18, and the particles of
  # AgeableMob.ageUp). The eating sound is not on the wiki either.
  def feed_animal(m)
    return unless m.feed
    @inv.take(@slot, 1) if @survival
    @swing = 0.25
    play_from(m, Sfx::EAT, 0.6)
    # to_i and to_f: Spinel cannot type the mob. The sparkles fill the
    # block cell of the baby.
    if m.baby?
      @particles.growth(m.x.floor.to_i, m.y.floor.to_i, m.z.floor.to_i, false)
    else
      @particles.hearts(m.x.to_f, m.y.to_f, m.z.to_f, m.half.to_f, m.tall.to_f)
    end
  end

  # Shears carve a face into the side of the pumpkin at x, y, z that the
  # player looks at. On the top or the bottom, the face turns to the
  # player. The pumpkin drops 4 seeds. minecraft.wiki/w/Pumpkin
  def carve_pumpkin(x, y, z)
    d = if @player.px != x
      @player.px > x ? 0 : 1
    elsif @player.pz != z
      @player.pz > z ? 2 : 3
    else
      look_direction ^ 1
    end
    set_block(x, y, z, Block.facing_id(Block::CARVED_PUMPKIN, d))
    drop_from_block(Block::PUMPKIN_SEEDS, 4, x, y, z)
    play(MATERIAL_DIG[M_WOOD], 0.7)
    @swing = 0.25
    wear_tool(1)
  end

  # An empty bucket takes the first water or lava source in view. A full
  # bucket pours its source into the cell where a block would go.
  def use_bucket # rubocop:todo Metrics/MethodLength
    b = current_block.to_i
    if b == Block::BUCKET && @target_mob >= 0 && @mobs[@target_mob].kind == Mob::COW
      swap_bucket(Block::MILK_BUCKET)
      play_from(@mobs[@target_mob], Sfx::MILK, 1.0)
    elsif b == Block::BUCKET
      return unless fluid_in_view
      fluid = @world.get(@fluid_x, @fluid_y, @fluid_z)
      set_block(@fluid_x, @fluid_y, @fluid_z, Block::AIR)
      swap_bucket(fluid == Block::WATER ? Block::WATER_BUCKET : Block::LAVA_BUCKET)
      play(fluid == Block::WATER ? Sfx::WATER_TAKE : Sfx::LAVA_POUR, 0.5)
    else
      return unless @player.hit
      x = @player.px
      y = @player.py
      z = @player.pz
      if Block.replaceable?(@world.get(@player.hx, @player.hy, @player.hz))
        x = @player.hx
        y = @player.hy
        z = @player.hz
      end
      return unless @world.inside?(x, y, z)
      current = @world.get(x, y, z)
      return if Block.solid?(current) || Block.door?(current)
      set_block(x, y, z, b == Block::WATER_BUCKET ? Block::WATER : Block::LAVA)
      swap_bucket(Block::BUCKET)
      play(b == Block::WATER_BUCKET ? Sfx::WATER_POUR : Sfx::LAVA_POUR, 0.5)
    end
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
    @inv.take(@slot, 1)
    if @inv.empty?(@slot)
      @inv.set(@slot, b, 1)
    elsif !@inv.add(b)
      throw_stack(b, 1)
    end
  end

  # Seconds before the next block starts to break, after a block that did
  # not break at once: 6 ticks. minecraft.wiki/w/Breaking
  MINE_DELAY = 0.3

  # As in Minecraft, a block takes 1.5 seconds for each point of hardness,
  # divided by the speed of the tool. Without the pickaxe tier that the
  # block needs, it takes 5 seconds for each point and drops nothing. It
  # takes 5 times as long with the head under water, and again 5 times as
  # long off the ground. minecraft.wiki/w/Breaking
  def mine(dt) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    @mine_delay -= dt
    return if @mine_delay > 0.0
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
      play(MATERIAL_DIG[material(b)], 0.55)
      @dig_wait = 0.25
    end
    # A held button swings again when the last swing ends.
    @swing = SWING if @swing <= 0.0
    tool = current_block.to_i
    tier = Block.dig_tier(tool, b)
    need = Block::NEEDS_PICK[b]
    shears = tool == Block::SHEARS
    speed = Block.dig_speed(tool, b)
    speed /= 5.0 if Block.water?(@world.get(@player.x.floor, @player.eye_y.floor, @player.z.floor))
    speed /= 5.0 unless @player.on_ground
    seconds = hardness * (tier >= need ? 1.5 : 5.0)
    @mine_progress += hardness == 0.0 ? 1.0 : dt * speed / seconds
    if @mine_progress >= 1.0
      @particles.burst(x, y, z, b)
      play(MATERIAL_BREAK[material(b)], 0.7)
      set_block(x, y, z, Block::AIR)
      @attack_time = 0.0
      drop_from_block(shears ? Block.shear_drop(b) : Block::DROPS[b], 1, x, y, z) if tier >= need
      drop_extra(b, x, y, z) unless shears && (Block.leaves?(b) || b == Block::TALL_GRASS)
      if hardness > 0.0
        wear_tool(Block.wear(tool, false))
        @mine_delay = MINE_DELAY
      end
      @vitals.exhaust(Vitals::MINE_COST)
      @mining = false
    end
  end

  # The material of block b for its sounds, as in VoxeLibre (mcl_sounds).
  def material(b) # rubocop:todo Metrics/CyclomaticComplexity
    b = Block::BASE[b]
    return M_GLASS if b == Block::GLASS
    return M_GRAVEL if b == Block::GRAVEL
    return M_SAND if b == Block::SAND
    return M_GRASS if b == Block::GRASS || b == Block::SNOW_GRASS
    return M_SNOW if b == Block::SNOW
    return M_CLOTH if b == Block::WOOL
    return M_WOOD if b == Block::TORCH || b == Block::CACTUS || Block.pumpkin?(b)
    return M_LEAVES if Block.leaves?(b) || Block.plant?(b)
    return M_STONE if Block::NEEDS_PICK[b] > 0 || b == Block::BEDROCK || b == Block::FURNACE
    return M_WOOD if Block.log?(b) || Block.planks?(b) || b == Block::CHEST || b == Block::BED || b == Block::DOOR || b == Block::CRAFTING_TABLE || b == Block::LADDER
    M_DIRT
  end

  # A bed sets the spawn point; at night with no monster close by, it skips to morning.
  def use_bed(x, y, z)
    @spawn_x = x + 0.5
    @spawn_z = z + 0.5
    if @clock.daylight > 0.35
      say("SPAWN SET  YOU CAN ONLY SLEEP AT NIGHT")
      return
    end
    near = @mobs.count { |m| !m.passive? && !m.dying? && (m.x - x) ** 2 + (m.z - z) ** 2 < 100.0 }
    if near > 0
      say("YOU CANNOT SLEEP NOW  MONSTERS ARE NEARBY")
      return
    end
    @clock.skip_night
    say("GOOD MORNING")
  end

  # What a broken block drops besides Block::DROPS: leaves now and then a
  # sapling of their wood, oak leaves more rarely an apple, tall grass now
  # and then seeds, and ripe wheat 1 or 2 seeds.
  def drop_extra(b, x, y, z)
    r = @rng.rand01
    if Block.leaves?(b)
      # Spruce and birch leaves drop a sapling 1 time in 20, and no apple.
      # minecraft.wiki/w/Leaves
      sapling = Block::BASE[b] == Block::OAK_LEAVES ? 0.1 : 0.05
      if r < sapling
        drop_from_block(Block::SAPLINGS[Block.wood(b)], 1, x, y, z)
      elsif Block::BASE[b] == Block::OAK_LEAVES && r < 0.15
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
    b = Block.door_toggled(@world.get(x, y, z))
    other = @world.door_partner(x, y, z)
    # A closed door must not close on the player or a mob.
    unless Block.door_open?(b)
      return if @player.overlaps?(x, y, z) || @player.overlaps?(x, other, z)
      return if mob_in?(x, y < other ? y : other, z, 2)
    end
    @world.set(x, y, z, b)
    partner = @world.get(x, other, z)
    @world.set(x, other, z, Block.door_toggled(partner)) if Block.door?(partner)
    @chunk_meshes.mark_block(x, z)
    play(Block.door_open?(b) ? Sfx::DOOR_OPEN : Sfx::DOOR_CLOSE, 0.6)
    @swing = SWING
  end

  # True when a mob overlaps the column of tall cells from x, y, z up.
  def mob_in?(x, y, z, tall)
    @mobs.each do |m|
      next if m.dying?
      return true if x + 1 > m.x - m.half && x < m.x + m.half && y + tall > m.y && y < m.y + m.tall && z + 1 > m.z - m.half && z < m.z + m.half
    end
    false
  end

  # The direction on the ground that the player looks in most (see
  # Block::DIR_DX). A new bed points its head this way, and a new furnace
  # turns its front the other way, to the player.
  def look_direction
    fx = @player.fx
    fz = @player.fz
    if fx.abs > fz.abs
      fx > 0.0 ? 0 : 1
    else
      fz > 0.0 ? 2 : 3
    end
  end

  # A bed has its foot at x, y, z and its head at hx, y, hz. Both stand on
  # solid blocks.
  def bed_fits?(x, y, z, hx, hz)
    head = @world.get(hx, y, hz)
    return false unless head == Block::AIR || Block.replaceable?(head)
    return false unless Block.solid?(@world.get(x, y - 1, z)) && Block.solid?(@world.get(hx, y - 1, hz))
    !@player.overlaps?(hx, y, hz) && !mob_in?(hx, y, hz, 1)
  end

  # Bone meal on the block in view: it spends one in survival when the
  # block grows, and green sparkles show where it worked.
  def use_bone_meal
    x = @player.hx.to_i
    y = @player.hy.to_i
    z = @player.hz.to_i
    grass = @world.get(x, y, z) == Block::GRASS
    grows = @plants.fertilize(x, y, z, @changes)
    apply_changes
    return unless grows
    @inv.take(@slot, 1) if @survival
    @particles.growth(x, y, z, grass)
  end

  # True when the player holds food and can eat it now.
  # Milk needs no hunger. minecraft.wiki/w/Milk_Bucket
  def edible?
    return false if !@survival || @inv.empty?(@slot)
    b = current_block.to_i
    b == Block::MILK_BUCKET || (@vitals.hungry? && Block.food(b) > 0)
  end

  # True for a block that the right button opens or uses.
  def usable?(b)
    base = Block::BASE[b]
    base == Block::CHEST || base == Block::CRAFTING_TABLE || base == Block::FURNACE || Block.bed?(b) || Block.door?(b)
  end

  # dt more seconds of eating. After CHEW_START, each CHEW_EVERY plays a
  # bite and throws crumbs of the food. At EAT_TIME the player eats it.
  def chew(dt)
    before = @eat_time < 0.0 ? 0.0 : @eat_time
    @eat_time = before + dt
    if @eat_time >= EAT_TIME
      eat
      @eat_time = -1.0
    elsif @eat_time >= CHEW_START && ((@eat_time - CHEW_START) / CHEW_EVERY).floor != ((before - CHEW_START) / CHEW_EVERY).floor
      milk = current_block == Block::MILK_BUCKET
      play(milk ? Sfx::DRINK : Sfx::EAT, 0.5)
      @particles.shatter(@player, current_block.to_i) unless milk
    end
  end

  # Rotten flesh gives the Hunger effect 4 times in 5.
  # minecraft.wiki/w/Rotten_Flesh
  def eat
    b = current_block.to_i
    return drink_milk if b == Block::MILK_BUCKET
    @vitals.eat(Block.food(b), Block.saturation(b))
    @vitals.give_hunger_effect if @rng.rand01 < Block.hunger_chance(b)
    @inv.take(@slot, 1)
    play(Sfx::EAT, 0.6)
  end

  # Milk ends the effects and leaves the empty bucket.
  # minecraft.wiki/w/Milk_Bucket
  def drink_milk
    @vitals.clear_effects
    swap_bucket(Block::BUCKET)
    play(Sfx::DRINK, 0.6)
  end

  def place # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    # Spinel types an Array read as Integer or nil. A plain Integer here keeps
    # the parameters of Block.solid?, plant? and emits? unboxed.
    b = current_block.to_i
    return if b == Block::AIR || Block.item?(b)
    return if @survival && @inv.empty?(@slot)
    x = @player.px
    y = @player.py
    z = @player.pz
    # A block placed on grass (Block.replaceable?) takes its cell, as in Minecraft.
    if Block.replaceable?(@world.get(@player.hx, @player.hy, @player.hz))
      x = @player.hx
      y = @player.hy
      z = @player.hz
    end
    return unless @world.inside?(x, y, z)
    # A torch or a ladder on the side of a block hangs on that block, and
    # faces away from it. A ladder hangs only on the side of a solid block.
    side = y == @player.hy && (x != @player.hx || z != @player.hz)
    if (b == Block::TORCH || b == Block::LADDER) && side
      wall = @player.hx > x ? 0 : (@player.hx < x ? 1 : (@player.hz > z ? 2 : 3))
      return if b == Block::LADDER && !Block.solid?(@world.get(@player.hx, @player.hy, @player.hz))
      b = Block.facing_id(b, wall ^ 1)
    elsif b == Block::LADDER
      return
    elsif Block::FACING[b] >= 0
      b = Block.facing_id(b, look_direction ^ 1)
    elsif b == Block::DOOR
      # A closed door stands on the edge of its cell next to the player.
      b = Block.door_id(look_direction ^ 1, false, false)
    elsif b == Block::BED
      # The head goes the way that the player looks, and each half faces
      # away from the other.
      b = Block.bed_id(look_direction ^ 1, false)
    elsif Block.leaves?(b)
      b = Block::PLACED_LEAVES[Block.wood(b)]
    end
    return if Block.solid?(b) && @player.overlaps?(x, y, z)
    if Block.plant?(b)
      held = if Block.wall_torch?(b)
        @world.get(x - Block::DIR_DX[Block::FACING[b]], y, z - Block::DIR_DZ[Block::FACING[b]])
      else
        @world.get(x, y - 1, z)
      end
      return if !Block.solid?(held) || Block.water?(@world.get(x, y, z)) || Block.lava?(@world.get(x, y, z))
      return if Block::SOIL_PLANTS.include?(b) && !Block.soil?(held)
      # Dry grass also goes on sand. minecraft.wiki/w/Short_Dry_Grass
      return if b == Block::DRY_GRASS && !Block.soil?(held) && held != Block::SAND
    end
    # A cactus stands only on sand or on another cactus. minecraft.wiki/w/Cactus
    return if b == Block::CACTUS && @world.get(x, y - 1, z) != Block::SAND && @world.get(x, y - 1, z) != Block::CACTUS
    return if Block.solid?(b) && mob_in?(x, y, z, Block.door?(b) ? 2 : 1)
    current = @world.get(x, y, z)
    # The view ray can pass a flower, so a block only replaces grass.
    # It passes water and lava, and a block replaces them, as in Minecraft.
    return unless current == Block::AIR || Block.water?(current) || Block.lava?(current) || Block.replaceable?(current)
    if Block.door?(b)
      return unless @world.door_fits?(x, y, z)
      return if @player.overlaps?(x, y + 1, z)
      set_block(x, y + 1, z, Block.door_id(Block::FACING[b], true, false))
    end
    if Block.bed?(b)
      d = Block::FACING[b] ^ 1
      return unless bed_fits?(x, y, z, x + Block::DIR_DX[d], z + Block::DIR_DZ[d])
      set_block(x + Block::DIR_DX[d], y, z + Block::DIR_DZ[d], Block.bed_id(d, true))
    end
    b = join_chest(x, y, z, b) if Block::BASE[b] == Block::CHEST
    set_block(x, y, z, b)
    play(MATERIAL_PLACE[material(b)], 0.7)
    @swing = 0.25
    @inv.take(@slot, 1) if @survival
  end

  # A chest b placed at x, y, z next to a chest of one block that faces the
  # same way joins it into a large chest. A chest on its left joins first.
  # It gives the block for x, y, z. minecraft.wiki/w/Chest
  def join_chest(x, y, z, b)
    d = Block::FACING[b]
    left = Block::CHEST_LEFT_DIR[d]
    if @world.get(x + Block::DIR_DX[left], y, z + Block::DIR_DZ[left]) == b
      set_block(x + Block::DIR_DX[left], y, z + Block::DIR_DZ[left], Block::CHEST_LEFT + d)
      return Block::CHEST_RIGHT + d
    end
    if @world.get(x - Block::DIR_DX[left], y, z - Block::DIR_DZ[left]) == b
      set_block(x - Block::DIR_DX[left], y, z - Block::DIR_DZ[left], Block::CHEST_RIGHT + d)
      return Block::CHEST_LEFT + d
    end
    b
  end
end
