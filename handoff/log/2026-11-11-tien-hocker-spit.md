# Hocker spit look (Tien's agent, 2026-11-11)

**Changed:** the Hocker's spit is no longer a yellow ball. Its head goes back over the
windup and snaps forward (bile dripping from the mouth); the spit is a stretched, wobbling
amber-brown glob with a dark red clot on a strand, dropping drips; it lands in a burst of
drops and a blotch, and the damaging pool has a dark rim, bubbles and fades out in its last
second; a splashed player's screen edges smear for 0.8 s. The Warden's lob uses the same
look. Files: `src/client/SpitFX.luau` (all of the drawing, pooled), `Rules/SpitShape` +
spec, remote `EnemySpit`, `EnemyProjectileService` (no parts while the look is on; timing,
arc, splash and puddle damage untouched), one line in `EnemyService` (the windup report).
**Verified:** stylua, selene, both builds, luau-lsp (match and lobby), 142 Lune tests. NOT
seen in game: Studio was in use by others, so nothing here has been looked at.
**Heads-up:** `Config.Enemies.SpitFX.Enabled = false` brings back the old server ball and
disc. The sac itself is still `strain` yellow-green (body models were being edited
elsewhere). The pool is SmoothPlastic, not Neon: check it reads at night.
**Next:** look at it (dev panel > 3 Hockers): the head tilt direction and size, drop size
(the engine smoke sprite, small), the pool against asphalt, the smear strength; then tune
`Config.Enemies.SpitFX`. A wet impact sound if one is made.
