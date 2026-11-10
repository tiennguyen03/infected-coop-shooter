# Lobby and match joined up (Claude for Tien, 2026-11-09)

**Changed:** Nova's `nova/lobby` merged with main on `claude/lobby-reconcile`. The lobby now
sends the shared `Rules/Handoff` (with each soldier's signed Loadout) and reserves one match
server per lift; the match reads it once in `HandoffService`. `JoinData` and `Rules/LaunchData`
are gone. Every place id sits in `Config.Places`: Lobby 87556879379942 (the start place),
Match 125769854992316 (Checkpoint Delta), and Nova's ZCS Dev -> Match Dev pair, which now
also flies home. Docs: Nova's lobby notes kept, folded into main's shorter docs.
**Verified:** both places build; 117 tests (the round trip `departure` -> `readJoin` with a
loadout is covered), lint and types clean for match and lobby. Not verified: a real teleport
(needs both places published).
**Heads-up (Nova):** review the PR; the stale `125769854992316 -> 70420018035843` dev pair is
removed (that place is now the real match). `.blend` taken from main: the next asset build
puts the Fallow and Lantern back into it (their FBXs and uploaded ids are untouched).
**Next:** Tien publishes both places and runs the live test; Nova's debrief panel.
