# Sprint 1: Pick a Mission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A soldier on the Carrier opens the map room's Mission Board, picks Checkpoint Delta or Mile 14, presses DEPLOY and lands (alone with bots) in the mission they picked; Mile 14 plays end to end on a grey-block v2 frame with its own objectives and the Warden as a stand-in.

**Architecture:** One match place builds any mission. A shared `MissionCatalog` (plain data) lists missions; the lobby writes the pick to a MemoryStore HashMap keyed by the reserved server's `PrivateServerId`; the match resolves the mission at boot (`Missions/init`) before `ArenaService` builds. Everything Delta-only (map size, pads, boss route, hold point, Delta's extra builders, the Delta XL hooks) moves onto the mission file, with Delta's values pointing at the same Config values as today so Delta does not change.

**Tech Stack:** Luau (`--!strict`), Rojo, Lune specs (`tests/*.spec.luau`), MemoryStoreService, TeleportService, Studio MCP for live checks.

**Spec:** `docs/superpowers/specs/2026-11-20-game-loop-design.md` (sections 1-5, sprint 1, "Calls made after the builder check").

## Global Constraints

- Work in `C:\Users\Bread\ras-integration` on a new branch `claude/loop-s1-pick-mission` from `claude/test-mix-6`; one PR into `main` titled for sprint 1 (stacked on #92-#99, say so in the body).
- `--!strict` in every file; `os.clock()` for timing; `task.*`.
- Tuning in `src/shared/Config.luau`; remote names in `Remotes.luau`, message kinds in `Messages.luau`, attribute names in `Attributes.luau`; never inline those strings.
- Pure rules in `src/shared/Rules/` with a spec in `tests/` written first.
- Player-facing text in plain words (`docs/OWNER.md`; the ObjectiveDefinitions spec's BANNED list applies to new rows).
- Delta must build and play exactly as before; Delta XL (`Config.DeltaXL.Enabled`, and the dev toggle) must keep working.
- Delta and Mile 14 are both open from day one; Mile 14's extraction is one-way (insert at the Toll Plaza admin lot, extract at the Rest Stop alt pad); the Warden stands in as Mile 14's boss.
- Files in `src/lobby/` are Nova's: every change there is listed under **Heads-up** in the session's `handoff/log/` note.
- After every task, all clean: `stylua src tests && selene src && rojo build -o build.rbxlx && rojo build lobby.project.json -o lobby.rbxlx && lune run tests/run`, then both luau-lsp runs (`AGENTS.md` > Commands). `export PATH="$HOME/.rokit/bin:$PATH"`.
- Commits that touch `src/` carry docs or `[no-docs]` (the doc-sync hook); the last task carries the docs for the whole sprint. Messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No Studio MCP while the owner is playing; ask before stopping a playtest.

## Where this plan differs from the spec (and why)

- **Studio fallback:** the spec's "a `mission` field in `Rules/Handoff` launch data" is dropped. The map is built at boot, before any player's join data exists, and teleports don't run in Studio anyway; the Workspace `Mission` attribute (already read today) is the Studio path.
- **Mile 14's placed sleepers** (named posts) wait for sprint 5's cover pass; sprint 1 scatters the Infected over the 640 x 900 frame and keeps the roaming spawns at its edges (both barricades and the pine lines are edges).
- **Catalog fields** `Pay`, `Points`, `Unlock`, `Lighting` wait for the sprints that read them (YAGNI); night is already keyed by mission id (`Config.Awareness.Night`).

## Review Focus

1. **MemoryStore read fails or the key expired** (slow teleport, MemoryStore outage): the match must still boot, on Delta, with a warning, never an error that stops boot. Test: `MissionPick.choose` returns the default for nil/garbage stored values (Task 1).
2. **A stored or tagged id that is not in the catalog, or is outside its `Window`** (an old lobby build, a removed mission): fall back to the default, never `assert`. Test in Task 1.
3. **Delta drifting after the refactor** (a builder now skipped, a pad moved, the Warden walking a different route): compare the Task 0 fingerprint after Task 3. Test: the fingerprint matches exactly (Task 3 Step 5).
4. **A client firing the board remote with a made-up id, or twice quickly** (double DEPLOY): the server validates the id against `MissionCatalog.isOpen` and refuses a second launch while one is in flight. Test: source-wiring assertion plus a live double-click check (Task 7).
5. **Mile 14 positions that fall outside the 640 x 900 frame or inside a block** (a site in a hill, a pad under the deck): spec asserts every `Maps.mile14` site and the mission's Landing/Extract/Boss points are inside the frame (Task 5), and the live walk checks each one (Task 6).

---

### Task 0: Baseline Delta fingerprint

**Files:**
- Create: `scratchpad/delta_fingerprint_before.json` (session scratchpad, not committed)

**Interfaces:**
- Produces: the fingerprint JSON Task 3 compares against.

- [ ] **Step 1: Create the branch** — `git checkout -b claude/loop-s1-pick-mission claude/test-mix-6` in `C:\Users\Bread\ras-integration`.
- [ ] **Step 2: Record Delta as built today.** With the owner's OK, `solo_playtest` on Checkpoint Delta (port 34874), then `execute_luau` on the server: count every BasePart under `workspace.Arena` by `Name`, the sum of their positions rounded to 0.1, the `Helipad` / `AltHelipad` CFrames, `ArenaService.landingPoint()`, `ArenaService.spawnInset()`, the Floor's size, and `Config.Index.Warden.SpawnPosition` / `Waypoints`. Save the printed JSON to the scratchpad file. Stop the playtest.

---

### Task 1: Mission catalog and the pick rule

**Files:**
- Create: `src/shared/MissionCatalog.luau`
- Create: `src/shared/Rules/MissionPick.luau`
- Test: `tests/MissionCatalog.spec.luau`, `tests/MissionPick.spec.luau`

**Interfaces:**
- Produces:
  - `MissionCatalog.Rows: { [string]: Row }`, `MissionCatalog.Order: { string }` (board order), `MissionCatalog.DEFAULT = "delta"`, `MissionCatalog.get(id: string): Row?`, `MissionCatalog.isOpen(row: Row, now: number): boolean` (Window only this sprint; nil Window = open).
  - `export type Row = { Id: string, Name: string, District: string, Layout: string, Pool: string, Boss: string, Blurb: string, Players: { number }, Window: { From: number, To: number }?, Place: number? }` — `Players = { 1, 4 }`, `Boss = "warden"` for both. Plain data, no Roblox requires (specs load it).
  - Rows: `delta` (Name "Checkpoint Delta", District "DELTA", Layout "Delta", Pool "delta", Blurb "The army checkpoint on the highway out. Take it back so the helicopter can land.") and `mile14` (Name "Mile 14", District "MILE 14", Layout "Mile14", Pool "mile14", Blurb "A dead convoy at night. Land at the toll plaza, get to the rest stop. Stay quiet.").
  - `MissionPick.choose(stored: unknown, tagged: unknown, now: number, catalog): string` — first valid of: `stored` (a table with string `mission`), `tagged` (a string), else `catalog.DEFAULT`. Valid = in the catalog and `isOpen`.
  - `MissionPick.launchRecord(missionId: string, userIds: { number }): { mission: string, party: { number }, version: number }` — the MemoryStore value the lobby writes (version 1).

- [ ] **Step 1: Write the failing specs.**
  - `MissionCatalog.spec`: `every row's Layout file exists` (`src/server/Missions/<Layout>.luau` via `fs.isFile`); `every row's Pool is a map in ObjectiveDefinitions.Maps`; `Order lists every row once`; `DEFAULT is a row`; `isOpen respects Window` (row with `Window = {From=100, To=200}`: false at 50, true at 150, false at 250); `blurbs use no banned word` (the ObjectiveDefinitions BANNED list).
  - `MissionPick.spec`: `stored mission wins` (`choose({mission="mile14"}, "delta", 0, cat) == "mile14"`); `tagged used when nothing stored`; `garbage stored falls back` (`choose(42, nil, 0, cat) == "delta"`, `choose({mission=7}, nil, ...) == "delta"`); `unknown id falls back` (`{mission="kestrel"}` → `"delta"`); `closed window falls back to tagged then default`; `launchRecord shape` (`{ mission="mile14", party={1,2}, version=1 }`).
- [ ] **Step 2: Run** `lune run tests/run` — expected: FAIL, both specs "could not load".
- [ ] **Step 3: Implement** both modules per the Interfaces block.
- [ ] **Step 4: Run** `lune run tests/run` — expected: all pass (803 + the new ones).
- [ ] **Step 5: Commit** — `git add src/shared/MissionCatalog.luau src/shared/Rules/MissionPick.luau tests/MissionCatalog.spec.luau tests/MissionPick.spec.luau && git commit -m "Missions: the catalog and the pick rule (spec first) [no-docs]"`.

---

### Task 2: The match resolves its mission at boot

**Files:**
- Modify: `src/server/Missions/init.luau` (the `tagged` / `currentId` block, lines ~22-27)
- Modify: `src/shared/Config.luau` (`Operation.Missions` → removed; add `Missions = { LaunchMap = "Launches", LaunchSeconds = 600 }`)
- Modify: `src/shared/Attributes.luau` (comment on `Mission`: "Studio: set it on Workspace to test a mission; a live server reads the lobby's launch")
- Test: `tests/SourceWiring.spec.luau` (or the existing source-wiring spec's file) — add an assertion

**Interfaces:**
- Consumes: `MissionPick.choose`, `MissionCatalog` (Task 1).
- Produces: `Missions.current(): Mission` unchanged in signature; resolved once, the first time the module is required. `Config.Missions.LaunchMap` / `.LaunchSeconds` used by the lobby in Task 7.

- [ ] **Step 1: Write the failing assertion** in the source-wiring spec: `Config.Operation.Missions is read nowhere` (grep `src/` for `Operation.Missions`; expect none).
- [ ] **Step 2: Run** `lune run tests/run` — expected: FAIL (init.luau reads it).
- [ ] **Step 3: Implement.** In `Missions/init`: if `game.PrivateServerId ~= ""`, `pcall` `MemoryStoreService:GetHashMap(Config.Missions.LaunchMap):GetAsync(game.PrivateServerId)` (one retry after 1 s); `warn` once on failure. `currentId = MissionPick.choose(stored, workspace:GetAttribute(Attributes.Mission), os.time(), MissionCatalog)`. Print `[Missions] building <id> (from launch|tag|default)`. Remove `Config.Operation.Missions` and fix every reader the spec finds (keep `Handoff.DEFAULT_OPERATION` and the `operation` field: it is the run's tag in the result, not the map).
- [ ] **Step 4: Run** the full check suite — expected: all clean.
- [ ] **Step 5: Commit** — `git commit -am "Missions: the match builds the mission the lobby launched (MemoryStore, by private server) [no-docs]"`.

---

### Task 3: Missions as data; Delta unchanged

**Files:**
- Modify: `src/server/Missions/MissionTypes.luau` (Mission type: new fields)
- Modify: `src/server/Missions/Delta.luau` (fill the new fields)
- Modify: `src/server/ArenaService.luau` (`HALF` line 43 and its 6 uses, `XL_AT_BOOT` line 93, `init` lines ~1391-1407, `landingPoint` line 1283)
- Modify: `src/server/ExtractionService.luau:31`, `src/server/LoadoutService.luau:540`, `src/server/EnemyService.luau:2078` and its populate scatter, `src/server/ObjectiveService.luau` (every `Config.Objective.ZonePosition`), `src/server/IndexService.luau:2287` (+ route at 2173)
- Test: source-wiring spec

**Interfaces:**
- Consumes: `Missions.current()`.
- Produces (MissionTypes):
  - `Part = { name: string, kind: string, at: Vector3, size: Vector3, yaw: number? }` — `kind` is a `Config.Arena.Materials`-style key; a name containing "wedge" builds a WedgePart rising to +Z (the v2 generator's rule).
  - Mission gains: `Size: Vector2` (x, z extent), `Landing: Vector3`, `Extract: Vector3?` (nil = Landing), `AltPad: Vector3?`, `Boss: { Spawn: Vector3, Waypoints: { Vector3 } }`, `Hold: Vector3`, `Parts: { Part }`, `Features: { Roads: boolean?, Highway: boolean?, Landmarks: boolean?, Perches: boolean?, Gantry: boolean?, BigMap: boolean? }`.
  - `ArenaService.landingPoint()` / `ExtractionService`'s pickup keep their `DropPoint` / `PickupPoint` attribute override (Delta XL), then fall back to `mission.Landing` / `mission.Extract or mission.Landing` instead of Config.
  - At boot, ArenaService sets the workspace `DropPoint` / `PickupPoint` attributes from the mission when nothing has set them, so the client's `InsertionCutscene` (which reads `DropPoint`, then Config) lands right on every mission.
- Delta's values reference today's Config (no number copied): `Size = Vector2.new(600, 600)`, `Landing = Config.Extraction.ZonePosition`, `AltPad = Vector3.new(255, 0.3, 85)`, `Boss = { Spawn = Config.Index.Warden.SpawnPosition, Waypoints = Config.Index.Warden.Waypoints }`, `Hold = Config.Objective.ZonePosition`, `Parts = {}`, `Features = { Roads = true, Highway = true, Landmarks = true, Perches = true, Gantry = true, BigMap = true }`.

- [ ] **Step 1: Write the failing assertions** in the source-wiring spec: `Extraction.ZonePosition is read only by Missions/Delta and the client cutscene's fallback`; `Objective.ZonePosition and Index.Warden.SpawnPosition are read only by Missions/Delta`; `ArenaService has no HALF constant`.
- [ ] **Step 2: Run** `lune run tests/run` — expected: FAIL listing each reader.
- [ ] **Step 3: Implement.** `HALF` → `HALF_X = mission.Size.X / 2`, `HALF_Z = mission.Size.Y / 2` per axis; Floor sized from `Size`; perimeter walls per axis. Each Delta builder runs only when its `Features` flag is set; `XL_AT_BOOT = Config.DeltaXL.Enabled and mission.Features.BigMap == true`. `buildHelipad(arena, "Helipad", Landing...)`; `AltHelipad` only when `AltPad`; a one-way mission (Extract ~= Landing) also gets a `Helipad` at Extract named `ExtractHelipad`. Build `mission.Parts` (anchored, Box collision, `Config.Arena.Materials[kind]`). Every listed reader switches to the mission field. `EnemyService.populate`'s scatter uses `HALF_X/HALF_Z` minus `spawnInset()` instead of 300.
- [ ] **Step 4: Run** the full check suite — expected: all clean.
- [ ] **Step 5: Compare Delta live.** Owner's OK, `solo_playtest` Delta, run Task 0's `execute_luau` again — expected: identical JSON (diff the two files). Then `SetMainObjective` one pool objective and `WardenNow`: the Warden walks the same route (screenshot). With `Config.DeltaXL.Enabled = true` once: boots, logs no errors (`get_runtime_logs`). Stop.
- [ ] **Step 6: Commit** — `git commit -am "Missions: map size, pads, boss route, hold and Delta's builders come from the mission file (Delta unchanged) [no-docs]"`.

---

### Task 4: Objective modules lose their Delta words

**Files:**
- Modify: `src/shared/ObjectiveDefinitions.luau` (Row type + `sanitize`, `silence_alarm` rows)
- Modify: `src/server/Objectives/Sanitize.luau:65-68`, `src/server/Objectives/SilenceAlarm.luau:22-67`
- Test: `tests/ObjectiveDefinitions.spec.luau`

**Interfaces:**
- Produces Row fields: `Prompt: string?` (the hold prompt's action, Sanitize default "Burn the tent"), `Object: string?` (the prompt's object, default "Fuel can"), `Target: string?` (SilenceAlarm: the workspace part it silences, default "Siren"), `Sound: string?` (SilenceAlarm's loop key, default "amb_siren"), `Noise: { Reach: number, Every: number }?` (SilenceAlarm: until done, `EnemyService.noise(targetPosition, Reach)` every `Every` seconds; nil = none).
- `sanitize` and `silence_alarm` rows set nothing new (defaults are today's words), so Delta is unchanged.

- [ ] **Step 1: Write the failing spec:** `prompt words come from the row` — the spec reads `Sanitize.luau` / `SilenceAlarm.luau` source and asserts the literals "Burn the tent", "Fuel can", "Siren", "amb_siren" appear only as `or` defaults (pattern `row%.%a+ or "`).
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement** the fields and the noise pulse (a `task.spawn` loop that stops when the objective is done or the run resets; the module's existing cleanup path).
- [ ] **Step 4: Run** the full check suite — expected: all clean.
- [ ] **Step 5: Commit** — `git commit -am "Objectives: Sanitize and Silence the Alarm read their words, target and noise from the row [no-docs]"`.

---

### Task 5: Mile 14 v2 grey frame and its objective pool

**Files:**
- Bring in: `assets/3d/build/mile14_v2.py`, `docs/sprints/SPRINT_20_MILE14.md`, `assets/3d/build/driver.py` and the v2 previews from `origin/claude/mile14-v2` (`git checkout origin/claude/mile14-v2 -- <paths>`; not the `.blend` files)
- Rewrite: `src/server/Missions/Mile14.luau`
- Modify: `src/shared/ObjectiveDefinitions.luau` (rows `burn_buses`, `kill_horn`; `MAPS.mile14`)
- Test: `tests/Mile14.spec.luau` (new), `tests/ObjectiveDefinitions.spec.luau` (existing checks now cover mile14)

**Interfaces:**
- Consumes: MissionTypes fields (Task 3), Row fields (Task 4).
- Produces: `Mile14.luau` returns a Mission with `Id = "mile14"`, `Size = Vector2.new(640, 900)`, `Landing = Vector3.new(130, 12.6, 310)`, `Extract = Vector3.new(-262, 0.4, -195)`, `AltPad = nil`, `Boss = { Spawn = Vector3.new(0, 12, -445), Waypoints = { (0,12,-400), (0,12,-246), (0,12,-120) } }` (walks north up the lane), `Hold = Vector3.new(0, 12.5, 260)`, `Features = {}`, `Hills` = the generator's `HILLS` minus the backdrop `BeyondN`/`BeyondS` (outside the frame), `Parts` = the generator's `PARTS` (name, kind, centre, size, yaw), `Dressing` = the 24 convoy buses (`env_bus`, from `_jam_vehicles` bus entries only) and the tanker jackknife as a `Part` block, plus `env_lamp_post` at the Weigh Station (3) and the Rest Stop (2) for Lights On; `Fence` round x +-320 / z +-450 open across the deck (|x| < 56) at both ends; `Ramps` for the interchange and Rest Stop / Weigh Station ramps (from the generator's ramp entries in PARTS/`_overpass`/`_rest_stop`/`_weigh_station`).
- Rows (copy exactly):
  - `burn_buses`: Kind "signature", Map "mile14", Role "main", Module "Sanitize", Name "Burn the Buses", Brief "Three buses in the jam are sealed with the bitten inside. When they get out, the road is theirs. Burn all three.", Why "Sealed buses full of the bitten", Done "The buses are burning. Nothing is getting out of them.", Needs { "Points" }, StartRadius 60, Hold 3, Prompt "Burn the bus", Object "Fuel can", BurnWave { Runner = 4, Walker = 3 }, Boss { At = 0.6, Contest = 14, Arrive = "The fires woke something in the lead bus. It's coming up the lane.", Contested = "It's standing over the last fuel can. Pull it off, then burn the bus.", Blocked = "The Warden is at the fuel can: pull him off" }.
  - `kill_horn`: Kind "signature", Map "mile14", Role "side", Module "SilenceAlarm", Name "Kill the Horn", Brief "A bus horn near the toll plaza is stuck on, and it is waking the whole jam. Get to the cab and kill it.", Why "The horn is waking the Infected", Done "Horn's dead. The jam goes quiet.", Needs {}, StartRadius 0, Supply 150, Hold 4, Radius 140, SpawnFactor 0.4, Target "Horn", Prompt "Kill the horn", Object "Bus cab", Noise { Reach = 200, Every = 6 }. (Sound stays the siren loop until a horn sound exists: note it in the log.)
  - `MAPS.mile14`: Main `{ burn_buses 1.5, secure_site 1, restore_comms 1, confirm_casualties 1, recover_record 1 }`, Side `{ kill_horn 1.5, lights_on 1, misdrop 1, clear_spitters 1 }`, Sites exactly as the spec's section 5 (Burn the Buses Points (-11.5,12.6,-160), (20.5,12.6,-246), (-11.5,12.6,-366), Position (16,12,-246), BossFrom (-16,12,-400); Secure the Site's three sites with sizes and BossFrom (-70,26,80) / (-80,12,236) / (-70,0,-320); Restore Comms (225,8.6,-350); Confirm Casualties (150,0.5,-185) with its six Spawns; Recover the Record (154,12.6,341) To (0,26.5,80) ToName "the Overpass"; Kill the Horn Position (21.5,13,168) Name "the jam"; Lights On (142,3,-172.8) "the Weigh Station"; Misdrop (-200,0,250) "the Halt", (230,0,10) "the east field", (-250,26,80) "the county road"; Clear the Spitters (0,12,-425) "the south barricade", (-110,0,-50) "the Drop"). The Horn part: a block named "Horn" in `Mile14.luau`'s Parts at (16, 14, 186).
  - Nova's `Config.Awareness.Missions.mile14` / `.Night.mile14` keys stay as they are.

- [ ] **Step 1: Write the failing spec** `Mile14.spec`: `frame is 640 x 900`; `every Maps.mile14 site, To and BossFrom is inside x +-320, z +-450`; `Landing, Extract and every Boss point are inside the frame`; `Landing and Extract are at least 400 studs apart` (one-way); `24 buses`; `a part named Horn exists`; `no hill pokes outside the frame`. (The spec requires `src/server/Missions/Mile14.luau`; keep it free of Roblox requires other than `script.Parent.MissionTypes` — if the spec cannot load it that way, give `Mile14.luau` its data in a plain `Mile14Data.luau` next to it and have the spec load that.)
- [ ] **Step 2: Run** — expected: FAIL.
- [ ] **Step 3: Implement** the layout file and the pool data.
- [ ] **Step 4: Run** the full check suite — expected: all clean (the ObjectiveDefinitions spec now validates `mile14`'s sites and signature main).
- [ ] **Step 5: Commit** — `git add -A && git commit -m "Mile 14: the v2 frame in grey blocks, its objective pool (Burn the Buses, Kill the Horn), one-way extraction [no-docs]"`.

---

### Task 6: Play Mile 14 in Studio

**Files:** none (fixes found here go back into Tasks 3-5's files and commit as `[no-docs]` fixups).

- [ ] **Step 1:** Owner's OK. In Studio's match place, Workspace attribute `Mission = "mile14"` (Properties panel), Play solo.
- [ ] **Step 2:** `capture_screenshot` top-down; compare with `assets/3d/build/previews/mile14_v2_overview.png`. Expected: deck, span, toll, rest stop, weigh station, knoll where the picture has them.
- [ ] **Step 3:** Walk pad → Toll → span → Culvert → Rest Stop (teleport the character between points with `execute_luau`; check you stand on ground, not inside a block).
- [ ] **Step 4:** For each main objective `SetMainObjective <id>` then `WardenNow`; for each side `SetSideObjective <id>`. Expected: marker, prompt words (Burn the bus / Kill the horn), the Warden comes from the row's BossFrom or the south route; `get_runtime_logs` shows no errors.
- [ ] **Step 5:** Finish one run: extract at the Rest Stop pad (not the insert pad). Expected: helicopter lands at (-262, 0.4, -195); results screen.
- [ ] **Step 6:** Stop the playtest; set the attribute back; commit any fixups.

---

### Task 7: Lobby: the Mission Board and solo DEPLOY

**Files:**
- Modify: `src/lobby/server/LaunchService.luau` (extract the reserve + teleport loop of `lift` into `send`)
- Create: `src/lobby/server/MissionBoardService.luau`, `src/lobby/client/MissionBoardUI.luau`
- Modify: `src/lobby/server/Main.server.luau`, `src/lobby/client/Main.client.luau` (BOOT lists), `src/lobby/client/DeskDialogUI.luau` (plot choice 1, lines ~141-147), `src/lobby/shared/LobbyDesks.luau` (plot `open` = "Show me the missions.", its `openLine`)
- Modify: `src/shared/Remotes.luau` (`MissionBoard`), `src/shared/Messages.luau` (`MissionBoard = { Deploy, Refused, Lifting }`), `src/shared/Config.luau` (`Lobby.MissionBoard = { DeployCooldown = 5 }`)
- Test: source-wiring spec

**Interfaces:**
- Consumes: `MissionCatalog`, `MissionPick.launchRecord`, `Config.Missions.LaunchMap/LaunchSeconds`.
- Produces:
  - `LaunchService.send(party: { Player }, missionId: string, label: string): (boolean, string?)` — reserves once (`local code, privateId = TeleportService:ReserveServer(placeId)`), writes `MissionPick.launchRecord(missionId, userIds)` to `MemoryStoreService:GetHashMap(Config.Missions.LaunchMap):SetAsync(privateId, record, Config.Missions.LaunchSeconds)` (pcall; on failure still teleport: the match falls back to Delta and the log says so), then teleports with today's retries. Place id: `row.Place or Config.Places.Dev[game.PlaceId] or Config.Places.Match`. Studio: returns false, "Teleports don't run in Studio..." as today. `lift` calls `send(party, MissionCatalog.DEFAULT, "spot n")` (the rings keep launching Delta).
  - `MissionBoard` RemoteEvent. Client → server: `(Messages.MissionBoard.Deploy, missionId: string)`. Server → client: `(Messages.MissionBoard.Refused, text: string)`, `(Messages.MissionBoard.Lifting)`.
  - `MissionBoardService`: on Deploy, refuse unless `typeof(missionId) == "string"`, `MissionCatalog.get` finds it, `isOpen(row, os.time())`, the player is not already lifting, and `DeployCooldown` has passed; then fire Lifting and `LaunchService.send({ player }, id, "board")`; on failure fire Refused with the text.
  - `MissionBoardUI.open(): ()` / `.close()` — opened by the Plot's choice 1 next to the existing map view (`viewMap()`): one card per `MissionCatalog.Order` row (Name, District, Blurb), a selected state, a DEPLOY button ("DEPLOY · ALONE WITH BOTS" this sprint), and the refusal line. Layout through the ui-ux-designer brief (Prototype 2) before building; Backspace / walking off closes it as the dialog does today.

- [ ] **Step 1: Get the board's layout** from the ui-ux-designer agent (`.claude/agents/ui-ux-designer.md`): cards over the map view, DEPLOY, refusal line. Put its text-sketch in the PR body.
- [ ] **Step 2: Write the failing assertions** in the source-wiring spec: `MissionBoard remote is declared and used by MissionBoardService and MissionBoardUI`; `LaunchService writes the launch record before teleporting` (in `send`, `SetAsync` appears before `TeleportAsync`); `MissionBoardService checks MissionCatalog.isOpen`.
- [ ] **Step 3: Run** — expected: FAIL.
- [ ] **Step 4: Implement** per the Interfaces block.
- [ ] **Step 5: Run** the full check suite — expected: all clean.
- [ ] **Step 6: Studio check (lobby, port 34873):** talk to the watch officer, choice 1 opens the board over the map; pick Mile 14, DEPLOY → "Teleports don't run in Studio..." refusal shows; double-click DEPLOY → one refusal, no error; Backspace closes. Screenshot for the PR.
- [ ] **Step 7: Commit** — `git commit -am "Lobby: the Mission Board at the map table, solo DEPLOY into the picked mission [no-docs]"`.

---

### Task 8: Ship it: review, docs, PR

**Files:**
- Modify: `docs/PROGRESSION.md` (> Missions: the catalog, Mile 14's pool, one-way extraction), `docs/LEVELS.md` (Mile 14 v2 replaces C1's v1 layout; site table), `docs/ARCHITECTURE.md` (F6: missions resolve at boot from the launch record), `docs/STUDIO_MCP.md` (testing a mission in Studio: the Workspace `Mission` attribute), `docs/HISTORY.md` (one row), `docs/BACKLOG.md` (§1 Try it: the Mission Board and Mile 14; §7 item 6 → "The mission board and party invites (loop sprints 1-2)"; call 11 answered: v2), `handoff/README.md` (in place), `handoff/log/2026-11-20-claude-loop-s1-pick-mission.md` (with **Heads-up Nova**: `LaunchService.send`, `MissionBoardService`, `MissionBoardUI`, `DeskDialogUI` plot choice, `LobbyDesks` plot words, `Mile14.luau` rewritten to v2 with the awareness keys kept)
- Delete: nothing (`mile14.project.json` stays for testing until the board launches Mile 14 live)

- [ ] **Step 1:** Run the performance-reviewer agent (`.claude/agents/performance-reviewer.md`) on the branch diff; fix what it flags or note why not.
- [ ] **Step 2:** Write the docs above (facts that changed only).
- [ ] **Step 3:** Run the full check suite — expected: all clean.
- [ ] **Step 4:** Commit with the docs (no `[no-docs]`), `git push -u origin claude/loop-s1-pick-mission`, open the PR into `main` with: what it is, stacked on #92-#99 (merge order), the Studio screenshots, the try-it list (board, Mile 14 each objective, Delta unchanged), Nova's review request.
- [ ] **Step 5:** Rebuild the test mix: merge the branch into `claude/test-mix-6`, run the suite, push; restart both `rojo serve` (34873 lobby, 34874 match) from `C:\Users\Bread\ras-integration`.
