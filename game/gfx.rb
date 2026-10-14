# Thin SDL3 layer: window, input, and the SDL GPU (Metal) renderer.
# Every game decision lives in Ruby; this file only moves data to SDL.
module Gfx
  ffi_lib "SDL3"
  ffi_lib "vorbisfile"
  ffi_cflags "-I/opt/homebrew/include -L/opt/homebrew/lib"
  ffi_source <<~'C'
    #include <SDL3/SDL.h>
    #include <math.h>
    #include <vorbis/vorbisfile.h>
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>

    static SDL_Window *win;
    static SDL_GPUDevice *dev;
    static SDL_GPUGraphicsPipeline *p_chunk, *p_water, *p_lod, *p_dyn, *p_ui, *p_cloud, *p_cloud_box, *p_cloud_depth, *p_hand, *p_rain;
    static SDL_GPUTexture *atlas, *skins, *depth_tex, *cloud_tex;
    static SDL_GPUSampler *sampler, *cloud_sampler;
    static SDL_GPUTextureFormat depth_fmt;
    static Uint32 depth_w, depth_h;
    static SDL_GPUCommandBuffer *cmd;
    static SDL_GPURenderPass *pass;
    static SDL_GPUTexture *swap_tex;
    static Uint32 swap_w = 1280, swap_h = 720;
    /* These sizes must match the Ruby side. gfx_limit returns them, and
       Game#check_gfx_limits compares them with LEVELS, Mesher::COLUMNS and
       the GPU slots that the game uses. */
    #define LEVELS 4
    #define UNIFORMS (44 + 4 * LEVELS)
    #define COLUMNS 1024
    #define STR2(x) #x
    #define STR(x) STR2(x)
    static float uni[UNIFORMS];
    static char shot_path[1024];
    static Uint64 gpu_wait_ns, gpu_frames;
    /* Time that this frame waited for the swapchain or the GPU, not CPU work. */
    static Uint64 frame_wait_ns;
    static SDL_GPUTexture *shot_tex;
    static SDL_GPUTextureFormat swap_fmt;

    #define MAX_SLOTS 32768
    /* The faces of every chunk and far tile live in one GPU buffer, the arena,
       so a pass binds one vertex buffer. Sizes and positions in the arena
       count faces of 8 bytes. A slot owns the range slot_at, slot_len. A new
       mesh gets a new range, and the old range stays reserved for
       RETIRE_FRAMES frames, because a frame on the GPU can still read it. */
    #define ARENA_START (1u << 22)
    #define RETIRE_FRAMES 3
    #define MAX_RETIRE (MAX_SLOTS * 2)
    #define MAX_FREE (MAX_SLOTS + MAX_RETIRE + 1)
    static SDL_GPUBuffer *arena, *arena_old;
    static Uint32 arena_cap, arena_copy;
    static Uint32 free_at[MAX_FREE], free_len[MAX_FREE];
    static int nfree;
    static Uint32 retire_at[MAX_RETIRE], retire_len[MAX_RETIRE];
    static Uint64 retire_frame[MAX_RETIRE];
    static int nretire;
    static Uint64 frame_no;
    static Uint32 slot_at[MAX_SLOTS], slot_len[MAX_SLOTS], slot_count[MAX_SLOTS];
    static Uint32 slot_off[MAX_SLOTS][8];
    static SDL_GPUBuffer *quad_index;

    typedef struct { SDL_GPUTransferBuffer *tb; Uint32 at, size; } Pending;
    static Pending pending[MAX_SLOTS];
    static int npending;

    /* A dynamic vertex: x y z, u v, layer, r g b a, glow (Mesh3#vert). */
    #define DYN_FLOATS 11
    #define DYN_CAP (1 << 18)
    #define UI_CAP (1 << 16)
    static SDL_GPUBuffer *dyn_buf, *ui_buf, *sky_buf;
    static SDL_GPUTransferBuffer *dyn_tb, *ui_tb, *sky_tb;
    static Uint32 dyn_count, ui_count, sky_count;
    /* The dynamic vertices from hand_first on are the held item. */
    static Uint32 hand_first;
    #define SKY_CAP 8192
    /* The cloud boxes change only when the player's cloud cell changes. */
    #define CLOUD_CAP (1 << 17)
    static SDL_GPUBuffer *cloud_buf;
    static SDL_GPUTransferBuffer *cloud_tb;
    static Uint32 cloud_count;
    static int cloud_changed;
    /* The rain quads change only when the player moves to another block. */
    #define RAIN_CAP (1 << 15)
    static SDL_GPUBuffer *rain_buf;
    static SDL_GPUTransferBuffer *rain_tb;
    static Uint32 rain_count;
    static int rain_changed;

    static char keys_now[SDL_SCANCODE_COUNT], keys_prev[SDL_SCANCODE_COUNT];
    static float mouse_dx, mouse_dy, wheel;
    static Uint32 buttons_now, buttons_prev;
    static int quit_requested, focus_lost;

    static const char *MSL =
      "#include <metal_stdlib>\n"
      "using namespace metal;\n"
      "struct U { float4x4 vp; float4 cam; float4 fog; float4 misc; float4 lod[" STR(LEVELS) "]; float4 cloud; float4 cloud_near; float4 rain; float4 opt; };\n"
      "struct VOut { float4 pos [[position]]; float2 uv; float layer [[flat]]; float4 color; float fog; };\n"
      "struct VChunk { uint2 d [[attribute(0)]]; };\n"
      "constant float3 CORNER[10][4] = {\n"
      "  {{1,0,1},{1,0,0},{1,1,0},{1,1,1}}, {{0,0,0},{0,0,1},{0,1,1},{0,1,0}},\n"
      "  {{0,1,1},{1,1,1},{1,1,0},{0,1,0}}, {{0,0,0},{1,0,0},{1,0,1},{0,0,1}},\n"
      "  {{0,0,1},{1,0,1},{1,1,1},{0,1,1}}, {{1,0,0},{0,0,0},{0,1,0},{1,1,0}},\n"
      "  {{0.15,0,0.15},{0.85,0,0.85},{0.85,1,0.85},{0.15,1,0.15}}, {{0.85,0,0.85},{0.15,0,0.15},{0.15,1,0.15},{0.85,1,0.85}},\n"
      "  {{0.85,0,0.15},{0.15,0,0.85},{0.15,1,0.85},{0.85,1,0.15}}, {{0.15,0,0.85},{0.85,0,0.15},{0.85,1,0.15},{0.15,1,0.85}} };\n"
      "constant float2 UV[4] = {{0,1},{1,1},{1,0},{0,0}};\n"
      "constant float2 BACK[4] = {{-1,0},{1,0},{0,-1},{0,1}};\n"
      "// The boxes of Block::SHAPE_BOX, in sixteenths of the cell.\n"
      "constant float SHAPE[6][6] = {{0,0,0,16,16,16}, {13,0,0,16,16,16}, {0,0,13,16,16,16}, {0,0,0,1,16,16},\n"
      "                              {1,0,1,15,14,15}, {0,0,0,16,9,16}};\n"
      "// v (x, z) turned d quarter turns: +x goes to the direction d of Block::DIR_DX.\n"
      "float2 turn(uint d, float2 v) { return d == 0u ? v : (d == 1u ? -v : (d == 2u ? float2(-v.y, v.x) : float2(v.y, -v.x))); }\n"
      "// Light for each face direction; Mesh3::SHADE in mesh3.rb has the same values.\n"
      "constant float SHADE[10] = {0.82, 0.82, 1.0, 0.55, 0.9, 0.9, 0.95, 0.95, 0.95, 0.95};\n"
      "float fog_of(float3 p, constant U &u) {\n"
      "  float d = length(p - u.cam.xyz);\n"
      "  float edge = clamp((d - u.misc.y) / (u.fog.w - u.misc.y), 0.0, 1.0);\n"
      "  // Haze: the more air between the camera and p, the more p takes the sky color.\n"
      "  float haze = 1.0 - exp(-d / 1800.0);\n"
      "  return max(edge, haze);\n"
      "}\n"
      "// The brightness option, u.opt.x from 0 to 1, lifts the light l toward\n"
      "// 1 - (1 - l)^4, as the brightness option of Minecraft does.\n"
      "float bright(float l, constant U &u) {\n"
      "  float d = 1.0 - l;\n"
      "  return mix(l, 1.0 - d * d * d * d, u.opt.x);\n"
      "}\n"
      "vertex VOut vchunk(VChunk in [[stage_in]], uint vid [[vertex_id]], constant U &u [[buffer(0)]]) {\n"
      "  uint w0 = in.d.x, w1 = in.d.y;\n"
      "  float3 bp = float3(w0 & 1023u, (w0 >> 10) & 127u, (w0 >> 17) & 1023u);\n"
      "  // x and z are storage columns of a ring of COLUMNS blocks; use the copy nearest the camera.\n"
      "  bp.x += " STR(COLUMNS) ".0 * floor((u.cam.x - bp.x) / " STR(COLUMNS) ".0 + 0.5);\n"
      "  bp.z += " STR(COLUMNS) ".0 * floor((u.cam.z - bp.z) / " STR(COLUMNS) ".0 + 0.5);\n"
      "  uint face = (w0 >> 27) & 15u;\n"
      "  uint c = (vid + ((w1 >> 16) & 1u)) & 3u;\n"
      "  float3 corner = CORNER[face][c];\n"
      "  float3 p = bp + corner;\n"
      "  // Bits 25-27 of a plant hold 1 + the facing of a wall torch (Block::FACING). BACK is the\n"
      "  // step to its wall. The torch moves up and toward the wall, and leans out of it (Block.wall_lean).\n"
      "  uint facing = (w1 >> 25) & 7u;\n"
      "  uint shape = (w1 >> 28) & 7u;\n"
      "  float2 uv = UV[c];\n"
      "  if (facing != 0u && face >= 6u) {\n"
      "    p.xz += BACK[facing - 1u] * (0.42 - 0.4 * corner.y);\n"
      "    p.y += 0.2;\n"
      "  } else if (shape != 0u) {\n"
      "    // Bits 28-30 of a cube face hold the shape of its block (Block::SHAPE), and bits 25-27\n"
      "    // hold 1 + its facing. The corner turns back to the block that faces +x, moves onto the\n"
      "    // box of the shape, and turns to the facing again. The face takes the part of the\n"
      "    // texture under it on that block: u along x (along z on an x face), and v down from\n"
      "    // the top (along z on the top and the bottom).\n"
      "    uint d = facing - 1u;\n"
      "    float2 m = turn(d < 2u ? d : d ^ 1u, corner.xz - 0.5) + 0.5;\n"
      "    float3 lo = float3(SHAPE[shape][0], SHAPE[shape][1], SHAPE[shape][2]) / 16.0;\n"
      "    float3 hi = float3(SHAPE[shape][3], SHAPE[shape][4], SHAPE[shape][5]) / 16.0;\n"
      "    float3 q = mix(lo, hi, float3(m.x, corner.y, m.y));\n"
      "    p = bp + float3(0.5, q.y, 0.5);\n"
      "    p.xz += turn(d, q.xz - 0.5);\n"
      "    // A quarter turn makes an x face of the block a z face of the cell.\n"
      "    bool xface = (face < 2u) == (d < 2u);\n"
      "    uv = face == 2u || face == 3u ? q.xz : float2(xface ? q.z : q.x, 1.0 - q.y);\n"
      "  }\n"
      "  bool sunk = ((w1 >> 18) & 1u) != 0u;\n"
      "  if (sunk && corner.y > 0.5) p.y -= 0.12 + float((w1 >> 8) & 7u) * 0.11;\n"
      "  float ao = sunk ? 1.0 : 0.5 + float((w1 >> (8 + 2 * c)) & 3u) * 0.5 / 3.0;\n"
      "  float day = u.misc.x;\n"
      "  float light = ((w1 >> 17) & 1u) != 0u ? (0.12 + 0.88 * day) : (0.08 + 0.37 * day);\n"
      "  // 14 is Mesher::LIGHT_MAX, the light at a torch.\n"
      "  float torch = pow(float((w1 >> 19) & 15u) / 14.0, 1.6);\n"
      "  float warm = clamp((torch - light) * 3.0, 0.0, 1.0);\n"
      "  light = bright(max(light, torch), u);\n"
      "  float s = SHADE[face] * ao * light;\n"
      "  VOut o;\n"
      "  o.pos = u.vp * float4(p, 1.0);\n"
      "  o.uv = uv;\n"
      "  // Bits 23-24 scroll the texture: 1 like water, 2 like lava (Tex.scroll).\n"
      "  uint scroll = (w1 >> 23) & 3u;\n"
      "  if (scroll == 1u) o.uv += float2(u.cam.w * 0.06, u.cam.w * 0.1);\n"
      "  if (scroll == 2u) o.uv += float2(u.cam.w * 0.02, u.cam.w * 0.035);\n"
      "  o.layer = float(w1 & 255u);\n"
      "  o.color = float4(float3(s) * mix(float3(1.0), float3(1.0, 0.82, 0.6), warm), 1.0);\n"
      "  o.fog = fog_of(p, u);\n"
      "  return o;\n"
      "}\n"
      "// Far terrain: one record per face of a cell of 2^s x 2^s blocks (level s - 2).\n"
      "// w0 holds the cell column in a ring of COLUMNS cells, the base y and the face;\n"
      "// w1 the texture, the face height in blocks and s.\n"
      "struct VOutL { float4 pos [[position]]; float2 uv; float layer [[flat]]; float4 color; float fog; float2 wp; uint level [[flat]]; };\n"
      "vertex VOutL vlod(VChunk in [[stage_in]], uint vid [[vertex_id]], constant U &u [[buffer(0)]]) {\n"
      "  uint w0 = in.d.x, w1 = in.d.y;\n"
      "  uint sh = (w1 >> 15) & 7u;\n"
      "  float cs = float(1u << sh);\n"
      "  float ring = " STR(COLUMNS) ".0 * cs;\n"
      "  float3 bp = float3(float(w0 & 1023u) * cs, float((w0 >> 10) & 127u), float((w0 >> 17) & 1023u) * cs);\n"
      "  bp.x += ring * floor((u.cam.x - bp.x) / ring + 0.5);\n"
      "  bp.z += ring * floor((u.cam.z - bp.z) / ring + 0.5);\n"
      "  uint face = (w0 >> 27) & 15u;\n"
      "  uint c = vid & 3u;\n"
      "  float hgt = float((w1 >> 8) & 127u);\n"
      "  float3 corner = CORNER[face][c];\n"
      "  float3 p = bp + corner * float3(cs, hgt, cs);\n"
      "  float day = u.misc.x;\n"
      "  float s = SHADE[face] * bright(0.12 + 0.88 * day, u);\n"
      "  VOutL o;\n"
      "  o.pos = u.vp * float4(p, 1.0);\n"
      "  o.uv = face == 2u ? UV[c] * cs : UV[c] * float2(cs, hgt);\n"
      "  o.layer = float(w1 & 255u);\n"
      "  o.color = float4(float3(s), 1.0);\n"
      "  o.fog = fog_of(p, u);\n"
      "  o.wp = p.xz;\n"
      "  o.level = sh - 2u;\n"
      "  return o;\n"
      "}\n"
      "// u.lod[L] is the square (x0, z0, x1, z1) that the next finer level covers:\n"
      "// full-detail chunks for level 0, level L - 1 for level L.\n"
      "fragment float4 flod(VOutL in [[stage_in]], constant U &u [[buffer(0)]],\n"
      "                     texture2d_array<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {\n"
      "  float4 r = u.lod[in.level];\n"
      "  if (in.wp.x > r.x && in.wp.x < r.z && in.wp.y > r.y && in.wp.y < r.w) discard_fragment();\n"
      "  float4 c = tex.sample(smp, in.uv, uint(in.layer)) * in.color;\n"
      "  return float4(mix(c.rgb, u.fog.rgb, in.fog), 1.0);\n"
      "}\n"
      "struct VDyn { float3 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; float layer [[attribute(2)]]; float4 color [[attribute(3)]]; float glow [[attribute(4)]]; };\n"
      "// glow is the least light: 1 for flames, which are as bright at night.\n"
      "VOut dyn_out(VDyn in, float3 p, constant U &u) {\n"
      "  VOut o;\n"
      "  o.pos = u.vp * float4(p, 1.0);\n"
      "  o.uv = in.uv; o.layer = in.layer;\n"
      "  float l = max(bright(0.2 + 0.8 * u.misc.x, u), in.glow);\n"
      "  o.color = float4(in.color.rgb * l, in.color.a);\n"
      "  o.fog = fog_of(p, u);\n"
      "  return o;\n"
      "}\n"
      "vertex VOut vdyn(VDyn in [[stage_in]], constant U &u [[buffer(0)]]) {\n"
      "  return dyn_out(in, in.pos, u);\n"
      "}\n"
      "// The held item: its depth goes to the first 1% of the range, so it is\n"
      "// in front of every wall that the camera touches.\n"
      "vertex VOut vhand(VDyn in [[stage_in]], constant U &u [[buffer(0)]]) {\n"
      "  VOut o = dyn_out(in, in.pos, u);\n"
      "  o.pos.z *= 0.01;\n"
      "  o.fog = 0.0;\n"
      "  return o;\n"
      "}\n"
      "// Rain: the streaks move down, and they fade with the strength of the\n"
      "// rain, u.rain.x, toward the edge of its circle, u.rain.y, and in the\n"
      "// columns next to the camera, where a streak would look wide.\n"
      "vertex VOut vrain(VDyn in [[stage_in]], constant U &u [[buffer(0)]]) {\n"
      "  VOut o = dyn_out(in, in.pos, u);\n"
      "  o.uv.y -= u.cam.w * 3.0;\n"
      "  float d = length(in.pos.xz - u.cam.xz);\n"
      "  o.color.a *= u.rain.x * clamp(1.0 - d / u.rain.y, 0.0, 1.0) * clamp((d - 1.0) / 2.0, 0.0, 1.0);\n"
      "  return o;\n"
      "}\n"
      "// Cloud boxes: Clouds#build makes them without the drift, u.cloud.x.\n"
      "vertex VOut vcloud_box(VDyn in [[stage_in]], constant U &u [[buffer(0)]]) {\n"
      "  return dyn_out(in, in.pos + float3(u.cloud.x, 0.0, 0.0), u);\n"
      "}\n"
      "// The far cloud layer: one square around the camera, out to the far plane.\n"
      "// u.cloud is (drift, y of the layer, cell size, grid size), and u.cloud_near\n"
      "// the cells (i0, j0, i1, j1) that have boxes.\n"
      "struct VOutC { float4 pos [[position]]; float3 wp; float shade [[flat]]; };\n"
      "constant float2 SQUARE[6] = {{-1,-1},{1,-1},{1,1},{-1,-1},{1,1},{-1,1}};\n"
      "vertex VOutC vcloud(uint vid [[vertex_id]], constant U &u [[buffer(0)]]) {\n"
      "  float r = u.fog.w + 40.0;\n"
      "  float3 p = float3(u.cam.x + SQUARE[vid].x * r, u.cloud.y, u.cam.z + SQUARE[vid].y * r);\n"
      "  VOutC o;\n"
      "  o.pos = u.vp * float4(p, 1.0);\n"
      "  o.wp = p;\n"
      "  // The light of a box top from above, of a box bottom from below.\n"
      "  o.shade = SHADE[u.cam.y > u.cloud.y ? 2 : 3] * (0.2 + 0.8 * u.misc.x);\n"
      "  return o;\n"
      "}\n"
      "fragment float4 fcloud(VOutC in [[stage_in]], constant U &u [[buffer(0)]],\n"
      "                       texture2d<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {\n"
      "  float2 cell = float2(in.wp.x - u.cloud.x, in.wp.z) / u.cloud.z;\n"
      "  float2 c = floor(cell);\n"
      "  float4 n = u.cloud_near;\n"
      "  if (c.x >= n.x && c.x <= n.z && c.y >= n.y && c.y <= n.w) discard_fragment();\n"
      "  // Fog lowers the alpha: over the sky this gives the same color as a mix\n"
      "  // with the fog color, and the sun and the stars still show.\n"
      "  float a = tex.sample(smp, cell / u.cloud.w).a * (1.0 - fog_of(in.wp, u));\n"
      "  if (a < 0.02) discard_fragment();\n"
      "  return float4(float3(in.shade), a);\n"
      "}\n"
      "struct VUi { float2 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; float layer [[attribute(2)]]; float4 color [[attribute(3)]]; };\n"
      "vertex VOut vui(VUi in [[stage_in]], constant U &u [[buffer(0)]]) {\n"
      "  VOut o;\n"
      "  o.pos = float4(in.pos.x / u.misc.z * 2.0 - 1.0, 1.0 - in.pos.y / u.misc.w * 2.0, 0.0, 1.0);\n"
      "  o.uv = in.uv; o.layer = in.layer; o.color = in.color; o.fog = 0.0;\n"
      "  return o;\n"
      "}\n"
      "fragment float4 fworld(VOut in [[stage_in]], constant U &u [[buffer(0)]],\n"
      "                       texture2d_array<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {\n"
      "  float4 c = tex.sample(smp, in.uv, uint(in.layer)) * in.color;\n"
      "  if (c.a < (in.color.a > 0.99 ? 0.5 : 0.02)) discard_fragment();\n"
      "  return float4(mix(c.rgb, u.fog.rgb, in.fog), c.a);\n"
      "}\n"
      "// The dynamic vertices also draw mobs: a layer from 256 on is layer - 256 of the\n"
      "// mob skins (Tex::SKINS).\n"
      "fragment float4 fdyn(VOut in [[stage_in]], constant U &u [[buffer(0)]],\n"
      "                     texture2d_array<float> tex [[texture(0)]], texture2d_array<float> skins [[texture(1)]],\n"
      "                     sampler smp [[sampler(0)]], sampler skin_smp [[sampler(1)]]) {\n"
      "  float4 c = in.layer < 256.0 ? tex.sample(smp, in.uv, uint(in.layer)) : skins.sample(skin_smp, in.uv, uint(in.layer - 256.0));\n"
      "  c *= in.color;\n"
      "  if (c.a < (in.color.a > 0.99 ? 0.5 : 0.02)) discard_fragment();\n"
      "  return float4(mix(c.rgb, u.fog.rgb, in.fog), c.a);\n"
      "}\n"
      "fragment float4 fui(VOut in [[stage_in]], texture2d_array<float> tex [[texture(0)]], sampler smp [[sampler(0)]]) {\n"
      "  float4 c = tex.sample(smp, in.uv, uint(in.layer)) * in.color;\n"
      "  if (c.a < 0.01) discard_fragment();\n"
      "  return c;\n"
      "}\n";

    static bool fail(const char *what) {
      fprintf(stderr, "%s: %s\n", what, SDL_GetError());
      return false;
    }

    static SDL_GPUShader *shader(const char *entry, SDL_GPUShaderStage stage, int samplers) {
      SDL_GPUShaderCreateInfo info = {0};
      info.code = (const Uint8 *)MSL;
      info.code_size = SDL_strlen(MSL);
      info.entrypoint = entry;
      info.format = SDL_GPU_SHADERFORMAT_MSL;
      info.stage = stage;
      info.num_samplers = samplers;
      info.num_uniform_buffers = 1;
      return SDL_CreateGPUShader(dev, &info);
    }

    /* blend 0 writes the color, 1 blends it by alpha, and 2 writes no color
       (a pass for depth only). */
    static SDL_GPUGraphicsPipeline *pipeline(SDL_GPUShader *vs, SDL_GPUShader *fs,
        SDL_GPUVertexBufferDescription *vb, SDL_GPUVertexAttribute *attrs, int nattrs,
        int depth_test, int depth_write, int blend, int cull) {
      SDL_GPUColorTargetDescription ct = {0};
      ct.format = SDL_GetGPUSwapchainTextureFormat(dev, win);
      if (blend == 2) {
        ct.blend_state.enable_color_write_mask = true;
        ct.blend_state.color_write_mask = 0;
      } else if (blend) {
        ct.blend_state.enable_blend = true;
        ct.blend_state.src_color_blendfactor = SDL_GPU_BLENDFACTOR_SRC_ALPHA;
        ct.blend_state.dst_color_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
        ct.blend_state.color_blend_op = SDL_GPU_BLENDOP_ADD;
        ct.blend_state.src_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE;
        ct.blend_state.dst_alpha_blendfactor = SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
        ct.blend_state.alpha_blend_op = SDL_GPU_BLENDOP_ADD;
      }
      SDL_GPUGraphicsPipelineCreateInfo pi = {0};
      pi.vertex_shader = vs;
      pi.fragment_shader = fs;
      pi.vertex_input_state.vertex_buffer_descriptions = vb;
      pi.vertex_input_state.num_vertex_buffers = vb ? 1 : 0;
      pi.vertex_input_state.vertex_attributes = attrs;
      pi.vertex_input_state.num_vertex_attributes = nattrs;
      pi.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
      pi.rasterizer_state.cull_mode = cull ? SDL_GPU_CULLMODE_BACK : SDL_GPU_CULLMODE_NONE;
      pi.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
      pi.depth_stencil_state.enable_depth_test = depth_test;
      pi.depth_stencil_state.enable_depth_write = depth_write;
      pi.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS_OR_EQUAL;
      pi.target_info.color_target_descriptions = &ct;
      pi.target_info.num_color_targets = 1;
      pi.target_info.has_depth_stencil_target = true;
      pi.target_info.depth_stencil_format = depth_fmt;
      return SDL_CreateGPUGraphicsPipeline(dev, &pi);
    }

    static SDL_GPUBuffer *make_buffer(Uint32 size) {
      SDL_GPUBufferCreateInfo bi = {.usage = SDL_GPU_BUFFERUSAGE_VERTEX, .size = size};
      return SDL_CreateGPUBuffer(dev, &bi);
    }

    static SDL_GPUTransferBuffer *make_transfer(Uint32 size) {
      SDL_GPUTransferBufferCreateInfo tbi = {.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD, .size = size};
      return SDL_CreateGPUTransferBuffer(dev, &tbi);
    }

    /* Returns a range to the sorted free list and joins it with the free
       ranges next to it. */
    static void free_range(Uint32 at, Uint32 len) {
      int lo = 0, hi = nfree;
      while (lo < hi) { int mid = (lo + hi) / 2; if (free_at[mid] < at) lo = mid + 1; else hi = mid; }
      int i = lo;
      int join_prev = i > 0 && free_at[i - 1] + free_len[i - 1] == at;
      int join_next = i < nfree && at + len == free_at[i];
      if (join_prev && join_next) {
        free_len[i - 1] += len + free_len[i];
        memmove(&free_at[i], &free_at[i + 1], (nfree - i - 1) * sizeof(Uint32));
        memmove(&free_len[i], &free_len[i + 1], (nfree - i - 1) * sizeof(Uint32));
        nfree--;
      } else if (join_prev) {
        free_len[i - 1] += len;
      } else if (join_next) {
        free_at[i] = at;
        free_len[i] += len;
      } else {
        memmove(&free_at[i + 1], &free_at[i], (nfree - i) * sizeof(Uint32));
        memmove(&free_len[i + 1], &free_len[i], (nfree - i) * sizeof(Uint32));
        free_at[i] = at;
        free_len[i] = len;
        nfree++;
      }
    }

    /* Doubles the arena until len more faces fit. The next copy pass copies
       the old contents, so every range keeps its position. */
    static int grow_arena(Uint32 len) {
      Uint32 cap = arena_cap * 2;
      while (cap - arena_cap < len) cap *= 2;
      SDL_GPUBuffer *b = make_buffer(cap * 8);
      if (!b) return 0;
      if (arena_old) {
        /* A second growth before the copy: the middle buffer was never used. */
        SDL_ReleaseGPUBuffer(dev, arena);
      } else {
        arena_old = arena;
        arena_copy = arena_cap;
      }
      arena = b;
      free_range(arena_cap, cap - arena_cap);
      arena_cap = cap;
      return 1;
    }

    /* First fit. Returns UINT32_MAX when the arena cannot grow. */
    static Uint32 alloc_range(Uint32 len) {
      for (;;) {
        for (int i = 0; i < nfree; i++) {
          if (free_len[i] < len) continue;
          Uint32 at = free_at[i];
          free_at[i] += len;
          free_len[i] -= len;
          if (free_len[i] == 0) {
            memmove(&free_at[i], &free_at[i + 1], (nfree - i - 1) * sizeof(Uint32));
            memmove(&free_len[i], &free_len[i + 1], (nfree - i - 1) * sizeof(Uint32));
            nfree--;
          }
          return at;
        }
        if (!grow_arena(len)) return UINT32_MAX;
      }
    }

    /* quiet runs the game as a background app, and opens the window behind the
       other windows, so the game does not take the keyboard from the active app. */
    bool gfx_init(long w, long h, long vsync, long quiet) {
      if (quiet) {
        SDL_SetHint(SDL_HINT_MAC_BACKGROUND_APP, "1");
        SDL_SetHint(SDL_HINT_WINDOW_ACTIVATE_WHEN_SHOWN, "0");
      }
      if (!SDL_Init(SDL_INIT_VIDEO)) return fail("SDL_Init");
      win = SDL_CreateWindow("Spinelcraft", (int)w, (int)h, SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
      if (!win) return fail("SDL_CreateWindow");
      dev = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_MSL, false, NULL);
      if (!dev) return fail("SDL_CreateGPUDevice");
      if (!SDL_ClaimWindowForGPUDevice(dev, win)) return fail("SDL_ClaimWindowForGPUDevice");
      SDL_GPUPresentMode mode = SDL_GPU_PRESENTMODE_VSYNC;
      if (!vsync && SDL_WindowSupportsGPUPresentMode(dev, win, SDL_GPU_PRESENTMODE_IMMEDIATE))
        mode = SDL_GPU_PRESENTMODE_IMMEDIATE;
      SDL_SetGPUSwapchainParameters(dev, win, SDL_GPU_SWAPCHAINCOMPOSITION_SDR, mode);
      depth_fmt = SDL_GPUTextureSupportsFormat(dev, SDL_GPU_TEXTUREFORMAT_D32_FLOAT,
        SDL_GPU_TEXTURETYPE_2D, SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET)
        ? SDL_GPU_TEXTUREFORMAT_D32_FLOAT : SDL_GPU_TEXTUREFORMAT_D16_UNORM;

      SDL_GPUShader *vchunk = shader("vchunk", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *vdyn = shader("vdyn", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *vcloud_box = shader("vcloud_box", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *vhand = shader("vhand", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *vrain = shader("vrain", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *vui = shader("vui", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *fworld = shader("fworld", SDL_GPU_SHADERSTAGE_FRAGMENT, 1);
      SDL_GPUShader *fdyn = shader("fdyn", SDL_GPU_SHADERSTAGE_FRAGMENT, 2);
      SDL_GPUShader *vlod = shader("vlod", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *flod = shader("flod", SDL_GPU_SHADERSTAGE_FRAGMENT, 1);
      SDL_GPUShader *vcloud = shader("vcloud", SDL_GPU_SHADERSTAGE_VERTEX, 0);
      SDL_GPUShader *fcloud = shader("fcloud", SDL_GPU_SHADERSTAGE_FRAGMENT, 1);
      SDL_GPUShaderCreateInfo fui_info = {0};
      fui_info.code = (const Uint8 *)MSL;
      fui_info.code_size = SDL_strlen(MSL);
      fui_info.entrypoint = "fui";
      fui_info.format = SDL_GPU_SHADERFORMAT_MSL;
      fui_info.stage = SDL_GPU_SHADERSTAGE_FRAGMENT;
      fui_info.num_samplers = 1;
      SDL_GPUShader *fui = SDL_CreateGPUShader(dev, &fui_info);
      if (!vchunk || !vdyn || !vui || !fworld || !fdyn || !fui || !vlod || !flod || !vcloud || !fcloud || !vcloud_box || !vhand || !vrain) return fail("SDL_CreateGPUShader");

      SDL_GPUVertexBufferDescription chunk_vb = {.slot = 0, .pitch = 8, .input_rate = SDL_GPU_VERTEXINPUTRATE_INSTANCE};
      SDL_GPUVertexAttribute chunk_attr = {.location = 0, .buffer_slot = 0, .format = SDL_GPU_VERTEXELEMENTFORMAT_UINT2};
      p_chunk = pipeline(vchunk, fworld, &chunk_vb, &chunk_attr, 1, 1, 1, 0, 1);
      p_water = pipeline(vchunk, fworld, &chunk_vb, &chunk_attr, 1, 1, 0, 1, 0);
      p_lod = pipeline(vlod, flod, &chunk_vb, &chunk_attr, 1, 1, 1, 0, 1);

      SDL_GPUVertexBufferDescription dyn_vb = {.slot = 0, .pitch = DYN_FLOATS * 4, .input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX};
      SDL_GPUVertexAttribute dyn_attr[5] = {
        {.location = 0, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3, .offset = 0},
        {.location = 1, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = 12},
        {.location = 2, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = 20},
        {.location = 3, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = 24},
        {.location = 4, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = 40},
      };
      p_dyn = pipeline(vdyn, fdyn, &dyn_vb, dyn_attr, 5, 1, 1, 1, 0);
      p_hand = pipeline(vhand, fdyn, &dyn_vb, dyn_attr, 5, 1, 1, 1, 0);
      p_rain = pipeline(vrain, fworld, &dyn_vb, dyn_attr, 5, 1, 0, 1, 0);
      /* Cloud boxes: depth first, then the color of the nearest face only, so
         each pixel blends one cloud face. */
      p_cloud_depth = pipeline(vcloud_box, fworld, &dyn_vb, dyn_attr, 5, 1, 1, 2, 0);
      p_cloud_box = pipeline(vcloud_box, fworld, &dyn_vb, dyn_attr, 5, 1, 0, 1, 0);
      /* The cloud layer makes its corners from the vertex index: no vertex buffer. */
      p_cloud = pipeline(vcloud, fcloud, NULL, NULL, 0, 1, 1, 1, 0);

      SDL_GPUVertexBufferDescription ui_vb = {.slot = 0, .pitch = 36, .input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX};
      SDL_GPUVertexAttribute ui_attr[4] = {
        {.location = 0, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = 0},
        {.location = 1, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2, .offset = 8},
        {.location = 2, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT, .offset = 16},
        {.location = 3, .format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4, .offset = 20},
      };
      p_ui = pipeline(vui, fui, &ui_vb, ui_attr, 4, 0, 0, 1, 0);
      if (!p_chunk || !p_water || !p_lod || !p_dyn || !p_ui || !p_cloud || !p_cloud_box || !p_cloud_depth || !p_hand || !p_rain) return fail("SDL_CreateGPUGraphicsPipeline");
      SDL_ReleaseGPUShader(dev, vchunk);
      SDL_ReleaseGPUShader(dev, vdyn);
      SDL_ReleaseGPUShader(dev, vui);
      SDL_ReleaseGPUShader(dev, fworld);
      SDL_ReleaseGPUShader(dev, fdyn);
      SDL_ReleaseGPUShader(dev, vlod);
      SDL_ReleaseGPUShader(dev, flod);
      SDL_ReleaseGPUShader(dev, fui);
      SDL_ReleaseGPUShader(dev, vcloud);
      SDL_ReleaseGPUShader(dev, fcloud);
      SDL_ReleaseGPUShader(dev, vcloud_box);
      SDL_ReleaseGPUShader(dev, vhand);
      SDL_ReleaseGPUShader(dev, vrain);

      SDL_GPUSamplerCreateInfo si = {0};
      si.min_filter = SDL_GPU_FILTER_NEAREST;
      si.mag_filter = SDL_GPU_FILTER_NEAREST;
      si.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
      si.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
      si.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_REPEAT;
      si.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
      si.max_lod = 4.0f;
      sampler = SDL_CreateGPUSampler(dev, &si);
      /* Clouds: sharp cell edges near the camera, and averaged mipmaps far
         away, so that small far cells do not flicker. */
      si.min_filter = SDL_GPU_FILTER_LINEAR;
      si.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_LINEAR;
      si.max_lod = 16.0f;
      cloud_sampler = SDL_CreateGPUSampler(dev, &si);

      SDL_GPUBufferCreateInfo ibi = {.usage = SDL_GPU_BUFFERUSAGE_INDEX, .size = 12};
      quad_index = SDL_CreateGPUBuffer(dev, &ibi);
      SDL_GPUTransferBuffer *itb = make_transfer(12);
      Uint16 *idx = SDL_MapGPUTransferBuffer(dev, itb, false);
      idx[0] = 0; idx[1] = 1; idx[2] = 2; idx[3] = 0; idx[4] = 2; idx[5] = 3;
      SDL_UnmapGPUTransferBuffer(dev, itb);
      SDL_GPUCommandBuffer *ic = SDL_AcquireGPUCommandBuffer(dev);
      SDL_GPUCopyPass *icp = SDL_BeginGPUCopyPass(ic);
      SDL_GPUTransferBufferLocation isrc = {.transfer_buffer = itb};
      SDL_GPUBufferRegion idst = {.buffer = quad_index, .size = 12};
      SDL_UploadToGPUBuffer(icp, &isrc, &idst, false);
      SDL_EndGPUCopyPass(icp);
      SDL_SubmitGPUCommandBuffer(ic);
      SDL_ReleaseGPUTransferBuffer(dev, itb);
      arena_cap = ARENA_START;
      arena = make_buffer(arena_cap * 8);
      if (!arena) return fail("arena");
      free_range(0, arena_cap);
      dyn_buf = make_buffer(DYN_CAP * DYN_FLOATS * 4);
      ui_buf = make_buffer(UI_CAP * 36);
      sky_buf = make_buffer(SKY_CAP * 36);
      sky_tb = make_transfer(SKY_CAP * 36);
      dyn_tb = make_transfer(DYN_CAP * DYN_FLOATS * 4);
      ui_tb = make_transfer(UI_CAP * 36);
      cloud_buf = make_buffer(CLOUD_CAP * DYN_FLOATS * 4);
      cloud_tb = make_transfer(CLOUD_CAP * DYN_FLOATS * 4);
      rain_buf = make_buffer(RAIN_CAP * DYN_FLOATS * 4);
      rain_tb = make_transfer(RAIN_CAP * DYN_FLOATS * 4);
      if (!sampler || !cloud_sampler || !dyn_buf || !ui_buf || !dyn_tb || !ui_tb || !cloud_buf || !cloud_tb || !rain_buf || !rain_tb) return fail("SDL_CreateGPUBuffer");
      return true;
    }

    /* layers of 16x16 RGBA pixels, one Integer per pixel (0xAABBGGRR). */
    bool gfx_textures(const int64_t *px, long layers) {
      SDL_GPUTextureCreateInfo ti = {0};
      ti.type = SDL_GPU_TEXTURETYPE_2D_ARRAY;
      ti.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
      ti.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
      ti.width = 16; ti.height = 16;
      ti.layer_count_or_depth = (Uint32)layers;
      ti.num_levels = 5;
      atlas = SDL_CreateGPUTexture(dev, &ti);
      if (!atlas) return fail("SDL_CreateGPUTexture");
      Uint32 size = (Uint32)(layers * 256 * 4);
      SDL_GPUTransferBuffer *tb = make_transfer(size);
      Uint32 *dst = SDL_MapGPUTransferBuffer(dev, tb, false);
      for (long i = 0; i < layers * 256; i++) dst[i] = (Uint32)px[i];
      SDL_UnmapGPUTransferBuffer(dev, tb);
      SDL_GPUCommandBuffer *c = SDL_AcquireGPUCommandBuffer(dev);
      SDL_GPUCopyPass *cp = SDL_BeginGPUCopyPass(c);
      SDL_GPUTextureTransferInfo src = {.transfer_buffer = tb, .pixels_per_row = 16, .rows_per_layer = 16};
      SDL_GPUTextureRegion region = {.texture = atlas, .w = 16, .h = 16, .d = 1};
      for (long l = 0; l < layers; l++) {
        src.offset = (Uint32)(l * 1024);
        region.layer = (Uint32)l;
        SDL_UploadToGPUTexture(cp, &src, &region, false);
      }
      SDL_EndGPUCopyPass(cp);
      SDL_GenerateMipmapsForGPUTexture(c, atlas);
      SDL_SubmitGPUCommandBuffer(c);
      SDL_ReleaseGPUTransferBuffer(dev, tb);
      return true;
    }

    /* layers of 64x64 RGBA pixels (0xAABBGGRR): the mob skins. Mobs are
       small on the screen only when they are far, so the skins have no
       mipmaps. */
    bool gfx_skins(const int64_t *px, long layers) {
      SDL_GPUTextureCreateInfo ti = {0};
      ti.type = SDL_GPU_TEXTURETYPE_2D_ARRAY;
      ti.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
      ti.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
      ti.width = 64; ti.height = 64;
      ti.layer_count_or_depth = (Uint32)layers;
      ti.num_levels = 1;
      skins = SDL_CreateGPUTexture(dev, &ti);
      if (!skins) return fail("SDL_CreateGPUTexture");
      Uint32 size = (Uint32)(layers * 4096 * 4);
      SDL_GPUTransferBuffer *tb = make_transfer(size);
      Uint32 *dst = SDL_MapGPUTransferBuffer(dev, tb, false);
      for (long i = 0; i < layers * 4096; i++) dst[i] = (Uint32)px[i];
      SDL_UnmapGPUTransferBuffer(dev, tb);
      SDL_GPUCommandBuffer *c = SDL_AcquireGPUCommandBuffer(dev);
      SDL_GPUCopyPass *cp = SDL_BeginGPUCopyPass(c);
      SDL_GPUTextureTransferInfo src = {.transfer_buffer = tb, .pixels_per_row = 64, .rows_per_layer = 64};
      SDL_GPUTextureRegion region = {.texture = skins, .w = 64, .h = 64, .d = 1};
      for (long l = 0; l < layers; l++) {
        src.offset = (Uint32)(l * 4096 * 4);
        region.layer = (Uint32)l;
        SDL_UploadToGPUTexture(cp, &src, &region, false);
      }
      SDL_EndGPUCopyPass(cp);
      SDL_SubmitGPUCommandBuffer(c);
      SDL_ReleaseGPUTransferBuffer(dev, tb);
      return true;
    }

    /* The pixels of the last image that gfx_png loaded (0xAABBGGRR). */
    static Uint32 png_px[64 * 64];

    /* Loads a PNG of w x h pixels, at most 64 x 64. The path is relative to
       the folder of the game, so the game finds assets/ from any working
       directory. */
    bool gfx_png(const char *path, long w, long h) {
      char full[1024];
      SDL_snprintf(full, sizeof full, "%s%s", SDL_GetBasePath(), path);
      SDL_Surface *s = SDL_LoadPNG(full);
      if (!s) return fail(full);
      SDL_Surface *c = SDL_ConvertSurface(s, SDL_PIXELFORMAT_RGBA32);
      SDL_DestroySurface(s);
      if (!c) return fail(full);
      bool ok = c->w == w && c->h == h && w * h <= 64 * 64;
      if (ok) {
        for (int y = 0; y < h; y++) SDL_memcpy(png_px + y * w, (Uint8 *)c->pixels + y * c->pitch, w * 4);
      } else {
        fprintf(stderr, "%s: not %ldx%ld\n", full, w, h);
      }
      SDL_DestroySurface(c);
      return ok;
    }

    long gfx_png_pixel(long i) { return png_px[i]; }

    /* The cloud grid: size x size RGBA pixels, one Integer per pixel (0xAABBGGRR).
       A new grid replaces the old one. */
    bool gfx_clouds(const int64_t *px, long size) {
      int levels = 1;
      while ((1L << levels) <= size) levels++;
      SDL_GPUTextureCreateInfo ti = {0};
      ti.type = SDL_GPU_TEXTURETYPE_2D;
      ti.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
      ti.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER | SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
      ti.width = (Uint32)size; ti.height = (Uint32)size;
      ti.layer_count_or_depth = 1;
      ti.num_levels = (Uint32)levels;
      SDL_GPUTexture *t = SDL_CreateGPUTexture(dev, &ti);
      if (!t) return fail("SDL_CreateGPUTexture");
      Uint32 bytes = (Uint32)(size * size * 4);
      SDL_GPUTransferBuffer *tb = make_transfer(bytes);
      Uint32 *dst = SDL_MapGPUTransferBuffer(dev, tb, false);
      for (long i = 0; i < size * size; i++) dst[i] = (Uint32)px[i];
      SDL_UnmapGPUTransferBuffer(dev, tb);
      SDL_GPUCommandBuffer *c = SDL_AcquireGPUCommandBuffer(dev);
      SDL_GPUCopyPass *cp = SDL_BeginGPUCopyPass(c);
      SDL_GPUTextureTransferInfo src = {.transfer_buffer = tb};
      SDL_GPUTextureRegion region = {.texture = t, .w = (Uint32)size, .h = (Uint32)size, .d = 1};
      SDL_UploadToGPUTexture(cp, &src, &region, false);
      SDL_EndGPUCopyPass(cp);
      SDL_GenerateMipmapsForGPUTexture(c, t);
      SDL_SubmitGPUCommandBuffer(c);
      SDL_ReleaseGPUTransferBuffer(dev, tb);
      /* SDL frees the old texture when no frame on the GPU uses it. */
      if (cloud_tex) SDL_ReleaseGPUTexture(dev, cloud_tex);
      cloud_tex = t;
      return true;
    }

    /* Two Integers per face; stored on the GPU as two uint32 words. */
    long gfx_mesh(long slot, const int64_t *data, long faces, const int64_t *offsets) {
      if (slot < 0 || slot >= MAX_SLOTS) return -1;
      for (int i = 0; i < 8; i++) slot_off[slot][i] = (Uint32)offsets[i];
      if (slot_len[slot]) {
        if (nretire == MAX_RETIRE) return -1;
        retire_at[nretire] = slot_at[slot];
        retire_len[nretire] = slot_len[slot];
        retire_frame[nretire] = frame_no;
        nretire++;
        slot_len[slot] = 0;
      }
      slot_count[slot] = 0;
      if (faces == 0) return 0;
      if (npending == MAX_SLOTS) return -1;
      /* Whole blocks of 16 faces keep small gaps out of the free list. */
      Uint32 len = ((Uint32)faces + 15) & ~15u;
      Uint32 at = alloc_range(len);
      if (at == UINT32_MAX) return -1;
      slot_at[slot] = at;
      slot_len[slot] = len;
      slot_count[slot] = (Uint32)faces;
      Uint32 size = (Uint32)(faces * 8);
      SDL_GPUTransferBuffer *tb = make_transfer(size);
      Uint32 *dst = SDL_MapGPUTransferBuffer(dev, tb, false);
      for (long i = 0; i < faces * 2; i++) dst[i] = (Uint32)data[i];
      SDL_UnmapGPUTransferBuffer(dev, tb);
      pending[npending++] = (Pending){tb, at, size};
      return 0;
    }

    static Uint32 stage_floats(SDL_GPUTransferBuffer *tb, const double *v, long n, long cap) {
      if (n > cap) n = cap;
      if (n <= 0) return 0;
      float *dst = SDL_MapGPUTransferBuffer(dev, tb, true);
      for (long i = 0; i < n; i++) dst[i] = (float)v[i];
      SDL_UnmapGPUTransferBuffer(dev, tb);
      return (Uint32)n;
    }

    /* The floats from hand_floats on are the held item (see gfx_draw_hand). */
    long gfx_dyn(const double *v, long nfloats, long hand_floats) {
      dyn_count = stage_floats(dyn_tb, v, nfloats, DYN_CAP * DYN_FLOATS) / DYN_FLOATS;
      hand_first = hand_floats / DYN_FLOATS < dyn_count ? (Uint32)(hand_floats / DYN_FLOATS) : dyn_count;
      return 0;
    }
    long gfx_ui(const double *v, long nfloats) { ui_count = stage_floats(ui_tb, v, nfloats, UI_CAP * 9) / 9; return 0; }
    long gfx_sky(const double *v, long nfloats) { sky_count = stage_floats(sky_tb, v, nfloats, SKY_CAP * 9) / 9; return 0; }
    long gfx_cloud_boxes(const double *v, long nfloats) {
      cloud_count = stage_floats(cloud_tb, v, nfloats, CLOUD_CAP * DYN_FLOATS) / DYN_FLOATS;
      cloud_changed = 1;
      return 0;
    }
    long gfx_rain(const double *v, long nfloats) {
      rain_count = stage_floats(rain_tb, v, nfloats, RAIN_CAP * DYN_FLOATS) / DYN_FLOATS;
      rain_changed = 1;
      return 0;
    }

    /* uniforms: 16 view-projection (column-major), cam xyz + time, fog rgb + end,
       daylight, fog start, screen w, screen h, for each far terrain level the
       square x0 z0 x1 z1 that the next finer level covers, 8 for the far cloud
       layer, 4 for the rain, and 4 for the options (brightness first).
       Returns true when there is a frame to draw. */
    bool gfx_begin(const double *u) {
      for (int i = 0; i < UNIFORMS; i++) uni[i] = (float)u[i];
      frame_wait_ns = 0;
      cmd = SDL_AcquireGPUCommandBuffer(dev);
      if (!cmd) return fail("SDL_AcquireGPUCommandBuffer");
      frame_no++;
      int kept = 0;
      for (int i = 0; i < nretire; i++) {
        if (frame_no - retire_frame[i] >= RETIRE_FRAMES) {
          free_range(retire_at[i], retire_len[i]);
        } else {
          retire_at[kept] = retire_at[i];
          retire_len[kept] = retire_len[i];
          retire_frame[kept] = retire_frame[i];
          kept++;
        }
      }
      nretire = kept;
      if (arena_old) {
        /* Its own pass, so the copy ends before the uploads write the new arena. */
        SDL_GPUCopyPass *gp = SDL_BeginGPUCopyPass(cmd);
        SDL_GPUBufferLocation from = {.buffer = arena_old};
        SDL_GPUBufferLocation to = {.buffer = arena};
        SDL_CopyGPUBufferToBuffer(gp, &from, &to, arena_copy * 8, false);
        SDL_EndGPUCopyPass(gp);
        SDL_ReleaseGPUBuffer(dev, arena_old);
        arena_old = NULL;
      }
      SDL_GPUCopyPass *cp = SDL_BeginGPUCopyPass(cmd);
      for (int i = 0; i < npending; i++) {
        SDL_GPUTransferBufferLocation src = {.transfer_buffer = pending[i].tb};
        SDL_GPUBufferRegion dst = {.buffer = arena, .offset = pending[i].at * 8, .size = pending[i].size};
        /* No cycling: that would drop the rest of the arena. No frame on the
           GPU reads this range (see RETIRE_FRAMES). */
        SDL_UploadToGPUBuffer(cp, &src, &dst, false);
        SDL_ReleaseGPUTransferBuffer(dev, pending[i].tb);
      }
      npending = 0;
      if (dyn_count) {
        SDL_GPUTransferBufferLocation src = {.transfer_buffer = dyn_tb};
        SDL_GPUBufferRegion dst = {.buffer = dyn_buf, .size = dyn_count * DYN_FLOATS * 4};
        SDL_UploadToGPUBuffer(cp, &src, &dst, true);
      }
      if (ui_count) {
        SDL_GPUTransferBufferLocation src = {.transfer_buffer = ui_tb};
        SDL_GPUBufferRegion dst = {.buffer = ui_buf, .size = ui_count * 36};
        SDL_UploadToGPUBuffer(cp, &src, &dst, true);
      }
      if (cloud_changed && cloud_count) {
        SDL_GPUTransferBufferLocation src = {.transfer_buffer = cloud_tb};
        SDL_GPUBufferRegion dst = {.buffer = cloud_buf, .size = cloud_count * DYN_FLOATS * 4};
        SDL_UploadToGPUBuffer(cp, &src, &dst, true);
      }
      cloud_changed = 0;
      if (rain_changed && rain_count) {
        SDL_GPUTransferBufferLocation src = {.transfer_buffer = rain_tb};
        SDL_GPUBufferRegion dst = {.buffer = rain_buf, .size = rain_count * DYN_FLOATS * 4};
        SDL_UploadToGPUBuffer(cp, &src, &dst, true);
      }
      rain_changed = 0;
      if (sky_count) {
        SDL_GPUTransferBufferLocation src = {.transfer_buffer = sky_tb};
        SDL_GPUBufferRegion dst = {.buffer = sky_buf, .size = sky_count * 36};
        SDL_UploadToGPUBuffer(cp, &src, &dst, true);
      }
      SDL_EndGPUCopyPass(cp);

      swap_tex = NULL;
      Uint64 w0 = SDL_GetTicksNS();
      if (!SDL_WaitAndAcquireGPUSwapchainTexture(cmd, win, &swap_tex, &swap_w, &swap_h)) return fail("acquire");
      frame_wait_ns += SDL_GetTicksNS() - w0;
      if (!swap_tex) { SDL_SubmitGPUCommandBuffer(cmd); cmd = NULL; return false; }
      if (!depth_tex || depth_w != swap_w || depth_h != swap_h) {
        if (depth_tex) SDL_ReleaseGPUTexture(dev, depth_tex);
        SDL_GPUTextureCreateInfo ti = {.type = SDL_GPU_TEXTURETYPE_2D, .format = depth_fmt,
          .usage = SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET, .width = swap_w, .height = swap_h,
          .layer_count_or_depth = 1, .num_levels = 1};
        depth_tex = SDL_CreateGPUTexture(dev, &ti);
        depth_w = swap_w; depth_h = swap_h;
      }
      SDL_GPUTexture *target = swap_tex;
      if (shot_path[0]) {
        swap_fmt = SDL_GetGPUSwapchainTextureFormat(dev, win);
        SDL_GPUTextureCreateInfo sti = {.type = SDL_GPU_TEXTURETYPE_2D, .format = swap_fmt,
          .usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER, .width = swap_w, .height = swap_h,
          .layer_count_or_depth = 1, .num_levels = 1};
        shot_tex = SDL_CreateGPUTexture(dev, &sti);
        target = shot_tex;
      }
      SDL_GPUColorTargetInfo cti = {.texture = target, .load_op = SDL_GPU_LOADOP_CLEAR,
        .store_op = SDL_GPU_STOREOP_STORE, .clear_color = {uni[20], uni[21], uni[22], 1.0f}};
      SDL_GPUDepthStencilTargetInfo dti = {.texture = depth_tex, .clear_depth = 1.0f,
        .load_op = SDL_GPU_LOADOP_CLEAR, .store_op = SDL_GPU_STOREOP_DONT_CARE,
        .stencil_load_op = SDL_GPU_LOADOP_DONT_CARE, .stencil_store_op = SDL_GPU_STOREOP_DONT_CARE};
      pass = SDL_BeginGPURenderPass(cmd, &cti, 1, &dti);
      SDL_PushGPUVertexUniformData(cmd, 0, uni, sizeof uni);
      SDL_PushGPUFragmentUniformData(cmd, 0, uni, sizeof uni);
      SDL_GPUTextureSamplerBinding tsb = {.texture = atlas, .sampler = sampler};
      SDL_BindGPUFragmentSamplers(pass, 0, &tsb, 1);
      if (sky_count) {
        /* The HUD pipeline writes no depth, so terrain drawn next covers the sky. */
        SDL_BindGPUGraphicsPipeline(pass, p_ui);
        SDL_GPUBufferBinding b = {.buffer = sky_buf};
        SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
        SDL_DrawGPUPrimitives(pass, sky_count, 1, 0, 0);
      }
      return true;
    }

    /* Pairs of (slot, direction mask). Bit f draws the faces of direction f
       (0..5 for +x -x +y -y +z -z, 6 for plants). kind 0 is opaque, 1 is water, 2 is far terrain. */
    long gfx_chunks(const int64_t *pairs, long n, long kind) {
      if (!pass) return 0;
      SDL_BindGPUGraphicsPipeline(pass, kind == 2 ? p_lod : (kind ? p_water : p_chunk));
      SDL_GPUBufferBinding ib = {.buffer = quad_index};
      SDL_BindGPUIndexBuffer(pass, &ib, SDL_GPU_INDEXELEMENTSIZE_16BIT);
      SDL_GPUBufferBinding b = {.buffer = arena};
      SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
      long faces = 0;
      for (long i = 0; i < n; i++) {
        long s = pairs[i * 2];
        long mask = pairs[i * 2 + 1];
        if (s < 0 || s >= MAX_SLOTS || !slot_count[s]) continue;
        int f = 0;
        while (f < 7) {
          if (!((mask >> f) & 1)) { f++; continue; }
          int g = f;
          while (g + 1 < 7 && ((mask >> (g + 1)) & 1)) g++;
          Uint32 first = slot_off[s][f], last = slot_off[s][g + 1];
          if (last > first) {
            SDL_DrawGPUIndexedPrimitives(pass, 6, last - first, 0, 0, slot_at[s] + first);
            faces += last - first;
          }
          f = g + 1;
        }
      }
      return faces;
    }

    long gfx_draw_dyn(void) {
      if (!pass || !hand_first) return 0;
      SDL_BindGPUGraphicsPipeline(pass, p_dyn);
      SDL_GPUTextureSamplerBinding tsb[2] = {{.texture = atlas, .sampler = sampler}, {.texture = skins, .sampler = sampler}};
      SDL_BindGPUFragmentSamplers(pass, 0, tsb, 2);
      SDL_GPUBufferBinding b = {.buffer = dyn_buf};
      SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
      SDL_DrawGPUPrimitives(pass, hand_first, 1, 0, 0);
      return 0;
    }

    /* The rain, after the water. uni[UNIFORMS - 8] is its strength, u.rain.x. */
    long gfx_draw_rain(void) {
      if (!pass || !rain_count || uni[UNIFORMS - 8] <= 0.0f) return 0;
      SDL_BindGPUGraphicsPipeline(pass, p_rain);
      SDL_GPUBufferBinding b = {.buffer = rain_buf};
      SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
      SDL_DrawGPUPrimitives(pass, rain_count, 1, 0, 0);
      return 0;
    }

    /* The held item, after everything else in the world. */
    long gfx_draw_hand(void) {
      if (!pass || dyn_count <= hand_first) return 0;
      SDL_BindGPUGraphicsPipeline(pass, p_hand);
      SDL_GPUTextureSamplerBinding tsb[2] = {{.texture = atlas, .sampler = sampler}, {.texture = skins, .sampler = sampler}};
      SDL_BindGPUFragmentSamplers(pass, 0, tsb, 2);
      SDL_GPUBufferBinding b = {.buffer = dyn_buf};
      SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
      SDL_DrawGPUPrimitives(pass, dyn_count - hand_first, 1, hand_first, 0);
      return 0;
    }

    /* The cloud boxes, then the flat cloud layer around them. */
    long gfx_draw_clouds(void) {
      if (!pass) return 0;
      if (cloud_count) {
        SDL_GPUBufferBinding b = {.buffer = cloud_buf};
        SDL_BindGPUGraphicsPipeline(pass, p_cloud_depth);
        SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
        SDL_DrawGPUPrimitives(pass, cloud_count, 1, 0, 0);
        SDL_BindGPUGraphicsPipeline(pass, p_cloud_box);
        SDL_DrawGPUPrimitives(pass, cloud_count, 1, 0, 0);
      }
      if (!cloud_tex) return 0;
      SDL_BindGPUGraphicsPipeline(pass, p_cloud);
      SDL_GPUTextureSamplerBinding cb = {.texture = cloud_tex, .sampler = cloud_sampler};
      SDL_BindGPUFragmentSamplers(pass, 0, &cb, 1);
      SDL_DrawGPUPrimitives(pass, 6, 1, 0, 0);
      SDL_GPUTextureSamplerBinding tsb = {.texture = atlas, .sampler = sampler};
      SDL_BindGPUFragmentSamplers(pass, 0, &tsb, 1);
      return 0;
    }

    long gfx_end(void) {
      if (!cmd) return 0;
      if (pass) {
        if (ui_count) {
          SDL_BindGPUGraphicsPipeline(pass, p_ui);
          SDL_GPUBufferBinding b = {.buffer = ui_buf};
          SDL_BindGPUVertexBuffers(pass, 0, &b, 1);
          SDL_DrawGPUPrimitives(pass, ui_count, 1, 0, 0);
        }
        SDL_EndGPURenderPass(pass);
        pass = NULL;
      }
      if (shot_tex) {
        SDL_GPUBlitInfo bl = {0};
        bl.source.texture = shot_tex; bl.source.w = swap_w; bl.source.h = swap_h;
        bl.destination.texture = swap_tex; bl.destination.w = swap_w; bl.destination.h = swap_h;
        SDL_BlitGPUTexture(cmd, &bl);
        Uint32 size = swap_w * swap_h * 4;
        SDL_GPUTransferBufferCreateInfo tbi = {.usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD, .size = size};
        SDL_GPUTransferBuffer *tb = SDL_CreateGPUTransferBuffer(dev, &tbi);
        SDL_GPUCopyPass *cp = SDL_BeginGPUCopyPass(cmd);
        SDL_GPUTextureRegion src = {.texture = shot_tex, .w = swap_w, .h = swap_h, .d = 1};
        SDL_GPUTextureTransferInfo dst = {.transfer_buffer = tb};
        SDL_DownloadFromGPUTexture(cp, &src, &dst);
        SDL_EndGPUCopyPass(cp);
        SDL_GPUFence *fence = SDL_SubmitGPUCommandBufferAndAcquireFence(cmd);
        SDL_WaitForGPUFences(dev, true, &fence, 1);
        SDL_ReleaseGPUFence(dev, fence);
        const Uint8 *px = SDL_MapGPUTransferBuffer(dev, tb, false);
        FILE *out = fopen(shot_path, "wb");
        if (out) {
          int bgra = swap_fmt == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM || swap_fmt == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB;
          fprintf(out, "P6\n%u %u\n255\n", swap_w, swap_h);
          for (Uint32 i = 0; i < swap_w * swap_h; i++) {
            Uint8 rgb[3] = {px[i * 4 + (bgra ? 2 : 0)], px[i * 4 + 1], px[i * 4 + (bgra ? 0 : 2)]};
            fwrite(rgb, 1, 3, out);
          }
          fclose(out);
        }
        SDL_UnmapGPUTransferBuffer(dev, tb);
        SDL_ReleaseGPUTransferBuffer(dev, tb);
        SDL_ReleaseGPUTexture(dev, shot_tex);
        shot_tex = NULL;
        shot_path[0] = 0;
        cmd = NULL;
        return 1;
      }
      if (getenv("GPUTIME")) {
        /* Measurement mode: wait for the GPU so the time includes its work. */
        Uint64 t0 = SDL_GetTicksNS();
        SDL_GPUFence *fence = SDL_SubmitGPUCommandBufferAndAcquireFence(cmd);
        SDL_WaitForGPUFences(dev, true, &fence, 1);
        SDL_ReleaseGPUFence(dev, fence);
        gpu_wait_ns += SDL_GetTicksNS() - t0;
        frame_wait_ns += SDL_GetTicksNS() - t0;
        gpu_frames++;
      } else {
        SDL_SubmitGPUCommandBuffer(cmd);
      }
      cmd = NULL;
      return 0;
    }

    long gfx_wait_ns(void) { return (long)frame_wait_ns; }
    double gfx_gpu_ms(void) { return gpu_frames ? gpu_wait_ns / 1e6 / gpu_frames : 0.0; }

    void gfx_screenshot(const char *path) { SDL_strlcpy(shot_path, path, sizeof shot_path); }

    /* Audio: a few voices bound to one device; SDL mixes them. */
    #define VOICES 8
    #define SOUNDS 64
    #define AU_RATE 44100
    static SDL_AudioDeviceID audio_dev;
    static SDL_AudioStream *voice[VOICES];
    static float *sound_data[SOUNDS];
    static int sound_len[SOUNDS];
    static int next_voice;

    bool au_init(void) {
      if (!SDL_InitSubSystem(SDL_INIT_AUDIO)) return fail("SDL_InitSubSystem(audio)");
      SDL_AudioSpec spec = {SDL_AUDIO_F32, 1, AU_RATE};
      audio_dev = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &spec);
      if (!audio_dev) return fail("SDL_OpenAudioDevice");
      for (int i = 0; i < VOICES; i++) {
        voice[i] = SDL_CreateAudioStream(&spec, NULL);
        if (!voice[i] || !SDL_BindAudioStream(audio_dev, voice[i])) return fail("SDL_BindAudioStream");
      }
      return true;
    }

    /* Loads the OGG file at path, relative to the folder of the game, as
       sound id in the format of the device, louder by gain dB. Samples above
       KNEE bend smoothly toward 1.0, so that a sharp peak does not clip. It
       needs no audio device, so a muted game can load sounds too. Returns 0,
       or -1 when it fails. */
    #define KNEE 0.8f
    long au_load_ogg(long id, const char *path, double gain) {
      if (id < 0 || id >= SOUNDS) return -1;
      char full[1024];
      SDL_snprintf(full, sizeof full, "%s%s", SDL_GetBasePath(), path);
      OggVorbis_File vf;
      if (ov_fopen(full, &vf) != 0) { fail(full); return -1; }
      vorbis_info *vi = ov_info(&vf, -1);
      int ch = vi->channels;
      SDL_AudioSpec src = {SDL_AUDIO_F32, ch, (int)vi->rate};
      float *buf = NULL;
      int len = 0, cap = 0, section;
      float **pcm;
      long n;
      while ((n = ov_read_float(&vf, &pcm, 4096, &section)) > 0) {
        if (len + n * ch > cap) {
          cap = (len + n * ch) * 2;
          buf = SDL_realloc(buf, cap * sizeof(float));
        }
        for (long i = 0; i < n; i++)
          for (int c = 0; c < ch; c++) buf[len++] = pcm[c][i];
      }
      ov_clear(&vf);
      if (n < 0 || len == 0) { SDL_free(buf); fail(full); return -1; }
      SDL_AudioSpec dst = {SDL_AUDIO_F32, 1, AU_RATE};
      Uint8 *out;
      int out_len;
      bool ok = SDL_ConvertAudioSamples(&src, (Uint8 *)buf, len * (int)sizeof(float), &dst, &out, &out_len);
      SDL_free(buf);
      if (!ok) { fail(full); return -1; }
      float *s = (float *)out;
      int count = out_len / (int)sizeof(float);
      float k = powf(10.0f, (float)gain / 20.0f);
      for (int i = 0; i < count; i++) {
        float a = fabsf(s[i] * k);
        if (a > KNEE) a = KNEE + (1.0f - KNEE) * tanhf((a - KNEE) / (1.0f - KNEE));
        s[i] = s[i] < 0 ? -a : a;
      }
      SDL_free(sound_data[id]);
      sound_data[id] = s;
      sound_len[id] = count;
      return 0;
    }

    double au_seconds(long id) { return id < 0 || id >= SOUNDS ? 0.0 : sound_len[id] / (double)AU_RATE; }

    void au_play(long id, double volume) {
      if (!audio_dev || id < 0 || id >= SOUNDS || !sound_data[id] || volume <= 0.01) return;
      SDL_AudioStream *v = NULL;
      for (int i = 0; i < VOICES; i++)
        if (SDL_GetAudioStreamQueued(voice[i]) == 0) { v = voice[i]; break; }
      if (!v) { v = voice[next_voice]; next_voice = (next_voice + 1) % VOICES; SDL_ClearAudioStream(v); }
      SDL_SetAudioStreamGain(v, (float)volume);
      SDL_PutAudioStreamData(v, sound_data[id], sound_len[id] * (int)sizeof(float));
    }

    long gfx_width(void) { return swap_w; }
    long gfx_height(void) { return swap_h; }
    long gfx_ns(void) { return (long)SDL_GetTicksNS(); }
    void gfx_quit(void) { SDL_WaitForGPUIdle(dev); SDL_Quit(); }

    /* Input. Edges (pressed this frame) compare against the previous poll. */
    bool in_poll(void) {
      memcpy(keys_prev, keys_now, sizeof keys_now);
      buttons_prev = buttons_now;
      mouse_dx = mouse_dy = wheel = 0;
      focus_lost = 0;
      SDL_Event e;
      while (SDL_PollEvent(&e)) {
        switch (e.type) {
          case SDL_EVENT_QUIT: quit_requested = 1; break;
          case SDL_EVENT_MOUSE_MOTION: mouse_dx += e.motion.xrel; mouse_dy += e.motion.yrel; break;
          case SDL_EVENT_MOUSE_WHEEL: wheel += e.wheel.y; break;
          case SDL_EVENT_WINDOW_FOCUS_LOST: focus_lost = 1; break;
          default: break;
        }
      }
      int n = 0;
      const bool *ks = SDL_GetKeyboardState(&n);
      for (int i = 0; i < n && i < SDL_SCANCODE_COUNT; i++) keys_now[i] = ks[i];
      buttons_now = SDL_GetMouseState(NULL, NULL);
      return quit_requested;
    }
    bool in_key(long sc) { return keys_now[sc]; }
    bool in_key_pressed(long sc) { return keys_now[sc] && !keys_prev[sc]; }
    bool in_button(long b) { return (buttons_now >> (b - 1)) & 1; }
    bool in_button_pressed(long b) { return ((buttons_now & ~buttons_prev) >> (b - 1)) & 1; }
    double in_mouse_dx(void) { return mouse_dx; }
    double in_mouse_dy(void) { return mouse_dy; }
    double in_wheel(void) { return wheel; }
    bool in_focus_lost(void) { return focus_lost; }
    /* Cursor position in swapchain pixels. */
    double in_mouse_x(void) { float x, y; SDL_GetMouseState(&x, &y); return x * SDL_GetWindowPixelDensity(win); }
    double in_mouse_y(void) { float x, y; SDL_GetMouseState(&x, &y); return y * SDL_GetWindowPixelDensity(win); }
    void in_capture(long on) { SDL_SetWindowRelativeMouseMode(win, on != 0); }
    void gfx_fullscreen(long on) { SDL_SetWindowFullscreen(win, on != 0); }
    /* 0: far terrain levels, 1: ring width in columns, 2: GPU mesh slots, 3: uniforms. */
    long gfx_limit(long which) { return which == 0 ? LEVELS : (which == 1 ? COLUMNS : (which == 2 ? MAX_SLOTS : UNIFORMS)); }
  C
  ffi_func :gfx_init, [:long, :long, :long, :long], :bool
  ffi_func :gfx_textures, [:int_array, :long], :bool
  ffi_func :gfx_skins, [:int_array, :long], :bool
  ffi_func :gfx_png, [:str, :long, :long], :bool
  ffi_func :gfx_png_pixel, [:long], :long
  ffi_func :gfx_clouds, [:int_array, :long], :bool
  ffi_func :gfx_mesh, [:long, :int_array, :long, :int_array], :long
  ffi_func :gfx_dyn, [:float_array, :long, :long], :long
  ffi_func :gfx_ui, [:float_array, :long], :long
  ffi_func :gfx_sky, [:float_array, :long], :long
  ffi_func :gfx_cloud_boxes, [:float_array, :long], :long
  ffi_func :gfx_rain, [:float_array, :long], :long
  ffi_func :gfx_begin, [:float_array], :bool
  ffi_func :gfx_chunks, [:int_array, :long, :long], :long
  ffi_func :gfx_draw_dyn, [], :long
  ffi_func :gfx_draw_hand, [], :long
  ffi_func :gfx_draw_rain, [], :long
  ffi_func :gfx_draw_clouds, [], :long
  ffi_func :gfx_end, [], :long
  ffi_func :gfx_screenshot, [:str], :void
  ffi_func :gfx_gpu_ms, [], :double
  ffi_func :gfx_wait_ns, [], :long
  ffi_func :au_init, [], :bool
  ffi_func :au_load_ogg, [:long, :str, :double], :long
  ffi_func :au_seconds, [:long], :double
  ffi_func :au_play, [:long, :double], :void
  ffi_func :gfx_width, [], :long
  ffi_func :gfx_height, [], :long
  ffi_func :gfx_ns, [], :long
  ffi_func :gfx_quit, [], :void
  ffi_func :in_poll, [], :bool
  ffi_func :in_key, [:long], :bool
  ffi_func :in_key_pressed, [:long], :bool
  ffi_func :in_button, [:long], :bool
  ffi_func :in_button_pressed, [:long], :bool
  ffi_func :in_mouse_dx, [], :double
  ffi_func :in_mouse_dy, [], :double
  ffi_func :in_wheel, [], :double
  ffi_func :in_focus_lost, [], :bool
  ffi_func :in_mouse_x, [], :double
  ffi_func :in_mouse_y, [], :double
  ffi_func :in_capture, [:long], :void
  ffi_func :gfx_fullscreen, [:long], :void
  ffi_func :gfx_limit, [:long], :long
end

module Key
  A = 4
  D = 7
  E = 8
  F = 9
  G = 10
  Q = 20
  R = 21
  S = 22
  T = 23
  W = 26
  N1 = 30
  ESCAPE = 41
  SPACE = 44
  F3 = 60
  F5 = 62
  F11 = 68
  LCTRL = 224
  LSHIFT = 225
end
