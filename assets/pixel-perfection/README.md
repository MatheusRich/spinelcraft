# Pixel Perfection

These images come from Pixel Perfection, a 16x16 resource pack for Minecraft by Hugh "XSSheep" Rutland. We take them from VoxeLibre, a Luanti game that uses Pixel Perfection for most of its textures. VoxeLibre changed or redid some textures.

- License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). The changed images below keep this license.
- Original pack: <https://www.planetminecraft.com/texture_pack/131pixel-perfection/>
- Source of these files: the `textures/` folder of <https://git.minetest.land/VoxeLibre/VoxeLibre> (the `master` branch, October 2026). VoxeLibre's `LEGAL.md` gives the license.

Each file has the name of its layer in `Tex` (`iron_pick.png` is `Tex::IRON_PICK`). `Tex::IMAGE_FILES` in `game/textures.rb` lists the files that the game loads.

## Copies

These files are copies with no changes.

| File | VoxeLibre file |
| --- | --- |
| `wood_pick.png`, `stone_pick.png`, `iron_pick.png`, `diamond_pick.png` | `default_tool_woodpick.png`, `default_tool_stonepick.png`, `default_tool_steelpick.png`, `default_tool_diamondpick.png` |
| `wood_axe.png`, `stone_axe.png`, `iron_axe.png`, `diamond_axe.png` | `default_tool_woodaxe.png`, `default_tool_stoneaxe.png`, `default_tool_steelaxe.png`, `default_tool_diamondaxe.png` |
| `wood_shovel.png`, `stone_shovel.png`, `iron_shovel.png`, `diamond_shovel.png` | `default_tool_woodshovel.png`, `default_tool_stoneshovel.png`, `default_tool_steelshovel.png`, `default_tool_diamondshovel.png` |
| `wood_sword.png`, `stone_sword.png`, `iron_sword.png`, `diamond_sword.png` | `default_tool_woodsword.png`, `default_tool_stonesword.png`, `default_tool_steelsword.png`, `default_tool_diamondsword.png` |
| `bow.png` | `mcl_bows_bow.png` |
| `arrow.png` | `mcl_bows_arrow_inv.png` |
| `dirt.png`, `stone.png`, `sand.png`, `gravel.png` | `default_dirt.png`, `default_stone.png`, `default_sand.png`, `default_gravel.png` |
| `snow.png`, `snow_side.png`, `bedrock.png` | `default_snow.png`, `mcl_core_grass_side_snowed.png`, `mcl_core_bedrock.png` |
| `coal.png`, `iron.png`, `diamond.png` | `mcl_core_coal_ore.png`, `mcl_core_iron_ore.png`, `mcl_core_diamond_ore.png` |
| `log_side.png`, `log_top.png`, `planks.png` | `default_tree.png`, `default_tree_top.png`, `default_wood.png` |
| `cobble.png`, `brick.png`, `glass.png`, `wool.png` | `default_cobble.png`, `default_brick.png`, `default_glass.png`, `wool_white.png` |
| `cactus_side.png`, `cactus_top.png` | `mcl_core_cactus_side.png`, `mcl_core_cactus_top.png` |
| `rose.png`, `dandelion.png`, `sapling.png` | `mcl_flowers_poppy.png`, `flowers_dandelion_yellow.png`, `default_sapling.png` |
| `seeds.png`, `wheat_1.png`, `wheat_2.png`, `wheat_ripe.png` | `mcl_farming_wheat_stage_1.png`, `mcl_farming_wheat_stage_3.png`, `mcl_farming_wheat_stage_5.png`, `mcl_farming_wheat_stage_7.png` |
| `craft_top.png`, `craft_side.png` | `crafting_workbench_top.png`, `crafting_workbench_front.png` (VoxeLibre has no other side for the crafting table) |
| `door_lower.png`, `door_upper.png`, `door_item.png` | `mcl_doors_door_wood_lower.png`, `mcl_doors_door_wood_upper.png`, `doors_item_wood.png` |
| `furnace.png`, `furnace_side.png`, `furnace_top.png`, `furnace_lit.png` | `default_furnace_front.png`, `default_furnace_side.png`, `default_furnace_top.png`, `default_furnace_front_active.png` |
| `bed_item.png` | `mcl_beds_bed_red_inv.png` |
| `torch.png`, `ladder.png`, `fire.png` | `default_torch_on_floor.png`, `default_ladder.png`, `fire_basic_flame.png` |
| `apple.png`, `bread.png`, `wheat.png` | `default_apple.png`, `farming_bread.png`, `farming_wheat_harvested.png` |
| `porkchop.png`, `cooked_porkchop.png`, `iron_ingot.png` | `mcl_mobitems_porkchop_raw.png`, `mcl_mobitems_porkchop_cooked.png`, `default_steel_ingot.png` |
| `rotten_flesh.png` | `mcl_mobitems_rotten_flesh.png` |
| `mutton.png`, `cooked_mutton.png` | `mcl_mobitems_mutton_raw.png`, `mcl_mobitems_mutton_cooked.png` |
| `bucket.png`, `water_bucket.png`, `lava_bucket.png` | `mcl_buckets_bucket.png`, `mcl_buckets_water_bucket.png`, `mcl_buckets_lava_bucket.png` |

