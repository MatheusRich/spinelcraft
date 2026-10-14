# Vertex builder for dynamic 3D boxes.
class Mesh3
  # Corner order: bit 0 is x, bit 1 is y, bit 2 is z.
  FACES = [[1, 5, 7, 3], [4, 0, 2, 6], [2, 3, 7, 6], [0, 4, 5, 1], [5, 4, 6, 7], [0, 1, 3, 2]]
  # Light for each face direction. The same values as SHADE in the chunk shader (gfx.rb).
  SHADE = [0.82, 0.82, 1.0, 0.55, 0.9, 0.9]

  attr_reader :v
  # The least light of the next vertices: 1.0 for flames (see dyn_out in gfx.rb).
  attr_accessor :glow

  def initialize
    @v = []
    @glow = 0.0
    @cx = Array.new(8, 0.0)
    @cy = Array.new(8, 0.0)
    @cz = Array.new(8, 0.0)
    # The origin and the x, y and z axes of the frame for frame_box.
    @frame = Array.new(12, 0.0)
    @roll_cos = 1.0
    @roll_sin = 0.0
  end

  def clear = @v.clear
  def count = @v.size

  def vert(x, y, z, u, w, layer, r, g, b, a)
    @v << x << y << z << u << w << layer << r << g << b << a << @glow
  end

  # A vertical quad from (x0, z0) to (x1, z1), between y0 and y1. The texture
  # runs from u 0 to u1 across, and from v0 at the top to v1 at the bottom.
  def wall(x0, z0, x1, z1, y0, y1, u1, v0, v1, layer, r, g, b, a)
    l = layer.to_f
    vert(x0, y1, z0, 0.0, v0, l, r, g, b, a)
    vert(x1, y1, z1, u1, v0, l, r, g, b, a)
    vert(x1, y0, z1, u1, v1, l, r, g, b, a)
    vert(x0, y1, z0, 0.0, v0, l, r, g, b, a)
    vert(x1, y0, z1, u1, v1, l, r, g, b, a)
    vert(x0, y0, z0, 0.0, v1, l, r, g, b, a)
  end

  # A square of half size h around x, y, z that faces the camera, whose
  # right and up axes are (rx, 0, rz) and (ux, uy, uz).
  def billboard(x, y, z, h, rx, rz, ux, uy, uz, layer, r, g, b, a)
    l = layer.to_f
    ax = (rx + ux) * h
    ay = uy * h
    az = (rz + uz) * h
    bx = (rx - ux) * h
    by = -uy * h
    bz = (rz - uz) * h
    vert(x - bx, y - by, z - bz, 0.0, 0.0, l, r, g, b, a)
    vert(x + ax, y + ay, z + az, 1.0, 0.0, l, r, g, b, a)
    vert(x + bx, y + by, z + bz, 1.0, 1.0, l, r, g, b, a)
    vert(x - bx, y - by, z - bz, 0.0, 0.0, l, r, g, b, a)
    vert(x + bx, y + by, z + bz, 1.0, 1.0, l, r, g, b, a)
    vert(x - ax, y - ay, z - az, 0.0, 1.0, l, r, g, b, a)
  end

  # Tips the bodies of the next boxes by angle around their forward (z) axis
  # through their feet, to the body's left side (+x). 0.0 stands them up again.
  def roll(angle)
    @roll_cos = Math.cos(angle)
    @roll_sin = Math.sin(angle)
  end

  # A box in a body's local space: the box swings by `swing` around the x axis
  # through (0, pivot_y, pivot_z), the body tips by the angle of roll, then the
  # body turns by `yaw` and moves to ox, oy, oz.
  def box(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1, layer, r, g, b, a)
    body_corners(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1)
    corner_faces(63, layer, layer, layer, r, g, b, a)
  end

  # The box of box with the skin of a mob (layer Tex::SKINS + k) in the
  # layout of Minecraft: a box of w x h x d skin pixels at u, v. The front
  # of the body is +z, and its right is -x. mirror swaps the right and the
  # left, as on the left legs of Minecraft models.
  def skin_box(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1, layer, u, v, w, h, d, mirror, r, g, b, a)
    body_corners(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1)
    k = 1.0 / 64.0
    # Under the top and the bottom, the skin has the right side, the front,
    # the left side and the back in a row. A mirror takes the right side
    # for the left, and the left side for the right.
    right = mirror ? u + d + w : u
    left = mirror ? u : u + d + w
    front = u + d
    back = u + d + d + w
    # The corners of FACES go across each face the other way from the skin,
    # so a face goes from the far edge of its rectangle (n) to the near edge
    # (m). A mirror turns this around.
    m = mirror ? 0.0 : 1.0
    n = 1.0 - m
    s0 = (v + d) * k
    s1 = (v + d + h) * k
    face_quad(0, layer, (left + d * m) * k, (left + d * n) * k, s0, s1, r, g, b, a)
    face_quad(1, layer, (right + d * m) * k, (right + d * n) * k, s0, s1, r, g, b, a)
    face_quad(2, layer, (front + w * n) * k, (front + w * m) * k, s0, v * k, r, g, b, a)
    face_quad(3, layer, (front + w + w * n) * k, (front + w + w * m) * k, v * k, s0, r, g, b, a)
    face_quad(4, layer, (front + w * m) * k, (front + w * n) * k, s0, s1, r, g, b, a)
    face_quad(5, layer, (back + w * m) * k, (back + w * n) * k, s0, s1, r, g, b, a)
  end

  # Puts the corners of the box of box in @cx, @cy and @cz.
  def body_corners(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1)
    cs = Math.cos(swing)
    sn = Math.sin(swing)
    cyw = Math.cos(yaw)
    syw = Math.sin(yaw)
    cr = @roll_cos
    sr = @roll_sin
    i = 0
    while i < 8
      lx = (i & 1) == 0 ? x0 : x1
      ly = (i & 2) == 0 ? y0 : y1
      lz = (i & 4) == 0 ? z0 : z1
      dy = ly - pivot_y
      dz = lz - pivot_z
      sy = pivot_y + dy * cs - dz * sn
      rz = pivot_z + dy * sn + dz * cs
      rx = lx * cr + sy * sr
      ry = sy * cr - lx * sr
      @cx[i] = ox + rx * cyw - rz * syw
      @cy[i] = oy + ry
      @cz[i] = oz + rx * syw + rz * cyw
      i += 1
    end
  end

  def aabb(x0, y0, z0, x1, y1, z1, layer, r, g, b, a)
    box(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, x0, y0, z0, x1, y1, z1, layer, r, g, b, a)
  end

  # An axis-aligned box that draws only the faces in mask: bit f draws face f
  # (0..5 for +x -x +y -y +z -z).
  def aabb_faces(x0, y0, z0, x1, y1, z1, mask, layer, r, g, b, a)
    i = 0
    while i < 8
      @cx[i] = (i & 1) == 0 ? x0 : x1
      @cy[i] = (i & 2) == 0 ? y0 : y1
      @cz[i] = (i & 4) == 0 ? z0 : z1
      i += 1
    end
    corner_faces(mask, layer, layer, layer, r, g, b, a)
  end

  # Sets the frame for frame_box: the origin o and the axes a, b and c. The
  # length of an axis scales the box along it.
  def set_frame(ox, oy, oz, ax, ay, az, bx, by, bz, cx, cy, cz)
    f = @frame
    f[0] = ox
    f[1] = oy
    f[2] = oz
    f[3] = ax
    f[4] = ay
    f[5] = az
    f[6] = bx
    f[7] = by
    f[8] = bz
    f[9] = cx
    f[10] = cy
    f[11] = cz
  end

  # A box from (x0, y0, z0) to (x1, y1, z1) in the frame of set_frame. It
  # draws the faces in mask (see aabb_faces), with the top layer on the +y
  # face, the bottom layer on the -y face, and the side layer on the others.
  def frame_box(x0, y0, z0, x1, y1, z1, mask, top, side, bottom, r, g, b, a)
    frame_corners(x0, y0, z0, x1, y1, z1)
    corner_faces(mask, top, side, bottom, r, g, b, a)
  end

  # Puts the corners of the box of frame_box in @cx, @cy and @cz.
  def frame_corners(x0, y0, z0, x1, y1, z1)
    f = @frame
    i = 0
    while i < 8
      lx = (i & 1) == 0 ? x0 : x1
      ly = (i & 2) == 0 ? y0 : y1
      lz = (i & 4) == 0 ? z0 : z1
      @cx[i] = f[0] + lx * f[3] + ly * f[6] + lz * f[9]
      @cy[i] = f[1] + lx * f[4] + ly * f[7] + lz * f[10]
      @cz[i] = f[2] + lx * f[5] + ly * f[8] + lz * f[11]
      i += 1
    end
  end

  # Block or item b as a unit model around the origin of the frame of set_frame.
  def item_model(b)
    if Block.flat?(b)
      layer = Block::SIDE[b]
      frame_box(-0.5, -0.5, 0.0, 0.5, 0.5, 0.0, 16, layer, layer, layer, 1.0, 1.0, 1.0, 1.0)
    elsif Block::SHAPE[b] > 0
      shape_model(b)
    elsif Block::FACING[b] >= 0
      # The front is on the -x face, which faces the view in the hand.
      frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 61, Block::TOP[b], Block::SIDE[b], Block::BOTTOM[b], 1.0, 1.0, 1.0, 1.0)
      frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 2, Block::FRONT[b], Block::FRONT[b], Block::FRONT[b], 1.0, 1.0, 1.0, 1.0)
    else
      frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 63, Block::TOP[b], Block::SIDE[b], Block::BOTTOM[b], 1.0, 1.0, 1.0, 1.0)
    end
  end

  # Block b with a shape (a chest) as the box of its shape, with the front
  # on the -x face. Each face takes the part of its texture that it covers
  # on the block in the world (see vchunk in gfx.rb). The box is the same
  # on both sides of its middle, so it needs no turn.
  def shape_model(b)
    s = Block::SHAPE[b] * 6
    x0 = Block::SHAPE_BOX[s] / 16.0
    y0 = Block::SHAPE_BOX[s + 1] / 16.0
    z0 = Block::SHAPE_BOX[s + 2] / 16.0
    x1 = Block::SHAPE_BOX[s + 3] / 16.0
    y1 = Block::SHAPE_BOX[s + 4] / 16.0
    z1 = Block::SHAPE_BOX[s + 5] / 16.0
    frame_corners(x0 - 0.5, y0 - 0.5, z0 - 0.5, x1 - 0.5, y1 - 0.5, z1 - 0.5)
    face_quad(0, Block::SIDE[b], z0, z1, 1.0 - y1, 1.0 - y0, 1.0, 1.0, 1.0, 1.0)
    face_quad(1, Block::FRONT[b], z0, z1, 1.0 - y1, 1.0 - y0, 1.0, 1.0, 1.0, 1.0)
    face_quad(2, Block::TOP[b], x0, x1, z0, z1, 1.0, 1.0, 1.0, 1.0)
    face_quad(3, Block::BOTTOM[b], x0, x1, z0, z1, 1.0, 1.0, 1.0, 1.0)
    face_quad(4, Block::SIDE[b], x0, x1, 1.0 - y1, 1.0 - y0, 1.0, 1.0, 1.0, 1.0)
    face_quad(5, Block::SIDE[b], x0, x1, 1.0 - y1, 1.0 - y0, 1.0, 1.0, 1.0, 1.0)
  end

  # The faces in mask of the box with the corners in @cx, @cy and @cz.
  def corner_faces(mask, top, side, bottom, r, g, b, a)
    f = 0
    while f < 6
      face_quad(f, f == 2 ? top : (f == 3 ? bottom : side), 0.0, 1.0, 0.0, 1.0, r, g, b, a) if ((mask >> f) & 1) == 1
      f += 1
    end
  end

  # Face f of the box with the corners in @cx, @cy and @cz. The texture runs
  # from u0 to u1 across, and from v0 at the top to v1 at the bottom.
  def face_quad(f, layer, u0, u1, v0, v1, r, g, b, a)
    l = layer.to_f
    face = FACES[f]
    s = SHADE[f]
    a0 = face[0]
    a1 = face[1]
    a2 = face[2]
    a3 = face[3]
    vert(@cx[a0], @cy[a0], @cz[a0], u0, v1, l, r * s, g * s, b * s, a)
    vert(@cx[a1], @cy[a1], @cz[a1], u1, v1, l, r * s, g * s, b * s, a)
    vert(@cx[a2], @cy[a2], @cz[a2], u1, v0, l, r * s, g * s, b * s, a)
    vert(@cx[a0], @cy[a0], @cz[a0], u0, v1, l, r * s, g * s, b * s, a)
    vert(@cx[a2], @cy[a2], @cz[a2], u1, v0, l, r * s, g * s, b * s, a)
    vert(@cx[a3], @cy[a3], @cz[a3], u0, v0, l, r * s, g * s, b * s, a)
  end

  # Dark edges around the box of a block in the cell x, y, z: hx and hz
  # around the center on x and z, and top high. A box that is not in the middle of its
  # cell (see Block.box_dx) moves x, y and z.
  def outline(x, y, z, hx, hz, top)
    t = 0.012
    e = 0.004
    x0 = x + 0.5 - hx - e
    y0 = y - e
    z0 = z + 0.5 - hz - e
    x1 = x + 0.5 + hx + e
    y1 = y + top + e
    z1 = z + 0.5 + hz + e
    i = 0
    while i < 4
      ya = i % 2 == 0 ? y0 : y1
      za = i / 2 == 0 ? z0 : z1
      aabb(x0, ya - t, za - t, x1, ya + t, za + t, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      xa = i % 2 == 0 ? x0 : x1
      aabb(xa - t, y0, za - t, xa + t, y1, za + t, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      xb = i / 2 == 0 ? x0 : x1
      yb = i % 2 == 0 ? y0 : y1
      aabb(xb - t, yb - t, z0, xb + t, yb + t, z1, Tex::WHITE, 0.05, 0.05, 0.05, 1.0)
      i += 1
    end
  end
end
