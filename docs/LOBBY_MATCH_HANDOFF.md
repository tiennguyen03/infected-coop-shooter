# Lobby <-> match handoff (Tien + Nova, 2026-11-09)

How the lobby place and the match place fit together, and exactly what passes between them.
Nova owns the lobby side; Tien (+ Claude) the match side. If both sides follow this page, the
two halves snap together without either waiting on the other. The shape lives in code as
`src/shared/Rules/Handoff.luau` (spec: `tests/Handoff.spec.luau`); change both together.

## The flow

```
 LOBBY place (Nova)                    MATCH place (today's game, "Co-op Zombie Shooter")
 main menu                  teleport   Mission 1: Checkpoint Delta
 party up (1-4)            ─────────►    insert, explore, Primary, boss, call Lantern, board
 loadout (Arms Room rules)  party +             | helo ride = the loading screen
 pick the operation         loadouts +  Mission 2: Mile 14      (same server)
 READY                      operation           |
     ▲                                  Mission 3: Kestrel      (same server)
     |          teleport home                   |
     └────────── with the result ───── Stand Down: score screen
```

- **One operation = three missions in a row on the same match server.** The match clears the
  map and builds the next mission itself (missions are built from code). Players teleport
  only twice per operation: lobby to match, match to lobby.
- **Why not one teleport per mission:** teleports are slow, can fail, do not work in Studio,
  and can split a squad. Building the next map in place is cheap because every map is code.
- Both places are in the same experience (owned by Boomin Dev Studios), so they share
  DataStores and the group's sounds and animations.

## Lobby -> match (Nova sends)

The lobby reserves a private server of the match place and teleports the whole party with one
call, carrying this table as teleport data:

```lua
-- TeleportOptions: ReservedServerAccessCode = TeleportService:ReserveServer(MATCH_PLACE_ID)
-- options:SetTeleportData(data); TeleportService:TeleportAsync(MATCH_PLACE_ID, players, options)
local data = {
	version = 1, -- Handoff.VERSION; the match ignores any other version
	operation = "harlan_corridor", -- which operation the squad picked (one exists today)
	party = {
		-- keyed by tostring(player.UserId)
		["12345"] = {
			slot = 1, -- squad slot 1-4 (Pike One to Four)
			loadout = {
				primary = "service_rifle", -- WeaponDefinitions ids
				secondary = "pistol",
				grenade = "frag",
				callIns = { "hammer", "anvil", "shrike", "doorman" }, -- [slot] = CallInDefinitions id
			},
		},
		-- one entry per party member
	},
}
```

- The loadout uses the same shape and the same rules as the in-match Arms Room
  (`Rules/Loadout`, `ArmsRoom.catalog()`). Build the lobby's loadout screen on those so a pick
  that is legal in the lobby is legal in the match.