## Mob skins

The mob skins are in the layout of Minecraft skins: each face of each box of a model has its own rectangle of the image. `Tex::SKIN_FILES` lists them. The game loads them into a second texture array of 64x64 layers, and a skin of 64x32 fills the top half of its layer.

VoxeLibre replaced the creeper with another mob, so the creeper skin comes from Mineclonia, another game that continues MineClone 2. Its `mods/ENTITIES/mobs_mc/LICENSE-media.md` gives the same source and license as VoxeLibre: Pixel Perfection, CC BY-SA 4.0.

| File | Source file |
| --- | --- |
| `skin_pig.png`, `skin_sheep.png`, `skin_sheep_fur.png` | VoxeLibre `mobs_mc_pig.png`, `mobs_mc_sheep.png`, `mobs_mc_sheep_fur.png` |
| `skin_zombie.png`, `skin_skeleton.png` | VoxeLibre `mobs_mc_zombie.png`, `mobs_mc_skeleton.png`, changed by MysticTempest for VoxeLibre |
| `skin_creeper.png` | Mineclonia `mods/ENTITIES/mobs_mc/textures/mobs_mc_creeper.png` (<https://codeberg.org/mineclonia/mineclonia>, the `main` branch, October 2026) |

## Changed images

In Minecraft, grass, leaves and water are gray, and the biome gives them their color. Spinelcraft has no biome color, so these images have the plains color of Minecraft. The colors come from minecraft.wiki/w/Plains: grass `#91BD59`, foliage `#77AB2F` and water `#3F76E4`. A tint multiplies each channel of a pixel by the channel of the color.

| File | Change |
| --- | --- |
| `grass_top.png` | `mcl_core_grass_block_top.png` with the grass tint |
| `grass_side.png` | `default_dirt.png` with `mcl_core_grass_block_side_overlay.png` on top. The overlay has the grass tint. |
| `tall_grass.png` | `mcl_flowers_tallgrass.png` with the grass tint |
| `leaves.png` | `default_leaves.png` with the foliage tint |
| `water.png` | The first frame of `mcl_core_water_source_animation.png` with the water tint. The alpha is 170 at most. |
| `lava.png` | The first frame of `mcl_core_lava_source_animation.png` |

The chest and the bed are not blocks in VoxeLibre. They are models with one 64x64 image for all their faces: `mcl_chests_normal.png` and `mcl_beds_bed_red.png`. These images are parts of those two images, cut out and put together in a 16x16 image. A face takes the part of its image that it covers on the block, so the parts sit where the face is in its cell. The other pixels are clear.

| File | Change |
| --- | --- |
| `chest_front.png` | The front of the lid (5 rows) over the front of the base (its lower 9 rows), 1 pixel in from the left and the right, with the front of the latch in the middle |
| `chest_side.png` | The side of the lid over the side of the base, in the same way |
| `chest_top.png` | The top of the lid, turned a quarter turn, 1 pixel in from each edge |
| `bed_head_top.png`, `bed_top.png` | The top of the head half and of the foot half, turned so that the outer end of the half is on the right |
| `bed_head_side.png`, `bed_side.png` | The side of each half in rows 7-12, with the outer end on the right, and a leg in rows 13-15 at the outer end |
| `bed_head_end.png`, `bed_foot_end.png` | The outer end of each half in rows 7-12, with a leg in rows 13-15 at each corner |

## Add an image

1. Find the texture in the VoxeLibre `textures/` folder. Its raw URL is `https://git.minetest.land/VoxeLibre/VoxeLibre/raw/branch/master/textures/<name>.png`.
2. Save it here with the name of its `Tex` layer, and add a row to a table above.
3. Add the layer to `Tex::IMAGE_LAYERS` and the name to `Tex::IMAGE_FILES`.

The game loads only 16x16 images for blocks and items. An animated texture is a strip of frames, so take the first 16x16 frame.
