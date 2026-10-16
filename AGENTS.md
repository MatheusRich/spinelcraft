# Notes for agents

Spinelcraft is pre-alpha. No player, save or tool depends on old behavior yet.

- Do not keep compatibility with old saves, old names or old behavior. When a change makes old code obsolete, remove it.
- Do not add importers, fallbacks or guards for data from an earlier version of the game.
- When the save format changes, change `SAVE_VERSION` in `game/constants.rb`. Then an old save does not load, and the game moves it to `world-bad.sav` and starts a new world. That is all the old save gets.
- Remove code that nothing calls.
- Write idiomatic Ruby where it costs no speed. When the speed is not known, measure it.
- Balance values (damage, durability, mining time, hunger, mob health, drops) copy Minecraft Java Edition on Normal difficulty. Take each value from minecraft.wiki, and cite its page in a comment beside the value, for example `# minecraft.wiki/w/Hunger`. When the wiki does not confirm a value, the comment says so.

## Tests

- A check that needs no `Game` and no `Gfx` goes in `test/` as a Minitest test, and `rake test` runs it under CRuby. Every other check goes in the self-test (`tools/selftest.sh`), which runs the compiled game.
- Check what the player sees, such as the health, a sound or a mob that moves. A check of the internal state only (a flag or a helper) can pass while the game is wrong.
- A bug fix comes with a regression check. Make sure that the check fails without the fix.
- After you change a file in `game/` that a Minitest test covers, or the test itself, mutation test that pair with mutineer:

  ```sh
  OPS=$(mise exec -- mutineer --list-operators | awk '/ tier [0-9] /{print $1}' | paste -sd, -)
  mise exec -- mutineer run game/vitals.rb --test test/vitals_test.rb --operators "$OPS" --since main
  ```

  `--since main` mutates only the lines that the branch changes. Leave it off to mutate the whole file.
- Each surviving mutant is a claim that a behavior has no test. When the mutant is equivalent (no test can see the change), name the reason. Otherwise, write the test that kills it, and run mutineer again. A run where every mutant is `errored` tested nothing.
- mutineer cannot mutate the self-test checks, because they run in the compiled game.
