# The held item in first person: a 3D model at the lower right of the view.
# It swings when the player uses it, drops and rises when the selection
# changes, and sways while the player walks. An empty hand shows the arm.
class Game
  # Seconds that one swing takes (see @swing): 6 ticks, as in the game code
  # (LivingEntity.getCurrentSwingDuration). The wiki does not say.
  SWING = 0.3

  def update_hand(dt)
    block = current_block.to_i
    if block != @hand_block
      @hand_block = block
      @equip = 1.0
      @attack_time = 0.0
      @eat_time = -1.0
    end
    @equip -= dt * 5.0 if @equip > 0.0
    # The sway follows the walk speed over about a fifth of a second, so it
    # fades in and out when the player starts, stops, jumps or lands.
    p = @player
    walk = p.on_ground && !p.flying ? (Math.sqrt(p.vx * p.vx + p.vz * p.vz) / 4.3).clamp(0.0, 1.0) : 0.0
    @hand_walk += (walk - @hand_walk) * (dt * 6.0).clamp(0.0, 1.0)
    # A turn of @bob is one step: the item dips once in each step, and it
    # goes to one side in one step and back in the next.
    @hand_dx = Math.sin(@bob * 0.5) * 0.025 * @hand_walk
    @hand_dy = -(1.0 - Math.cos(@bob)) * 0.5 * 0.02 * @hand_walk
  end

  # Adds the held model to @dyn, in the frame of the eye at ex, ey, ez.
  def draw_hand(ex, ey, ez) # rubocop:todo Metrics/MethodLength
    return if !@captured || @vitals.dead?

    block = @hand_block
    p = @player
    fx = p.fx
    fy = p.fy
    fz = p.fz
    rx = Math.cos(p.yaw)
    rz = Math.sin(p.yaw)
    # Up is right x forward; back is -forward.
    ux = -rz * fy
    uy = rz * fx - rx * fz
    uz = rx * fy
    flat = block != Block::AIR && Block.flat?(block)
    # The move of the model from the arm, which turns with the swing.
    dx = 0.0
    dy = 0.0
    dz = 0.0
    # The place (right, up, back) and the turn of the model in view space.
    # Items and blocks copy Minecraft: ItemInHandRenderer puts the arm at
    # (0.56, -0.52, -0.72), and the firstperson_righthand display of the
    # models item/generated and block/block moves, turns and scales the model.
    if block == Block::AIR
      ox = 0.6
      oy = -0.62
      oz = -0.55
      yaw = 0.2
      pitch = 0.7
      roll = 0.0
      size = 0.16
    elsif flat
      # item/generated: translation (1.13, 3.2, 1.13) / 16, rotation
      # (0, -90, 25) and scale 0.68. The texture of the sprite goes along -x,
      # not +x as in Minecraft, so the roll has the other sign. The item is
      # 0.08 higher than in Minecraft, so the guard of a sword shows.
      ox = 0.56
      oy = -0.52
      oz = -0.72
      dx = 1.13 / 16.0
      dy = 3.2 / 16.0 + 0.08
      dz = 1.13 / 16.0
      yaw = -Math::PI / 2.0
      pitch = 0.0
      roll = -25.0 * Math::PI / 180.0
      size = 0.68
    else
      # block/block: rotation (0, 45, 0) and scale 0.4.
      ox = 0.56
      oy = -0.52
      oz = -0.72
      yaw = Math::PI / 4.0
      pitch = 0.0
      roll = 0.0
      size = 0.4
    end
    if @draw_time >= 0.0
      pull = @draw_time > 1.0 ? 1.0 : @draw_time
      ox -= pull * 0.15
      oz += pull * 0.12
    end
    if @eat_time >= 0.0
      # The food moves to the mouth in a few frames, and it bobs once with
      # each bite. As in Minecraft (ItemInHandRenderer.applyEatTransform,
      # not on the wiki).
      lift = 1.0 - (1.0 - @eat_time / EAT_TIME) ** 27
      ox -= lift * 0.36
      oy += lift * 0.12
      oz += lift * 0.1
      yaw += lift * 0.8
      roll += lift * 0.3
      oy += (Math.cos(@eat_time / CHEW_EVERY * Math::PI) * 0.04).abs if @eat_time >= CHEW_START
    end
    oy -= @equip * 0.45
    ox += @hand_dx
    oy += @hand_dy
    # The turn: roll around back, then yaw around up, then pitch around right.
    frame = @hand_frame
    12.times { |i| frame[i] = i % 4 == 0 ? 1.0 : 0.0 }
    turn_hand(2, roll)
    turn_hand(1, yaw)
    turn_hand(0, pitch)
    # The view sees the back of the sprite, so a blade or a bow string above
    # the handle faces the player. A tool mirrors across its handle, so that
    # part faces forward.
    # The arm of the skin is long in y, with the hand at -y and the front at
    # +z. Its y goes back along the view, and its front faces down.
    if block == Block::AIR
      3.times do |i|
        t = frame[3 + i]
        frame[3 + i] = frame[6 + i]
        frame[6 + i] = -t
      end
    end
    if Block.tool?(block)
      3.times do |i|
        t = frame[i]
        frame[i] = -frame[3 + i]
        frame[3 + i] = -t
      end
    end
    frame[9] = dx
    frame[10] = dy
    frame[11] = dz
    swing_hand
    ox += frame[9]
    oy += frame[10]
    oz += frame[11]
    m00 = frame[0]
    m10 = frame[1]
    m20 = frame[2]
    m01 = frame[3]
    m11 = frame[4]
    m21 = frame[5]
    m02 = frame[6]
    m12 = frame[7]
    m22 = frame[8]
    # Minecraft draws the hand with a fixed view of 70 degrees, so the model
    # keeps its size when the view gets wider in a sprint. The world view has
    # the half angle @fov, so the model scales across the view by
    # tan(@fov) / tan(35 degrees).
    k = Math.tan(@fov) / Math.tan(35.0 * Math::PI / 180.0)
    rx *= k
    rz *= k
    ux *= k
    uy *= k
    uz *= k
    # View space to the world: right r, up u, back -f.
    @dyn.set_frame(ex + ox * rx + oy * ux - oz * fx, ey + oy * uy - oz * fy, ez + ox * rz + oy * uz - oz * fz,
                   (m00 * rx + m10 * ux - m20 * fx) * size, (m10 * uy - m20 * fy) * size, (m00 * rz + m10 * uz - m20 * fz) * size,
                   (m01 * rx + m11 * ux - m21 * fx) * size, (m11 * uy - m21 * fy) * size, (m01 * rz + m11 * uz - m21 * fz) * size,
                   (m02 * rx + m12 * ux - m22 * fx) * size, (m12 * uy - m22 * fy) * size, (m02 * rz + m12 * uz - m22 * fz) * size)
    if block == Block::AIR
      # The right arm of the skin of the player, 4 x 12 x 4 pixels, reaches
      # forward from below the view.
      @dyn.frame_skin_box(-0.5, -2.5, -0.5, 0.5, 0.5, 0.5, Tex::SKINS + Tex::SKIN_PLAYER, 40.0, 16.0, 4.0, 12.0, 4.0, false, 1.0, 1.0, 1.0, 1.0)
    else
      @dyn.item_model(block)
    end
  end

  # Swings @hand_frame. The swing copies the game code
  # (ItemInHandRenderer.renderArmWithItem and renderPlayerArm), not the wiki.
  # The model turns around the arm, in a frame that is 45 degrees to the
  # left: an item tips forward, and the empty hand turns to the left. Then
  # the arm goes left, up and forward.
  def swing_hand
    return if @swing <= 0.0

    t = 1.0 - @swing / SWING
    fast = Math.sin(Math.sqrt(t) * Math::PI)
    slow = Math.sin(t * t * Math::PI)
    bob = Math.sin(Math.sqrt(t) * Math::PI * 2.0)
    push = Math.sin(t * Math::PI)
    quarter = Math::PI / 4.0
    degree = Math::PI / 180.0
    frame = @hand_frame
    turn_hand(1, -quarter)
    if @hand_block == Block::AIR
      turn_hand(2, slow * -20.0 * degree)
      turn_hand(1, quarter + fast * 70.0 * degree)
      frame[9] -= fast * 0.3
      frame[10] += bob * 0.4
      frame[11] -= push * 0.4
    else
      turn_hand(0, fast * -80.0 * degree)
      turn_hand(2, fast * -20.0 * degree)
      turn_hand(1, quarter + slow * -20.0 * degree)
      frame[9] -= fast * 0.4
      frame[10] += bob * 0.2
      frame[11] -= push * 0.2
    end
    nil
  end

  # Turns @hand_frame (the 3 axes of the held model, then its move from the
  # arm) by angle around the x (0), y (1) or z (2) axis of the view.
  def turn_hand(axis, angle)
    c = Math.cos(angle)
    s = Math.sin(angle)
    frame = @hand_frame
    4.times do |i|
      x = frame[i * 3]
      y = frame[i * 3 + 1]
      z = frame[i * 3 + 2]
      case axis
      when 0
        frame[i * 3 + 1] = c * y - s * z
        frame[i * 3 + 2] = s * y + c * z
      when 1
        frame[i * 3] = c * x + s * z
        frame[i * 3 + 2] = c * z - s * x
      else
        frame[i * 3] = c * x - s * y
        frame[i * 3 + 1] = s * x + c * y
      end
    end
    nil
  end
end
