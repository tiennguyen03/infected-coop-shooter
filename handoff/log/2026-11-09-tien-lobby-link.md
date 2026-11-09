# Lobby -> Delta -> lobby, match side (Claude for Tien, 2026-11-09)

**Changed:** a squad the lobby sends now lands together: the match waits for everyone the lobby
sent (or 30 s; "WAITING FOR SQUAD n / N"), gives each player the loadout the lobby sent, and at
run end READY becomes BACK TO THE CARRIER and flies the squad home with the result
(`HandoffService`, `RunManager`, `Rules/Handoff`, `Config.Places`). A direct join and Studio
play exactly as before.
**Verified:** Studio with mock lobby data (ServerStorage `MockTeleportData`): staging line,
lobby SMG and call-ins kept, timeout start with 3 bots, forged gun falls back, READY restarts
in Studio; 71 tests, lint, types clean. Not verified: real teleports (need published places).
**Heads-up (Nova):** `docs/LOBBY_MATCH_HANDOFF.md` > "What each of us does next" lists the
lobby-side changes in `LaunchService` (send `Handoff.departure`, reserve once per lift) and a
`DebriefUI`; merge main first.
**Next:** Tien sends the lobby place id (`Config.Places.Lobby`); Nova's side; the live test.
