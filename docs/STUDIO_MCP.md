# Dev environment and live testing (Studio MCP)

Read this when you set up a machine or run a playtest; not needed otherwise. Moved out of
`handoff/README.md` on 2026-11-09 so the handoff stays short.

## Machine setup

Toolchain is Rokit-managed (`rokit.toml`): rojo 7.7.1, StyLua 2.5.2, selene 0.31.0,
luau-lsp 1.68.0, lune 0.11.1. Binaries in `~/.rokit/bin` — add to PATH if a tool is "missing":

```bash
export PATH="$HOME/.rokit/bin:$PATH"
```

Sync to Studio (keep this running in a terminal tab). **Match work:**

```bash
rojo serve default.project.json
```

then open **Checkpoint Delta** (125769854992316) in Studio, Rojo plugin → Connect
(localhost:34872). **Lobby work:** `rojo serve lobby.project.json --port 34873` into a lobby
place (Nova: ZCS Dev). Which project goes into which place: [Places and publishing](#places-and-publishing)
below; get it wrong and Rojo overwrites that place's Studio copy with the other game. After
any `*.project.json` change, restart `rojo serve` and reconnect.

## Places and publishing

The game is **one experience, "Co-op Zombie Shooter"** (group Boomin Dev Studios, universe
10775557234), with two places. Ids live in `Config.Places`.

| Place | Holds | Rojo project | Who |
|---|---|---|---|
| Co-op Zombie Shooter, 87556879379942 (**start place**: where the app drops you) | the lobby (the Carrier) | `lobby.project.json` | published from `main` only |
| Checkpoint Delta, 125769854992316 | the match | `default.project.json` | Tien's day-to-day match work |
| Nova's own experience: ZCS Dev 83558708746036 -> Match Dev 108949482095254 | test copies of both | both | Nova (`Config.Places.Dev`: launches and the trip home stay inside it) |

Rules (from the 2026-11-09 mix-up, when the app kept opening the old match):
1. **A project only connects to its own kind of place.** `default.project.json` never in the
   start place; `lobby.project.json` never in Checkpoint Delta. Rojo makes the open place
   whatever the project says.
2. **Git is the source of truth.** Places are only where code is published; no hand edits
   in Studio.
3. **The real places are published from `main`** (after the PR merges), from a folder on
   `main`: `rojo build lobby.project.json -o lobby.rbxlx` and `rojo build -o match.rbxlx`,
   open each file, then publish it to its place. Build in your usual folder: a fresh
   clone or worktree has no `src/shared/AnimationClips/*.json` (git-ignored Mixamo tables),
   and its build comes out without them.
4. **Save is not publish.** "Save to Roblox (As)" only stores a version; players get the
   version from **File → Publish to Roblox** (Alt+P). A window opened from Creator Hub is
   already linked to its place, so Publish asks nothing. A local file asks: Boomin Dev Studios
   → the Co-op Zombie Shooter tile → the place → Overwrite.
5. **Check it went out:** Studio MCP `manage_experience` (`action = "get"`, `universe_id`
   10775557234, `place_id`) shows the place's `updated_at`; it moves on every publish.
6. **Old servers keep old code.** After a publish, close the app, wait a minute and rejoin;
   if it still shows the old build: Creator Hub → the game's ⋯ → Shut Down All Servers.
7. **The start place can't be changed** in Roblox. To move what players land on, publish the
   other content into the start place (that is how the lobby got there on 2026-11-09).
8. Teleports don't run in Studio. A real lobby -> match -> lobby trip needs both places
   published from the same commit (`docs/LOBBY_MATCH_HANDOFF.md` > The live test).

Static checks after every change:

```bash
stylua src
```

```bash
selene src
```

```bash
rojo build -o build.rbxlx
```

VS Code: `.vscode/extensions.json` recommends Luau LSP, StyLua, selene and Rojo
extensions; `.vscode/settings.json` points them at the Rokit binaries.

## Roblox Studio MCP (live verification)

Server `robloxstudio` (`@chrrxs/robloxstudio-mcp@latest --auto-install-plugin`) is
configured at user scope in `~/.claude.json`, so it is available in any Claude Code session.
Studio must be open with the MCP plugin connected. Tools: `solo_playtest`, `execute_luau`
(targets `server` / `client-1`), `grep_scripts`, `get_script_source`, `get_runtime_logs`,
`capture_screenshot`, `upload_asset`, `manage_instance`.

Hard-won gotchas:
- **Studio MCP gotchas found 2026-11-07.** (1) A runtime error inside `execute_luau`
  comes back as "Unknown error" with no message: wrap the body in `pcall` and return the
  error string. (2) `Player.Character.Archivable` is false, so `Character:Clone()` returns
  nil; set it true around the clone. (3) If `solo_playtest` returns "Unknown error" and
  `get_connected_instances` shows a stale standalone "Server" instance, drive play with
  the other server's `mcp__Roblox_Studio__start_stop_play` (studio id from
  `list_roblox_studios`) and keep using `mcp__robloxstudio__execute_luau` with
  `instance_id` of the COD.rbxl instance. (4) Measuring movement: disable the
  PlayerModule controls and `UnbindFromRenderStep("Momentum")` on the client, drive
  `Humanoid:Move` yourself and sample `AssemblyLinearVelocity`; a healthy body reaches
  WalkSpeed within 0.1 s. A hand-built minimal rig in the same spot is the reference.
