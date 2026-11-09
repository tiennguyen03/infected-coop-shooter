# Brief for a new co-developer's coding agent

You are joining an existing Roblox project with an owner (Tien) and his own Claude Code
setup. Your human is a second developer. This file is your orientation; `CLAUDE.md` at the
repo root holds the binding rules (Claude Code loads it automatically; any other agent:
read it first, it applies to you too).

## Read before writing code

1. `CLAUDE.md`: layout, conventions, commands, doc-sync rule.
2. `handoff/README.md`: current state, open work in priority order, Studio MCP gotchas
   (the section "Roblox Studio MCP" saves hours).
3. `docs/HISTORY.md`, then the doc for the area you touch (`CLAUDE.md` lists which doc owns
   what). Don't read everything up front; the docs are long.

## Non-negotiables

- **Never push to or merge into `main`.** Work on `<human>/<feature>`, open a PR, the owner
  merges. Push only when your human asks.
- **Never print, read aloud or commit secrets** (Open Cloud API keys, Hugging Face tokens,
  `~/.claude.json` contents). Your human uses their own keys in their user config.
- **Doc-sync every commit:** code/assets changes carry `handoff/README.md` (edit the
  feature's state line in place, never append a section), one `docs/HISTORY.md` row, and the
  feature doc. `.claude/hooks/doc-sync-check.js` (needs Node) blocks violations.
- **Checks after every change**, all must be clean:
  `stylua src tests && selene src && rojo build -o build.rbxlx && lune run tests/run`, then
  `rojo sourcemap default.project.json -o sourcemap.json && luau-lsp analyze --sourcemap sourcemap.json --defs=globalTypes.d.luau src`.
  (Fetch `globalTypes.d.luau` the way `.github/workflows/ci.yml` does if it's missing; it is
  gitignored.)
- **Code rules in short:** `--!strict` everywhere; tuning numbers only in
  `src/shared/Config.luau`; remotes in `Remotes.luau`, message kinds in `Messages.luau`,
  attribute names in `Attributes.luau` (never inline the strings); damage only through
  `DamageService.dealDamage`; server authoritative; state keyed per `Player` or per run
  (never `GetPlayers()[1]`); services hook run/player events via `Lifecycle.register`; pure
  rules in `src/shared/Rules/` with a `tests/<Rule>.spec.luau` written first.
- **Studio:** never create script instances in Studio for Rojo-managed files. A running
  playtest never sees synced code: Stop → Play. If a playtest is already running, it may be
  your human (or the owner) playing: ask before stopping it or firing commands into it.
- **Design calls go through the design agents** in `.claude/agents/` (Claude Code:
  `subagent_type` = the file name; other agents: read the file and follow its brief). They
  return doc text; your human and the owner approve before it lands.
- **Don't recreate other games' content.** The genre and structure are Helldivers-like; names,
  art and lore are original (`docs/LORE.md`).
- **The owner wants recommendations, not menus.** When there's a choice, propose one option
  with the reason.

## Coordination with the owner's sessions

The owner runs Claude Code on the same repo, often with several worktree subagents. To avoid
stepping on each other:
- Before starting, `git fetch` and check open PRs (`gh pr list`) and the "Open work" list for
  anything already in progress.
- Keep diffs narrow. `Config.luau`, `handoff/README.md` and `docs/HISTORY.md` conflict
  often: touch only the lines your feature owns, rebase on `main` before opening the PR.
- Line endings: the repo is LF. If a merge shows whole-file CRLF diffs, run `stylua src tests`.
- Uploaded asset ids (`assets/*/ASSET_IDS.md`, `src/shared/MeshAssets.luau`) belong to
  whoever uploaded them. Don't re-upload or replace an existing id without saying so in the PR;
  see `onboarding/README.md` > Asset permissions.

## Verifying in a live game (Studio MCP)

`solo_playtest` → `execute_luau` (target `client-1` or `server`) → `capture_screenshot` →
`get_runtime_logs`. `require()` inside `execute_luau` gives an un-initialised module copy:
drive the game by firing the `DevCommand` RemoteEvent from `client-1` (command list in
`handoff/README.md`). For a deterministic test: `God`, `ToggleSpawns`, `SetBots 0`, then
`SpawnEnemy` exactly what you need. Report outcomes honestly: unplaytested work is labelled
"built, not playtested" in the handoff.

## Good first tasks

Pick with your human and tell the owner which one:
- The integrated playtest of the Pike rework (checklist in `handoff/README.md` > Open work).
- Gun meshes: every gun still wears the rifle mesh (`assets/3d/build/build_assets.py`
  Weapons collection; style in `docs/STYLES.md`).
- A crawl clip for legless Infected (they limp on the stump now; `GoreService`,
  `EnemyService.cripple`).
- Move a pure calculation out of a service into `src/shared/Rules/` with its spec first
  (e.g. the dismemberment joint thresholds in `GoreService`).
