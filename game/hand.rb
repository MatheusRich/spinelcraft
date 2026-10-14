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
  def draw_hand(ex, ey, ez)
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
    if b == Block::AIR
      ox = 0.6
      oy = -0.62
      oz = -0.55
      yaw = 0.2
      pitch = 0.7
      roll = 0.0
      size = 0.16
    elsif flat
      ox = 0.44
      oy = -0.36
      oz = -0.72
      yaw = -1.0
      pitch = 0.1
      roll = 0.1
      size = 0.36
    else
      ox = 0.42
      oy = -0.4
      oz = -0.75
      yaw = 0.6
      pitch = 0.0
      roll = 0.0
      size = 0.24
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
    # The turn: yaw around up, then pitch around right, then roll around back.
    cy = Math.cos(yaw)
    sy = Math.sin(yaw)
    cp = Math.cos(pitch)
    sp = Math.sin(pitch)
    cr = Math.cos(roll)
    sr = Math.sin(roll)
    m00 = cr * cy - sr * sp * sy
    m01 = -sr * cp
    m02 = cr * sy + sr * sp * cy
    m10 = sr * cy + cr * sp * sy
    m11 = cr * cp
    m12 = sr * sy - cr * sp * cy
    m20 = -cp * sy
    m21 = sp
    m22 = cp * cy
    # The view sees the back of the sprite, so a blade or a bow string above
    # the handle faces the player. A tool mirrors across its handle, so that
    # part faces forward.
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
    # View space to the world: right r, up u, back -f.
    @dyn.set_frame(ex + ox * rx + oy * ux - oz * fx, ey + oy * uy - oz * fy, ez + ox * rz + oy * uz - oz * fz,
                   (m00 * rx + m10 * ux - m20 * fx) * size, (m10 * uy - m20 * fy) * size, (m00 * rz + m10 * uz - m20 * fz) * size,
                   (m01 * rx + m11 * ux - m21 * fx) * size, (m11 * uy - m21 * fy) * size, (m01 * rz + m11 * uz - m21 * fz) * size,
                   (m02 * rx + m12 * ux - m22 * fx) * size, (m12 * uy - m22 * fy) * size, (m02 * rz + m12 * uz - m22 * fz) * size)
    if b == Block::AIR
      # The arm reaches forward from below the view.
      @dyn.frame_box(-0.5, -0.5, -2.6, 0.5, 0.5, 0.5, 63, Tex::SKIN, Tex::SKIN, Tex::SKIN, 0.86, 0.66, 0.52, 1.0)
    else
      @dyn.item_model(b)
    end
  end
end
