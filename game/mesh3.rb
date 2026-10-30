# Vertex builder for dynamic 3D boxes.
class Mesh3
  # Corner order: bit 0 is x, bit 1 is y, bit 2 is z.
  FACES = [[1, 5, 7, 3], [4, 0, 2, 6], [2, 3, 7, 6], [0, 4, 5, 1], [5, 4, 6, 7], [0, 1, 3, 2]]
  # Light for each face direction. The same values as SHADE in the chunk shader (gfx.rb).
  SHADE = [0.82, 0.82, 1.0, 0.55, 0.9, 0.9]

  attr_reader :v
  # The least light of the next vertices: 1.0 for flames (see dyn_out in gfx.rb).
  attr_writer :glow
  # The opaque pixels of the texture layers (see Tex.opaque), for item_model.
  attr_accessor :opaque

  def initialize
    @v = []
    @glow = 0.0
    @opaque = []
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
  def wall(x0, z0, x1, z1, y0, y1, u1, v0, v1, layer, color)
    l = layer.to_f
    red = color.red
    green = color.green
    blue = color.blue
    alpha = color.alpha
    vert(x0, y1, z0, 0.0, v0, l, red, green, blue, alpha)
    vert(x1, y1, z1, u1, v0, l, red, green, blue, alpha)
    vert(x1, y0, z1, u1, v1, l, red, green, blue, alpha)
    vert(x0, y1, z0, 0.0, v0, l, red, green, blue, alpha)
    vert(x1, y0, z1, u1, v1, l, red, green, blue, alpha)
    vert(x0, y0, z0, 0.0, v1, l, red, green, blue, alpha)
  end

  # A square of half size h around x, y, z that faces the camera, whose
  # right and up axes are (rx, 0, rz) and (ux, uy, uz). It shows the square
  # of the texture from (u0, v0) with the side du.
  def billboard(x, y, z, h, rx, rz, ux, uy, uz, u0, v0, du, layer, color)
    l = layer.to_f
    red = color.red
    green = color.green
    blue = color.blue
    alpha = color.alpha
    ax = (rx + ux) * h
    ay = uy * h
    az = (rz + uz) * h
    bx = (rx - ux) * h
    by = -uy * h
    bz = (rz - uz) * h
    u1 = u0 + du
    v1 = v0 + du
    vert(x - bx, y - by, z - bz, u0, v0, l, red, green, blue, alpha)
    vert(x + ax, y + ay, z + az, u1, v0, l, red, green, blue, alpha)
    vert(x + bx, y + by, z + bz, u1, v1, l, red, green, blue, alpha)
    vert(x - bx, y - by, z - bz, u0, v0, l, red, green, blue, alpha)
    vert(x + bx, y + by, z + bz, u1, v1, l, red, green, blue, alpha)
    vert(x - ax, y - ay, z - az, u0, v1, l, red, green, blue, alpha)
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
  def box(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1, layer, color)
    body_corners(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1)
    corner_faces(63, layer, layer, layer, color)
  end

  # A box with the faces of a block on a body, as box: the front (+z, the
  # front of a mob's model) takes front, and the other sides take side.
  def block_box(ox, oy, oz, yaw, x0, y0, z0, x1, y1, z1, top, side, bottom, front, color)
    body_corners(ox, oy, oz, yaw, 0.0, 0.0, 0.0, x0, y0, z0, x1, y1, z1)
    6.times do |f|
      face_quad(f, f == 2 ? top : (f == 3 ? bottom : (f == 4 ? front : side)), 0.0, 1.0, 0.0, 1.0, color)
    end
  end

  # The box of box with the skin of a mob (layer Tex::SKINS + k) in the
  # layout of Minecraft: a box of w x h x d skin pixels at u, v. The front
  # of the body is +z, and its right is -x. mirror swaps the right and the
  # left, as on the left legs of Minecraft models.
  def skin_box(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1, layer, u, v, w, h, d, mirror, color)
    body_corners(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1)
    skin_faces(layer, u, v, w, h, d, mirror, color)
  end

  # The box of frame_box with a skin, as skin_box: +z is the front of the box.
  def frame_skin_box(x0, y0, z0, x1, y1, z1, layer, u, v, w, h, d, mirror, color)
    frame_corners(x0, y0, z0, x1, y1, z1)
    skin_faces(layer, u, v, w, h, d, mirror, color)
  end

  # The six faces of the corners in @cx, @cy and @cz, with the skin of a box
  # of w x h x d skin pixels at u, v.
  def skin_faces(layer, u, v, w, h, d, mirror, color)
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
    face_quad(0, layer, (left + d * m) * k, (left + d * n) * k, s0, s1, color)
    face_quad(1, layer, (right + d * m) * k, (right + d * n) * k, s0, s1, color)
    face_quad(2, layer, (front + w * n) * k, (front + w * m) * k, s0, v * k, color)
    face_quad(3, layer, (front + w + w * n) * k, (front + w + w * m) * k, v * k, s0, color)
    face_quad(4, layer, (front + w * m) * k, (front + w * n) * k, s0, s1, color)
    face_quad(5, layer, (back + w * m) * k, (back + w * n) * k, s0, s1, color)
  end

  # Puts the corners of the box of box in @cx, @cy and @cz.
  def body_corners(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1)
    cs = Math.cos(swing)
    sn = Math.sin(swing)
    cyw = Math.cos(yaw)
    syw = Math.sin(yaw)
    cr = @roll_cos
    sr = @roll_sin
    8.times do |i|
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
    end
  end

  def aabb(x0, y0, z0, x1, y1, z1, layer, color)
    box(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, x0, y0, z0, x1, y1, z1, layer, color)
  end

  # An axis-aligned box that draws only the faces in mask: bit f draws face f
  # (0..5 for +x -x +y -y +z -z).
  def aabb_faces(x0, y0, z0, x1, y1, z1, mask, layer, color)
    8.times do |i|
      @cx[i] = (i & 1) == 0 ? x0 : x1
      @cy[i] = (i & 2) == 0 ? y0 : y1
      @cz[i] = (i & 4) == 0 ? z0 : z1
    end
    corner_faces(mask, layer, layer, layer, color)
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
  def frame_box(x0, y0, z0, x1, y1, z1, mask, top, side, bottom, color)
    frame_corners(x0, y0, z0, x1, y1, z1)
    corner_faces(mask, top, side, bottom, color)
  end

  # Puts the corners of the box of frame_box in @cx, @cy and @cz.
  def frame_corners(x0, y0, z0, x1, y1, z1)
    f = @frame
    8.times do |i|
      lx = (i & 1) == 0 ? x0 : x1
      ly = (i & 2) == 0 ? y0 : y1
      lz = (i & 4) == 0 ? z0 : z1
      @cx[i] = f[0] + lx * f[3] + ly * f[6] + lz * f[9]
      @cy[i] = f[1] + lx * f[4] + ly * f[7] + lz * f[10]
      @cz[i] = f[2] + lx * f[5] + ly * f[8] + lz * f[11]
    end
  end

  # Block or item as a unit model around the origin of the frame of set_frame.
  # A flat item is its sprite with a thickness of one pixel, as in Minecraft.
  # The texture goes along -x on both faces.
  def item_model(block)
    if Block.flat?(block)
      sprite_model(Block::SIDE[block])
    elsif Block::SHAPE[block] > 0
      shape_model(block)
    elsif Block::FACING[block] >= 0
      # The front is on the -x face, which faces the view in the hand.
      frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 61, Block::TOP[block], Block::SIDE[block], Block::BOTTOM[block], Color::WHITE)
      frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 2, Block::FRONT[block], Block::FRONT[block], Block::FRONT[block], Color::WHITE)
    else
      frame_box(-0.5, -0.5, -0.5, 0.5, 0.5, 0.5, 63, Block::TOP[block], Block::SIDE[block], Block::BOTTOM[block], Color::WHITE)
    end
  end

  # A flat item with the image of texture layer layer.
  def sprite_model(layer)
    frame_corners(-0.5, -0.5, -ITEM_T, 0.5, 0.5, ITEM_T)
    face_quad(4, layer, 0.0, 1.0, 0.0, 1.0, Color::WHITE)
    face_quad(5, layer, 1.0, 0.0, 0.0, 1.0, Color::WHITE)
    item_edges(layer)
  end

  # Half the thickness of a flat item: one pixel of 16 is 1/16 of the model.
  ITEM_T = 1.0 / 32.0

  # The sides of the pixels of layer that have a clear pixel or the border
  # of the texture next to them. A side shows the color of its pixel.
  def item_edges(layer)
    k = layer * 32
    16.times do |i|
      row = @opaque[k + i]
      col = @opaque[k + 16 + i]
      above = i > 0 ? @opaque[k + i - 1] : 0
      below = i < 15 ? @opaque[k + i + 1] : 0
      before = i > 0 ? @opaque[k + 15 + i] : 0
      after = i < 15 ? @opaque[k + 17 + i] : 0
      edge_runs(row & (0xffff ^ above), i, i, true, SHADE[2], layer)
      edge_runs(row & (0xffff ^ below), i, i + 1, true, SHADE[3], layer)
      edge_runs(col & (0xffff ^ before), i, i, false, SHADE[0], layer)
      edge_runs(col & (0xffff ^ after), i, i + 1, false, SHADE[0], layer)
    end
  end

  # One quad for each run of set bits in mask. The run goes along the row
  # (along_x) or the column with the index line, and its quad stands on the
  # pixel border edge (0 to 16) across the run.
  def edge_runs(mask, line, edge, along_x, shade, layer)
    l = layer.to_f
    c = (line + 0.5) / 16.0
    e = 0.5 - edge / 16.0
    a = 0
    while a < 16
      if ((mask >> a) & 1) == 1
        b = a + 1
        b += 1 while b < 16 && ((mask >> b) & 1) == 1
        a0 = 0.5 - a / 16.0
        b0 = 0.5 - b / 16.0
        if along_x
          side_quad(a0, e, b0, e, a / 16.0, c, b / 16.0, c, shade, l)
        else
          side_quad(e, a0, e, b0, c, a / 16.0, c, b / 16.0, shade, l)
        end
        a = b
      else
        a += 1
      end
    end
  end

  # A quad across the thickness of a flat item, from the point (ax, ay) with
  # the texture at (au, av) to the point (bx, by) with the texture at (bu, bv).
  def side_quad(ax, ay, bx, by, au, av, bu, bv, shade, l)
    frame_vert(ax, ay, -ITEM_T, au, av, l, shade)
    frame_vert(bx, by, -ITEM_T, bu, bv, l, shade)
    frame_vert(bx, by, ITEM_T, bu, bv, l, shade)
    frame_vert(ax, ay, -ITEM_T, au, av, l, shade)
    frame_vert(bx, by, ITEM_T, bu, bv, l, shade)
    frame_vert(ax, ay, ITEM_T, au, av, l, shade)
  end

  # A vertex at x, y, z in the frame of set_frame, with the light s.
  def frame_vert(x, y, z, u, w, l, s)
    f = @frame
    vert(f[0] + x * f[3] + y * f[6] + z * f[9], f[1] + x * f[4] + y * f[7] + z * f[10],
         f[2] + x * f[5] + y * f[8] + z * f[11], u, w, l, s, s, s, 1.0)
  end

  # Block with a shape (a chest) as the box of its shape, with the front
  # on the -x face. Each face takes the part of its texture that it covers
  # on the block in the world (see vchunk in gfx.rb). The box is the same
  # on both sides of its middle, so it needs no turn.
  def shape_model(block)
    s = Block::SHAPE[block] * 6
    x0 = Block::SHAPE_BOX[s] / 16.0
    y0 = Block::SHAPE_BOX[s + 1] / 16.0
    z0 = Block::SHAPE_BOX[s + 2] / 16.0
    x1 = Block::SHAPE_BOX[s + 3] / 16.0
    y1 = Block::SHAPE_BOX[s + 4] / 16.0
    z1 = Block::SHAPE_BOX[s + 5] / 16.0
    frame_corners(x0 - 0.5, y0 - 0.5, z0 - 0.5, x1 - 0.5, y1 - 0.5, z1 - 0.5)
    face_quad(0, Block::SIDE[block], z0, z1, 1.0 - y1, 1.0 - y0, Color::WHITE)
    face_quad(1, Block::FRONT[block], z0, z1, 1.0 - y1, 1.0 - y0, Color::WHITE)
    face_quad(2, Block::TOP[block], x0, x1, z0, z1, Color::WHITE)
    face_quad(3, Block::BOTTOM[block], x0, x1, z0, z1, Color::WHITE)
    face_quad(4, Block::SIDE[block], x0, x1, 1.0 - y1, 1.0 - y0, Color::WHITE)
    face_quad(5, Block::SIDE[block], x0, x1, 1.0 - y1, 1.0 - y0, Color::WHITE)
  end

  # The faces in mask of the box with the corners in @cx, @cy and @cz.
  def corner_faces(mask, top, side, bottom, color)
    6.times do |f|
      face_quad(f, f == 2 ? top : (f == 3 ? bottom : side), 0.0, 1.0, 0.0, 1.0, color) if ((mask >> f) & 1) == 1
    end
  end

  # Face f of the box with the corners in @cx, @cy and @cz. The texture runs
  # from u0 to u1 across, and from v0 at the top to v1 at the bottom.
  def face_quad(f, layer, u0, u1, v0, v1, color)
    l = layer.to_f
    face = FACES[f]
    s = SHADE[f]
    red = color.red * s
    green = color.green * s
    blue = color.blue * s
    alpha = color.alpha
    a0 = face[0]
    a1 = face[1]
    a2 = face[2]
    a3 = face[3]
    vert(@cx[a0], @cy[a0], @cz[a0], u0, v1, l, red, green, blue, alpha)
    vert(@cx[a1], @cy[a1], @cz[a1], u1, v1, l, red, green, blue, alpha)
    vert(@cx[a2], @cy[a2], @cz[a2], u1, v0, l, red, green, blue, alpha)
    vert(@cx[a0], @cy[a0], @cz[a0], u0, v1, l, red, green, blue, alpha)
    vert(@cx[a2], @cy[a2], @cz[a2], u1, v0, l, red, green, blue, alpha)
    vert(@cx[a3], @cy[a3], @cz[a3], u0, v0, l, red, green, blue, alpha)
  end

  # The outline of the aimed block is black at alpha 0.4, as in the game
  # code of Minecraft Java (LevelRenderer); the wiki does not give it.
  OUTLINE_ALPHA = 0.4
  # Each vertex of the outline moves this part of the way to the eye. Its
  # place on the screen stays the same, but it is in front of the faces of
  # the block, so the faces do not hide it in part.
  OUTLINE_PULL = 0.01

  # The edges around the box of a block in the cell x, y, z: hx and hz
  # around the center on x and z, and top high. A box that is not in the
  # middle of its cell (see Block.box_dx) moves x, y and z. Each edge is a
  # strip that faces the eye at ex, ey, ez, which looks along fx, fy, fz.
  # At a depth d along the view, the strip is k * d wide on each side of
  # the edge, so it keeps one width in pixels at each distance.
  def outline(x, y, z, hx, hz, top, ex, ey, ez, fx, fy, fz, k)
    e = 0.002
    # to_f: Spinel cannot type the cell of the aimed block.
    x0 = x.to_f + 0.5 - hx - e
    y0 = y.to_f - e
    z0 = z.to_f + 0.5 - hz - e
    x1 = x.to_f + 0.5 + hx + e
    y1 = y.to_f + top + e
    z1 = z.to_f + 0.5 + hz + e
    4.times do |i|
      ya = i % 2 == 0 ? y0 : y1
      za = i / 2 == 0 ? z0 : z1
      edge_line(x0, ya, za, x1, ya, za, ex, ey, ez, fx, fy, fz, k)
      xa = i % 2 == 0 ? x0 : x1
      edge_line(xa, y0, za, xa, y1, za, ex, ey, ez, fx, fy, fz, k)
      xb = i / 2 == 0 ? x0 : x1
      yb = i % 2 == 0 ? y0 : y1
      edge_line(xb, yb, z0, xb, yb, z1, ex, ey, ez, fx, fy, fz, k)
    end
  end

  # One edge of outline, from a to b.
  def edge_line(ax, ay, az, bx, by, bz, ex, ey, ez, fx, fy, fz, k) # rubocop:todo Metrics/MethodLength
    dx = bx - ax
    dy = by - ay
    dz = bz - az
    # The side of the strip is square to the edge and to the line from the
    # eye to the middle of the edge.
    vx = (ax + bx) * 0.5 - ex
    vy = (ay + by) * 0.5 - ey
    vz = (az + bz) * 0.5 - ez
    sx = dy * vz - dz * vy
    sy = dz * vx - dx * vz
    sz = dx * vy - dy * vx
    len = Math.sqrt(sx * sx + sy * sy + sz * sz)
    # An edge that points at the eye shows as a point.
    return if len < 1.0e-9

    # A depth under the near plane would make the strip too thin to see.
    wa = k * ((ax - ex) * fx + (ay - ey) * fy + (az - ez) * fz).clamp(0.08, 1000.0) / len
    wb = k * ((bx - ex) * fx + (by - ey) * fy + (bz - ez) * fz).clamp(0.08, 1000.0) / len
    q = 1.0 - OUTLINE_PULL
    p0x = ex + (ax + sx * wa - ex) * q
    p0y = ey + (ay + sy * wa - ey) * q
    p0z = ez + (az + sz * wa - ez) * q
    p1x = ex + (ax - sx * wa - ex) * q
    p1y = ey + (ay - sy * wa - ey) * q
    p1z = ez + (az - sz * wa - ez) * q
    p2x = ex + (bx - sx * wb - ex) * q
    p2y = ey + (by - sy * wb - ey) * q
    p2z = ez + (bz - sz * wb - ez) * q
    p3x = ex + (bx + sx * wb - ex) * q
    p3y = ey + (by + sy * wb - ey) * q
    p3z = ez + (bz + sz * wb - ez) * q
    l = Tex::WHITE.to_f
    a = OUTLINE_ALPHA
    vert(p0x, p0y, p0z, 0.5, 0.5, l, 0.0, 0.0, 0.0, a)
    vert(p1x, p1y, p1z, 0.5, 0.5, l, 0.0, 0.0, 0.0, a)
    vert(p2x, p2y, p2z, 0.5, 0.5, l, 0.0, 0.0, 0.0, a)
    vert(p0x, p0y, p0z, 0.5, 0.5, l, 0.0, 0.0, 0.0, a)
    vert(p2x, p2y, p2z, 0.5, 0.5, l, 0.0, 0.0, 0.0, a)
    vert(p3x, p3y, p3z, 0.5, 0.5, l, 0.0, 0.0, 0.0, a)
    # A nil return keeps Spinel from boxing it.
    nil
  end
end
