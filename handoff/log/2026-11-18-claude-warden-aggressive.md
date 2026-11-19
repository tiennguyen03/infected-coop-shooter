# The Warden hunts (Claude, 2026-11-18)

**Changed:** the Warden closes distance and keeps pressure. He leaps at whoever is furthest
from the rest of the squad (a yellow ring goes down where they stood during a 0.8 s crouch;
he lands on it 0.8 s later: 35 and a short knockdown), walks 12 / 13 / 15 (was 8 / 8 / 11),
throws gas from the first phase, charges out to 60 studs and waits about half as long
between attacks. Below 30% he rages: faster leaps and the Volley (gas at everyone). His back
plate is a weak spot (rounds count whole, half goes through to the body, headshot marker;
Control names it 10 s in). 5,000 hp (was 7,000), lighter plates. The Bash's Mixamo clip spun
him 360°; it is now a keyed shield punch (`warden_shove`), the leap is keyed too
(`warden_leap`), both from the new `assets/animations/build/keyed.luau`, uploaded to the
group through Open Cloud with the new `upload_animations.js`. Files: `IndexService`,
`Rules/WardenBrain` (+ spec), `Rules/Plates`, `DamageService`, `ProjectileServer`, `Config.Index.Warden`,
`EnemyDefinitions.Warden`, `BossBarUI` tells, dev "To the rage" (`RageWarden`).
**Verified:** specs (WardenBrain, Plates), stylua, selene, both builds, luau-lsp. Not run in
Studio (no Studio MCP this session): the clips were keyed from numbers and never watched;
the leap's arc over cover and its landing on slopes are unseen.
**Heads-up:** `Plates.hit` returns a third value (body damage) and takes an optional
`bodyShare`. `Config.Animations.MoveClipSpeed.warden_walk` is 11 (was 6: his boots slid at
scale 1.9). New radio lines and tells are placeholders for the lore developer.
**Next:** play it (F1 > THE WARDEN > "In front of me", then "To the rage"); retune the keyed
poses if they read wrong; time the fight.
