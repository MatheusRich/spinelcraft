module Ray
  # Distance along the ray from o along d to the box from x0, y0, z0 to x1,
  # y1, z1, or -1.0 when the ray misses it. This is the slab test.
  def self.box_distance(ox, oy, oz, dx, dy, dz, x0, y0, z0, x1, y1, z1)
    near = 0.0
    far = 1.0e9
    if dx == 0.0
      return -1.0 if ox < x0 || ox > x1
    else
      t0 = (x0 - ox) / dx
      t1 = (x1 - ox) / dx
      near = t0 < t1 ? (t0 > near ? t0 : near) : (t1 > near ? t1 : near)
      far = t0 < t1 ? (t1 < far ? t1 : far) : (t0 < far ? t0 : far)
    end
    if dy == 0.0
      return -1.0 if oy < y0 || oy > y1
    else
      t0 = (y0 - oy) / dy
      t1 = (y1 - oy) / dy
      near = t0 < t1 ? (t0 > near ? t0 : near) : (t1 > near ? t1 : near)
      far = t0 < t1 ? (t1 < far ? t1 : far) : (t0 < far ? t0 : far)
    end
    if dz == 0.0
      return -1.0 if oz < z0 || oz > z1
    else
      t0 = (z0 - oz) / dz
      t1 = (z1 - oz) / dz
      near = t0 < t1 ? (t0 > near ? t0 : near) : (t1 > near ? t1 : near)
      far = t0 < t1 ? (t1 < far ? t1 : far) : (t0 < far ? t0 : far)
    end
    near <= far ? near : -1.0
  end
end
