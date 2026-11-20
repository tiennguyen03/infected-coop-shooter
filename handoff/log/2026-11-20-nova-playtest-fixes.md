# Playtest fixes: saved Loadout on a direct join, Infected pass through soldiers (Nova + Claude, 2026-11-20)

**Changed:** a match started straight from Studio (no lobby teleport) now starts with the
Loadout last signed at the Loadmaster instead of the default service rifle and pistol
(`HandoffService.savedLoadout` reads `LoadmasterLoadouts` / `u_<UserId>`; `RunManager.receive`
applies it). The Infected no longer collide with soldiers: Runners can't shove you and a pile
can't lift you into the air. Players and bots sit in a new `Soldier` collision group
(`src/server/SoldierCollision.luau`, `Config.Player.Collision`); StanceService returns a
standing body to it; the Hocker's spit casts in `EnemyShot` so it still hits soldiers. Aimed in
first person, the red dot and CompM2 now show their red dot (`src/client/DotSightView.luau`,
from each optic's `Config.Optics.<id>.Reticle`; CameraController drives it). The RMR rides a
taller riser (dot 0.1 above the irons, `optics.py` `REDDOT_LIFT`) so the front post sits under
the dot; `wpn_m16_reddot` re-uploaded as 80921148772778.
**Verified:** stylua, selene, both Rojo builds, both luau-lsp runs, 687/687 Lune tests. Not yet
seen in Studio: Nova to playtest (the saved Loadout needs Studio API access on).
**Heads-up:** built on Nova's local merge of #92-#95 (not on `origin/main`). Anything that sets a
character part's `CollisionGroup` must use `Config.Player.Collision.Group`, not "Default".
`BlockInfected = true` puts the old solid bodies back.
**Next:** Nova's playtest; if hordes now feel too easy to walk through, a soft push-out instead.
