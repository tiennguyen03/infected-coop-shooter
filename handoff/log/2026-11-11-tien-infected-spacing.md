# Infected spacing (Tien's agent, 2026-11-11)

**Changed:** the Infected spread round a player instead of piling onto one point and walking
through each other. Each melee body on the straight chase now aims at its own side of an
attack ring, is pushed off overlapping neighbours, and will not walk into a body in its way
near the target (it waits or slides round); radius, approach curve and weave differ per body.
Bodies still pass through each other physically (Enemy collision group unchanged). Files:
`Rules/Spacing` (+ spec, with a 24-body simulated crowd), `EnemySpacing` (grid of cells), three
small edits in `EnemyService` (require, `add` at spawn, the goal before the nudge check),
`Config.Enemies.Spacing`, `EnemyDefinitions.SpacingRadius` (optional per form).
**Verified:** stylua, selene, both rojo builds, luau-lsp (both places), 157 Lune tests. **Not
played in game** (Studio was in use).
**Heads-up:** fewer bodies can hit one player at once now (about 6-8 Walkers fit the ring;
before, the whole stack hit), so the horde does less damage: a balance change to judge by
playing. `EnemyService` is also being edited on `claude/infected-v2-ingame`; the edits here
are three short hunks. Hockers, bosses, lures, paths and climbs are not steered.
**Next:** play it. Look for: a ring round you rather than a stack; jitter or bodies turning
their backs in a packed crowd (lower `Steer.Strength`, raise `Steer.Deadzone`); a crowd
standing too far off or too thin (lower `Radius`, raise `Steer.BlockSlack`); queues that
stall at a door or the foot of stairs (raise `Steer.TravelMinPull`, lower
`Steer.EngageDistance`); bodies behind low cover that no longer climb (lower
`Steer.WaitStep`); robotic straight lines or too much weave (`Steer.SwayAngle`,
`Steer.RingSpread`). If it is worse than before: `Enabled = false`.
