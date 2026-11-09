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

## Who builds what

| Piece | Owner | Status |
|---|---|---|
| Lobby place, menu, party, loadout screen, operation pick, teleport in | Nova | in progress |
| `Rules/Handoff` (the shape above, unit-tested) | Tien + Claude | done (not wired) |
| Read the handoff in `RunManager`, apply the loadout per player | Tien + Claude | next, after the lobby can send |
| Mission data split: each mission one data file, one builder | Tien + Claude | started (`docs/ARCHITECTURE.md` F6) |
| Mission-to-mission transition (helo ride, clear, build, respawn at the pad) | Tien + Claude | after the split |
| Teleport home with the result | Tien + Claude | with Stand Down |

## Open questions

- **Operation ids:** only one operation exists (Delta, Mile 14, Kestrel). The lobby can send
  `"harlan_corridor"` and show no picker until a second operation exists.
- **Matchmaking strangers** across lobby servers needs a MemoryStore queue
  (`docs/ARCHITECTURE.md` > Sessions); party-only first.
- **Teleports do not work in Studio.** Test the real round trip in a published private copy.