- **Studio MCP gotchas found in the Warden v2 session (2026-11-07).** (5) When a stale
  instance is listed, every `robloxstudio` tool needs `instance_id` (here
  `instance:75r-q99`) or it returns "Unknown error"; `solo_playtest start` also needs
  `mode: "play"`, and `execute_luau` takes the peer as `target` (`server` / `client-1`),
  not as part of the instance id. (6) A playtest can boot into `Ended Wiped`; fire
  `RestartRun` and wait for `RunState Explore` before any spawn command. (7) Client-side
  `AnimationTrack.Animation.Name` is always "Animation" for server-loaded tracks: identify
  tracks by `Length` on the client, by name on the server. (8) A server Humanoid driven by
  `MoveTo` reports `MoveDirection` = 0; test "moving" with the root's
  `AssemblyLinearVelocity`. (9) Published animation ids go into `Config.Animations.Ids`
  with the `rbxassetid://` prefix; a bare number fails with "unknown AssetId protocol".
  (10) The owner may be playing the same Studio playtest you drive (their F1 commands and
  call-ins show in the logs): read, do not hijack the camera or restart the run under
  them. To photograph a body without them: `UnbindFromRenderStep("OTSCamera")` on
  client-1 and set `CurrentCamera` Scriptable. (11) `execute_luau` with a `task.wait`
  over ~30 s returns "Unknown error": wait in 10 s slices. (12) Vector3 values do not
  JSON-serialise in a returned table: format them as strings.
- **`execute_luau` runs in an isolated VM.** `require()` returns a fresh, un-`init()`ed
  module copy — calling service functions from eval hits nil remotes. Drive the real game by
  firing the `DevCommand` RemoteEvent from `client-1`; use eval only to read Instance/
  attribute state. Stateless modules (GroundUtil) are fine in eval.
- **Dev tools v2 (2026-11-07).** In game, F1 opens the dev panel (cursor freed; grouped
  Player / Run / Infected / Squad / Teleport / Checks) with a live info line (fps, RunState,
  Infected, GOD, SPAWNS OFF). Hotkeys with the panel closed: F2 god, F3 clear Infected, F4
  10 Walkers, F5 restart, F6 fill Resupply, F7 spawning on/off. Teleports run client-side.
- DevCommand commands (fire from `client-1`): God (toggle; player attribute DevGod skips
  enemy damage), Heal (also revives), DownPlayer(botName?), RevivePlayer(botName?),
  KillPlayer, DownBot, KillBots, SetBots(n), ToggleSpawns (workspace DevSpawnsOff),
  ActivateObjective (hold zone now), ForceObjectiveComplete, ForceMissionSuccess, ForceWipe,
  RestartRun, FillResupply, SpawnEnemy(type, count), ClearEnemies, SetCallIn(slot, id),
  GiveUpgrade(id), ClearUpgrades, RefillAmmo, RestockCallIns, SetWeapon(id),
  DropUpgradeCrate, DropSupplyCrate, PrintRunState, VerifyCleanup (expects a dead run: in a
  live run it reports the armed objective zone and natural spawns). Pick a card via the
  `Resupply` remote (client fires "pick", crateId, cardId within 5.5 studs of the card) or
  walk the character into it. Call-ins: `CallIn` remote (slot, landingPoint). Teleport the
  character from `client-1` (`root.CFrame = ...`); `Humanoid:MoveTo` loses to live input.
  For a deterministic test: God + ToggleSpawns + SetBots 0, then spawn exactly what you need.
- A running playtest never picks up synced code — always Stop → Play after a sync. Studio
  MCP sometimes can't tear down a wedged playtest; manual Stop → Play fixes it.
- `grep_scripts` / `get_script_source` return "Unknown error" when Rojo isn't connected or
  when the playtest has ended (peers gone). Check `solo_playtest` status first.
- NEVER create script instances in Studio for files Rojo manages (duplicates break boot).
- **Measuring footfall phases** (`Config.Audio.Footsteps.Phases`): on `client-1`, anchor
  the live character's root, load each locomotion clip from `Config.Animations.Ids` onto
  its Animator at `Action4` priority, play it looped alone, sample `TimePosition / Length`
  and `LeftFoot`/`RightFoot` `Position.Y - root.Position.Y` every Heartbeat for two loops,
  and take the phase where each foot first drops within 0.06 studs of its minimum. The
  character must be alive (a dead R15 has broken joints, so the feet never move) and the
  scripted `MoveTo` route does not work while the control module runs.

- **Gotchas found 2026-11-09.** (13) Group-owned sounds and animations only play in a place
  the group owns (any place in Co-op Zombie Shooter, or a place in a group experience); a
  personal copy plays them silent.
  `game.CreatorType` / `CreatorId` in an `execute_luau` on `edit` tells you who owns the open
  place. (14) A ragdolled body's parts are server-owned and in the `Gore` collision group;
  test kills with `Humanoid.Health = 0` on the server (no push) or real `FireWeapon` shots
  from `client-1` (the hit listeners only run for real damage). (15) Before driving a browser
  with Claude in Chrome, check `list_connected_browsers`: another machine's Chrome can be
  the one selected. (16) `execute_luau` cannot reach `edit` while a playtest runs.
