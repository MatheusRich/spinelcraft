# Boats (game/boat.rb): the player puts one on water, gets in, paddles,
# gets out, and breaks it.
class Game
  MAX_BOATS = 64

  def riding? = @riding >= 0

  # A boat item on a water source in view puts a boat there that faces the
  # way the player looks.
  def place_boat
    b = current_block.to_i
    return if @survival && @inv.empty?(@slot)
    return unless fluid_in_view && @world.get(@fluid_x, @fluid_y, @fluid_z) == Block::WATER
    return if @boats.size >= MAX_BOATS
    x = @fluid_x + 0.5
    y = @fluid_y + Block::WATER_LEVEL[Block::WATER] / 9.0 - Boat::DRAFT
    z = @fluid_z + 0.5
    return if @world.solid_in_box?(x, y, z, Boat::HALF, Boat::TALL)
    @boats << Boat.new(b, x, y, z, @player.yaw)
    @inv.take(@slot, 1) if @survival
    play_at(Sfx::SPLASH, x, y, z, 0.4, SOUND_RANGE)
    @swing = 0.25
  end

  def board_boat(i)
    @riding = i
    @player.flying = false
    seat_player(@boats[i])
    say("PRESS SHIFT TO DISMOUNT")
  end

  # The rider sits in the boat, and does not fall or swim.
  def seat_player(boat)
    p = @player
    p.x = boat.x
    p.y = boat.y + Boat::SEAT
    p.z = boat.z
    p.vx = 0.0
    p.vy = 0.0
    p.vz = 0.0
    p.fall_start = p.y
    p.on_ground = false
    p.in_water = false
  end

  # The player gets out on the side of the boat that they face, or else on
  # another side, on land when there is land. With no room on any side,
  # the player stands on the boat. minecraft.wiki/w/Boat
  def leave_boat
    boat = @boats[@riding]
    @riding = -1
    p = @player
    fx = Math.sin(p.yaw)
    fz = -Math.cos(p.yaw)
    out = Boat::HALF + Player::HALF + 0.1
    p.x = boat.x
    p.y = boat.y + Boat::TALL
    p.z = boat.z
    base = boat.y.floor
    found = false
    side = 0
    while side < 4 && !found
      # Ahead, to the right, to the left, then behind.
      dx = side == 0 ? fx : (side == 1 ? -fz : (side == 2 ? fz : -fx))
      dz = side == 0 ? fz : (side == 1 ? fx : (side == 2 ? -fx : -fz))
      # Right beside the boat, then half a block further.
      far = 0
      while far < 2 && !found
        x = boat.x + dx * (out + far * 0.6)
        z = boat.z + dz * (out + far * 0.6)
        # A bank one block above the boat's cell first, then the cell of
        # the boat, then two blocks up.
        up = 0
        while up < 3 && !found
          y = base + (up == 0 ? 1 : (up == 1 ? 0 : 2))
          found = dry_stand?(x, y, z)
          if found
            p.x = x
            p.y = y.to_f
            p.z = z
          end
          up += 1
        end
        far += 1
      end
      side += 1
    end
    p.fall_start = p.y
  end

  # True when the player fits at x, y, z, out of the water, and stands on
  # a solid block.
  def dry_stand?(x, y, z)
    !@world.solid_in_box?(x, y.to_f, z, Player::HALF, Player::TALL) && @world.solid_in_box?(x, y - 0.1, z, Player::HALF, 0.05) &&
      !Block.water?(@world.get(x.floor, y, z.floor))
  end

  # Moves each boat in a loaded chunk. The boat that the player rides takes
  # the movement keys, turns the player with it, and carries the player.
  def update_boats(dt, fwd, turn)
    @boats.each_with_index do |boat, i|
      next unless @world.loaded?(boat.x.floor, boat.z.floor)
      ridden = i == @riding
      yaw = boat.yaw
      strokes = boat.strokes
      boat.move_boat(@world, dt, ridden ? fwd : 0.0, ridden ? turn : 0.0)
      next unless ridden
      @player.yaw += boat.yaw - yaw
      seat_player(boat)
      play(boat.afloat ? Sfx::STEP_WATER : Sfx::STEP_WOOD, 0.3) if boat.strokes != strokes
    end
  end

  # The boat in the crosshair, nearer than the block in view and within
  # the reach for mobs, in @target_boat (or -1), and its distance.
  def find_target_boat
    @target_boat = -1
    best = @player.hit && @player.hit_t < Player::MOB_REACH ? @player.hit_t : Player::MOB_REACH
    i = 0
    while i < @boats.size
      if i != @riding
        t = @boats[i].ray(@player.x.to_f, @player.eye_y.to_f, @player.z.to_f, @player.fx, @player.fy, @player.fz)
        if t >= 0.0 && t < best
          best = t
          @target_boat = i
        end
      end
      i += 1
    end
    @target_boat_t = best
  end

  # A hit on boat i, with the damage of a hit on a mob. In creative one hit
  # breaks it and it drops nothing; in survival it drops its boat item.
  # minecraft.wiki/w/Boat
  def hit_boat(i)
    boat = @boats[i]
    charge = attack_charge
    damage = Block.damage(current_block.to_i) * (0.2 + 0.8 * charge * charge)
    @attack_time = 0.0
    @swing = 0.25
    if @survival && !boat.hit(damage)
      play_at(Sfx::DIG_WOOD, boat.x, boat.y, boat.z, 0.6, SOUND_RANGE)
      return
    end
    leave_boat if @riding == i
    @riding -= 1 if @riding > i
    @particles.burst(boat.x.floor, boat.y.floor, boat.z.floor, Block::PLANKS[boat.item - Block::OAK_BOAT])
    play_at(Sfx::BREAK, boat.x, boat.y, boat.z, 0.7, SOUND_RANGE)
    # Spinel reads @boats as untyped, and to_i and to_f keep drop_item typed.
    drop_item(boat.item.to_i, 1, boat.x.to_f, boat.y.to_f + 0.3, boat.z.to_f, 0.0, 2.0, 0.0, PICKUP_WAIT) if @survival
    @boats.delete_at(i)
    @target_boat = -1
  end
end
