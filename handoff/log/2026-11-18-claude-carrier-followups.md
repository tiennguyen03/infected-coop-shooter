# Carrier follow-ups: counts and seller idles (Claude, 2026-11-18)

**Changed:** the call-in tallies over the show floor and the MISSIONS HOME board are painted
numbers, counted for real: the match's new `TallyService` counts player call-ins (hook in
`CallInService`) and an extraction, and adds them to one DataStore key at run end (one pcall'd line
in `RunManager.endRun`); the lobby's new `TallyBoards` paints Config start + stored count on the
cards `CarrierV2` registers (generated rows carry a `count` tag). The DAYS SINCE tiles count up
(`Config.Lobby.DaysSince`). Each seller plays a hand-keyed loop (`seller_idles.luau`, 5 clips
uploaded) from `NpcPose`. The scoreboard mesh lost its chalk marks (re-uploaded). `Rules/Tally`
+ spec. `upload_animations.js` is PR #83's file, copied as is.
**Verified:** stylua, selene, both Rojo builds, both luau-lsp passes, Lune tests. Not seen in
Studio (Studio tools not used): the idles, the text, the board.
**Heads-up:** Nova: your `NpcPose` (idle swap), `CarrierV2`, lobby `Main` changed; new
`TallyBoards`. Match: `RunManager`, `CallInService`, `Main` got one line each. Every new
call-in row needs a `Tally` (defaults to 0 if missing). The days digits used to be placed right
to left (would have read 412); now left to right.
**Next:** a Studio look at the five idles and both boards; publish both places to see real counts.
