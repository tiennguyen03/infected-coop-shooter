# Lobby soldier matches the match (Tien's agent, 2026-11-11)

**Changed:** on the ship your soldier stands and walks with the match's rifle idle and
four-way walk instead of Roblox's default, and carries the primary from the signed Loadout
(the default rifle until one is signed); other players see both. New: client
`src/lobby/client/SoldierMoves`, `src/shared/SoldierLocomotion`, `Rules/MoveBlend` (+ spec),
`Config.Lobby.Soldier`. The match's `AnimationController` now takes its walk/run blend from
`SoldierLocomotion` (same maths, moved, not rewritten).
**Verified:** stylua, selene, both rojo builds, luau-lsp for both places, 142 Lune tests.
**Not seen in game** (Studio was in use): nothing here has been played, in the lobby or the
match.
**Heads-up (Nova):** three small edits in your files: `PikeBody` calls
`PlayerSetup.attachRifle` after the limb swap; `LoadmasterService` sets the player's `Weapon`
attribute when a Loadout is signed or loaded; lobby `Main.client` starts `SoldierMoves`. The
Backpack hotbar is hidden in the lobby (the rifle is a Tool). If any of it is in your way:
`Config.Lobby.Soldier.Enabled = false` (or `CarryRifle = false` for empty hands).
**Next:** play it in the lobby place (checklist in `docs/sprints/LOBBY_V1_FALLOW.md` > What
v1 has) and walk once in the match to confirm the blend still looks the same; then a relaxed
carry clip if the rifle idle reads too ready, a jump clip, the match's footsteps.
