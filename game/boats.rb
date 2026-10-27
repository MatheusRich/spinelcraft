# Boats (game/boat.rb): the player puts one on water, gets in, paddles,
# gets out, and breaks it.
#
# Spinel reads the elements of @boats as untyped, as it does for @mobs and
# @items. So each method reads the fields of a boat once, through to_f or
# to_i, and works on typed locals.
class Game
  MAX_BOATS = 64

  def riding? = @riding >= 0

  # A boat item on a water source in view puts a boat there that faces the
  # way the player looks.
  def place_boat
    block = current_block.to_i
    return if @survival && @inv.empty?(@slot)
    return unless fluid_in_view && @world.get(@fluid_x, @fluid_y, @fluid_z) == Block::WATER
    return if @boats.size >= MAX_BOATS

    x = @fluid_x.to_i + 0.5
    y = @fluid_y.to_i + Block::WATER_LEVEL[Block::WATER] / 9.0 - Boat::DRAFT
    z = @fluid_z.to_i + 0.5
    return if @world.solid_in_box?(x, y, z, Boat::HALF, Boat::TALL)

    @boats << Boat.new(block, x, y, z, @player.yaw)
    @inv.take(@slot, 1) if @survival
    @sfx.play_at(Sfx::SPLASH, x, y, z, 0.4)
    @swing = SWING
  end

  def board_boat(i)
    @riding = i
    @player.flying = false
    boat = @boats[i]
    @player.seat_in(boat)
    say("PRESS SHIFT TO DISMOUNT")
  end

  # The player gets out on the side of the boat that they face, or else on
  # another side (Player#leave).
  def leave_boat
    @player.leave(@boats[@riding], @world)
    @riding = -1
  end

  # Moves each boat in a loaded chunk. The boat that the player rides takes
  # the movement keys, turns the player with it, and carries the player.
  def update_boats(dt)
    fwd = @player.controls.forward
    turn = @player.controls.strafe
    @boats.size.times do |i|
      boat = @boats[i]
      if @world.loaded?(boat.x.to_f.floor, boat.z.to_f.floor)
        ridden = i == @riding
        yaw = boat.yaw.to_f
        strokes = boat.strokes.to_i
        boat.move_boat(@world, dt, ridden ? fwd : 0.0, ridden ? turn : 0.0)
        if ridden
          @player.yaw += boat.yaw.to_f - yaw
          @player.seat_in(boat)
          @sfx.play(boat.afloat ? Sfx::STEP_WATER : Sfx::STEP_WOOD, 0.3) if boat.strokes.to_i != strokes
        end
      end
    end
  end

  # Sets @target_boat to the nearest boat that is closer than best, or to -1.
  # Returns the distance of that boat, or best when there is none.
  def scan_boats(best)
    @target_boat = -1
    @boats.each_with_index do |boat, index|
      next if index == @riding

      distance = boat.hit_distance(@target_block)
      next unless distance >= 0.0 && distance < best

      best = distance
      @target_boat = index
    end
    best
  end

  # A hit on boat i, with the damage of a hit on a mob. In creative one hit
  # breaks it and it drops nothing; in survival it drops its boat item.
  # minecraft.wiki/w/Boat
  def hit_boat(i)
    boat = @boats[i]
    item = boat.item.to_i
    x = boat.x.to_f
    y = boat.y.to_f
    z = boat.z.to_f
    damage = @player.melee_attack.scaled_damage(current_block.to_i)
    @player.melee_attack.restart
    @swing = SWING
    if @survival && !boat.hit(damage)
      @sfx.play_at(Sfx::DIG_WOOD, x, y, z, 0.6)
      return
    end
    leave_boat if @riding == i
    @riding -= 1 if @riding > i
    @particles.burst(x.floor, y.floor, z.floor, Block::PLANKS[item - Block::OAK_BOAT])
    @sfx.play_at(Sfx::BREAK, x, y, z, 0.7)
    drop_item(item, 1, x, y + 0.3, z, 0.0, 2.0, 0.0, PICKUP_WAIT) if @survival
    @boats.delete_at(i)
    @target_boat = -1
  end
end
