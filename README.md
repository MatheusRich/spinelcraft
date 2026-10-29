# <img src="assets/logo.png" alt="Spinelcraft" height="96">

A small Minecraft-like game written in Ruby. The [Spinel](https://github.com/matz/spinel) compiler turns the Ruby into a native executable, and SDL3 GPU (Metal on macOS) draws it. All game logic is Ruby. The only C is a thin layer in `game/gfx.rb` that passes data to SDL.

![Green hills with oaks and a river at the default 1600-block view](screenshots/landscape.png)

## Screenshots

| | |
| --- | --- |
| ![A sunset over green hills with oaks](screenshots/sunset.png) | ![A zombie, a skeleton and a creeper on a stone floor](screenshots/mobs.png) |
| ![A cave lit by lava](screenshots/cave.png) | ![The creative block picker](screenshots/inventory.png) |

![A chest, doors, a ladder, a lit furnace, a crafting table and a bed, with dropped items in front](screenshots/blocks.png)

![The world from 400 blocks up with a 5000-block view](screenshots/far.png)

## Build and run

You need macOS and a built Spinel compiler. `brew bundle` installs the libraries in `Brewfile`.

```sh
./build.sh      # writes ./spinelcraft
./spinelcraft
```

`build.sh` uses `$SPINEL` if you set it. Otherwise it uses `spinel` from `PATH`, and then `~/Documents/dev/oss/spinel/spinel`. Use a recent Spinel.

The game saves to `world.sav` in the current directory and loads it at start. To get a new world, delete the file or start with `NEW=1`.

## Controls

| Key | Action |
| --- | --- |
| WASD, mouse | Move, look |
| Space | Jump, swim up, fly up; double-tap: fly (creative) |
| Left Shift | Sneak, fly down, get out of a boat |
| Left Ctrl, double-tap W | Sprint |
| Left click | Break a block, attack |
| Right click | Place a block, use an item or a block, throw an egg, get in a boat |
| 1–9, wheel | Select a hotbar slot |
| E | Inventory and crafting |
| F3 | Debug text |
| F5 | Save |
| T, / | Chat and commands |
| Esc | Pause, play again |

The game starts on a title screen, with buttons to play, to start a new world, and to quit. The pause menu has sliders for brightness, volume, music, render distance and field of view, and buttons for the graphics (FANCY or FAST), fullscreen, the debug text, and save and quit to the title. FAST graphics simplifies how some things look, so the game uses less memory and has less to draw. It helps on a weaker computer.

In survival, start by punching a tree. The inventory shows a recipe after you have had its ingredient. Some recipes need a crafting table or a furnace near you.

## What is in it

- An endless generated world with continents, rivers, mountains and nine biomes, from snowy taiga to desert and jungle, plus caves, ores and trees.
- A day and night cycle, rain, flowing water and lava, and torch light.
- Thunderstorms: the sky goes dark enough for monsters by day, and lightning strikes near you. A strike hurts and burns what it hits, and its thunder comes later, as far behind as the sound needs to travel. `/weather thunder` starts a storm.
- Creative and survival modes, with health, hunger, tools, crafting and smelting.
- Iron and diamond armor. Right-click a piece to put it on, or put it in the armor row of the inventory. Armor lowers the damage of hits, arrows, explosions, lava and cactus as in Minecraft, and each hit wears it down.
- Animals, and monsters that come out in the dark. Shears take the wool of a sheep, but not of a baby sheep, and the sheep grows it back when it eats grass. A bucket milks a cow, and the milk ends the Hunger effect. A chicken lays an egg every 5 to 10 minutes. A thrown egg hatches a chick 1 time in 8. Wheat puts a cow, a sheep or a pig in love mode, and seeds put a chicken in love mode. Two animals of one kind in love mode make a baby, which grows up in 20 minutes. An animal follows a player who holds its food.
- Boats of oak, spruce and birch. Put one on water, get in, and paddle with WASD.
- Pumpkin patches. Shears cut leaves and wool fast, and carve a face into a pumpkin, and a carved pumpkin and a torch make a jack o'lantern, which lights the night. Pumpkin seeds grow a stem, and the stem grows new pumpkins. On October 31, some monsters wear a pumpkin on their heads.
- Bone meal. Skeletons drop bones, and a bone makes 3 bone meal. Bone meal makes a crop, a pumpkin stem or a sapling grow, and grows tall grass and flowers on a grass block.
- A view distance of up to 5000 blocks.
- A chat line with commands, as in Minecraft.
- Sounds from VoxeLibre, under free licenses. `assets/sounds/CREDITS.md` names the author and the license of each file.
- Music from VoxeLibre, under free licenses. `assets/music/CREDITS.md` names the author and the license of each track.

## Commands

T opens the chat line, and / opens it with a slash. The chat frees the mouse while it is open. Enter runs the line, Esc closes it, and Up and Down bring back the lines that you typed before. Cmd+V (Ctrl+V on other systems) pastes the text of the clipboard, without the line breaks and the characters that the font cannot draw. Tab completes a command name, an item name in `/give` and a mob name in `/summon`, and each next Tab puts the next name on the line. The names that fit show above the line. A line that starts with a slash is a command. The commands follow the syntax of Minecraft, and `~` gives a coordinate relative to the player.

| Command | Effect |
| --- | --- |
| `/time set day\|noon\|night\|midnight\|<time>` | Set the time of day. A time is in ticks, or has the unit `d` (days), `s` (seconds) or `t` (ticks) |
| `/time add <time>` | Move the clock forward |
| `/time query` | Show the time in ticks and the day |
| `/weather clear\|rain\|thunder` | Stop the rain, start the rain, or start a thunderstorm. No key does this |
| `/gamemode survival\|creative` | Switch between survival and creative. No key does this |
| `/tp <x> <y> <z>` | Go to a place, for example `/tp ~ ~10 ~` |
| `/give <item> [count]` | Get an item, for example `/give diamond_pickaxe` |
| `/summon <pig\|sheep\|cow\|chicken\|zombie\|skeleton\|creeper> [x y z]` | Make a mob, 3 blocks in front of you or at a place |
| `/kill` | Die |
| `/seed` | Show the seed of the world |
| `/spawn` | Go to the spawn point |
| `/help` | List the commands |

## Development

See [docs/DEVELOPING.md](docs/DEVELOPING.md) for the code layout, the test switches, the debug log and the tests. `AGENTS.md` has the rules for contributors.

## Credits

The images in `assets/pixel-perfection` come from Pixel Perfection by Hugh "XSSheep" Rutland, as changed by the VoxeLibre and Mineclonia contributors. They have the [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) license. `assets/pixel-perfection/README.md` gives the sources.
