# Infected Co-op Shooter

Roblox 4-player co-op shooter (Helldivers-style loadout power, original mechanics), grounded
military bio-horror setting. **Final product is 4-player co-op**; single-player is the current build target. Enemies are "the Infected" (model name `Infected`).

Read on demand, not up front:
- `handoff/README.md` — **current state, open work, dev-env startup, Studio MCP gotchas.**
  Start here in a fresh session.
- `docs/HISTORY.md` — what shipped, sprint by sprint, with links to each sprint doc.
- `docs/PLAN.md` — scope rules + roadmap (what is explicitly out of scope).
- `docs/LORE.md` — setting, tone, naming. Lore never overrides gameplay.
- `docs/PROGRESSION.md` — run structure: stages, hold, bosses, loop, Stand Down, the
  Infected roster, and the technical plan. Read before touching enemies, objectives or
  run flow.
- `docs/STYLES.md` — every visual decision: palette, icons, UI, low-poly 3D/Blender, VFX,
  performance budgets. Read before any visual work.
- `docs/MULTIPLAYER_READINESS.md` — co-op rules, single-player debt register, open design
  decisions. Read before touching run flow, pause, XP, death, spawning, or objectives.
- `docs/ARCHITECTURE.md` — code review findings and the ranked foundation backlog
  (F1-F11), plus how lobby, private match servers and the shared war map scale.
- `docs/sprints/` — one doc per shipped sprint; linked from HISTORY.md.
- `.claude/agents/` — design subagents: lore-developer, systems-designer, level-designer,
  playtest-critic. Use them for design calls in their area before building. They are
  read-only and hand back paste-ready doc text: apply what the owner approves, in the same
  commit as the work. performance-reviewer checks a feature against the STYLES budgets
  before it ships. art-director owns the look: build sheets from the lore developer's
  canon, then reviews the Blender preview renders (the engineer routes between them).

## Guiding rule

Simplest solution that creates a playable game. playability > stability > clean
architecture > visual polish. Performance (smooth on low-end devices) is a playability
concern, not polish.

## Project layout (Rojo)

| Disk | Roblox |
|---|---|
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared/` | `ReplicatedStorage.Shared` |

- `Main.server.luau` / `Main.client.luau` are the only entry points; every other file is a
  ModuleScript exposing `init()`, started from Main in dependency order.
- All tuning values live in `src/shared/Config.luau`. Never hardcode balance numbers.
- RemoteEvents are declared in `src/shared/Remotes.luau` (`REMOTE_NAMES`).
- Art sources: `assets/icons/build/icons.js` (icons), `assets/3d/build/build_assets.py`
  (meshes). Rendered PNG/FBX are outputs; edit the generator, not the output.

## Conventions

- `--!strict` in every file. `os.clock()` for timing, `task.*` over `wait`/`spawn`.
- Server is authoritative: clients send intent, server validates and simulates.
- Enemies: Models tagged `"Enemy"` with a Humanoid. Damage goes through
  `ItemEffectService.dealDamage` (the one damage entry point).
- UI is code-generated; disk is the single source of truth. No hand edits in Studio.
- Design for up to 4 players: state keyed by `Player` (cleaned on `PlayerRemoving`) or
  explicitly per run; never `GetPlayers()[1]`; `resetPlayer` touches only that player,
  `reset` only run state. New single-player shortcuts are not allowed; existing ones are
  listed in `docs/MULTIPLAYER_READINESS.md`.

## Commands (Rokit toolchain; `export PATH="$HOME/.rokit/bin:$PATH"` if a tool is missing)

- `rojo serve default.project.json` — sync (restart + reconnect after any project.json change)
- `stylua src && selene src && rojo build -o build.rbxlx` — static checks, run after every change
- Live verification: Studio MCP `solo_playtest` → `execute_luau` (fire `DevCommand` from
  `client-1`) → `capture_screenshot` → `get_runtime_logs`. Details in handoff/README.md.

## Workflow rules

- One feature per turn: build, verify in a playtest, then move on.
- Never create script instances in Studio for Rojo-managed files (duplicates break boot).
- A running playtest never picks up synced code: Stop → Play after every sync.
- Never print or commit API keys. The Open Cloud key lives in `~/.claude.json`.

## Doc-sync (every commit)

Docs are the project's memory across sessions, so a commit is complete only when its docs are
staged with it. A commit that touches `src/` or `assets/` carries:

1. `handoff/README.md` — replace the stale "current state" / "open work" lines (edit in
   place, never append a new section).
2. `docs/HISTORY.md` — one table row for the sprint or feature that shipped.
3. The feature's own doc (`docs/sprints/SPRINT_*.md`, `docs/STYLES.md` for visuals,
   `assets/*/README.md` for pipelines) — only the facts that changed.

Keep this file and handoff/README.md short; detail goes in the linked doc. State each fact in
one place and link to it. The hook `.claude/hooks/doc-sync-check.js` blocks a commit that
stages code without docs; `[no-docs]` in the message bypasses it for pure fixups.

Commit messages end with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` (or the
model running). `gh` is installed and logged in (repo scope); push with plain `git push`.
