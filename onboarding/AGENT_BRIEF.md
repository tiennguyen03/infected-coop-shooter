# Brief for a new co-developer's coding agent

You are joining a Roblox project with an owner (Tien) and a second developer (your human).
Several people and agents work on it at once, so the shared files are how you coordinate.

1. Read `AGENTS.md` (Claude Code loads it through `CLAUDE.md`; any other agent: read it
   first). It holds every rule: layout, conventions, checks, git and docs.
2. Read `handoff/README.md`, then the notes in `handoff/log/` newer than your human's last
   one. That is what changed since you were last here.
3. Read `docs/OWNER.md` before proposing anything: what the owner wants and has rejected.
4. Claim work in the open-work table of `handoff/README.md` before starting; stay in your
   human's area (the ownership table). Bugs in someone else's files go to them.
5. End every session: edit `handoff/README.md` in place, add one note to `handoff/log/`,
   open a PR to `main`. Never merge it yourself.

Coordination tips:
- `git fetch` and `gh pr list` before starting; rebase on `main` before opening a PR.
- `Config.luau`, `handoff/README.md` and `docs/HISTORY.md` conflict often: touch only your
  lines.
- If a Studio playtest is already running it may be someone playing: ask before stopping it.
- Uploads go to the group (`groupId` 270506601) with your own group key, never a personal one.
- Live testing in Studio: `docs/STUDIO_MCP.md`.
