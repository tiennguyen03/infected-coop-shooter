# Infected Co-op Shooter: rules for every developer and coding agent

Roblox 4-player co-op shooter (Helldivers-style loadout power, our own names), grounded
military bio-horror; solo plays with bots. Enemies are "the Infected" (model `Infected`);
players are Pike soldiers.

**Session start:** `handoff/README.md` (now, who owns what, open work), then the notes in
`handoff/log/` newer than your last one. **Before proposing or building anything new:**
`docs/OWNER.md` (what the owner wants and has rejected).

Read on demand, **only the section you need** (big docs open with a Contents line):
`docs/PROGRESSION.md` (run, enemies, loadout, bosses), `docs/STYLES.md` (look, UI, 3D, VFX,
budgets), `docs/LEVELS.md` (maps), `docs/LORE.md` (setting, naming; never overrides
gameplay), `docs/MULTIPLAYER_READINESS.md` (before touching run flow, death, spawning,
objectives), `docs/ARCHITECTURE.md` (code), `docs/PLAN.md` (scope), `docs/LATER.md`
(designed, not built). What shipped: `docs/HISTORY.md`, `docs/sprints/`. Studio:
`docs/STUDIO_MCP.md`.

## Guiding rule

Simplest solution that creates a playable game: playability > stability > clean
architecture > visual polish. Smooth on low-end devices is playability, not polish.

## Project layout (Rojo)

| Disk | Roblox |
|---|---|
| `src/server/` | `ServerScriptService.Server` |
| `src/client/` | `StarterPlayer.StarterPlayerScripts.Client` |
| `src/shared/` | `ReplicatedStorage.Shared` |

- `Main.server.luau` / `Main.client.luau` are the only entry points; every other file is a
  ModuleScript with `init()`, started from Main's `BOOT` list in dependency order.
- All tuning values live in `src/shared/Config.luau`. Per-item values (guns, call-ins,
  grenades) live on that item's own row with a default, never in a list of item names
  elsewhere: loadouts change.
- Remotes in `src/shared/Remotes.luau`, message kinds in `Messages.luau`, attribute names in
  `Attributes.luau`. Never inline those strings.
- Art sources are generators (`assets/*/build/`); edit the generator, not the output.
- Uploaded assets belong to the Roblox group Boomin Dev Studios (`groupId` 270506601).

## Conventions

- `--!strict` in every file. `os.clock()` for timing, `task.*` over `wait`/`spawn`.
- Server is authoritative: clients send intent, the server validates and simulates.
- Enemies are Models tagged `"Enemy"` with a Humanoid; all damage goes through
  `DamageService.dealDamage`.
- UI is code-generated; disk is the source of truth: no hand edits or new scripts in Studio.
- Up to 4 players: state keyed by `Player` or per run, never `GetPlayers()[1]`. A service with
  run or player state registers its hooks in `init()` with `Lifecycle.register`.
- Pure rules live in `src/shared/Rules/` with a `tests/<Rule>.spec.luau`; the spec comes first.

## Commands (Rokit; `export PATH="$HOME/.rokit/bin:$PATH"` if a tool is missing)

- Places: the start place holds the lobby (`lobby.project.json`), Checkpoint Delta the match
  (`default.project.json`); never connect a project in the other place; publish (not Save)
  from `main` only (`docs/STUDIO_MCP.md` > Places and publishing).
- Sync: `rojo serve default.project.json`; a running playtest needs Stop, then Play.
- After every change, all clean: `stylua src tests && selene src && rojo build -o build.rbxlx
  && lune run tests/run`, then `rojo sourcemap default.project.json -o sourcemap.json &&
  luau-lsp analyze --sourcemap sourcemap.json --defs=globalTypes.d.luau --ignore "src/lobby/**" src`,
  plus the lobby place's build and types (top of `.github/workflows/ci.yml`). CI runs the same.
- The lobby is its own Rojo project: `rojo serve lobby.project.json --port 34873`.

## Git and docs

- Never commit to `main`: branch `<name>/<feature>`, open a PR; the owner merges. Never
  print or commit API keys or tokens.
- A commit that touches `src/` or `assets/` carries its docs: `handoff/README.md` edited in
  place, one `docs/HISTORY.md` row, and the feature's own doc (facts that changed only).
  Work that opens, finishes or needs an owner decision also moves its line in
  `docs/BACKLOG.md` (the owner's one page; plain words).
  End each work session with one note in `handoff/log/` (format there).
- **Doc size budget:** state each fact once and link to it, never repeat it. This file
  ≤ 4.5k, `handoff/README.md` ≤ 7k (now only), `docs/BACKLOG.md` ≤ 10k, a HISTORY row ≤ 2
  lines; older rows move to `docs/history/`. Delete superseded text.
