# Pixel Perfection

These images come from Pixel Perfection, a 16x16 resource pack for Minecraft by Hugh "XSSheep" Rutland. We take them from VoxeLibre, a Luanti game that uses Pixel Perfection for most of its textures. VoxeLibre changed or redid some textures. The files here are copies from VoxeLibre, with no changes.

- License: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). If you change an image, the changed image keeps this license.
- Original pack: <https://www.planetminecraft.com/texture_pack/131pixel-perfection/>
- Source of these files: the `textures/` folder of <https://git.minetest.land/VoxeLibre/VoxeLibre> (the `master` branch, October 2026). VoxeLibre's `LEGAL.md` gives the license.

## Files

Each file has the name of its layer in `Tex` (`iron_pick.png` is `Tex::IRON_PICK`). `Tex::SPRITE_FILES` in `game/textures.rb` lists the files that the game loads.

| File | VoxeLibre file |
| --- | --- |
| `wood_pick.png`, `stone_pick.png`, `iron_pick.png`, `diamond_pick.png` | `default_tool_woodpick.png`, `default_tool_stonepick.png`, `default_tool_steelpick.png`, `default_tool_diamondpick.png` |
| `wood_axe.png`, `stone_axe.png`, `iron_axe.png`, `diamond_axe.png` | `default_tool_woodaxe.png`, `default_tool_stoneaxe.png`, `default_tool_steelaxe.png`, `default_tool_diamondaxe.png` |
| `wood_shovel.png`, `stone_shovel.png`, `iron_shovel.png`, `diamond_shovel.png` | `default_tool_woodshovel.png`, `default_tool_stoneshovel.png`, `default_tool_steelshovel.png`, `default_tool_diamondshovel.png` |
| `wood_sword.png`, `stone_sword.png`, `iron_sword.png`, `diamond_sword.png` | `default_tool_woodsword.png`, `default_tool_stonesword.png`, `default_tool_steelsword.png`, `default_tool_diamondsword.png` |
| `bow.png` | `mcl_bows_bow.png` |
| `arrow.png` | `mcl_bows_arrow_inv.png` |

## Add an image

1. Find the texture in the VoxeLibre `textures/` folder. Its raw URL is `https://git.minetest.land/VoxeLibre/VoxeLibre/raw/branch/master/textures/<name>.png`.
2. Save it here with the name of its `Tex` layer, and add a row to the table above.
3. Add the layer to `Tex::SPRITE_LAYERS` and the name to `Tex::SPRITE_FILES`.

The game loads only 16x16 images.
