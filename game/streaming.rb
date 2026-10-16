# Chunk streaming: the ring of chunk slots, far terrain tiles, and remeshing.
class Game
  MESH_BUDGET_NS = 1_000_000

  # Chunk offsets in rings around the player, nearest ring first.
  def make_ring
    @ring_dx = Array.new(0, 0)
    @ring_dz = Array.new(0, 0)
    World.square_rings(LOAD_R, @ring_dx, @ring_dz)
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
      Log.debug(Log::STREAM) do
        "center chunk #{pcx} #{pcz}, radius #{radius}. Since the last center: #{@stream_loads} chunks loaded, " \
          "#{@stream_meshes} chunks meshed, #{@far.take_builds} far tiles built"
      end
      @stream_loads = 0
      @stream_meshes = 0
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
          @stream_meshes += 1
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
      @stream_loads += 1
    end
  end

  # Chunks to load around the player for the view distance: the meshed ones
  # (one ring less) then reach past the fog.
  def view_radius = (((detail_view + 20.0) / CHUNK).ceil + 1).clamp(SYNC_R, LOAD_R)

  def detail_view = @options.view < FarTerrain::DETAIL_VIEW ? @options.view : FarTerrain::DETAIL_VIEW

  def far_terrain? = @options.view > FarTerrain::DETAIL_VIEW

  # The widest square ring of chunks around the stream center that is all meshed.
  def detail_rings = ((Math.sqrt(@mesh_at.to_f).to_i - 1) / 2)

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
    return if @meshed[i] == 0 || @dirty[i]
    @dirty[i] = true
    @dirty_list << i
  end

  # Marks the chunk cx, cz as mark_chunk does, but its remesh can wait for
  # later frames.
  def mark_later(cx, cz)
    return unless @world.chunk_loaded?(cx, cz)
    i = World.slot(cx.to_i, cz.to_i)
    later_slot(i)
    nil
  end

  # Lets the chunks that mark_chunk marked after the first n wait for later
  # frames.
  def postpone_since(n)
    k = n
    while k < @dirty_list.size
      i = @dirty_list[k]
      @dirty[i] = false
      later_slot(i)
      k += 1
    end
    @dirty_list.pop while @dirty_list.size > n
    nil
  end

  def later_slot(i)
    return if @meshed[i] == 0 || @dirty[i] || @later[i]
    @later[i] = true
    @later_list << i
    nil
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
