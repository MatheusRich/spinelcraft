# A flat cloud layer that drifts east; cells are 12x12 blocks.
# A cloud near the player is boxes, all of it, which build makes without the
# drift; the GPU adds it. Beyond them the GPU draws the other cells as one
# flat layer out to the fog (see vcloud in gfx.rb).
class Clouds
  CELL = 12
  # The pattern repeats every GRID cells.
  GRID = 256
  # The drift wraps at one pattern, so the GPU gets a small value.
  PERIOD = (CELL * GRID).to_f
  # Minecraft clouds are at y 192.33 (minecraft.wiki/w/Cloud).
  HEIGHT = 192.0
  # minecraft.wiki/w/Clouds: "always four blocks tall".
  DEPTH = 4.0
  # The share of the cells with a cloud. The wiki does not give it: 20.4% of
  # the pixels of Minecraft's clouds.png (1.21.1) are clouds.
  COVER = 0.2
  ALPHA = 0.82
  # A cloud with a cell within NEAR cells of the player's cell (about 800
  # blocks) is boxes, out to REACH cells. The boxed square is then smaller
  # than the pattern, so a cell of the pattern has at most one box.
  NEAR = 66
  REACH = 127

  # The boxes for the clouds around (built_i, built_j).
  attr_reader :mesh
  # The boxed cells as GRID x GRID pixels for gfx_cloud_boxes: pixel
  # j * GRID + i is 1 when cell (i, j) has a box, else 0.
  attr_reader :boxed

  def initialize(seed)
    @mesh = Mesh3.new
    @built = false
    @built_i = 0
    @built_j = 0
    @boxed = Array.new(GRID * GRID, 0)
    # The cells that mark_clouds has yet to spread from, as i, j pairs.
    @fill = []
    values = Clouds.noise_values(seed)
    # The cells with a noise value above the threshold are clouds: COVER of them.
    threshold = values.sort[((1.0 - COVER) * values.size).to_i]
    @cells = values.map { |value| value > threshold ? 1 : 0 }
  end

  # The noise value of each cell, at i * GRID + j.
  def self.noise_values(seed)
    noise = Noise.new(seed * 13 + 5)
    values = Array.new(GRID * GRID, 0.0)
    # The radius of the torus keeps the clouds the same size for any GRID.
    r = GRID / 32.0
    GRID.times do |i|
      GRID.times do |j|
        # Sampled on a torus so the pattern wraps without a seam.
        a = i * 6.283185 / GRID
        b = j * 6.283185 / GRID
        values[i * GRID + j] = noise.noise3(Math.cos(a) * r, Math.sin(a) * r + Math.cos(b) * r, Math.sin(b) * r)
      end
    end
    values
  end

  # The cell column of the x or z position p, after the drift.
  def self.cell(p) = (p / CELL).floor

  # The grid as GRID x GRID white pixels for gfx_clouds, with the cloud cells
  # at ALPHA and the other cells clear. Pixel j * GRID + i is cell (i, j).
  def pixels
    clear = 0xffffff
    cloud = ((ALPHA * 255.0).round << 24) | clear
    px = Array.new(GRID * GRID, clear)
    GRID.times { |i| GRID.times { |j| px[j * GRID + i] = cloud if @cells[i * GRID + j] == 1 } }
    px
  end

  # Writes the far layer's 8 uniforms at u[at]: the drift, the y of the
  # layer, CELL, GRID, and the square of cells (i0, j0, i1, j1) that can have
  # boxes.
  def write_uniforms(u, at, py, drift)
    u[at] = drift
    # From above, the layer is at the top of the boxes.
    u[at + 1] = py > HEIGHT + DEPTH / 2.0 ? HEIGHT + DEPTH : HEIGHT
    u[at + 2] = CELL.to_f
    u[at + 3] = GRID.to_f
    u[at + 4] = (@built_i - REACH).to_f
    u[at + 5] = (@built_j - REACH).to_f
    u[at + 6] = (@built_i + REACH).to_f
    u[at + 7] = (@built_j + REACH).to_f
  end

  # Makes the boxes again when the player's cell changes. Returns true when it did.
  def build(px, pz, drift) # rubocop:todo Metrics/MethodLength
    ci = Clouds.cell(px - drift)
    cj = Clouds.cell(pz)
    return false if @built && ci == @built_i && cj == @built_j
    @built = true
    @built_i = ci
    @built_j = cj
    mark_clouds(ci, cj)
    @mesh.clear
    (-REACH..REACH).each do |di|
      i = ci + di
      x0 = (i * CELL).to_f
      dj = -REACH
      while dj <= REACH
        j = cj + dj
        if boxed?(i, j)
          # Join a run of boxed cells along z into one box. A cell outside
          # the boxed square has no box, so the run stops in the square. The
          # box draws no face inside the cloud: the run has a cell with no
          # box at each z end, and side draws the x sides only next to such
          # cells.
          start = j
          while boxed?(i, j + 1)
            dj += 1
            j += 1
          end
          @mesh.aabb_faces(x0, HEIGHT, (start * CELL).to_f, x0 + CELL, HEIGHT + DEPTH, ((j + 1) * CELL).to_f, 4 | 8 | 16 | 32, Tex::WHITE, 1.0, 1.0, 1.0, ALPHA)
          side(i, start, j, i + 1, 1)
          side(i, start, j, i - 1, 2)
        end
        dj += 1
      end
    end
    true
  end

  def cloud?(i, j) = @cells[(i % GRID) * GRID + (j % GRID)] == 1

  def boxed?(i, j) = @boxed[(j % GRID) * GRID + (i % GRID)] == 1

  # Marks the cells of each cloud that has a cell within NEAR of (ci, cj),
  # out to REACH.
  def mark_clouds(ci, cj)
    @boxed.fill(0)
    (-NEAR..NEAR).each do |di|
      (-NEAR..NEAR).each { |dj| spread(ci + di, cj + dj, ci, cj) }
    end
    until @fill.empty?
      j = @fill.pop
      i = @fill.pop
      spread(i + 1, j, ci, cj)
      spread(i - 1, j, ci, cj)
      spread(i, j + 1, ci, cj)
      spread(i, j - 1, ci, cj)
    end
    nil
  end

  # Marks cell (i, j) and puts it on the fill when it is a cloud within
  # REACH of (ci, cj) and has no mark yet.
  def spread(i, j, ci, cj)
    return if (i - ci).abs > REACH || (j - cj).abs > REACH
    return if boxed?(i, j) || !cloud?(i, j)
    @boxed[(j % GRID) * GRID + (i % GRID)] = 1
    @fill << i << j
    nil
  end

  # The x side (face bit 1 for +x, 2 for -x) of the run of cells j0..j1 in
  # column i, where column ni beside it has no box.
  def side(i, j0, j1, ni, bit)
    x0 = (i * CELL).to_f
    j = j0
    while j <= j1
      unless boxed?(ni, j)
        start = j
        j += 1 while j < j1 && !boxed?(ni, j + 1)
        @mesh.aabb_faces(x0, HEIGHT, (start * CELL).to_f, x0 + CELL, HEIGHT + DEPTH, ((j + 1) * CELL).to_f, bit, Tex::WHITE, 1.0, 1.0, 1.0, ALPHA)
      end
      j += 1
    end
  end
end
