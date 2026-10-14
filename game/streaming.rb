# Chunk streaming: the ring of chunk slots, far terrain tiles, and remeshing.
class Game
  MESH_BUDGET_NS = 1_000_000

  # Chunk offsets in rings around the player, nearest ring first.
  def make_ring
    @ring_dx = Array.new(0, 0)
    @ring_dz = Array.new(0, 0)
    r = 0
    while r <= LOAD_R
      dx = -r
      while dx <= r
        dz = -r
        while dz <= r
          if dx.abs == r || dz.abs == r
            @ring_dx << dx
            @ring_dz << dz
          end
          dz += 1
        end
        dx += 1
      end
      r += 1
    end
  end

  # Loads and meshes the chunks within radius of chunk (pcx, pcz), nearest
  # first, until budget_ns has passed (a negative budget does all of them).
  # A chunk is meshed once its ring of neighbors has loaded.
  def stream_around(player_cx, player_cz, budget_ns, radius)
    # Spinel cannot type the player's position, so to_i gives the chunk
    # math and the world generator Integers.
    pcx = player_cx.to_i
    pcz = player_cz.to_i
    t0 = Gfx.gfx_ns
    if pcx != @stream_cx || pcz != @stream_cz
      @stream_cx = pcx
      @stream_cz = pcz
      @load_at = 0
      @mesh_at = 0
    end
    load_count = (radius * 2 + 1) * (radius * 2 + 1)
    mesh_count = (radius * 2 - 1) * (radius * 2 - 1)
    while budget_ns < 0 || Gfx.gfx_ns - t0 < budget_ns
      if @mesh_at < mesh_count
        cx = pcx + @ring_dx[@mesh_at]
        cz = pcz + @ring_dz[@mesh_at]
        if @meshed[World.slot(cx, cz)] == 1 && @world.chunk_loaded?(cx, cz)
          @mesh_at += 1
          next
        end
        if meshable?(cx, cz)
          remesh(cx, cz)
          @mesh_at += 1
          next
        end
      end
      break if @load_at >= load_count
      cx = pcx + @ring_dx[@load_at]
      cz = pcz + @ring_dz[@load_at]
      @load_at += 1
      next if @world.chunk_loaded?(cx, cz)
      @meshed[World.slot(cx, cz)] = 0
      @world.load_chunk(cx, cz)
      @tint.paint(cx, cz)
    end
  end

  # Chunks to load around the player for the view distance: the meshed ones
  # (one ring less) then reach past the fog.
  def view_radius = (((detail_view + 20.0) / CHUNK).ceil + 1).clamp(SYNC_R, LOAD_R)

  def detail_view = @fog_end < DETAIL_VIEW ? @fog_end : DETAIL_VIEW

  def far_terrain? = @fog_end > DETAIL_VIEW

  # The widest square ring of chunks around the stream center that is all meshed.
  def detail_rings = ((Math.sqrt(@mesh_at.to_f).to_i - 1) / 2)

  # The first distance a level draws: where the next finer one stops.
  def lod_start(level) = level == 0 ? DETAIL_VIEW : (LOD_REACH << (level - 1)).to_f

  # Tile rings a level builds for the current view.
  def lod_rings(level)
    reach = (LOD_REACH << level).to_f
    reach = @fog_end if @fog_end < reach
    (reach / @lods[level].tile).ceil + 1
  end

  # Far tile offsets in rings, nearest first.
  def make_lod_ring
    @lod_dx = Array.new(0, 0)
    @lod_dz = Array.new(0, 0)
    # Level L reaches LOD_REACH << L blocks with tiles of (4 << L) * CELLS
    # blocks, so every level needs the same number of rings as lod_rings gives.
    max = (LOD_REACH.to_f / (4 * Lod::CELLS)).ceil + 1
    r = 0
    while r <= max
      dx = -r
      while dx <= r
        dz = -r
        while dz <= r
          if dx.abs == r || dz.abs == r
            @lod_dx << dx
            @lod_dz << dz
          end
          dz += 1
        end
        dx += 1
      end
      r += 1
    end
  end

  # Builds the far tiles within the view, finest level and nearest first,
  # until budget_ns has passed.
  def stream_lod(budget_ns)
    t0 = Gfx.gfx_ns
    level = 0
    while level < LEVELS && @fog_end > lod_start(level)
      lod = @lods[level]
      ptx = (@player.x.floor >> lod.tile_shift).to_i
      ptz = (@player.z.floor >> lod.tile_shift).to_i
      if ptx != @lod_tx[level] || ptz != @lod_tz[level]
        @lod_tx[level] = ptx
        @lod_tz[level] = ptz
        @lod_at[level] = 0
      end
      r = lod_rings(level)
      count = (r * 2 + 1) * (r * 2 + 1)
      while @lod_at[level] < count
        return if Gfx.gfx_ns - t0 >= budget_ns
        at = @lod_at[level]
        tx = ptx + @lod_dx[at]
        tz = ptz + @lod_dz[at]
        @lod_at[level] = at + 1
        next if lod.ready?(tx, tz)
        slot = lod.build(tx, tz)
        upload_mesh(LOD_SLOT0 + level * TILE_SLOTS + slot, lod.faces, lod.offsets)
      end
      level += 1
    end
  end

  # The square a level covers with complete rings of tiles, into uniforms
  # at (the coarser level's discard square).
  def lod_square(level, at)
    lod = @lods[level]
    rc = (Math.sqrt(@lod_at[level].to_f).to_i - 1) / 2
    r = lod_rings(level)
    rc = r if rc > r
    @uniforms[at] = ((@lod_tx[level] - rc) * lod.tile).to_f
    @uniforms[at + 1] = ((@lod_tz[level] - rc) * lod.tile).to_f
    @uniforms[at + 2] = ((@lod_tx[level] + rc + 1) * lod.tile).to_f
    @uniforms[at + 3] = ((@lod_tz[level] + rc + 1) * lod.tile).to_f
  end

  def meshable?(cx, cz)
    w = @world
    w.chunk_loaded?(cx - 1, cz - 1) && w.chunk_loaded?(cx, cz - 1) && w.chunk_loaded?(cx + 1, cz - 1) &&
      w.chunk_loaded?(cx - 1, cz) && w.chunk_loaded?(cx, cz) && w.chunk_loaded?(cx + 1, cz) &&
      w.chunk_loaded?(cx - 1, cz + 1) && w.chunk_loaded?(cx, cz + 1) && w.chunk_loaded?(cx + 1, cz + 1)
  end

  def remesh(cx, cz)
    return unless meshable?(cx, cz)
    @mesher.build(cx, cz)
    s = World.slot(cx, cz)
    upload_mesh(s * 2, @mesher.opaque, @mesher.offsets)
    upload_mesh(s * 2 + 1, @mesher.water, @mesher.water_offsets)
    @has_water[s] = @mesher.water.empty? ? 0 : 1
    @meshed[s] = 1
  end

  # Sends face records (two Integers each) to GPU slot `slot`.
  def upload_mesh(slot, faces, offsets)
    abort "GPU mesh upload failed for slot #{slot}" if Gfx.gfx_mesh(slot, faces, faces.size / 2, offsets) != 0
  end

  # Marks the chunk of a block, and the chunks it touches across an edge.
  def mark_dirty(x, z)
    cx = x >> 4
    cz = z >> 4
    ex = (x & 15) == 0 ? -1 : ((x & 15) == 15 ? 1 : 0)
    ez = (z & 15) == 0 ? -1 : ((z & 15) == 15 ? 1 : 0)
    mark_chunk(cx, cz)
    mark_chunk(cx + ex, cz) if ex != 0
    mark_chunk(cx, cz + ez) if ez != 0
    mark_chunk(cx + ex, cz + ez) if ex != 0 && ez != 0
  end

  # A chunk without a mesh gets one from stream_around, so only meshed ones queue.
  def mark_chunk(cx, cz)
    return unless @world.chunk_loaded?(cx, cz)
    i = World.slot(cx.to_i, cz.to_i)
    return if @meshed[i] == 0
    if @defer
      return if @dirty[i] || @later[i]
      @later[i] = true
      @later_list << i
      return
    end
    return if @dirty[i]
    @dirty[i] = true
    @dirty_list << i
  end

  # Remeshes every chunk that an edit changed. Then it remeshes deferred
  # chunks until the frame has used MESH_BUDGET_NS.
  def flush_dirty
    t0 = Gfx.gfx_ns
    @dirty_list.each do |i|
      @dirty[i] = false
      @later[i] = false
      remesh(@world.slot_cx[i], @world.slot_cz[i]) if @meshed[i] == 1
    end
    @dirty_list.clear
    while !@later_list.empty? && Gfx.gfx_ns - t0 < MESH_BUDGET_NS
      i = @later_list.shift
      next unless @later[i]
      @later[i] = false
      remesh(@world.slot_cx[i], @world.slot_cz[i]) if @meshed[i] == 1
    end
    @mesh_ms = (Gfx.gfx_ns - t0) / 1.0e6
  end
end
