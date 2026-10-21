---
name: find-extraction
description: Find the next class extraction or refactor in spinelcraft, and triage the candidates with an independent agent. Use when the user asks for the next refactor or extraction, or to make a big file or class smaller.
---

# Find an extraction

An **extraction** moves state and the behavior that uses it out of a big class (most often `Game`, which is reopened over `main.rb` and `game/*.rb`) into a class that owns them. It must pass the **deletion test**: delete the new class in your head. When its complexity comes back in every caller, it earns its place. When the complexity disappears with it, it was a pass-through, and it fails. A class that only reads another object's fields fails too. A plain file split that reopens the same class is a weaker fallback.

1. **Investigate.** Read the "Code quality" section of `todo.md`, the line counts (`wc -l main.rb game/*.rb`), and the outline of each long file: its `def` lines and its `@field =` lines. Look for a group of fields that a group of methods alone reads and writes. Then read the leads of Reek: `mise exec -- reek --no-progress -c /dev/null --smell FeatureEnvy main.rb game` and the same command with `--smell UtilityFunction`. A method that refers to an object more than to self, such as `m` for a mob, is a lead for a move into the class of that object. A lead on a number, such as `x`, is noise. Done when you have the outline of the five longest files, the todo items that name an extraction, and the Reek leads on objects.
2. **Pick three or four candidates.** For each one, write the lines and fields that would move, the state that the new class would own, and the calls back into the old class (such as `set_block`, `play_at`, `hurt`). Done when each candidate names its fields and its call sites with `file:line`.
3. **Triage with an independent agent.** Spawn one fresh `general-purpose` agent, not a fork, so it has none of your reasoning. Give it the candidates as facts, `AGENTS.md` and the deletion test. Tell it to edit nothing and run nothing. Ask it, for each candidate: the lines and fields that move, the interface, what crosses the boundary, the deletion test, the risks of the Spinel compiler, the tests that cover it, and the lines that leave the old class. Then ask for one recommendation, and say that "none passes" is a valid answer. Done when it names one candidate, or none.

Tell the user the recommendation and the candidates that failed, with the reasons. Build the change only when the user says so.