- New guns: the sample guns (`revolver`, `sniper`, `goose`; PR #4) are rows in
  `WeaponDefinitions`; add them to `PRIMARIES` / `SECONDARIES` (or the lobby's own list) and
  they become pickable.
- Retry a failed teleport (`TeleportInitFailed`); a match starts with whoever arrived.

## Match reads it (Tien)

`Handoff.readJoin(player:GetJoinData().TeleportData, player.UserId, check)` per joining player,
in one place (`RunManager`):

- **No data** (Studio, a direct join) or **another `version`**: today's defaults, so Studio
  testing never needs the lobby.
- **A loadout the catalog does not offer** (old lobby, forged data): that player gets the
  default loadout; everything else still works.
- **A player missing from `party`, or a late joiner:** plays on the defaults. Missing players
  are normal: the match never waits forever (staging timeout).
- `partySize` is how many the lobby sent, so the match knows whom to wait for in staging.
- **Never trust teleport data for progress.** It is client-visible. Unlocks and the Containment
  Board are saved by the match server itself (DataStore, keyed by UserId).

## Match -> lobby (Tien sends home)

At Stand Down or a wipe, the match teleports the party back to the lobby with
`Handoff.result(operation, missions, standDown)`:

```lua
{
	version = 1,
	operation = "harlan_corridor",
	missions = {
		{ id = "delta", outcome = "win", secondaries = 2 }, -- outcome: "win" | "partial" | "loss"
		{ id = "mile14", outcome = "partial", secondaries = 1 },
	},
	standDown = true, -- boarded at the last mission (false = the squad wiped)
}
```

The lobby only **shows** it (an operation summary). The match has already saved whatever the
run earned; the lobby reads progress from the DataStore, never from this table.

### Merits (built 2026-11-10)

When a mission ends (`RunManager.endRun`), `MeritService` pays every real player in the
server, dead or alive (bots earn nothing): Win 120, Partial 60, Loss 0, each Secondary +30
(`Config.Merits`, `Rules/Economy.missionMerits`, outcome from `Handoff.outcome`). No mission
tracks Secondaries yet, so they pay 0.

- **Where:** the lobby's own record, DataStore `PikeRecords`, key `Rules/Record.key(userId)`
  (`r_<UserId>`), the versioned `Rules/Record` shape. The match uses `UpdateAsync` (read,
  credit, write in one step) and leaves a save it cannot read alone (`Record.canUpdate`). A
  player is in the lobby or in a match, never both, so the two never write one record at once.
- **Shown:** one line on the results screen, "+120 MERITS" (player attribute `MeritsEarned`;
  "MERITS NOT SAVED" when the save failed). The result table above is unchanged.
- **Trip home:** `goHome` waits for the saves first (`MeritService.settle`, at most
  `Config.Merits.SettleSeconds`), so the lobby reads the paid record on landing.
- **Studio:** DataStores fail without API access; it is logged once and the run end carries on.
- **A direct join** (no lobby) is paid too; a soldier with no record yet gets the starting
  merits plus the pay.

## The match side, built (2026-11-09, plan by the architect agent)

- **Shared rule** `Rules/Handoff`: `departure(operation, aboardUserIds, loadouts?)` builds the
  lobby's teleport data (slots in boarding order, at most 4, a loadout only when given);
  `readJoin` reads it in the match; `outcome(runResult, primaryDone)` (extracted = win, a wipe
  after the Primary = partial, else loss); `result(...)` builds the trip home and
  `readResult(data)` checks it in the lobby (nil for anything else). Spec:
  `tests/Handoff.spec.luau`. Neither side builds the table by hand.
- **`Config.Places`** (both places read their ids here, 2026-11-09): `Lobby` 87556879379942
  (the start place, "Co-op Zombie Shooter": the game opens in the lobby), `Match`
  125769854992316 ("Checkpoint Delta"), and `Dev`, test pairs lobby -> match (Nova's ZCS Dev
  83558708746036 -> Match Dev 108949482095254): a launch from a Dev lobby goes to its match, and
  that match flies home to its own lobby (`HandoffService.lobbyPlaceId`). **`Config.Handoff`**: `ReturnAfterSeconds` 60, `Retries` 2, `RetryDelay` 2.
  `Config.Run.StagingSeconds` 30.
- **`HandoffService`** (match server): reads each player's join data once (`joinFor`), knows
  whether the squad came from the lobby and which operation, and `sendHome(result)` (one
  TeleportOptions for the squad, retried; `TeleportInitFailed` retries that player on the same
  options). Studio: join data comes from the ServerStorage attribute `MockTeleportData` (a JSON
  teleport-data table), so the lobby's side can be stood in for without teleports.
- **`RunManager`**:
  - each arriving player gets the lobby's loadout through `LoadoutService.apply` (the Arms
    Room's own rules; a refused or forged one leaves the default);
  - **staging**: the `Lobby` state now waits until everyone the lobby sent has a body, or
    `StagingSeconds` after the first arrival. Bots are sized at Insert, so they fill exactly the
    missing seats (no bot churn). A direct join (`expected` 1) starts at once, as before.
  - **at run end**, if the squad can go home (`canReturn`: lobby published, a live server, the
    squad came from the lobby), READY reads **BACK TO THE CARRIER** and the squad flies home on
    the first full READY, the countdown, or `ReturnAfterSeconds` after the results screen
    opens, with `Handoff.result`. If every retry fails, a radio line says so and READY restarts
    in the match. Nobody is stranded.
- **Screens**: `StagingUI` ("WAITING FOR SQUAD 1 / 3 · 0:20"); `RunEndUI` (BACK TO THE CARRIER,
  LIFTING…). **Dev panel**: RUN > "Go to the lobby (live)" (`ToLobby`) flies a tester who
  joined the match place directly to its lobby.
- **Verified in Studio** (separate window): no data starts at once with 3 bots (unchanged); a
  mock squad of 3 shows the staging line, keeps the lobby's SMG and call-ins, starts at the
  30 s timeout with 3 bots; a forged gun falls back to the rifle; an extracted run in Studio
  keeps READY = restart, and READY restarts. Not verifiable in Studio: real teleports (both
  ways); that needs the published test below.

## The lobby side, joined up (2026-11-09, branch `claude/lobby-reconcile` off `nova/lobby`)

- `nova/lobby` merged with main; one handoff shape: the Loadmaster's `LaunchService.lift()`
  sends `Handoff.departure(DEFAULT_OPERATION, aboard, LoadmasterService.loadoutsFor(party))`
  plus `spot`. Nova's own reader (`JoinData`, `Rules/LaunchData` + spec) is retired: the match
  reads the signed Loadout once in `HandoffService` and `RunManager.receive` applies it
  (`LoadoutService.apply`, the Arms Room's checks).
- **One server per lift**: `ReserveServer` once, `ReservedServerAccessCode` reused on every
  retry (no split squad). `Config.Lobby.MatchPlaceId` / `DevMatchPlaceIds` became
  `Config.Places`.

## What's next

**Tien (Roblox):** publish both places from this code (a teleport always lands on the
published version): the lobby from `lobby.project.json` into the start place
(87556879379942), the match from `default.project.json` into Checkpoint Delta
(125769854992316).

**Nova (lobby side):** a `DebriefUI` (lobby client):
`Handoff.readResult(TeleportService:GetLocalPlayerTeleportData())` and, when it returns a
result, a one-time panel: the operation, STAND DOWN or SQUAD LOST, one row per mission (Delta:
WIN / PARTIAL / LOSS). Display only. Then, once the lobby issues every loadout, the match's B
Arms Room can be turned off for lobby runs.

**The live test (published places, Tien + a friend):** join (the game opens on the Carrier),
board one spot together, land in one server (the staging line counts you in, no bots pop in
and out), extract, see BACK TO THE CARRIER, fly home. Repeat with a wipe, and with one player
stepping off during the countdown (the match waits out the timeout and a bot takes the seat).

## Decisions (architect's recommendations, taken as defaults)

- **The lobby is the start place** (owner, 2026-11-09): the start place can't be changed, so
  the lobby was published into it and the match into Checkpoint Delta.
- **The in-match Arms Room (B) stays** until the lobby rack issues loadouts.
- **Home both ways**: the READY button and an automatic lift after 60 s, so nobody idles in a
  dead server. A wipe goes home too (`standDown = false`), Helldivers-style.
- **Home now, before the save service (F9)**: nothing is saved either way, so returning loses
  nothing and closes the loop.

## Open questions

- **Operation ids:** only one operation exists (Delta, Mile 14, Kestrel). The lobby can send
  `"harlan_corridor"` and show no picker until a second operation exists.
- **Matchmaking strangers** across lobby servers needs a MemoryStore queue
  (`docs/ARCHITECTURE.md` > Sessions); party-only first.
- **Teleports do not work in Studio.** Test the real round trip in a published private copy.
