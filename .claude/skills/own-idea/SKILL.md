---
name: own-idea
description: Come up with one feature or refactor for spinelcraft on your own, and build it unattended on a branch for the user to QA. Use when the user asks for an idea of your own, or when a scheduled run starts.
---

# Own idea

The user QAs one idea at a time. Ten branches at once were too much to QA. So this skill builds one **idea**: one feature or one refactor, small enough that the user can QA it in about 15 minutes.

1. **Check the queue.** Run `git branch --no-merged main --list 'idea/*'`. When a branch is listed, stop and tell the user that the branch waits for QA. Done when no idea branch is open.
2. **Gather candidates.** Read the sources below. Done when you have three candidates, and each candidate names what the player sees or what the code gains.
   - `todo.md`: the ideas, the Minecraft gaps and the code quality notes. Skip an item that is "Blocked by" something that does not exist yet.
   - The game itself: take shots of a few places (see the Tests section of `AGENTS.md`). Look for what is dull, ugly or wrong.
   - minecraft.wiki, for a system that the game has only in part. Parity is not the goal. A gap counts only when the game is better with it.
   - A refactor: follow steps 1 to 3 of the `find-extraction` skill. Its rule "build only when the user says so" does not apply here, because this skill is that permission.
   - Skip an idea that the user put off ("not now", "later") in the project memory or in `todo.md`.
3. **Pick one.** Pick the candidate with the most value for each minute of QA. Done when you can say in two sentences what it is and why it beats the other two.
4. **Build it** in a new worktree on a branch `idea/<slug>` off `main`. Follow `AGENTS.md`, and its finish rule too: checks, `/adversarial-review light`, fixes. Commit on the branch, because the branch is the unit of QA. Never commit on `main`. Done when the self-test prints `ALL n PASS` and the branch has its commits.
5. **Hand off.** Tell the user, in a few lines:
   - what the idea is, and why you picked it over the other two candidates,
   - how to see it: the command to run, the place to go or the screen to open, and what to look for,
   - what you are not sure of.

   Merging the branch into `main` is the user's call.
