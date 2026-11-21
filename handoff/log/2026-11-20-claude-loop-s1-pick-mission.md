# Loop sprint 1: pick a mission (Tien + Claude, 2026-11-20)

**Changed:** the watch officer's "Show me the missions." opens the Mission Board over the paper
map: pick Checkpoint Delta or Mile 14, DEPLOY flies you alone with bots (`MissionBoardUI`,
`MissionBoardService`; the deck's rings still fly to Delta). One match place builds any
mission: `MissionCatalog` rows; the lobby stores `{ mission, party }` in MemoryStore under the
reserved server's PrivateServerId (`LaunchService.send`), the match reads it at boot
(`Missions/init`, `Rules/MissionPick`). Mission files now carry `Size`, `Landing`, `Extract`,
`AltPad`, `Boss`, `Hold`, `Parts`, `Features` (Delta's values point at the same Config values).
Mile 14 is the v2 layout in grey blocks (`Missions/Mile14Data`), one way Toll Plaza to Rest
Stop, Burn the Buses + Kill the Horn (Sanitize / SilenceAlarm with row words, `Target`,
`Noise`) and the shared objectives, the Warden as a stand-in. `Config.Operation` is gone.
**Verified:** specs first (`MissionCatalog`, `MissionPick`, `Mile14`, `MissionWiring`, the row
words check), 839/839, stylua, selene, both builds and type checks; performance review: nothing
blocking. Studio checks: see the PR (Delta fingerprint, Mile 14 walk, the board).
**Heads-up:** **Nova:** your area changed: `LaunchService` (the teleport moved into
`LaunchService.send(party, missionId, spot?)`, `lift` calls it), new `MissionBoardService` and
`MissionBoardUI`, `DeskDialogUI` (the plot's choice 1 opens the board and hides the talk; its
Heartbeat and `close` know the board), `LobbyDesks` plot words, lobby `Main` boot lists;
`Missions/Mile14.luau` rewritten to v2 (your awareness keys `mile14` kept; your v1 woods return
in sprint 5's cover pass). New: `Attributes.MissionLanding`, `Config.Arena.PartKinds`,
`Config.Missions`, `Config.Lobby.MissionBoard`, the `MissionBoard` remote.
**Next:** sprint 2, party invites from a menu (the rings retire); 2b, the Driver's design refresh.
