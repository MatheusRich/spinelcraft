# The 3D frame: uniforms, chunk and far terrain draws, the sky, and the stars.
class Game
  STARS = 260

  def render
    w = Gfx.gfx_width.to_f
    h = Gfx.gfx_height.to_f
    ex = @player.x.to_f
    ey = @player.eye_y.to_f
    ez = @player.z.to_f
    walking = @player.on_ground && !@player.flying
    speed = Math.sqrt(@player.vx * @player.vx + @player.vz * @player.vz)
    ey += Math.sin(@bob) * 0.05 * (speed / 4.3).clamp(0.0, 1.0) if walking
    @camera.update_camera(ex, ey, ez, @player.yaw, @player.pitch, w / h, @options.view + 40.0, @fov)
    @camera.write_column_major(@uniforms)
    Gfx.gfx_cloud_boxes(@clouds.mesh.v, @clouds.mesh.count) if @clouds.build(ex, ez, @cloud_drift)
    set_uniforms(ex, ey, ez, w, h)
    reach = @options.view + 4.0
    cull_chunks(ex, ez, reach)
    cull_far_tiles(ex, ez, reach)
    build_dyn(ex, ey, ez, reach)
    Gfx.gfx_dyn(@dyn.v, @dyn.count, @hand_at)
    build_ui(w, h)
    Gfx.gfx_ui(@ui.v, @ui.v.size)
    build_sky(w, h, ui_scale(h))
    Gfx.gfx_sky(@sky.v, @sky.v.size)
    if @tint.changed
      Gfx.gfx_tint(@tint.pixels)
      @tint.changed = false
    end
    if Gfx.gfx_begin(@uniforms)
      @faces_drawn = Gfx.gfx_chunks(@visible, @visible.size / 2, 0)
      @faces_drawn += Gfx.gfx_chunks(@lod_visible, @lod_visible.size / 2, 2)
      Gfx.gfx_draw_dyn
      Gfx.gfx_draw_clouds
      @faces_drawn += Gfx.gfx_chunks(@water_visible, @water_visible.size / 2, 1)
      Gfx.gfx_draw_rain
      Gfx.gfx_draw_hand
    end
    Gfx.gfx_end
    # The frame's CPU time includes the draw calls, but not the waits.
    @cpu_end = Gfx.gfx_ns - Gfx.gfx_wait_ns
  end

  # Uniforms 16 to 27: the eye, the animation clock, the sky and fog colors,
  # daylight, the fog range, and the frame size. Then the far cloud layer and
  # the rain.
  def set_uniforms(ex, ey, ez, w, h)
    day = daylight
    under = Block.water?(@world.get(ex.floor, ey.floor, ez.floor))
    sky_r = 0.03 + 0.50 * day
    sky_g = 0.04 + 0.68 * day
    sky_b = 0.10 + 0.88 * day
    dusk = 1.0 - Math.sin(@time_of_day * Math::PI * 2.0).abs * 4.0
    if dusk > 0.0
      dusk *= 0.75
      sky_r += (1.0 - sky_r) * dusk
      sky_g += (0.55 - sky_g) * dusk
      sky_b += (0.25 - sky_b) * dusk
    end
    # Rain grays the sky, dims the light, and brings the fog nearer.
    gray = 0.06 + 0.4 * day
    sky_r += (gray - sky_r) * @weather.rain * 0.85
    sky_g += (gray - sky_g) * @weather.rain * 0.85
    sky_b += (gray * 1.08 - sky_b) * @weather.rain * 0.85
    fog = @options.view * (1.0 - 0.6 * @weather.rain)
    @uniforms[16] = ex
    @uniforms[17] = ey
    @uniforms[18] = ez
    # Seconds for texture animation; wraps before float precision suffers.
    @uniforms[19] = @anim_time
    @uniforms[20] = under ? 0.05 : sky_r
    @uniforms[21] = under ? 0.15 : sky_g
    @uniforms[22] = under ? 0.35 : sky_b
    @uniforms[23] = under ? 24.0 : fog
    @uniforms[24] = day * (1.0 - 0.35 * @weather.rain)
    # Fog at the view's end starts 65 blocks before it, or a quarter of the
    # view before it for long views, so it blends with the haze.
    @uniforms[25] = under ? 2.0 : fog - (fog * 0.25 > 65.0 ? fog * 0.25 : 65.0)
    @uniforms[26] = w
    @uniforms[27] = h
    @clouds.write_uniforms(@uniforms, CLOUD_UNIFORMS, ey, @cloud_drift)
    @uniforms[RAIN_UNIFORMS] = @weather.rain
    @uniforms[RAIN_UNIFORMS + 1] = Weather::R.to_f
    @uniforms[OPTION_UNIFORMS] = @options.brightness
  end

  def far_terrain? = @options.view > FarTerrain::DETAIL_VIEW

  # Fills @visible with the meshed chunks in the view and @water_visible with
  # their water, far chunks first.
  def cull_chunks(ex, ez, reach)
    @visible.clear
    @water_visible.clear
    @water_keys.clear
    # With far terrain on, full detail stops at the last complete ring, and
    # the far terrain shader skips the square those rings cover.
    rings = far_terrain? ? @chunk_meshes.detail_rings : ChunkMeshes::LOAD_R
    @chunk_meshes.detail_square(rings, @uniforms, 28)
    slots = @chunk_meshes.detail_slots(rings)
    k = 0
    while k < slots.size
      s = slots[k]
      x0 = (@world.slot_cx[s] * CHUNK).to_f
      z0 = (@world.slot_cz[s] * CHUNK).to_f
      dx = (x0 + 8.0 - ex).abs - 8.0
      dz = (z0 + 8.0 - ez).abs - 8.0
      dx = 0.0 if dx < 0.0
      dz = 0.0 if dz < 0.0
      d2 = dx * dx + dz * dz
      if d2 < reach * reach && @camera.box_visible?(x0, 0.0, z0, x0 + 16.0, WY.to_f, z0 + 16.0)
        slot = s * 2
        # Only directions that can face the camera.
        @visible << slot << (4 | 8 | 64 | side_mask(ex, ez, x0, z0, x0 + 16.0, z0 + 16.0))
        @water_keys << d2.to_i * LOD_SLOT0 + slot + 1 if @chunk_meshes.water_mesh?(s)
      end
      k += 1
    end
    # Water blends, so draw the far chunks first.
    @water_keys.sort!
    k = @water_keys.size - 1
    while k >= 0
      @water_visible << @water_keys[k] % LOD_SLOT0 << 127
      k -= 1
    end
  end

  # The bits of the side directions (+x 1, -x 2, +z 16, -z 32) that can face
  # a camera at ex, ez, for a box from x0, z0 to x1, z1.
  def side_mask(ex, ez, x0, z0, x1, z1)
    mask = 0
    mask |= 1 if ex > x0
    mask |= 2 if ex < x1
    mask |= 16 if ez > z0
    mask |= 32 if ez < z1
    mask
  end

  # Fills @lod_visible with the far terrain tiles in the view.
  def cull_far_tiles(ex, ez, reach)
    @lod_visible.clear
    level = 0
    while level < FarTerrain::LEVELS && @options.view > FarTerrain.level_start(level)
      # Uniforms 28 + 4 * L hold the square level L skips: full detail for
      # level 0, the complete rings of level L - 1 for the others.
      at = 28 + level * 4
      @far.skip_square(level - 1, @options.view, @uniforms, at) if level > 0
      lod = @far.lod(level)
      size = lod.tile.to_f
      s = 0
      while s < FarTerrain::TILE_SLOTS
        if lod.built[s] == 1
          x0 = lod.tile_x[s] * size
          z0 = lod.tile_z[s] * size
          x1 = x0 + size
          z1 = z0 + size
          dx = (x0 + size / 2.0 - ex).abs - size / 2.0
          dz = (z0 + size / 2.0 - ez).abs - size / 2.0
          dx = 0.0 if dx < 0.0
          dz = 0.0 if dz < 0.0
          inside = x0 >= @uniforms[at] && z0 >= @uniforms[at + 1] && x1 <= @uniforms[at + 2] && z1 <= @uniforms[at + 3]
          if !inside && dx * dx + dz * dz < reach * reach && @camera.box_visible?(x0, 0.0, z0, x1, WY.to_f + 8.0, z1)
            @lod_visible << LOD_SLOT0 + level * FarTerrain::TILE_SLOTS + s << (4 | side_mask(ex, ez, x0, z0, x1, z1))
          end
        end
        s += 1
      end
      level += 1
    end
  end

  # Fills @dyn with the parts that change every frame: mobs, arrows, items,
  # particles, the block outline, the cracks, and last the held model.
  def build_dyn(ex, ey, ez, reach)
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
    # The paddles reach past the box of a boat.
    @boats.each { |boat| boat.draw_boat(@dyn) if entity_in_view?(boat.x.to_f, boat.y.to_f, boat.z.to_f, 1.0, ex, ez, reach) }
    # The camera's right and up axes, as in Camera#update.
    fx = @player.fx
    fy = @player.fy
    fz = @player.fz
    rx = Math.cos(@player.yaw)
    rz = Math.sin(@player.yaw)
    @particles.draw(@dyn, rx, rz, -rz * fy, rz * fx - rx * fz, rx * fy)
    if @player.hit && @captured && @target_mob < 0 && @target_boat < 0
      aimed = @world.get(@player.hx, @player.hy, @player.hz)
      # The outline lines are max(2.5, width / 1920 * 2.5) pixels wide, as
      # in the game code of Minecraft Java (LevelRenderer); the wiki does
      # not give it. A pixel at the depth d along the view is
      # 2 * d * tan(@fov) / h blocks high (Camera#update_camera).
      h = Gfx.gfx_height.to_f
      pixels = [2.5, Gfx.gfx_width.to_f / 1920.0 * 2.5].max
      k = pixels * Math.tan(@fov.to_f) / h
      @dyn.outline(@player.hx + Block.box_dx(aimed), @player.hy + Block.box_dy(aimed), @player.hz + Block.box_dz(aimed), Block.box_hx(aimed), Block.box_hz(aimed), Block.box_top(aimed),
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

  # True when x, y, z is within reach of the eye, and the box 2 blocks
  # around it on x and z, from 1 block under it to top over it, is in view.
  def entity_in_view?(x, y, z, top, ex, ez, reach)
    dx = x - ex
    dz = z - ez
    return false if dx * dx + dz * dz > reach * reach
    @camera.box_visible?(x - 2.0, y - 1.0, z - 2.0, x + 2.0, y + top, z + 2.0)
  end

  def upload_clouds
    abort "cloud upload failed" unless Gfx.gfx_clouds(@clouds.pixels, Clouds::GRID)
  end

  # Star directions on the upper sphere, fixed for the world.
  def make_stars
    @stars = []
    rng = Rng.new(977)
    i = 0
    while i < STARS
      u = (rng.next_int % 10000) / 10000.0
      v = (rng.next_int % 10000) / 10000.0
      bright = 0.4 + (rng.next_int % 600) / 1000.0
      theta = u * 6.283185
      y = v * 1.6 - 0.6
      r = Math.sqrt(1.0 - y * y)
      @stars << r * Math.cos(theta) << y << r * Math.sin(theta) << bright
      i += 1
    end
  end

  # Sky layer: drawn before the world, so terrain and clouds cover it.
  def build_sky(w, h, s)
    @sky.clear
    draw_sky_body(w, h, s, 1.0, Tex::WHITE, 1.0, 0.95, 0.75, 70.0, 1.0)
    phase = @day % 8
    draw_sky_body(w, h, s, -1.0, Tex::MOON + phase, 1.0, 1.0, 1.0, 46.0, MOON_LIT[phase])
    # Rain hides the stars.
    night = (0.55 - daylight) * 2.5 * (1.0 - @weather.rain)
    return if night <= 0.0
    night = 1.0 if night > 1.0
    a = @time_of_day * Math::PI * 2.0
    ca = Math.cos(a)
    sa = Math.sin(a)
    ex = @player.x.to_f
    ey = @player.eye_y.to_f
    ez = @player.z.to_f
    i = 0
    while i < @stars.size
      # The stars turn with the sun around the z axis.
      sx = @stars[i]
      sy = @stars[i + 1]
      rx = sx * ca - sy * sa
      ry = sx * sa + sy * ca
      if ry > -0.05
        if @camera.project(ex + rx * 100.0, ey + ry * 100.0, ez + @stars[i + 2] * 100.0, w, h)
          size = 2.0 * s
          c = @stars[i + 3]
          @sky.rect(@camera.sx, @camera.sy, size, size, c, c, c * 1.05, night)
        end
      end
      i += 4
    end
  end

  # The sun (side 1) or the moon (side -1): the texture layer with the color
  # r, g, b, in a glow that is as bright as the lit part.
  def draw_sky_body(w, h, s, side, layer, r, g, b, size, lit)
    a = @time_of_day * Math::PI * 2.0
    dx = Math.cos(a) * side
    dy = Math.sin(a) * side
    dz = 0.25
    return if dy < -0.15
    ex = @player.x.to_f
    ey = @player.eye_y.to_f
    ez = @player.z.to_f
    return unless @camera.project(ex + dx * 100.0, ey + dy * 100.0, ez + dz * 100.0, w, h)
    half = size * s / 2.0
    sx = @camera.sx
    sy = @camera.sy
    # Rain hides the sun and the moon.
    clear = 1.0 - @weather.rain
    return if clear <= 0.0
    @sky.rect(sx - half * 1.4, sy - half * 1.4, half * 2.8, half * 2.8, r, g, b, 0.18 * clear * lit)
    @sky.quad(sx - half, sy - half, half * 2.0, half * 2.0, layer, 1.0, 1.0, r, g, b, clear)
  end
end
