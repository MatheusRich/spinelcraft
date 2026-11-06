# Notes for agents

Spinelcraft is pre-alpha. No player, save or tool depends on old behavior yet.

- Do not keep compatibility with old names or old behavior. When a change makes old code obsolete, remove it.
- Do not add importers, fallbacks or guards for data from an earlier version of the game, except for the save sections below.
- A save is a set of named sections (`game/save_file.rb`). A new part of the game that needs saving gets a new section, and a save without that section loads with the value of the part for a new world. A new section needs no new `SAVE_VERSION`.
- Change `SAVE_VERSION` in `game/constants.rb` only when an existing section changes its meaning or its layout, or when `SaveFile` changes. Then an old save does not load, and the game moves it to `world-bad.sav` and starts a new world. Ask the user before such a change whether a converter for the old save is worth writing.
- Remove code that nothing calls.
- Write idiomatic Ruby where it costs no speed. When the speed is not known, measure it. Use `each`, `find` and the other `Enumerable` methods by default. Use `while` only with a measurement that shows the gain, and name that measurement in the commit.
- Name things so that a reader who did not see the diff understands them. A class name is a noun. A method name is not a verb in disguise. Do not abbreviate (`ox`, `dy`, `m`). Give each relevant numeric literal a named constant.
- Keep comments to a bare minimum, ideally none: the names and the structure explain the code. Write a comment only for what the code cannot say: a wiki citation, a value that the wiki does not confirm, or a reason that is not obvious. When code is unclear, give it a better name instead of a comment.
- Finish work unattended. Run the checks in this file, then run `/adversarial-review light` and fix each finding that is worth a fix. Then leave the change uncommitted in the working tree and stop. The user reads the code in the files and decides when to commit. Do not paste the diff into the chat.
- When the next step stays inside the task (a test, a follow-up fix, a second measurement, a review finding), take it. Ask only for a design choice or for new scope.
- Run `mise exec -- rubocop` and `mise exec -- reek main.rb game tools` before each commit, and fix each offense. Do not add a `# rubocop:todo`, `# rubocop:disable` or `:reek:` comment to new code. When a change makes an old method short enough, remove its `# rubocop:todo` comment. When a fix removes the last Reek offense of a method, run `mise exec -- ruby tools/reek_todo.rb`.
- Balance values (damage, durability, mining time, hunger, mob health, drops) copy Minecraft Java Edition on Normal difficulty. Take each value from minecraft.wiki, and cite its page in a comment beside the value, for example `# minecraft.wiki/w/Hunger`. When the wiki does not confirm a value, the comment says so.

## Tests

- A check that needs no `Game` and no `Gfx` goes in `test/` as a Minitest test, and `rake test` runs it under CRuby. Every other check goes in the self-test (`tools/selftest.sh`), which runs the compiled game.
- Run `tools/selftest.sh` itself and read its last line. Do not pipe it into `grep -c`. That hides the exit status and a crash. The run passes only when it prints `ALL n PASS`.
- Check what the player sees, such as the health, a sound or a mob that moves. A check of the internal state only (a flag or a helper) can pass while the game is wrong.
- When a change shows on screen, look at it before you hand it over. Build the test binary with `./build.sh test`, then take shots with `tools/shot.sh out.png NEW=1 MUTE=1 CAM=x,y,z,yaw,pitch` (pitch in radians) and read them. For motion, take shots at a few `FRAMES` values. Fix what looks wrong, then open the game for the user once.
- A bug fix comes with a regression check. Make sure that the check fails without the fix.
- After you change a file in `game/` that a Minitest test covers, or the test itself, mutation test that pair with mutineer:

  ```sh
  OPS=$(mise exec -- mutineer --list-operators | awk '/ tier [0-9] /{print $1}' | paste -sd, -)
  mise exec -- mutineer run game/vitals.rb --test test/vitals_test.rb --operators "$OPS" --since main
  ```

  `--since main` mutates only the lines that the branch changes. Leave it off to mutate the whole file.
- Each surviving mutant is a claim that a behavior has no test. When the mutant is equivalent (no test can see the change), name the reason. Otherwise, write the test that kills it, and run mutineer again. A run where every mutant is `errored` tested nothing.
- mutineer cannot mutate the self-test checks, because they run in the compiled game.
