# The 3D frame: uniforms, chunk and far terrain draws, and the sky.
class Game
  def render # rubocop:todo Metrics/MethodLength
    w = Gfx.gfx_width.to_f
    h = Gfx.gfx_height.to_f
    ex = @player.x.to_f
    ey = @player.eye_y.to_f
    ez = @player.z.to_f
    walking = @player.on_ground && !@player.flying
    speed = @player.speed
    ey += Math.sin(@bob) * 0.05 * (speed / 4.3).clamp(0.0, 1.0) if walking
    @camera.update_camera(ex, ey, ez, @player.yaw, @player.pitch, w / h, @options.view + 40.0, @fov)
    @camera.write_column_major(@uniforms)
    Gfx.gfx_cloud_boxes(@clouds.mesh.v, @clouds.mesh.count) if @clouds.build(ex, ez, @cloud_drift)
    set_uniforms(ex, ey, ez, w, h)
    reach = @options.view + 4.0
    cull_view(reach)
    build_dyn(ex, ey, ez, reach)
    Gfx.gfx_dyn(@dyn.v, @dyn.count, @hand_at)
    build_ui(w, h)
    Gfx.gfx_ui(@ui.v, @ui.v.size)
    @sky.build_sky(w, h, ui_scale(h))
    Gfx.gfx_sky(@sky.mesh.v, @sky.mesh.v.size)
    if @tint.changed
      Gfx.gfx_tint(@tint.pixels)
      @tint.changed = false
    end
    if Gfx.gfx_begin(@uniforms)
      visible = @chunk_meshes.visible
      @faces_drawn = Gfx.gfx_chunks(visible, visible.size / 2, 0)
      @faces_drawn += Gfx.gfx_chunks(@far.visible, @far.visible.size / 2, 2)
      Gfx.gfx_draw_dyn
      Gfx.gfx_draw_clouds
      water = @chunk_meshes.water_visible
      @faces_drawn += Gfx.gfx_chunks(water, water.size / 2, 1)
      Gfx.gfx_draw_rain
      Gfx.gfx_draw_hand unless current_screen.title?
    end
    Gfx.gfx_end
    # The frame's CPU time includes the draw calls, but not the waits.
    @cpu_end = Gfx.gfx_ns - Gfx.gfx_wait_ns
  end

  # Uniforms 16 to 27: the eye, the animation clock, the sky and fog colors,
  # daylight, the fog range, and the frame size. Then the far cloud layer and
  # the rain.
  def set_uniforms(ex, ey, ez, w, h)
    @uniforms[16] = ex
    @uniforms[17] = ey
    @uniforms[18] = ez
    # Seconds for texture animation; wraps before float precision suffers.
    @uniforms[19] = @anim_time
    @sky.write_uniforms(@uniforms, SKY_UNIFORMS, @options.view)
    if Block.water?(@world.get(ex.floor, ey.floor, ez.floor))
      # Under water, the fog is blue and near.
      @uniforms[SKY_UNIFORMS] = 0.05
      @uniforms[SKY_UNIFORMS + 1] = 0.15
      @uniforms[SKY_UNIFORMS + 2] = 0.35
      @uniforms[SKY_UNIFORMS + 3] = 24.0
      @uniforms[SKY_UNIFORMS + 5] = 2.0
    end
    @uniforms[26] = w
    @uniforms[27] = h
    @clouds.write_uniforms(@uniforms, CLOUD_UNIFORMS, ey, @cloud_drift)
    @uniforms[RAIN_UNIFORMS] = @weather.rain
    @uniforms[RAIN_UNIFORMS + 1] = Weather::R.to_f
    @uniforms[OPTION_UNIFORMS] = @options.brightness
  end

  def far_terrain? = @options.view > FarTerrain::DETAIL_VIEW

  # The draw lists of the chunks and the far terrain tiles in view, nearer
  # than reach. With far terrain on, full detail stops at the last complete
  # ring, and the far terrain shader skips the square those rings cover.
  # Uniforms 28 + 4 * L hold the square that level L skips.
  def cull_view(reach)
    rings = far_terrain? ? @chunk_meshes.detail_rings : ChunkMeshes::LOAD_R
    @chunk_meshes.detail_square(rings, @uniforms, 28)
    @chunk_meshes.cull_chunks(@camera, rings, reach)
    @far.cull_tiles(@camera, @options.view, reach, @uniforms, 28)
  end

  # Fills @dyn with the parts that change every frame: mobs, arrows, items,
  # particles, the block outline, the cracks, and last the held model.
  def build_dyn(ex, ey, ez, reach) # rubocop:todo Metrics/CyclomaticComplexity, Metrics/MethodLength
    @dyn.clear
    @mobs.each do |m|
      # 2 blocks around the feet also hold a mob that lies on its side.
      m.draw(@dyn) if entity_in_view?(m.x.to_f, m.y.to_f, m.z.to_f, 2.0, ex, ez, reach)
    end
    @arrows.each { |a| a.draw(@dyn) }
    @eggs.each { |e| e.draw(@dyn) }
    @items.each_with_index do |item, i|
      ddx = item.x - ex
      ddz = item.z - ez
      item.draw(@dyn, i.to_f) if ddx * ddx + ddz * ddz < reach * reach
    end
    @falling.each { |f| f.draw(@dyn) }
    draw_beacons(ex, ez, reach) if @beacons
    # The paddles reach past the box of a boat.
    @boats.each { |boat| boat.draw_boat(@dyn) if entity_in_view?(boat.x.to_f, boat.y.to_f, boat.z.to_f, 1.0, ex, ez, reach) }
    # The camera's right and up axes, as in Camera#update.
    fx = @player.fx
    fy = @player.fy
    fz = @player.fz
    rx = Math.cos(@player.yaw)
    rz = Math.sin(@player.yaw)
    @particles.draw(@dyn, rx, rz, -rz * fy, rz * fx - rx * fz, rx * fy)
    if @target_block.hit? && current_screen.in_game? && !mob_in_view? && !boat_in_view?
      aimed = targeted_block
      # The outline lines are max(2.5, width / 1920 * 2.5) pixels wide, as
      # in the game code of Minecraft Java (LevelRenderer); the wiki does
      # not give it. A pixel at the depth d along the view is
      # 2 * d * tan(@fov) / h blocks high (Camera#update_camera).
      h = Gfx.gfx_height.to_f
      pixels = [2.5, Gfx.gfx_width.to_f / 1920.0 * 2.5].max
      k = pixels * Math.tan(@fov.to_f) / h
      @dyn.outline(@target_block.x + Block.box_dx(aimed), @target_block.y + Block.box_dy(aimed), @target_block.z + Block.box_dz(aimed), Block.box_hx(aimed), Block.box_hz(aimed), Block.box_top(aimed),
                   ex, ey, ez, fx, fy, fz, k)
      if @mining && @mine_progress > 0.0
        e = 0.003
        x = @mine_x.to_f
        y = @mine_y.to_f
        z = @mine_z.to_f
        stage = (@mine_progress * Tex::CRACK_STAGES).to_i
        stage = Tex::CRACK_STAGES - 1 if stage >= Tex::CRACK_STAGES
        @dyn.aabb(x - e, y - e, z - e, x + 1.0 + e, y + 1.0 + e, z + 1.0 + e, Tex::CRACK + stage, 1.0, 1.0, 1.0, 1.0)
      end
    end
    @hand_at = @dyn.count
    draw_hand(ex, ey, ez)
  end

  # Adds the held item to @dyn, in the frame of the eye at ex, ey, ez.
  def draw_hand(ex, ey, ez)
    return unless current_screen.in_game?

    @held_item.place(@dyn, @player, ex, ey, ez, @fov, @swing / SWING, @draw_time, @eat_time)
  end

  # A beam of gold light from the top of each treasure chest that is not
  # looted up past the clouds, within reach of the eye x, z (BEACONS=1).
  # Minecraft has no such beam: it is for playtests.
  def draw_beacons(ex, ez, reach)
    cells = (reach / TreasureMap::CELL).ceil.to_i
    cell_x = ex.floor >> TreasureMap::CELL_BITS
    cell_z = ez.floor >> TreasureMap::CELL_BITS
    (cell_x - cells..cell_x + cells).each do |site_x|
      (cell_z - cells..cell_z + cells).each do |site_z|
        site = @world.treasure_map.site(site_x, site_z)
        x = site.chest_x
        z = site.chest_z
        next unless @treasure.unlooted?(x, site.chest_y, z) && site.distance(ex, ez) < reach

        @dyn.aabb(x - 0.5, site.chest_y + 1.0, z - 0.5, x + 1.5, WY + 64.0, z + 1.5, Tex::WHITE, 1.0, 0.85, 0.2, 1.0)
      end
    end
    nil
  end

  # True when x, y, z is within reach of the eye, and the box 2 blocks
  # around it on x and z, from 1 block under it to top over it, is in view.
  # The reach counts from the point x, y, z, not from the box as in
  # Camera#box_in_view?.
  def entity_in_view?(x, y, z, top, ex, ez, reach)
    dx = x - ex
    dz = z - ez
    return false if dx * dx + dz * dz > reach * reach

    @camera.box_visible?(x - 2.0, y - 1.0, z - 2.0, x + 2.0, y + top, z + 2.0)
  end

  def upload_clouds
    abort "cloud upload failed" unless Gfx.gfx_clouds(@clouds.pixels, Clouds::GRID)
  end
end
