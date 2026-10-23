# DEMO=1 plays a reel of short scenes that show the game, for a video of
# about a minute (tools/demo.sh records it). The first frame of each scene
# builds its place. Each frame after that moves the player and acts through
# the normal actions. The game quits after the last scene.
#
# To change a scene:
# - The places come from the terrain of seed 1337. A new place needs a
#   look at that world.
# - Two runs are not the same: chunks stream in on a time budget, and the
#   mobs share the random numbers of the game. So keep a margin, as the
#   skeleton that comes late in the night does.
# - To see a take without a player, record it and make a contact sheet,
#   one frame each second:
#   ffmpeg -i demo.mp4 -vf "fps=1,scale=320:-2,tile=6x11" -frames:v 1 sheet.png
# - The self-test plays the whole reel (Game#test_demo_reel) and checks
#   what the video shows. Change those checks with the scenes.
class Game
  # The length of each scene in seconds, in the order of Game#play_scene.
  SCENE_SECONDS = [8.0, 9.0, 13.0, 14.0, 10.0, 7.0]
  # The place of the mine, under the spawn of seed 1337.
  MINE_X = 6
  MINE_Y = 40
  MINE_Z = -6
  # The blocks that the miner breaks, one after the other: x, y and z from
  # the mine.
  MINE_ORDER = [-1, 1, -2, 2, 1, -2, 0, 1, -2, 0, 0, -2, 0, 1, -3, 0, 0, -3]
  # The sheep to shear comes in here, out of view behind the player, when
  # the player turns to it, so that it has no time to walk away.
  SHEEP_X = 4.0
  SHEEP_Z = 3.5
  # The house goes on the flattest dry ground this far from the spawn.
  HOUSE_RANGE = 40

  # Plays the scene at this moment of the reel, dt seconds after the last frame.
  def demo(dt)
    @demo_time += dt
    start = 0.0
    scene = 0
    while scene < SCENE_SECONDS.size && @demo_time >= start + SCENE_SECONDS[scene]
      start += SCENE_SECONDS[scene]
      scene += 1
    end
    if scene >= SCENE_SECONDS.size
      @quit = true
      return
    end
    if scene != @demo_scene
      @demo_scene = scene
      stage_scene
    end
    @action_cooldown -= dt
    play_scene(@demo_time - start, dt)
  end

  # Sets up the place of the scene that starts.
  def stage_scene
    @mining = false
    @demo_left = false
    # Only the mobs of the scene, so that no other mob walks into the view.
    @mobs.clear
    demo_walk(0)
    case @demo_scene
    when 0 then stage_flight
    when 1 then stage_mine
    when 2 then stage_animals
    when 3 then stage_house
    when 4 then stage_night
    else @survival = false
    end
    nil
  end

  # Plays the scene at seconds at into it.
  def play_scene(at, dt)
    case @demo_scene
    when 0 then play_flight(at)
    when 1 then play_mine(at, dt)
    when 2 then play_animals(at, dt)
    when 3 then play_house(at)
    when 4 then play_night(at, dt)
    else play_ending(at)
    end
    nil
  end

  # A flight over the plains to the river, late in the afternoon.
  def stage_flight
    @survival = false
    @clock.time_of_day = 0.42
  end

  def play_flight(at)
    part = demo_ease(at / SCENE_SECONDS[0])
    fly_camera(-110.0 + 90.0 * part, 106.0 - 14.0 * part, 70.0 - 60.0 * part)
    @player.yaw = 0.9 + 0.5 * part
    @player.pitch = -0.3 - 0.1 * part
  end

  # A small mine under the plains: a room of stone, lit by torches, with
  # coal on the left and iron and a diamond behind the stone ahead.
  def stage_mine
    fill_box(MINE_X - 4, MINE_Y - 1, MINE_Z - 6, MINE_X + 4, MINE_Y + 4, MINE_Z + 4, Block::STONE)
    fill_box(MINE_X - 2, MINE_Y, MINE_Z - 1, MINE_X + 2, MINE_Y + 2, MINE_Z + 3, Block::AIR)
    set_block(MINE_X - 1, MINE_Y + 1, MINE_Z - 2, Block::COAL_ORE)
    set_block(MINE_X - 2, MINE_Y + 2, MINE_Z - 1, Block::COAL_ORE)
    set_block(MINE_X, MINE_Y + 1, MINE_Z - 3, Block::IRON)
    set_block(MINE_X + 1, MINE_Y + 1, MINE_Z - 3, Block::IRON)
    set_block(MINE_X, MINE_Y, MINE_Z - 3, Block::DIAMOND)
    set_block(MINE_X + 2, MINE_Y + 1, MINE_Z - 2, Block::SPINEL_ORE)
    set_block(MINE_X - 2, MINE_Y + 2, MINE_Z + 1, Block.facing_id(Block::TORCH, 0))
    set_block(MINE_X + 2, MINE_Y + 2, MINE_Z + 1, Block.facing_id(Block::TORCH, 1))
    stand_at(MINE_X, MINE_Y, MINE_Z + 1)
    @player.yaw = 0.0
    @player.pitch = -0.2
    demo_survival(Block::IRON_PICK, Block.uses(Block::IRON_PICK))
  end

  def play_mine(at, dt)
    index = mine_target
    if at < 1.0 || index < 0
      demo_look_at(MINE_X + 0.5, MINE_Y + 1.0, MINE_Z - 2.0, 2.0, dt)
      demo_buttons(dt, left: false, right: false)
      return
    end
    x = MINE_X + MINE_ORDER[index]
    y = MINE_Y + MINE_ORDER[index + 1]
    z = MINE_Z + MINE_ORDER[index + 2]
    demo_look_at(x + 0.5, y + 0.5, z + 1.0, 8.0, dt)
    aimed = @target_block.hit? && @target_block.x == x && @target_block.y == y && @target_block.z == z
    demo_buttons(dt, left: aimed, right: false)
  end

  # The index in MINE_ORDER of the first block that is still there, or -1.
  def mine_target
    index = 0
    index += 3 while index < MINE_ORDER.size &&
                     @world.get(MINE_X + MINE_ORDER[index], MINE_Y + MINE_ORDER[index + 1], MINE_Z + MINE_ORDER[index + 2]) == Block::AIR
    index < MINE_ORDER.size ? index : -1
  end

  # Cows and sheep in the meadow. The player feeds two cows, which breed,
  # and shears a sheep.
  def stage_animals
    stand_at(0, @world.height_at(0, 0), 0)
    @player.yaw = 0.0
    @player.pitch = -0.2
    demo_survival(Block::WHEAT, 16)
    @inv.set(1, Block::SHEARS, Block.uses(Block::SHEARS))
    @demo_animals = [demo_animal(Mob::COW, -2.0, -4.5), demo_animal(Mob::COW, 2.0, -4.5),
                     demo_animal(Mob::SHEEP, -5.0, -7.0),
                     demo_animal(Mob::PIG, 1.0, -8.0), demo_animal(Mob::CHICKEN, -3.0, -6.0)]
  end

  # An animal of kind at dx, dz from the player, on the ground.
  def demo_animal(kind, dx, dz)
    x = @player.x.to_f + dx
    z = @player.z.to_f + dz
    animal = Animal.new(kind, x, @world.height_at(x.floor, z.floor).to_f, z, @mobs.size + 7)
    @mobs << animal
    animal
  end

  # The player holds the shears, so that the animals do not follow the
  # wheat, and takes the wheat only to feed. At the end the player walks to
  # a sheep, and the shears take its wool.
  def play_animals(at, dt)
    @slot = 1
    if at < 2.5
      demo_click(@demo_animals[0], 0, dt)
    elsif at < 4.5
      demo_click(@demo_animals[1], 0, dt)
    elsif at < 9.0
      # A step back, so that the cows and the calf fit in the view.
      demo_walk(at < 5.5 ? -1 : 0)
      demo_watch_calf(dt)
    else
      @demo_animals << demo_animal(Mob::SHEEP, SHEEP_X, SHEEP_Z) if @demo_animals.size < 6
      demo_click(@demo_animals.last, 1, dt)
    end
  end

  # Looks at the animal, and walks to it until it is in reach. Once the
  # crosshair is on it, takes the item in slot and clicks the animal with
  # the right button.
  def demo_click(animal, slot, dt)
    demo_look_at(animal.x.to_f, animal.y + animal.tall * 0.6, animal.z.to_f, 6.0, dt)
    demo_walk(demo_distance(animal) > Player::MOB_REACH ? 1 : 0)
    on_it = @target_mob >= 0 && @mobs[@target_mob] == animal
    @slot = slot if on_it
    demo_buttons(dt, left: false, right: on_it)
  end

  # Looks between the two cows, and then at the calf once it comes.
  def demo_watch_calf(dt)
    first = @demo_animals[0]
    second = @demo_animals[1]
    x = (first.x.to_f + second.x.to_f) * 0.5
    z = (first.z.to_f + second.z.to_f) * 0.5
    calf = @mobs.find { |mob| mob.baby? && !mob.dying? }
    if calf
      x = calf.x.to_f
      z = calf.z.to_f
    end
    demo_look_at(x, first.y + 0.5, z, 3.0, dt)
    demo_buttons(dt, left: false, right: false)
  end

  # A house of planks and logs goes up on a stone floor, one block after
  # the other, while the sun goes down.
  def stage_house
    @survival = false
    @demo_house = House.flattest(@world, HOUSE_RANGE)
    house = @demo_house
    fill_box(house.corner_x - 1, house.floor_y + 1, house.corner_z - 1, house.corner_x + House::SIZE, house.floor_y + 9, house.corner_z + House::SIZE, Block::AIR)
    @demo_build = house.blocks
    @demo_built = 0
  end

  def play_house(at)
    part = demo_ease(at / SCENE_SECONDS[3])
    @clock.time_of_day = 0.4 + 0.07 * part
    built = (@demo_build.size / 4 * ((at - 0.5) / 10.0).clamp(0.0, 1.0)).to_i
    while @demo_built < built
      index = @demo_built * 4
      block = @demo_build[index + 3]
      set_block(@demo_build[index], @demo_build[index + 1], @demo_build[index + 2], block)
      # A place sound for each third block, so that the sounds do not run
      # into one noise.
      @sfx.play(MATERIAL_PLACE[material(block)], 0.4) if @demo_built % 3 == 0
      @demo_built += 1
    end
    house = @demo_house
    # The camera turns around the house from its side to its front (+z).
    turn = Math::PI - 1.4 + 1.4 * part
    fly_camera(house.middle_x + Math.sin(turn) * 12.0, house.floor_y + 7.0 - 3.0 * part, house.middle_z - Math.cos(turn) * 12.0)
    demo_face(house.middle_x, house.floor_y + 3.0, house.middle_z)
  end

  # Night in front of the house: a zombie and a creeper come from the
  # house, and the player fights them with a sword. A skeleton comes later,
  # so that its arrows do not take all the health of the player.
  def stage_night
    x = @demo_house.corner_x + 3
    z = @demo_house.corner_z + 16
    stand_at(x, @world.height_at(x, z), z)
    @player.yaw = 0.0
    @player.pitch = 0.0
    demo_survival(Block::IRON_SWORD, Block.uses(Block::IRON_SWORD))
    @clock.time_of_day = 0.62
    @demo_monsters = [demo_monster(Mob::ZOMBIE, -3.0, -8.0), demo_monster(Mob::CREEPER, 5.0, -14.0)]
  end

  # A monster of kind at dx, dz from the player, on the ground.
  def demo_monster(kind, dx, dz)
    x = @player.x.to_f + dx
    z = @player.z.to_f + dz
    monster = Monster.new(kind, x, @world.height_at(x.floor, z.floor).to_f, z, @mobs.size + 11)
    @mobs << monster
    monster
  end

  # Looks at the nearest monster that still lives, and hits it once the
  # sword has its full charge. The player steps back from a creeper that
  # hisses, so that the blast does not kill.
  def play_night(at, dt)
    @demo_monsters << demo_monster(Mob::SKELETON, 10.0, -12.0) if at >= 6.0 && @demo_monsters.size < 3
    foe = nil
    best = 1.0e9
    @demo_monsters.each do |monster|
      next if monster.dying? || !monster.alive

      distance = demo_distance(monster)
      next if distance >= best

      best = distance
      foe = monster
    end
    demo_walk(0)
    return demo_buttons(dt, left: false, right: false) unless foe

    demo_walk(-1) if foe.kind == Mob::CREEPER && foe.fuse > 0.0 && best < 5.5
    demo_look_at(foe.x.to_f, foe.y + foe.tall * 0.7, foe.z.to_f, 8.0, dt)
    hit = @target_mob >= 0 && @mobs[@target_mob] == foe && attack_charge >= 1.0 && !@demo_left
    demo_buttons(dt, left: hit, right: false)
  end

  # Sunrise: the camera rises from the door of the house into the sky.
  def play_ending(at)
    part = demo_ease(at / SCENE_SECONDS[5])
    @clock.time_of_day = (0.97 + 0.06 * part) % 1.0
    house = @demo_house
    fly_camera(house.middle_x, house.floor_y + 3.0 + 30.0 * part, house.middle_z + 10.5 + 20.0 * part)
    demo_face(house.middle_x, house.floor_y + 2.0, house.middle_z)
  end

  # Survival with full health and an empty inventory, and count of block in
  # the hand. The day starts again.
  def demo_survival(block, count)
    @survival = true
    @vitals = Vitals.new
    @inv.clear
    @inv.set(0, block, count)
    @slot = 0
    @clock.time_of_day = 0.3
  end

  # The distance from the player to the mob along x and z.
  def demo_distance(mob)
    dx = mob.x.to_f - @player.x
    dz = mob.z.to_f - @player.z
    Math.sqrt(dx * dx + dz * dz)
  end

  # Walks ahead (1), back (-1) or not at all (0), through the keys W and S.
  def demo_walk(ahead)
    Gfx.in_test_key(Key::W, ahead > 0 ? 1 : 0)
    Gfx.in_test_key(Key::S, ahead < 0 ? 1 : 0)
  end

  # Puts the camera at x, y, z, flying and at rest.
  def fly_camera(x, y, z)
    @player.x = x.to_f
    @player.y = y.to_f
    @player.z = z.to_f
    @player.vx = 0.0
    @player.vy = 0.0
    @player.vz = 0.0
    @player.flying = true
  end

  # Turns the view to the point x, y, z.
  def demo_face(x, y, z)
    dx = x - @player.x
    dy = y - @player.eye_y
    dz = z - @player.z
    @player.yaw = Math.atan2(dx, -dz).to_f
    @player.pitch = Math.atan2(dy, Math.sqrt(dx * dx + dz * dz)).to_f
  end

  # Turns the view part of the way to the point x, y, z, faster at a
  # higher rate, so that the view follows a target smoothly.
  def demo_look_at(x, y, z, rate, dt)
    yaw = @player.yaw
    pitch = @player.pitch
    demo_face(x, y, z)
    part = 1.0 - Math.exp(-rate * dt)
    turn = (@player.yaw - yaw + Math::PI) % (Math::PI * 2.0) - Math::PI
    @player.yaw = (yaw + turn * part).to_f
    @player.pitch = (pitch + (@player.pitch - pitch) * part).to_f
  end

  # The buttons of the mouse this frame, through the normal actions.
  def demo_buttons(dt, left:, right:)
    left_button(dt, left, left && !@demo_left)
    right_button(dt, right)
    @demo_left = left
    nil
  end

  # 0 at part 0, 1 at part 1, slow at both ends.
  def demo_ease(part)
    part = part.clamp(0.0, 1.0)
    part * part * (3.0 - 2.0 * part)
  end
end
