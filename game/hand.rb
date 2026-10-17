# The held item in first person: a 3D model at the lower right of the view.
# It swings when the player uses it, drops and rises when the selection
# changes, and sways while the player walks. An empty hand shows the arm.
class Game
  # Seconds that one swing takes (see @swing).
  SWING = 0.25

  def update_hand(dt)
    b = current_block.to_i
    if b != @hand_block
      @hand_block = b
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
    b = @hand_block
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
    flat = b != Block::AIR && Block.flat?(b)
    # The place (right, up, back) and the turn of the model in view space.
    # Items and blocks copy Minecraft: ItemInHandRenderer puts the arm at
    # (0.56, -0.52, -0.72), and the firstperson_righthand display of the
    # models item/generated and block/block moves, turns and scales the model.
    if b == Block::AIR
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
      ox = 0.56 + 1.13 / 16.0
      oy = -0.52 + 3.2 / 16.0 + 0.08
      oz = -0.72 + 1.13 / 16.0
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
    if @swing > 0.0
      t = 1.0 - @swing / SWING
      s1 = Math.sin(Math.sqrt(t) * Math::PI)
      ox -= s1 * 0.25
      oy += Math.sin(Math.sqrt(t) * Math::PI * 2.0) * 0.1
      oz -= Math.sin(t * Math::PI) * 0.12
      pitch -= s1 * 0.6
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
    cy = Math.cos(yaw)
    sy = Math.sin(yaw)
    cp = Math.cos(pitch)
    sp = Math.sin(pitch)
    cr = Math.cos(roll)
    sr = Math.sin(roll)
    m00 = cy * cr
    m01 = -cy * sr
    m02 = sy
    m10 = cp * sr + sp * sy * cr
    m11 = cp * cr - sp * sy * sr
    m12 = -sp * cy
    m20 = sp * sr - cp * sy * cr
    m21 = sp * cr + cp * sy * sr
    m22 = cp * cy
    # The view sees the back of the sprite, so a blade or a bow string above
    # the handle faces the player. A tool mirrors across its handle, so that
    # part faces forward.
    # The arm of the skin is long in y, with the hand at -y and the front at
    # +z. Its y goes back along the view, and its front faces down.
    if b == Block::AIR
      t0 = m01
      t1 = m11
      t2 = m21
      m01 = m02
      m11 = m12
      m21 = m22
      m02 = -t0
      m12 = -t1
      m22 = -t2
    end
    if Block.tool?(b)
      t0 = m00
      t1 = m10
      t2 = m20
      m00 = -m01
      m10 = -m11
      m20 = -m21
      m01 = -t0
      m11 = -t1
      m21 = -t2
    end
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
    if b == Block::AIR
      # The right arm of the skin of the player, 4 x 12 x 4 pixels, reaches
      # forward from below the view.
      @dyn.frame_skin_box(-0.5, -2.5, -0.5, 0.5, 0.5, 0.5, Tex::SKINS + Tex::SKIN_PLAYER, 40.0, 16.0, 4.0, 12.0, 4.0, false, 1.0, 1.0, 1.0, 1.0)
    else
      @dyn.item_model(b)
    end
  end
end
