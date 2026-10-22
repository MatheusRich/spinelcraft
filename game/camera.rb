# The view-projection matrix, the frustum planes, screen projection, and
# the test of a box against the view.
class Camera
  attr_reader :sx, :sy

  def initialize
    @vp = Array.new(16, 0.0)
    @planes = Array.new(24, 0.0)
    @sx = 0.0
    @sy = 0.0
    # The eye of the last update_camera.
    @ex = 0.0
    @ey = 0.0
    @ez = 0.0
  end

  # Builds the view-projection matrix (row-major in @vp) for Metal's 0..1 depth.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_camera(ex, ey, ez, yaw, pitch, aspect, far, fov) # rubocop:todo Metrics/MethodLength
    @ex = ex
    @ey = ey
    @ez = ez
    fx = Math.sin(yaw) * Math.cos(pitch)
    fy = Math.sin(pitch)
    fz = -Math.cos(yaw) * Math.cos(pitch)
    rx = Math.cos(yaw)
    rz = Math.sin(yaw)
    # up = right x forward (right has no y component)
    ux = -rz * fy
    uy = rz * fx - rx * fz
    uz = rx * fy
    near = 0.08
    t = 1.0 / Math.tan(fov)
    sx = t / aspect
    a = far / (near - far)
    b = near * far / (near - far)
    v0 = [rx, 0.0, rz, -(rx * ex + rz * ez)]
    v1 = [ux, uy, uz, -(ux * ex + uy * ey + uz * ez)]
    v2 = [-fx, -fy, -fz, fx * ex + fy * ey + fz * ez]
    4.times do |c|
      @vp[c] = sx * v0[c]
      @vp[4 + c] = t * v1[c]
      @vp[8 + c] = a * v2[c] + (c == 3 ? b : 0.0)
      @vp[12 + c] = -v2[c]
    end
    p = 0
    while p < 4
      # left, right, bottom, top from rows 0 and 1; near is row 2, far is row 3 - row 2.
      row = p / 2
      sign = p % 2 == 0 ? 1.0 : -1.0
      4.times { |i| @planes[p * 4 + i] = @vp[12 + i] + sign * @vp[row * 4 + i] }
      p += 1
    end
    4.times do |i|
      @planes[16 + i] = @vp[8 + i]
      @planes[20 + i] = @vp[12 + i] - @vp[8 + i]
    end
  end

  # Screen position of a world point: true and sx, sy in pixels, or false when it is behind.
  def project(x, y, z, w, h)
    cw = @vp[12] * x + @vp[13] * y + @vp[14] * z + @vp[15]
    return false if cw <= 0.01

    cx = (@vp[0] * x + @vp[1] * y + @vp[2] * z + @vp[3]) / cw
    cy = (@vp[4] * x + @vp[5] * y + @vp[6] * z + @vp[7]) / cw
    @sx = (cx + 1.0) * 0.5 * w
    @sy = (1.0 - cy) * 0.5 * h
    true
  end

  # Projects the point 100 blocks from the eye in the direction dx, dy, dz,
  # as project does. The sky puts the sun, the moon and the stars there.
  def project_direction(dx, dy, dz, w, h)
    project(@ex + dx * 100.0, @ey + dy * 100.0, @ez + dz * 100.0, w, h)
  end

  def write_column_major(out)
    4.times { |r| 4.times { |c| out[c * 4 + r] = @vp[r * 4 + c] } }
  end

  # True when the box from x0, z0 to x1, z1 is nearer than reach to the
  # eye along x and z, and the box from y0 to y1 is in the view. Chunks and
  # far terrain tiles reach from the bottom to the top of the world, so the
  # height does not count for the reach.
  def box_in_view?(x0, y0, z0, x1, y1, z1, reach)
    box_distance2(x0, z0, x1, z1) < reach * reach && box_visible?(x0, y0, z0, x1, y1, z1)
  end

  # The square of the distance along x and z from the eye to the nearest
  # point of the box from x0, z0 to x1, z1. It is 0.0 when the eye is
  # above or under the box.
  def box_distance2(x0, z0, x1, z1)
    dx = ((x0 + x1) * 0.5 - @ex).abs - (x1 - x0) * 0.5
    dz = ((z0 + z1) * 0.5 - @ez).abs - (z1 - z0) * 0.5
    dx = [dx, 0.0].max
    dz = [dz, 0.0].max
    dx * dx + dz * dz
  end

  # The bits of the side directions (+x 1, -x 2, +z 16, -z 32) whose faces
  # in the box from x0, z0 to x1, z1 can face the eye.
  def facing_sides(x0, z0, x1, z1)
    sides = 0
    sides |= 1 if @ex > x0
    sides |= 2 if @ex < x1
    sides |= 16 if @ez > z0
    sides |= 32 if @ez < z1
    sides
  end

  # True when a part of the box from x0, y0, z0 to x1, y1, z1 is inside the
  # six planes of the view.
  def box_visible?(x0, y0, z0, x1, y1, z1)
    6.times do |p|
      a = @planes[p * 4]
      b = @planes[p * 4 + 1]
      c = @planes[p * 4 + 2]
      d = @planes[p * 4 + 3]
      px = a > 0.0 ? x1 : x0
      py = b > 0.0 ? y1 : y0
      pz = c > 0.0 ? z1 : z0
      return false if a * px + b * py + c * pz + d < 0.0
    end
    true
  end
end
