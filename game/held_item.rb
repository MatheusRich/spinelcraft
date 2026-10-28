# The held item in first person: a 3D model at the lower right of the view.
# It swings when the player uses it, drops and rises when the selection
# changes, and sways while the player walks. An empty hand shows the arm.
# HeldItem owns the block in the hand, the drop after a change and the
# sway. Game owns the timers of the swing, the draw and the meal, and gives
# them to place.
class HeldItem
  attr_reader :block, :sway_x, :sway_y

  def initialize
    # The block in the hand model.
    @block = 0
    # How far down the model still is after the selection changed (1 to 0).
    @equip = 0.0
    # The sway while the player walks: its strength (0 to 1), and the move
    # of the model to the right and up.
    @walk = 0.0
    @sway_x = 0.0
    @sway_y = 0.0
    # The axes and the move of the model (see turn_x).
    @frame = Array.new(12, 0.0)
    # The place (right, up, back) and the turn of the model in view space,
    # and its move from the arm (see Game#draw_hand).
    @ox = 0.0
    @oy = 0.0
    @oz = 0.0
    @yaw = 0.0
    @pitch = 0.0
    @roll = 0.0
    @size = 0.0
    @dx = 0.0
    @dy = 0.0
    @dz = 0.0
    nil
  end

  # Puts block in the hand. It is true when the block is a new one, and the
  # model starts below the view.
  def change(block)
    return false if block == @block

    @block = block
    @equip = 1.0
    true
  end

  # dt more seconds. walk is the share of the walk speed (0 to 1), and bob
  # is the turn of the step cycle. The sway follows the walk speed over
  # about a fifth of a second, so it fades in and out when the player
  # starts, stops, jumps or lands.
  def ease(dt, walk, bob)
    @equip = (@equip - dt * 5.0).clamp(0.0, 1.0)
    @walk += (walk - @walk) * (dt * 6.0).clamp(0.0, 1.0)
    # A turn of bob is one step: the item dips once in each step, and it
    # goes to one side in one step and back in the next.
    @sway_x = Math.sin(bob * 0.5) * 0.025 * @walk
    @sway_y = -(1.0 - Math.cos(bob)) * 0.5 * 0.02 * @walk
    nil
  end

  # Adds the held model to dyn, in the frame of the eye at ex, ey, ez.
  # swing_left is the part of the swing that is left (0 for none), fov the
  # half angle of the view, and draw_time and eat_time the seconds of the
  # draw and of the meal (-1 for none).
  def place(dyn, player, ex, ey, ez, fov, swing_left, draw_time, eat_time)
    pose(draw_time, eat_time)
    orient(swing_left)
    put_frame(dyn, player, ex, ey, ez, fov)
    add_model(dyn, draw_time)
  end

  # The place of the model in the view. Items and blocks copy Minecraft:
  # ItemInHandRenderer puts the arm at (0.56, -0.52, -0.72), and the
  # firstperson_righthand display of the models item/generated and
  # block/block moves, turns and scales the model.
  def pose(draw_time, eat_time)
    @dx = 0.0
    @dy = 0.0
    @dz = 0.0
    if @block == Block::AIR
      pose_arm
    elsif Block.flat?(@block)
      pose_sprite
    else
      pose_cube
    end
    pull_bow(draw_time) if draw_time >= 0.0
    lift_food(eat_time) if eat_time >= 0.0
    @oy -= @equip * 0.45
    @ox += @sway_x
    @oy += @sway_y
    nil
  end

  def pose_arm
    @ox = 0.6
    @oy = -0.62
    @oz = -0.55
    @yaw = 0.2
    @pitch = 0.7
    @roll = 0.0
    @size = 0.16
  end

  # item/generated: translation (1.13, 3.2, 1.13) / 16, rotation (0, -90, 25)
  # and scale 0.68. The texture of the sprite goes along -x, not +x as in
  # Minecraft, so the roll has the other sign. The item is 0.08 higher than
  # in Minecraft, so the guard of a sword shows.
  def pose_sprite
    @ox = 0.56
    @oy = -0.52
    @oz = -0.72
    @dx = 1.13 / 16.0
    @dy = 3.2 / 16.0 + 0.08
    @dz = 1.13 / 16.0
    @yaw = -Math::PI / 2.0
    @pitch = 0.0
    @roll = -25.0 * Math::PI / 180.0
    @size = 0.68
  end

  # block/block: rotation (0, 45, 0) and scale 0.4.
  def pose_cube
    @ox = 0.56
    @oy = -0.52
    @oz = -0.72
    @yaw = Math::PI / 4.0
    @pitch = 0.0
    @roll = 0.0
    @size = 0.4
  end

  def pull_bow(draw_time)
    pull = draw_time > 1.0 ? 1.0 : draw_time
    @ox -= pull * 0.15
    @oz += pull * 0.12
  end

  # The food moves to the mouth in a few frames, and it bobs once with each
  # bite. As in Minecraft (ItemInHandRenderer.applyEatTransform, not on the
  # wiki).
  def lift_food(eat_time)
    lift = 1.0 - (1.0 - eat_time / Game::EAT_TIME)**27
    @ox -= lift * 0.36
    @oy += lift * 0.12
    @oz += lift * 0.1
    @yaw += lift * 0.8
    @roll += lift * 0.3
    @oy += (Math.cos(eat_time / Game::CHEW_EVERY * Math::PI) * 0.04).abs if eat_time >= Game::CHEW_START
  end

  # Fills @frame: the turn (roll around back, then yaw around up, then
  # pitch around right), the mirror of a tool, the swing, and the move.
  def orient(swing_left)
    12.times { |index| @frame[index] = index % 4 == 0 ? 1.0 : 0.0 }
    turn_z(@roll)
    turn_y(@yaw)
    turn_x(@pitch)
    # The view sees the back of the sprite, so a blade or a bow string above
    # the handle faces the player. A tool mirrors across its handle, so that
    # part faces forward.
    # The arm of the skin is long in y, with the hand at -y and the front at
    # +z. Its y goes back along the view, and its front faces down.
    swap_axes(3, 6) if @block == Block::AIR
    mirror_tool if Block.tool?(@block)
    @frame[9] = @dx
    @frame[10] = @dy
    @frame[11] = @dz
    swing(swing_left)
    @ox += @frame[9]
    @oy += @frame[10]
    @oz += @frame[11]
    nil
  end

  def swap_axes(first, second)
    3.times do |part|
      saved = @frame[first + part]
      @frame[first + part] = @frame[second + part]
      @frame[second + part] = -saved
    end
  end

  def mirror_tool
    3.times do |part|
      saved = @frame[part]
      @frame[part] = -@frame[3 + part]
      @frame[3 + part] = -saved
    end
  end

  # Moves the model by the swing. The swing copies the game code
  # (ItemInHandRenderer.renderArmWithItem and renderPlayerArm), not the
  # wiki. The model turns around the arm, in a frame that is 45 degrees to
  # the left: an item tips forward, and the empty hand turns to the left.
  # Then the arm goes left, up and forward.
  def swing(swing_left)
    return if swing_left <= 0.0

    progress = 1.0 - swing_left
    fast = Math.sin(Math.sqrt(progress) * Math::PI)
    slow = Math.sin(progress * progress * Math::PI)
    bob = Math.sin(Math.sqrt(progress) * Math::PI * 2.0)
    push = Math.sin(progress * Math::PI)
    quarter = Math::PI / 4.0
    degree = Math::PI / 180.0
    turn_y(-quarter)
    if @block == Block::AIR
      turn_z(slow * -20.0 * degree)
      turn_y(quarter + fast * 70.0 * degree)
      @frame[9] -= fast * 0.3
      @frame[10] += bob * 0.4
      @frame[11] -= push * 0.4
    else
      turn_x(fast * -80.0 * degree)
      turn_z(fast * -20.0 * degree)
      turn_y(quarter + slow * -20.0 * degree)
      @frame[9] -= fast * 0.4
      @frame[10] += bob * 0.2
      @frame[11] -= push * 0.2
    end
    nil
  end

  # Turns @frame (the 3 axes of the model, then its move from the arm) by
  # angle around the x, y or z axis of the view.
  def turn_x(angle)
    cosine = Math.cos(angle)
    sine = Math.sin(angle)
    4.times do |vector|
      y = @frame[vector * 3 + 1]
      z = @frame[vector * 3 + 2]
      @frame[vector * 3 + 1] = cosine * y - sine * z
      @frame[vector * 3 + 2] = sine * y + cosine * z
    end
    nil
  end

  def turn_y(angle)
    cosine = Math.cos(angle)
    sine = Math.sin(angle)
    4.times do |vector|
      x = @frame[vector * 3]
      z = @frame[vector * 3 + 2]
      @frame[vector * 3] = cosine * x + sine * z
      @frame[vector * 3 + 2] = cosine * z - sine * x
    end
    nil
  end

  def turn_z(angle)
    cosine = Math.cos(angle)
    sine = Math.sin(angle)
    4.times do |vector|
      x = @frame[vector * 3]
      y = @frame[vector * 3 + 1]
      @frame[vector * 3] = cosine * x - sine * y
      @frame[vector * 3 + 1] = sine * x + cosine * y
    end
    nil
  end

  # Sets the frame of dyn: the model in the view space of the eye, with the
  # right r, the up u and the back -f of the player. Minecraft draws the
  # hand with a fixed view of 70 degrees, so the model keeps its size when
  # the view gets wider in a sprint. The world view has the half angle fov,
  # so the model scales across the view by tan(fov) / tan(35 degrees).
  def put_frame(dyn, player, ex, ey, ez, fov)
    fx = player.fx
    fy = player.fy
    fz = player.fz
    scale = Math.tan(fov) / Math.tan(35.0 * Math::PI / 180.0)
    rx = Math.cos(player.yaw) * scale
    rz = Math.sin(player.yaw) * scale
    # Up is right x forward.
    ux = -rz * fy
    uy = rz * fx - rx * fz
    uz = rx * fy
    a_right = @frame[0]
    a_up = @frame[1]
    a_back = @frame[2]
    b_right = @frame[3]
    b_up = @frame[4]
    b_back = @frame[5]
    c_right = @frame[6]
    c_up = @frame[7]
    c_back = @frame[8]
    dyn.set_frame(ex + @ox * rx + @oy * ux - @oz * fx, ey + @oy * uy - @oz * fy, ez + @ox * rz + @oy * uz - @oz * fz,
                  (a_right * rx + a_up * ux - a_back * fx) * @size, (a_up * uy - a_back * fy) * @size, (a_right * rz + a_up * uz - a_back * fz) * @size,
                  (b_right * rx + b_up * ux - b_back * fx) * @size, (b_up * uy - b_back * fy) * @size, (b_right * rz + b_up * uz - b_back * fz) * @size,
                  (c_right * rx + c_up * ux - c_back * fx) * @size, (c_up * uy - c_back * fy) * @size, (c_right * rz + c_up * uz - c_back * fz) * @size)
  end

  def add_model(dyn, draw_time)
    if @block == Block::AIR
      # The right arm of the skin of the player, 4 x 12 x 4 pixels, reaches
      # forward from below the view.
      dyn.frame_skin_box(-0.5, -2.5, -0.5, 0.5, 0.5, 0.5, Tex::SKINS + Tex::SKIN_PLAYER, 40.0, 16.0, 4.0, 12.0, 4.0, false, Color::SOLID_WHITE)
    elsif @block == Block::BOW && draw_time >= 0.0
      dyn.sprite_model(Tex::BOW_PULLING + bow_stage(draw_time))
    else
      dyn.item_model(@block)
    end
  end

  # The image of the bow that the draw time shows: 0, then 1 at 0.65 seconds
  # and 2 at 0.9 seconds. As in Minecraft (the bow model, minecraft.wiki/w/Bow
  # does not give the times).
  def bow_stage(draw_time)
    return 2 if draw_time >= 0.9
    return 1 if draw_time >= 0.65

    0
  end
end
