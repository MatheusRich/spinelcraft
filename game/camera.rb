# The view-projection matrix, the frustum planes, and screen projection.
class Camera
  attr_reader :vp, :sx, :sy

  def initialize
    @vp = Array.new(16, 0.0)
    @planes = Array.new(24, 0.0)
    @sx = 0.0
    @sy = 0.0
  end

  # Builds the view-projection matrix (row-major in @vp) for Metal's 0..1 depth.
  # TODO: Rename back to update when Spinel types the parameters of each
  # method on its own. Now all methods named update share one type for each
  # parameter, and this one made the others untyped.
  def update_camera(ex, ey, ez, yaw, pitch, aspect, far, fov)
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
    c = 0
    while c < 4
      @vp[c] = sx * v0[c]
      @vp[4 + c] = t * v1[c]
      @vp[8 + c] = a * v2[c] + (c == 3 ? b : 0.0)
      @vp[12 + c] = -v2[c]
      c += 1
    end
    p = 0
    while p < 4
      # left, right, bottom, top from rows 0 and 1; near is row 2, far is row 3 - row 2.
      row = p / 2
      sign = p % 2 == 0 ? 1.0 : -1.0
      i = 0
      while i < 4
        @planes[p * 4 + i] = @vp[12 + i] + sign * @vp[row * 4 + i]
        i += 1
      end
      p += 1
    end
    i = 0
    while i < 4
      @planes[16 + i] = @vp[8 + i]
      @planes[20 + i] = @vp[12 + i] - @vp[8 + i]
      i += 1
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

  def write_column_major(out)
    r = 0
    while r < 4
      c = 0
      while c < 4
        out[c * 4 + r] = @vp[r * 4 + c]
        c += 1
      end
      r += 1
    end
  end

  def box_visible?(x0, y0, z0, x1, y1, z1)
    p = 0
    while p < 6
      a = @planes[p * 4]
      b = @planes[p * 4 + 1]
      c = @planes[p * 4 + 2]
      d = @planes[p * 4 + 3]
      px = a > 0.0 ? x1 : x0
      py = b > 0.0 ? y1 : y0
      pz = c > 0.0 ? z1 : z0
      return false if a * px + b * py + c * pz + d < 0.0
      p += 1
    end
    true
  end
end
