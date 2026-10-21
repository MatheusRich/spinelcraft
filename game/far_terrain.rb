# The far terrain past the full-detail chunks: one Lod for each of LEVELS
# levels. Each level builds its tiles in square rings around the tile of
# the player, nearest first, and keeps how far it got.
class FarTerrain
  # Full-detail chunks reach this far at most, and far terrain draws the
  # rest. This is also the limit of the chunk ring: Game#view_radius adds
  # 20 blocks and one ring, and 460 gives ChunkMeshes::LOAD_R.
  DETAIL_VIEW = 460.0
  # Level L has cells of 4 << L blocks and reaches REACH << L blocks, so
  # each level has about the same number of tiles.
  LEVELS = 4
  REACH = 640
  # The GPU slots of the tiles of one level.
  TILE_SLOTS = Lod::TRING * Lod::TRING

  # The draw list of the last cull_tiles: a GPU slot and the bits of its
  # face directions for each tile.
  attr_reader :visible

  # The far land of terrain (a Terrain). Its tiles go to the GPU slots from slot0 on,
  # TILE_SLOTS for each level.
  def initialize(terrain, slot0)
    @slot0 = slot0
    @lods = Array.new(LEVELS) { |l| Lod.new(terrain, l) }
    # Tile offsets in rings, nearest first. Level L reaches REACH << L
    # blocks with tiles of (4 << L) * CELLS blocks, so every level needs
    # the same number of rings.
    @ring_dx = Array.new(0, 0)
    @ring_dz = Array.new(0, 0)
    World.square_rings((REACH.to_f / (4 * Lod::CELLS)).ceil + 1, @ring_dx, @ring_dz)
    # For each level: the tile that its rings center on, and the next
    # ring entry to build.
    @center_x = Array.new(LEVELS, World::NONE)
    @center_z = Array.new(LEVELS, World::NONE)
    @built_at = Array.new(LEVELS, 0)
    @builds = 0
    @visible = Array.new(0, 0)
  end

  # The Lod of level l.
  def lod(l) = @lods[l]

  # The first distance that level l draws: where the next finer one stops.
  def self.level_start(l) = l == 0 ? DETAIL_VIEW : (REACH << (l - 1)).to_f

  # The tile rings that level l builds for a view of view blocks.
  def tile_rings(l, view)
    reach = (REACH << l).to_f
    reach = view if view < reach
    (reach / @lods[l].tile).ceil + 1
  end

  # Builds the tiles around block x, z within view blocks, finest level and
  # nearest first, until budget_ns has passed.
  def build_tiles(x, z, view, budget_ns)
    t0 = Gfx.gfx_ns
    l = 0
    while l < LEVELS && view > FarTerrain.level_start(l)
      lod = @lods[l]
      tx = x >> lod.tile_shift
      tz = z >> lod.tile_shift
      center_level(l, tx, tz)
      r = tile_rings(l, view)
      count = (r * 2 + 1) * (r * 2 + 1)
      while @built_at[l] < count
        return if Gfx.gfx_ns - t0 >= budget_ns

        at = @built_at[l]
        @built_at[l] = at + 1
        next if lod.ready?(tx + @ring_dx[at], tz + @ring_dz[at])

        slot = lod.build(tx + @ring_dx[at], tz + @ring_dz[at])
        @builds += 1
        upload_tile(@slot0 + l * TILE_SLOTS + slot, lod.faces, lod.offsets)
      end
      l += 1
    end
    nil
  end

  # Writes into uniforms at the square that level l covers with complete
  # rings of tiles, for a view of view blocks. The next coarser level skips
  # that square.
  def skip_square(l, view, uniforms, at)
    tile = @lods[l].tile
    rc = (Math.sqrt(@built_at[l].to_f).to_i - 1) / 2
    r = tile_rings(l, view)
    rc = r if rc > r
    uniforms[at] = ((@center_x[l] - rc) * tile).to_f
    uniforms[at + 1] = ((@center_z[l] - rc) * tile).to_f
    uniforms[at + 2] = ((@center_x[l] + rc + 1) * tile).to_f
    uniforms[at + 3] = ((@center_z[l] + rc + 1) * tile).to_f
  end

  # Fills visible with the built tiles that camera sees nearer than reach,
  # on the levels that a view of view blocks reaches. Level L skips the
  # square in uniforms at at + 4 * L: the full detail for level 0, which the
  # caller writes there, and the complete rings of level L - 1 for the
  # others.
  def cull_tiles(camera, view, reach, uniforms, at)
    @visible.clear
    level = 0
    while level < LEVELS && view > FarTerrain.level_start(level)
      skip_at = at + level * 4
      skip_square(level - 1, view, uniforms, skip_at) if level > 0
      lod = @lods[level]
      size = lod.tile.to_f
      TILE_SLOTS.times do |s|
        if lod.built[s] == 1
          x0 = lod.tile_x[s] * size
          z0 = lod.tile_z[s] * size
          x1 = x0 + size
          z1 = z0 + size
          inside = x0 >= uniforms[skip_at] && z0 >= uniforms[skip_at + 1] && x1 <= uniforms[skip_at + 2] && z1 <= uniforms[skip_at + 3]
          if !inside && camera.box_in_view?(x0, 0.0, z0, x1, WY.to_f + 8.0, z1, reach)
            @visible << @slot0 + level * TILE_SLOTS + s << (4 | camera.facing_sides(x0, z0, x1, z1))
          end
        end
      end
      level += 1
    end
    nil
  end

  # The count of tiles built since the last call, for Log::STREAM.
  def take_builds
    n = @builds
    @builds = 0
    n
  end

  # Starts the rings of level l again from tile tx, tz when the player
  # moves to a new tile.
  def center_level(l, tx, tz)
    return if tx == @center_x[l] && tz == @center_z[l]

    Log.debug(Log::STREAM) { "center far tile #{tx} #{tz}. Since the last center: #{take_builds} far tiles built" } if l == 0
    @center_x[l] = tx
    @center_z[l] = tz
    @built_at[l] = 0
  end

  # Sends the face records of a tile (two Integers each) to GPU slot slot.
  def upload_tile(slot, faces, offsets)
    abort "GPU mesh upload failed for slot #{slot}" if Gfx.gfx_mesh(slot, faces, faces.size / 2, offsets) != 0
  end
end
