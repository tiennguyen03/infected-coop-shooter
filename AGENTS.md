# Infected Co-op Shooter: rules for every developer and coding agent

Roblox 4-player co-op shooter (Helldivers-style loadout power, original names and mechanics),
grounded military bio-horror. Final product is 4-player co-op; solo plays with bots. Enemies
are "the Infected" (model name `Infected`); players are Pike soldiers.

**Session start:** `handoff/README.md` (now, who owns what, open work), then the notes in
`handoff/log/` newer than your last one. **Before proposing or building anything new:**
`docs/OWNER.md` (what the owner wants and has rejected).

Read on demand:
- `docs/PROGRESSION.md` (run, enemies, loadout, bosses), `docs/STYLES.md` (look, UI, 3D,
  VFX, budgets), `docs/LEVELS.md` (maps), `docs/LORE.md` (setting, naming; lore never
  overrides gameplay), `docs/MULTIPLAYER_READINESS.md` (co-op rules, before touching run
  flow, death, spawning, objectives), `docs/ARCHITECTURE.md` (code structure, backlog),
  `docs/PLAN.md` (scope).
- `docs/HISTORY.md` and `docs/sprints/`: what shipped and why. `docs/STUDIO_MCP.md`: machine
  setup and live testing in Studio.

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
- Art sources are generators (`assets/icons/build/icons.js`, `assets/3d/build/*.py`,
  `assets/audio/build/*.py`, `assets/animations/build/`); edit the generator, not the output.
- Uploaded assets belong to the Roblox group Boomin Dev Studios (`groupId` 270506601).

## Conventions

- `--!strict` in every file. `os.clock()` for timing, `task.*` over `wait`/`spawn`.
- Server is authoritative: clients send intent, the server validates and simulates.
- Enemies are Models tagged `"Enemy"` with a Humanoid; all damage goes through
  `DamageService.dealDamage`.
- UI is code-generated; disk is the source of truth. No hand edits in Studio, and never
  create script instances in Studio for Rojo-managed files.
- Up to 4 players: state keyed by `Player` or per run, never `GetPlayers()[1]`. A service with
  run or player state registers its hooks in `init()` with `Lifecycle.register`.
- Pure rules live in `src/shared/Rules/` with a `tests/<Rule>.spec.luau`; the spec comes first.

## Commands (Rokit; `export PATH="$HOME/.rokit/bin:$PATH"` if a tool is missing)

- Sync: `rojo serve default.project.json`. A running playtest never picks up synced code:
  Stop, then Play.
- After every change, all clean: `stylua src tests && selene src && rojo build -o build.rbxlx
  && lune run tests/run`, then `rojo sourcemap default.project.json -o sourcemap.json &&
  luau-lsp analyze --sourcemap sourcemap.json --defs=globalTypes.d.luau src`. CI runs the same.

## Git and docs

- Never commit to `main`. Branch `<name>/<feature>`, open a PR; the owner merges.
- Never print or commit API keys or tokens.
- A commit that touches `src/` or `assets/` carries its docs: `handoff/README.md` edited in
  place, one `docs/HISTORY.md` row, and the feature's own doc (facts that changed only).
  End each work session with one note in `handoff/log/` (format there). State each fact
  once and link to it; keep this file and the handoff short.
