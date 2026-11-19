# The Warden as a real boss (Claude, 2026-11-18)

**Changed:** the Warden now arrives (Control's warning, a ring, a dive from over the top, a
global shake, a roar, the boss bar slams in, his own fight loop), is bigger (2.2), never
flinches, turns at a capped rate, walks a keyed heavy stride matched to his speed with a boot
and a camera shake per heel strike, and shakes the screen on impacts. Stages at 66% / 33%
roar, shove the close ones and call Brutes; stage 2 opens the Quake (shockwave rings) and
charges through small cover, the rage the Rampage (three charges). Campers are leaped first.
Files: `IndexService`, `Rules/WardenBrain` (+spec), `EnemyService` (boss handle, no flinch),
new client `BossPresence`, `BossBarUI`, `CameraController.shake`, `Config.Index.Warden`
(Entrance, Weight, Music, StageRoar, Quake, Rampage, Smash, Camp), keyed `warden_stride`,
`assets/audio/build/warden_drone.js` + `upload_audio.js`.
**Verified:** stylua, selene, both builds, 613 tests, match and lobby types. Not seen in
Studio (no MCP this sprint): every visual, the stride, the numbers.
**Heads-up:** `HealthPerExtraPlayer` 0.33 -> 0.5; `Phases[].WalkersPerExtraPlayer` is now
`PerExtraPlayer` (a table). The music asset may sit in moderation (silent until approved).
**Next:** play it with F1 > THE WARDEN; tune shake strength and the stride's
`MoveClipSpeed.warden_stride`; a lore pass on the new lines.
