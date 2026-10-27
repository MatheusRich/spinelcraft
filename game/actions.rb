# Player input: keys, the mouse, mining, placing, beds, and food.
class Game
  def handle_input(dt)
    follow_fullscreen
    current = current_screen
    if current.title?
      handle_title
    elsif current.inventory?
      handle_inventory
    elsif current.typing? && !Gfx.in_focus_lost
      handle_chat
    else
      # The game pauses below, as with a closed chat.
      close_chat if current.typing?
      handle_world(dt)
    end
  end

  # The pause, the death screen, the pause menu and the play. Esc or a
  # window that loses the focus pauses the game first.
  def handle_world(dt)
    current = current_screen
    escape = Gfx.in_key_pressed(Key::ESCAPE)
    if (escape && current.playing?) || Gfx.in_focus_lost
      pause_game
    elsif current.death_screen?
      handle_death
    elsif current.pause_menu?
      handle_menu(escape)
    else
      handle_play(dt)
    end
  end

  # Opens the pause menu, and saves the world if it changed.
  def pause_game
    return unless current_screen.playing?

    # Saving takes tens of milliseconds, so it happens when the game pauses,
    # not mid-play.
    save if @changed && @save_on_quit
    show_screen(Screen::PAUSED)
    Gfx.in_capture(0)
  end

  # A click or R on the death screen respawns the player.
  def handle_death
    return unless Gfx.in_button_pressed(1) || Gfx.in_key_pressed(Key::R)

    respawn
    resume
  end

  # The look, the keys and the two buttons of a player who plays.
  def handle_play(dt)
    @player.look(Gfx.in_mouse_dx, Gfx.in_mouse_dy)
    select_slot
    if Gfx.in_key_pressed(Key::E)
      toggle_inventory
      return
    end
    handle_keys
    @action_cooldown -= dt
    # The click that went back to the game (resume) acts only after the
    # player lets the buttons go.
    @wait_for_release = false unless Gfx.in_button(1) || Gfx.in_button(3)
    left = Gfx.in_button(1) && !@wait_for_release
    right = Gfx.in_button(3) && !@wait_for_release
    left_pressed = Gfx.in_button_pressed(1)
    @action_cooldown = 0.0 if left_pressed || Gfx.in_button_pressed(3)
    if Gfx.in_button_pressed(2) && @target_block.hit? && !@survival
      picked = targeted_block
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

  # The window can leave or enter fullscreen without the menu or F11, as
  # through the green button of macOS. The FULLSCREEN option follows it.
  def follow_fullscreen
    change = Gfx.in_fullscreen_change
    @options.fullscreen = change == 1 if change >= 0
  end

  def toggle_fullscreen
    @options.fullscreen = !@options.fullscreen
    Gfx.gfx_fullscreen(@options.fullscreen ? 1 : 0)
  end

  # How full the attack cooldown is, from 0 to 1. A hit does 0.2 + 0.8 *
  # charge * charge of its damage. An attack, a miss, a broken block and a
  # new item in the hand start the cooldown again. The 0.025 seconds are
  # half a tick. minecraft.wiki/w/Melee_attack
  def attack_charge = ((@attack_time + 0.025) * Block.attack_speed(current_block.to_i)).clamp(0.0, 1.0)

  # The damage of a hit with the item in the hand at the given charge.
  def melee_damage(charge) = Block.damage(current_block.to_i) * (0.2 + 0.8 * charge * charge)

  # The left button hits the mob in the crosshair, or else breaks the block:
  # at once in creative, over time in survival.
  def left_button(dt, held, pressed)
    if held && mob_in_view?
      attack_mob(viewed_mob) if pressed
      @mining = false
    elsif held && boat_in_view?
      hit_boat(@target_boat) if pressed
      @mining = false
    elsif held && @target_block.hit?
      break_target(dt)
    else
      swing_at_air if pressed
      @mining = false
    end
  end

  # Hits the mob with the item in the hand.
  def attack_mob(mob)
    charge = attack_charge
    damage = @survival ? melee_damage(charge) : 10.0
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
    @sfx.play(Sfx::HIT, 0.8)
    @swing = SWING
  end

  # Mines the block in view over time in survival, and breaks it at once in
  # creative.
  def break_target(dt)
    return mine(dt) if @survival
    return unless @action_cooldown <= 0.0

    broken = targeted_block
    @particles.burst(@target_block.x, @target_block.y, @target_block.z, broken)
    @sfx.play(MATERIAL_BREAK[material(broken)], 0.7)
    set_block(@target_block.x, @target_block.y, @target_block.z, Block::AIR)
    @attack_time = 0.0
    @action_cooldown = 0.22
    @swing = SWING
  end

  # A click at the air swings the arm and starts the cooldown again. The
  # wiki does not say so; the game code does (Minecraft.startAttack).
  def swing_at_air
    @attack_time = 0.0
    @swing = SWING
  end

  # The right button gets in a boat, feeds an animal, draws the bow, opens
  # a chest, uses a bed, eats, carves a pumpkin, or places a block or a boat.
  def right_button(dt, held)
    ready = held && @action_cooldown <= 0.0
    target = viewed_block
    if target_click?
      @eat_time = -1.0
      @draw_time = -1.0
      click_target if ready
    elsif edible? && !usable?(target)
      if held
        chew(dt)
      else
        @eat_time = -1.0
      end
    elsif bow_click?(target)
      @eat_time = -1.0
      if held
        draw_bow(dt)
      else
        release_bow
      end
    else
      @eat_time = -1.0
      @draw_time = -1.0
      use_block(target) if ready
    end
  end

  # The block in view, or air when a mob stands in front of it.
  def viewed_block
    return Block::AIR unless block_in_view?

    targeted_block
  end

  # True when a boat or a mob in view takes the click.
  def target_click? = boat_click? || shear_click? || feed_click?

  # True when a boat is in view and the player is not in one.
  def boat_click? = boat_in_view? && !riding?

  # True when the player holds shears and a sheep with wool is in view.
  def shear_click? = current_block == Block::SHEARS && mob_in_view? && viewed_mob.shearable?

  # True when the mob in view eats the item in the hand.
  def feed_click? = mob_in_view? && viewed_mob.food?(current_block.to_i)

  # The click acts on the boat or the mob in view. The checks keep the
  # order of target_click?.
  def click_target
    if boat_click?
      board_boat(@target_boat)
    elsif shear_click?
      shear(viewed_mob)
    else
      feed_animal(viewed_mob)
    end
    @action_cooldown = 0.22
  end

  # True when the click draws the bow, not when it uses the block in view.
  def bow_click?(target) = current_block == Block::BOW && !usable?(target)

  # Adds dt seconds to the draw time of the bow.
  def draw_bow(dt)
    @draw_time = 0.0 if @draw_time < 0.0
    @draw_time += dt
  end

  # Shoots the arrow when the player lets the button go and the bow is drawn.
  def release_bow
    return if @draw_time < 0.0

    shoot_bow(@draw_time)
    @draw_time = -1.0
  end

  # The click acts on the block in view, or on the item in the hand.
  # A chest, a crafting table and a furnace open at once, with no cooldown.
  def use_block(target)
    return if open_container(target)

    if Block.bed?(target)
      use_bed(@target_block.x, @target_block.y, @target_block.z)
    elsif Block.door?(target)
      toggle_door(@target_block.x, @target_block.y, @target_block.z)
    else
      use_held
    end
    @action_cooldown = 0.22
  end

  # Opens the chest or the station at the block in view. True when it opens.
  def open_container(target)
    return false unless @survival

    x = @target_block.x
    y = @target_block.y
    z = @target_block.z
    base = Block::BASE[target]
    if block_in_view? && base == Block::CHEST
      open_chest(x, y, z)
    elsif base == Block::CRAFTING_TABLE
      open_station(x, y, z, Recipe::AT_TABLE)
    elsif base == Block::FURNACE
      open_station(x, y, z, Recipe::AT_FURNACE)
    else
      return false
    end
    true
  end

  # The item in the hand acts on the block in view, or on the air.
  def use_held
    if @survival && Block.bucket?(current_block.to_i)
      use_bucket
    elsif Block.boat?(current_block.to_i)
      place_boat
    elsif current_block == Block::SHEARS && viewed_block == Block::PUMPKIN
      carve_pumpkin(@target_block.x, @target_block.y, @target_block.z)
    elsif current_block == Block::BONE_MEAL && block_in_view?
      use_bone_meal
    elsif current_block == Block::EGG && (!@survival || !@inv.empty?(@slot))
      throw_egg
    elsif block_in_view?
      place
    end
  end

  # True when the view ray hits a block and no mob stands in front of it.
  # The ray stops at a mob, so a right-click never acts on the block behind.
  def block_in_view? = @target_block.hit? && !mob_in_view?

  # The block that the view ray hits. Call it only when @target_block.hit? is
  # true.
  def targeted_block = @world.get(@target_block.x, @target_block.y, @target_block.z)

  # True when the view ray hits a mob before a block.
  def mob_in_view? = @target_mob >= 0

  # The mob that the view ray hits. Call it only when mob_in_view? is true.
  def viewed_mob = @mobs[@target_mob]

  # True when the view ray hits a boat before a block or a mob.
  def boat_in_view? = @target_boat >= 0

  # Shears take the wool of a sheep without a hit: 1 to 3 wool
  # (minecraft.wiki/w/Sheep), for 1 use of the shears (minecraft.wiki/w/Shears).
  # The sound table has no sound for shears, so the wool sound plays.
  def shear(m)
    m.sheared = true
    loot(m, Block::WOOL, 1 + (@rng.rand01 * 3.0).to_i)
    play_from(m, Sfx::CLOTH, 1.0)
    @swing = SWING
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
    @swing = SWING
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
    d = if @target_block.front_x != x
      @target_block.front_x > x ? 0 : 1
    elsif @target_block.front_z != z
      @target_block.front_z > z ? 2 : 3
    else
      look_direction ^ 1
    end
    set_block(x, y, z, Block.facing_id(Block::CARVED_PUMPKIN, d))
    drop_from_block(Block::PUMPKIN_SEEDS, 4, x, y, z)
    @sfx.play(MATERIAL_DIG[M_WOOD], 0.7)
    @swing = SWING
    wear_tool(1)
  end

  # An empty bucket takes the first water or lava source in view. A full
  # bucket pours its source into the cell where a block would go.
  def use_bucket
    block = current_block.to_i
    if block == Block::BUCKET && mob_in_view? && viewed_mob.kind == Mob::COW
      swap_bucket(Block::MILK_BUCKET)
      play_from(viewed_mob, Sfx::MILK, 1.0)
    elsif block == Block::BUCKET
      return unless fluid_in_view

      fluid = @world.get(@fluid_x, @fluid_y, @fluid_z)
      set_block(@fluid_x, @fluid_y, @fluid_z, Block::AIR)
      swap_bucket(fluid == Block::WATER ? Block::WATER_BUCKET : Block::LAVA_BUCKET)
      @sfx.play(fluid == Block::WATER ? Sfx::WATER_TAKE : Sfx::LAVA_POUR, 0.5)
    else
      return unless block_in_view?

      x = place_x
      y = place_y
      z = place_z
      return unless @world.inside?(x, y, z)

      current = @world.get(x, y, z)
      return if Block.solid?(current) || Block.door?(current)

      # The wiki does not say what a bucket does to a plant; pour uses the
      # rule of flowing water and lava.
      pour(x, y, z, block == Block::WATER_BUCKET ? Block::WATER : Block::LAVA)
      swap_bucket(Block::BUCKET)
      @sfx.play(block == Block::WATER_BUCKET ? Sfx::WATER_POUR : Sfx::LAVA_POUR, 0.5)
    end
  end

  # Finds the first water or lava source on the line of sight within reach,
  # and keeps its cell in @fluid_x, @fluid_y and @fluid_z. A solid block
  # ends the line.
  def fluid_in_view
    # to_f: Spinel cannot type the position of the player.
    @fluid_walk.from(@player.x.to_f, @player.eye_y.to_f, @player.z.to_f)
               .toward(@player.fx, @player.fy, @player.fz, reach: Player::REACH) do |x, y, z|
      block = @world.get(x, y, z)
      if block == Block::WATER || block == Block::LAVA
        @fluid_x = x
        @fluid_y = y
        @fluid_z = z
        return true
      end
      return false if Block.solid?(block)
    end
    false
  end

  # Takes one bucket from the selected slot and gives block for it. An emptied
  # slot gets block, so block stays in the hand.
  def swap_bucket(block)
    @inv.take(@slot, 1)
    if @inv.empty?(@slot)
      @inv.set(@slot, block, 1)
    elsif !@inv.add(block)
      throw_stack(block, 1)
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
  def mine(dt)
    @mine_delay -= dt
    return if @mine_delay > 0.0

    start_mining unless mining_target?
    block = targeted_block
    hardness = Block::HARDNESS[block]
    return if hardness < 0.0

    play_dig_sound(block, hardness, dt)
    # A held button swings again when the last swing ends.
    @swing = SWING if @swing <= 0.0
    @mine_progress += mine_rate(block, hardness, dt)
    finish_mining(block) if @mine_progress >= 1.0
  end

  # True when the player keeps on mining the block that the last step mined.
  def mining_target?
    @mining && @target_block.x == @mine_x && @target_block.y == @mine_y && @target_block.z == @mine_z
  end

  # Starts to mine the block in view, with no progress.
  def start_mining
    @mining = true
    @mine_x = @target_block.x
    @mine_y = @target_block.y
    @mine_z = @target_block.z
    @mine_progress = 0.0
    @dig_wait = 0.0
  end

  # Plays the dig sound of block every 0.25 seconds while the player mines it.
  def play_dig_sound(block, hardness, dt)
    @dig_wait -= dt
    return unless @dig_wait <= 0.0 && hardness > 0.0

    @sfx.play(MATERIAL_DIG[material(block)], 0.55)
    @dig_wait = 0.25
  end

  # The part of block that dt seconds of mining break.
  def mine_rate(block, hardness, dt)
    return 1.0 if hardness == 0.0

    tool = current_block.to_i
    speed = Block.dig_speed(tool, block)
    speed /= 5.0 if Block.water?(@player.at_eyes(@world))
    speed /= 5.0 unless @player.on_ground
    seconds = hardness * (harvests?(tool, block) ? 1.5 : 5.0)
    dt * speed / seconds
  end

  # True when the tool has the pickaxe tier that block needs to drop its item.
  def harvests?(tool, block) = Block.dig_tier(tool, block) >= Block::NEEDS_PICK[block]

  # Breaks the mined block, and drops its item when the tool harvests it.
  def finish_mining(block)
    x = @target_block.x
    y = @target_block.y
    z = @target_block.z
    tool = current_block.to_i
    @particles.burst(x, y, z, block)
    @sfx.play(MATERIAL_BREAK[material(block)], 0.7)
    set_block(x, y, z, Block::AIR)
    @attack_time = 0.0
    drop_broken(block, x, y, z, tool) if harvests?(tool, block)
    if Block::HARDNESS[block] > 0.0
      wear_tool(Block.wear(tool, false))
      @mine_delay = MINE_DELAY
    end
    @vitals.exhaust(Vitals::MINE_COST)
    @mining = false
  end

  # The material of block for its sounds, as in VoxeLibre (mcl_sounds).
  def material(block) # rubocop:todo Metrics/CyclomaticComplexity
    block = Block::BASE[block]
    return M_GLASS if block == Block::GLASS
    return M_GRAVEL if block == Block::GRAVEL
    return M_SAND if block == Block::SAND
    return M_GRASS if block == Block::GRASS || block == Block::SNOW_GRASS
    return M_SNOW if block == Block::SNOW
    return M_CLOTH if block == Block::WOOL
    return M_WOOD if block == Block::TORCH || block == Block::CACTUS || Block.pumpkin?(block)
    return M_LEAVES if Block.leaves?(block) || Block.plant?(block)
    return M_STONE if Block::NEEDS_PICK[block] > 0 || block == Block::BEDROCK || block == Block::FURNACE
    return M_WOOD if Block.log?(block) || Block.planks?(block) || block == Block::CHEST || block == Block::BED || block == Block::DOOR || block == Block::CRAFTING_TABLE || block == Block::LADDER

    M_DIRT
  end

  # A bed sets the spawn point; at night with no monster close by, it skips to morning.
  def use_bed(x, y, z)
    @spawn_x = x + 0.5
    @spawn_z = z + 0.5
    say(Bed.use(x, y, z, @sky.light, @mobs, @clock))
  end

  # Opens or closes the door at x, y, z and the other half above or below it.
  def toggle_door(x, y, z)
    block = Block.door_toggled(@world.get(x, y, z))
    other = @world.door_partner(x, y, z)
    bottom = y < other ? y : other
    if Block.door_open?(block)
      # An open door must not swing onto the player or a mob.
      return if board_on_body?(block, x, bottom, z)
    else
      # A closed door must not close on the player or a mob.
      return if @player.overlaps?(x, y, z) || @player.overlaps?(x, other, z)
      return if mob_in?(x, bottom, z, 2)
    end
    @world.set(x, y, z, block)
    partner = @world.get(x, other, z)
    @world.set(x, other, z, Block.door_toggled(partner)) if Block.door?(partner)
    @chunk_meshes.mark_block(x, z)
    @sfx.play(Block.door_open?(block) ? Sfx::DOOR_OPEN : Sfx::DOOR_CLOSE, 0.6)
    @swing = SWING
  end

  # True when the board of the door half block, in the cells x, y, z and
  # x, y + 1, z, overlaps the player or a mob.
  def board_on_body?(block, x, y, z)
    return true if board_on?(block, x, y, z, @player.x, @player.y, @player.z, Player::HALF, Player::TALL)

    @mobs.any? { |mob| !mob.dying? && board_on?(block, x, y, z, mob.x, mob.y, mob.z, mob.half, mob.tall) }
  end

  # True when the board of the door half block, in the cells x, y, z and
  # x, y + 1, z, overlaps the box of solid_in_box? at bx, by, bz.
  def board_on?(block, x, y, z, bx, by, bz, half, tall)
    @world.block_in_box?(block, x, y, z, bx, by, bz, half, tall) || @world.block_in_box?(block, x, y + 1, z, bx, by, bz, half, tall)
  end

  # True when a mob overlaps the column of height cells from x, y, z up.
  def mob_in?(x, y, z, height) = @mobs.any? { |mob| !mob.dying? && mob.overlaps?(x, y, z, height) }

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
    return false unless Block.replaceable?(@world.get(hx, y, hz))
    return false unless Block.solid?(@world.get(x, y - 1, z)) && Block.solid?(@world.get(hx, y - 1, hz))

    !@player.overlaps?(hx, y, hz) && !mob_in?(hx, y, hz, 1)
  end

  # Bone meal on the block in view: it spends one in survival when the
  # block grows, and green sparkles show where it worked.
  def use_bone_meal
    x = @target_block.x.to_i
    y = @target_block.y.to_i
    z = @target_block.z.to_i
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

    block = current_block.to_i
    block == Block::MILK_BUCKET || (@vitals.hungry? && Block.food(block) > 0)
  end

  # True for a block that the right button opens or uses.
  def usable?(block)
    base = Block::BASE[block]
    base == Block::CHEST || base == Block::CRAFTING_TABLE || base == Block::FURNACE || Block.bed?(block) || Block.door?(block)
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
      @sfx.play(milk ? Sfx::DRINK : Sfx::EAT, 0.5)
      @particles.shatter(@player, current_block.to_i) unless milk
    end
  end

  # Rotten flesh gives the Hunger effect 4 times in 5.
  # minecraft.wiki/w/Rotten_Flesh
  def eat
    block = current_block.to_i
    return drink_milk if block == Block::MILK_BUCKET

    @vitals.eat(Block.food(block), Block.saturation(block))
    @vitals.give_hunger_effect if @rng.rand01 < Block.hunger_chance(block)
    @inv.take(@slot, 1)
    @sfx.play(Sfx::EAT, 0.6)
  end

  # Milk ends the effects and leaves the empty bucket.
  # minecraft.wiki/w/Milk_Bucket
  def drink_milk
    @vitals.clear_effects
    swap_bucket(Block::BUCKET)
    @sfx.play(Sfx::DRINK, 0.6)
  end

  def place
    # Spinel types an Array read as Integer or nil. A plain Integer here keeps
    # the parameters of Block.solid?, plant? and emits? unboxed.
    block = current_block.to_i
    return if block == Block::AIR || Block.item?(block)
    return if @survival && @inv.empty?(@slot)

    x = place_x
    y = place_y
    z = place_z
    return unless @world.inside?(x, y, z)
    return if block == Block::LADDER && !hangs_on_wall?(block)

    block = oriented_block(block, x, z)
    return unless placeable?(block, x, y, z)
    return unless place_other_half(block, x, y, z)

    block = join_chest(x, y, z, block) if Block::BASE[block] == Block::CHEST
    set_block(x, y, z, block)
    @sfx.play(MATERIAL_PLACE[material(block)], 0.7)
    @swing = SWING
    @inv.take(@slot, 1) if @survival
  end

  # A block placed on grass (Block.replaceable?) takes its cell, as in
  # Minecraft. Any other block goes in the cell in front of the block in view.
  def place_in_target? = Block.replaceable?(targeted_block)

  def place_x = place_in_target? ? @target_block.x : @target_block.front_x

  def place_y = place_in_target? ? @target_block.y : @target_block.front_y

  def place_z = place_in_target? ? @target_block.z : @target_block.front_z

  # True when a torch or a ladder goes on the side of the block in view, and
  # so hangs on that block.
  def hangs_on_wall?(block) = Block.wall_item?(block) && !place_in_target? && @target_block.front_y == @target_block.y

  # The block with the direction that it takes when the player places it.
  def oriented_block(block, x, z)
    return wall_facing_block(block, x, z) if hangs_on_wall?(block)
    return Block.facing_id(block, look_direction ^ 1) if Block::FACING[block] >= 0
    # A closed door stands on the edge of its cell next to the player.
    return Block.door_id(look_direction ^ 1, false, false) if block == Block::DOOR
    # The head goes the way that the player looks, and each half faces
    # away from the other.
    return Block.bed_id(look_direction ^ 1, false) if block == Block::BED
    return Block::PLACED_LEAVES[Block.wood(block)] if Block.leaves?(block)

    block
  end

  # A torch or a ladder on a wall faces away from the block in view.
  def wall_facing_block(block, x, z)
    return Block.facing_id(block, 1) if @target_block.x > x
    return Block.facing_id(block, 0) if @target_block.x < x
    return Block.facing_id(block, 3) if @target_block.z > z

    Block.facing_id(block, 2)
  end

  # True when the block fits in the cell x, y, z: no solid block in the
  # player or a mob, and nothing but grass, water or lava to replace. The
  # view ray can pass a flower, so a block only replaces grass. It passes
  # water and lava, and a block replaces them, as in Minecraft.
  def placeable?(block, x, y, z)
    return false if Block.solid?(block) && @player.overlaps?(x, y, z)
    return false unless @world.can_hold?(block, x, y, z)

    current = @world.get(x, y, z)
    return false if Block.plant?(block) && (Block.water?(current) || Block.lava?(current))
    return false if Block.solid?(block) && mob_in?(x, y, z, Block.door?(block) ? 2 : 1)

    Block.replaceable?(current)
  end

  # Places the second block of a door or a bed. False when it does not fit.
  def place_other_half(block, x, y, z)
    return place_door_top(block, x, y, z) if Block.door?(block)
    return place_bed_foot(block, x, y, z) if Block.bed?(block)

    true
  end

  def place_door_top(block, x, y, z)
    return false unless @world.door_fits?(x, y, z)
    return false if @player.overlaps?(x, y + 1, z)

    set_block(x, y + 1, z, Block.door_id(Block::FACING[block], true, false))
    true
  end

  def place_bed_foot(block, x, y, z)
    direction = Block::FACING[block] ^ 1
    foot_x = x + Block::DIR_DX[direction]
    foot_z = z + Block::DIR_DZ[direction]
    return false unless bed_fits?(x, y, z, foot_x, foot_z)

    set_block(foot_x, y, foot_z, Block.bed_id(direction, true))
    true
  end

  # A chest block placed at x, y, z next to a chest of one block that faces the
  # same way joins it into a large chest. A chest on its left joins first.
  # It gives the block for x, y, z. minecraft.wiki/w/Chest
  def join_chest(x, y, z, block)
    d = Block::FACING[block]
    left = Block::CHEST_LEFT_DIR[d]
    if @world.get(x + Block::DIR_DX[left], y, z + Block::DIR_DZ[left]) == block
      set_block(x + Block::DIR_DX[left], y, z + Block::DIR_DZ[left], Block::CHEST_LEFT + d)
      return Block::CHEST_RIGHT + d
    end
    if @world.get(x - Block::DIR_DX[left], y, z - Block::DIR_DZ[left]) == block
      set_block(x - Block::DIR_DX[left], y, z - Block::DIR_DZ[left], Block::CHEST_RIGHT + d)
      return Block::CHEST_LEFT + d
    end
    block
  end
end
