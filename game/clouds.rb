# A flat cloud layer that drifts east; cells are 12x12 blocks.
# Near the player the cells are boxes, which build makes without the drift; the
# GPU adds it. Beyond them the GPU draws the same cells as one flat layer out
# to the fog (see vcloud in gfx.rb).
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
  COLOR = Color.new(1.0, 1.0, 1.0, ALPHA)
  # Boxes go out to NEAR cells from the player's cell, about 800 blocks.
  NEAR = 66
  # The walls of the boxes fade out over FADE blocks, and are gone at
  # NEAR * CELL, the nearest that a cell switches between a box and the
  # flat layer. So a switch shows no change.
  FADE = 300.0

  # The boxes for the cells around (built_i, built_j).
  attr_reader :mesh

  def initialize(seed)
    @mesh = Mesh3.new
    @built = false
    @built_i = 0
    @built_j = 0
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

  # The fade of the walls as #defines for vcloud_box.
  def self.shader_defines
    fade_end = (NEAR * CELL).to_f
    "#define CLOUD_FADE_START #{fade_end - FADE}\n#define CLOUD_FADE_END #{fade_end}\n"
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
  # layer, CELL, GRID, and the cells (i0, j0, i1, j1) that have boxes.
  def write_uniforms(u, at, py, drift)
    u[at] = drift
    # From above, the layer is at the top of the boxes.
    u[at + 1] = py > HEIGHT + DEPTH / 2.0 ? HEIGHT + DEPTH : HEIGHT
    u[at + 2] = CELL.to_f
    u[at + 3] = GRID.to_f
    u[at + 4] = (@built_i - NEAR).to_f
    u[at + 5] = (@built_j - NEAR).to_f
    u[at + 6] = (@built_i + NEAR).to_f
    u[at + 7] = (@built_j + NEAR).to_f
  end

  # Makes the boxes again when the player's cell changes. Returns true when it did.
  def build(px, pz, drift) # rubocop:todo Metrics/MethodLength
    ci = Clouds.cell(px - drift)
    cj = Clouds.cell(pz)
    return false if @built && ci == @built_i && cj == @built_j

    @built = true
    @built_i = ci
    @built_j = cj
    @mesh.clear
    (-NEAR..NEAR).each do |di|
      i = ci + di
      x0 = (i * CELL).to_f
      dj = -NEAR
      while dj <= NEAR
        j = cj + dj
        if cloud?(i, j)
          # Join a run of cloud cells along z into one box. The box draws no
          # face inside the cloud: a z end only next to an empty cell, and
          # the x sides only where side finds empty cells.
          start = j
          while dj < NEAR && cloud?(i, j + 1)
            dj += 1
            j += 1
          end
          z0 = (start * CELL).to_f
          z1 = ((j + 1) * CELL).to_f
          @mesh.aabb_faces(x0, HEIGHT, z0, x0 + CELL, HEIGHT + DEPTH, z1, 4 | 8, Tex::WHITE, COLOR)
          # Glow -1 marks the walls, which vcloud_box fades out with distance.
          @mesh.glow = -1.0
          ends = 0
          ends |= 16 unless cloud?(i, j + 1)
          ends |= 32 unless cloud?(i, start - 1)
          @mesh.aabb_faces(x0, HEIGHT, z0, x0 + CELL, HEIGHT + DEPTH, z1, ends, Tex::WHITE, COLOR)
          side(i, start, j, i + 1, 1)
          side(i, start, j, i - 1, 2)
          @mesh.glow = 0.0
        end
        dj += 1
      end
    end
    true
  end

  def cloud?(i, j) = @cells[(i % GRID) * GRID + (j % GRID)] == 1

  # The x side (face bit 1 for +x, 2 for -x) of the run of cells j0..j1 in
  # column i, where column ni beside it has no cloud.
  def side(i, j0, j1, ni, bit)
    x0 = (i * CELL).to_f
    j = j0
    while j <= j1
      unless cloud?(ni, j)
        start = j
        j += 1 while j < j1 && !cloud?(ni, j + 1)
        @mesh.aabb_faces(x0, HEIGHT, (start * CELL).to_f, x0 + CELL, HEIGHT + DEPTH, ((j + 1) * CELL).to_f, bit, Tex::WHITE, COLOR)
      end
      j += 1
    end
  end
end
