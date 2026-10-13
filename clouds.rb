# A flat cloud layer that drifts east; cells are 12x12 blocks.
class Clouds
  CELL = 12
  GRID = 64
  HEIGHT = 88.0

  def initialize(seed)
    noise = Noise.new(seed * 13 + 5)
    @cells = Array.new(GRID * GRID, 0)
    i = 0
    while i < GRID
      j = 0
      while j < GRID
        # Sampled on a torus so the pattern wraps without a seam.
        a = i * 6.283185 / GRID
        b = j * 6.283185 / GRID
        v = noise.noise3(Math.cos(a) * 2.0, Math.sin(a) * 2.0 + Math.cos(b) * 2.0, Math.sin(b) * 2.0)
        @cells[i * GRID + j] = v > 0.12 ? 1 : 0
        j += 1
      end
      i += 1
    end
  end

  def draw(mesh, px, pz, drift)
    ci = ((px - drift) / CELL).floor
    cj = (pz / CELL).floor
    di = -11
    while di <= 11
      i = ci + di
      x0 = i * CELL + drift
      dj = -11
      while dj <= 11
        j = cj + dj
        if @cells[(i % GRID) * GRID + (j % GRID)] == 1
          # Join a run of cloud cells along z into one box.
          start = j
          while dj < 11 && @cells[(i % GRID) * GRID + ((j + 1) % GRID)] == 1
            dj += 1
            j += 1
          end
          mesh.aabb(x0, HEIGHT, (start * CELL).to_f, x0 + CELL, HEIGHT + 3.0, ((j + 1) * CELL).to_f, Tex::WHITE, 1.0, 1.0, 1.0, 0.82)
        end
        dj += 1
      end
      di += 1
    end
  end
end
