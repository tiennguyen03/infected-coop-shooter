# Satisfying pass, group migration, merge to main (Tien + Claude, 2026-11-09)

**Changed:** shooting and kills feel heavy: per-gun camera kick, blast shake, limp bodies
thrown by the killing hit (max 8, 4 s), hit flinch (Mixamo), legless crawl, low-health grey/
vignette/heartbeat/muffle (`LowHealthFX`), reload clip. Every sound and animation was
re-uploaded under the Roblox group; the game now lives in the group experience "Co-op Zombie
Shooter" (place 87556879379942). `hud-p2` merged into `main`.

**Verified:** live playtest with the owner shooting (limp bodies, flinch, reload, no errors);
performance review: ship after fixes (applied: corpses let rounds through, slows keep a
crawl, only stopped parts settle). Not measured: 2-client network, low-end device.

**Heads-up (Nova):** per-item feel lives on each item's own Config row: `Kick`, `Heavy`,
`ReloadClip` on `Config.Weapons.*`, `ShakePower`/`ShakeGlobal` on `Config.CallIns.*` and
`Config.Grenade.*`. A new gun or call-in works without touching the feel code; set those
fields if it should feel different. Upload new assets with `groupId` 270506601.

**Next:** owner tunes the feel by playing; checklist pass of every call-in and gun.
