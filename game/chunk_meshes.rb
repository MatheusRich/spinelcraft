# The full-detail chunks around the player and their meshes on the GPU.
# Each chunk slot of the World has two GPU meshes: slot * 2 for the opaque
# faces and slot * 2 + 1 for the water. stream loads and meshes the chunks
# in square rings around a center chunk, nearest first. An edit marks the
# chunks that it changes, and flush remeshes them.
class ChunkMeshes
  # Chunks within LOAD_R of the center are loaded. A chunk is meshed only
  # when its neighbors are loaded too, so meshes reach one chunk less.
  LOAD_R = RING / 2 - 1
  # The time that flush has each frame for the remeshes that can wait.
  MESH_BUDGET_NS = 1_000_000
  # The GPU slots of the chunk meshes, two for each chunk slot. The far
  # terrain tiles come after them.
  GPU_SLOTS = CX * CZ * 2

  # The milliseconds of the last flush, for the debug screen.
  attr_reader :mesh_ms
  # The draw lists of the last cull_chunks: a GPU slot and the bits of its
  # face directions for each mesh.
  attr_reader :visible, :water_visible

  # The chunk meshes of world. A chunk gets its tint from tint when it
  # loads.
  def initialize(world, tint)
    @world = world
    @tint = tint
    @mesher = Mesher.new(world)
    # Chunk offsets in rings around the center, nearest ring first.
    @ring_dx = Array.new(0, 0)
    @ring_dz = Array.new(0, 0)
    World.square_rings(LOAD_R, @ring_dx, @ring_dz)
    # 1 when the chunk of a slot has a current mesh on the GPU, and 1 when
    # that mesh has water faces.
    @meshed = Array.new(CX * CZ, 0)
    @has_water = Array.new(CX * CZ, 0)
    # The center chunk, and the next ring entry to load and to mesh.
    @center_x = World::NONE
    @center_z = World::NONE
    @load_at = 0
    @mesh_at = 0
    # The chunks loaded and meshed since the center last moved (for
    # Log::STREAM).
    @loads = 0
    @meshes = 0
    # The chunks to remesh in this frame, and the chunks that can wait a few
    # frames: torch light and flowing water.
    @dirty = Array.new(CX * CZ, false)
    @dirty_list = Array.new(0, 0)
    @later = Array.new(CX * CZ, false)
    @later_list = Array.new(0, 0)
    @mesh_ms = 0.0
    @detail = Array.new(0, 0)
    @visible = Array.new(0, 0)
    @water_visible = Array.new(0, 0)
    # The sort keys of the water meshes in view: distance * GPU_SLOTS + GPU
    # slot.
    @water_keys = Array.new(0, 0)
  end

  # Loads and meshes the chunks within radius of chunk (pcx, pcz), nearest
  # first, until budget_ns has passed (a negative budget does all of them).
  # A chunk is meshed once its ring of neighbors has loaded.
  def stream(player_cx, player_cz, budget_ns, radius) # rubocop:todo Metrics/MethodLength
    # Spinel cannot type the player's position, so to_i gives the chunk
    # math and the world generator Integers.
    pcx = player_cx.to_i
    pcz = player_cz.to_i
    t0 = Gfx.gfx_ns
    if pcx != @center_x || pcz != @center_z
      Log.debug(Log::STREAM) do
        "center chunk #{pcx} #{pcz}, radius #{radius}. Since the last center: #{@loads} chunks loaded, #{@meshes} chunks meshed"
      end
      @loads = 0
      @meshes = 0
      @center_x = pcx
      @center_z = pcz
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
          @meshes += 1
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
      @loads += 1
    end
    nil
  end

  # The widest square ring of chunks around the center that is all meshed.
  def detail_rings = ((Math.sqrt(@mesh_at.to_f).to_i - 1) / 2)

  # Writes into uniforms at the square of the chunks within rings of the
  # center, in blocks. The far terrain skips that square.
  def detail_square(rings, uniforms, at)
    uniforms[at] = ((@center_x - rings) * CHUNK).to_f
    uniforms[at + 1] = ((@center_z - rings) * CHUNK).to_f
    uniforms[at + 2] = ((@center_x + rings + 1) * CHUNK).to_f
    uniforms[at + 3] = ((@center_z + rings + 1) * CHUNK).to_f
    nil
  end

  # The slots of the meshed chunks within rings of the center. Each call
  # fills the same Array again.
  def detail_slots(rings)
    @detail.clear
    (CX * CZ).times do |s|
      if @meshed[s] == 1 && (@world.slot_cx[s] - @center_x).abs <= rings && (@world.slot_cz[s] - @center_z).abs <= rings
        @detail << s
      end
    end
    @detail
  end

  # Fills visible with the meshed chunks within rings of the center that
  # camera sees nearer than reach, and water_visible with their water, far
  # chunks first.
  def cull_chunks(camera, rings, reach)
    @visible.clear
    @water_visible.clear
    @water_keys.clear
    slots = detail_slots(rings)
    slots.size.times do |k|
      s = slots[k]
      x0 = (@world.slot_cx[s] * CHUNK).to_f
      z0 = (@world.slot_cz[s] * CHUNK).to_f
      x1 = x0 + 16.0
      z1 = z0 + 16.0
      if camera.box_in_view?(x0, 0.0, z0, x1, WY.to_f, z1, reach)
        slot = s * 2
        # Only directions that can face the camera.
        @visible << slot << (4 | 8 | 64 | camera.facing_sides(x0, z0, x1, z1))
        @water_keys << camera.box_distance2(x0, z0, x1, z1).to_i * GPU_SLOTS + slot + 1 if @has_water[s] == 1
      end
    end
    # Water blends, so draw the far chunks first.
    @water_keys.sort!
    (@water_keys.size - 1).downto(0) { |k| @water_visible << @water_keys[k] % GPU_SLOTS << 127 }
    nil
  end

  # Sets the FAST graphics for the leaves (Mesher#fast_leaves). The meshes
  # that exist change in the frames that follow, as the remeshes of
  # torch light do.
  def fast_leaves=(on)
    return if on == @mesher.fast_leaves

    @mesher.fast_leaves = on
    (CX * CZ).times { |slot| later_slot(slot) }
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
    nil
  end

  # Sends face records (two Integers each) to GPU slot `slot`.
  def upload_mesh(slot, faces, offsets)
    abort "GPU mesh upload failed for slot #{slot}" if Gfx.gfx_mesh(slot, faces, faces.size / 2, offsets) != 0
  end

  # Marks the chunk of the block x, z, and the chunks that it touches across
  # an edge.
  def mark_block(x, z)
    cx = x >> 4
    cz = z >> 4
    ex = (x & 15) == 0 ? -1 : ((x & 15) == 15 ? 1 : 0)
    ez = (z & 15) == 0 ? -1 : ((z & 15) == 15 ? 1 : 0)
    mark_chunk(cx, cz)
    mark_chunk(cx + ex, cz) if ex != 0
    mark_chunk(cx, cz + ez) if ez != 0
    mark_chunk(cx + ex, cz + ez) if ex != 0 && ez != 0
    nil
  end

  # A chunk without a mesh gets one from stream, so only meshed ones queue.
  def mark_chunk(cx, cz)
    return unless @world.chunk_loaded?(cx, cz)

    i = World.slot(cx.to_i, cz.to_i)
    return if @meshed[i] == 0 || @dirty[i]

    @dirty[i] = true
    @dirty_list << i
    nil
  end

  # Marks the chunk cx, cz as mark_chunk does, but its remesh can wait for
  # later frames.
  def mark_later(cx, cz)
    return unless @world.chunk_loaded?(cx, cz)

    i = World.slot(cx.to_i, cz.to_i)
    later_slot(i)
    nil
  end

  # The count of chunks that mark_chunk marked, for postpone_since.
  def dirty_count = @dirty_list.size

  # Lets the chunks that mark_chunk marked after the first n wait for later
  # frames.
  def postpone_since(n)
    (n...@dirty_list.size).each do |k|
      i = @dirty_list[k]
      @dirty[i] = false
      later_slot(i)
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

  # True when the chunk cx, cz waits for a remesh.
  def queued?(cx, cz)
    return false unless @world.chunk_loaded?(cx, cz)

    i = World.slot(cx, cz)
    @dirty[i] == true || @later[i] == true
  end

  # Remeshes every chunk that mark_chunk marked. Then it remeshes the chunks
  # that can wait until the frame has used MESH_BUDGET_NS. A frame with no
  # marked chunk keeps the time of the last flush.
  def flush
    return if @dirty_list.empty? && @later_list.empty?

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
    nil
  end

  # Remeshes every marked chunk now, also the ones that can wait.
  def flush_all
    flush while !@dirty_list.empty? || !@later_list.empty?
    nil
  end
end
