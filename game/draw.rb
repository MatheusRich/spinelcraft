# Vertex builders for the HUD (2D, pixels) and for dynamic 3D boxes.
class Ui
  attr_reader :v

  def initialize
    @v = []
  end

  def clear = @v.clear

  def vert(x, y, u, w, layer, r, g, b, a)
    @v << x << y << u << w << layer << r << g << b << a
  end

  def quad(x, y, w, h, layer, u1, v1, r, g, b, a)
    l = layer.to_f
    vert(x, y, 0.0, 0.0, l, r, g, b, a)
    vert(x + w, y, u1, 0.0, l, r, g, b, a)
    vert(x + w, y + h, u1, v1, l, r, g, b, a)
    vert(x, y, 0.0, 0.0, l, r, g, b, a)
    vert(x + w, y + h, u1, v1, l, r, g, b, a)
    vert(x, y + h, 0.0, v1, l, r, g, b, a)
  end

  def rect(x, y, w, h, r, g, b, a)
    quad(x, y, w, h, Tex::WHITE, 1.0, 1.0, r, g, b, a)
  end

  def icon(x, y, size, layer, shade)
    quad(x, y, size, size, layer, 1.0, 1.0, shade, shade, shade, 1.0)
  end

  def text(x, y, s, scale, r, g, b, a)
    cx = x
    s.each_char do |ch|
      glyph = Tex.glyph(ch)
      quad(cx + scale, y + scale, 3.0 * scale, 5.0 * scale, glyph, 9.0 / 16.0, 15.0 / 16.0, 0.0, 0.0, 0.0, a * 0.6)
      quad(cx, y, 3.0 * scale, 5.0 * scale, glyph, 9.0 / 16.0, 15.0 / 16.0, r, g, b, a)
      cx += 4.0 * scale
    end
  end

  def text_width(s, scale) = s.size * 4.0 * scale
end

class Mesh3
  # Corner order: bit 0 is x, bit 1 is y, bit 2 is z.
  FACES = [[1, 5, 7, 3], [4, 0, 2, 6], [2, 3, 7, 6], [0, 4, 5, 1], [5, 4, 6, 7], [0, 1, 3, 2]]
  # Light for each face direction. The same values as SHADE in the chunk shader (gfx.rb).
  SHADE = [0.82, 0.82, 1.0, 0.55, 0.9, 0.9]

  attr_reader :v

  def initialize
    @v = []
    @cx = Array.new(8, 0.0)
    @cy = Array.new(8, 0.0)
    @cz = Array.new(8, 0.0)
  end

  def clear = @v.clear
  def count = @v.size

  def vert(x, y, z, u, w, layer, r, g, b, a)
    @v << x << y << z << u << w << layer << r << g << b << a
  end

  # A box in a body's local space: the box swings by `swing` around the x axis
  # through (0, pivot_y, pivot_z), then the body turns by `yaw` and moves to ox, oy, oz.
  def box(ox, oy, oz, yaw, pivot_y, pivot_z, swing, x0, y0, z0, x1, y1, z1, layer, r, g, b, a)
    cs = Math.cos(swing)
    sn = Math.sin(swing)
    cyw = Math.cos(yaw)
    syw = Math.sin(yaw)
    i = 0
    while i < 8
      lx = (i & 1) == 0 ? x0 : x1
      ly = (i & 2) == 0 ? y0 : y1
      lz = (i & 4) == 0 ? z0 : z1
      dy = ly - pivot_y
      dz = lz - pivot_z
      ry = pivot_y + dy * cs - dz * sn
      rz = pivot_z + dy * sn + dz * cs
      @cx[i] = ox + lx * cyw - rz * syw
      @cy[i] = oy + ry
      @cz[i] = oz + lx * syw + rz * cyw
      i += 1
    end
    corner_faces(63, layer, r, g, b, a)
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
    corner_faces(mask, layer, r, g, b, a)
  end

  # The faces in mask of the box with the corners in @cx, @cy and @cz.
  def corner_faces(mask, layer, r, g, b, a)
    l = layer.to_f
    f = 0
    while f < 6
      if ((mask >> f) & 1) == 1
        face = FACES[f]
        s = SHADE[f]
        a0 = face[0]
        a1 = face[1]
        a2 = face[2]
        a3 = face[3]
        vert(@cx[a0], @cy[a0], @cz[a0], 0.0, 1.0, l, r * s, g * s, b * s, a)
        vert(@cx[a1], @cy[a1], @cz[a1], 1.0, 1.0, l, r * s, g * s, b * s, a)
        vert(@cx[a2], @cy[a2], @cz[a2], 1.0, 0.0, l, r * s, g * s, b * s, a)
        vert(@cx[a0], @cy[a0], @cz[a0], 0.0, 1.0, l, r * s, g * s, b * s, a)
        vert(@cx[a2], @cy[a2], @cz[a2], 1.0, 0.0, l, r * s, g * s, b * s, a)
        vert(@cx[a3], @cy[a3], @cz[a3], 0.0, 0.0, l, r * s, g * s, b * s, a)
      end
      f += 1
    end
  end

  # Dark edges around a block cell.
  def outline(x, y, z)
    t = 0.012
    e = 0.004
    x0 = x - e
    y0 = y - e
    z0 = z - e
    x1 = x + 1.0 + e
    y1 = y + 1.0 + e
    z1 = z + 1.0 + e
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
