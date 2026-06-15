# Integration Test Notes

## Date
2026-06-12

## Build Tested
Sprint 11 — DevTestService + DevTestPanel. Static checks all clean. **Live tests RUN and
PASSED** in a Studio playtest (2026-06-12) via the Studio MCP runtime. One real bug found
and fixed (projectile reset race — see below).

## Live results (verified in-engine)
- **Test A Startup:** PASS — dev service loaded, player + rifle spawned, 0 startup errors.
- **Test B Enemies:** PASS — Walker/Runner/Brute all spawn; enemy takes lethal damage,
  dies, and drops an XP orb (xpOrbDropped=true). ClearEnemies empties the world.
- **Test C Items:** PASS — GrantItem sets ItemsCollected=2; ClearItems → 0 and
  MoveSpeedMult back to 1 (stats restored). DEV TOOLS panel renders (creator-only).
- **Test D Damage routing / Hunter's Mark:** PASS — unmarked hit = 10 dmg; with Hunter's
  Mark x3 the same hit = 16 dmg (= +60%), proving the central dealDamage mark multiplier
  works across sources. Drones (capped 3) and fire pools (capped 6) confirmed at cap.
- **Test F Restart cleanup:** PASS — with 3 drones, 3 fire pools, 1 mark, 11 enemies live,
  KillPlayer → RestartRun → VerifyCleanup returned PASS, zero leftovers.

## Bug found + fixed during testing
A first messy-state run left **1 stray projectile** after restart — a drone fired a round
in the same frame as `ProjectileServer.reset()`, so the part existed in the Projectiles
folder but wasn't yet in the tracked table. Fix: every object-pool reset
(Projectile/Drone/Incendiary/Mine/AmmoCache/XPOrb) now also calls
`folder:ClearAllChildren()` to sweep any untracked stray. Re-test passed deterministically.

## Preflight (done)
- git: project is all-untracked (no commits yet); no staged/tracked changes to review.
- Secret scan: no API keys in any repo file. The Open Cloud key lives only in
  `~/.claude.json` (outside the repo). Asset IDs in `assets/icons/ASSET_IDS.md` are fine.
- `.gitignore` excludes place builds + generated tooling files.

## How to run the live tests
1. Open the place in Studio, `rojo serve`, connect the Rojo plugin.
2. Press Play. A "DEV TOOLS" panel appears top-left (creator/Studio only).
3. Use F1–F9, or drive commands via Studio MCP eval, e.g.
   `require(game.ServerScriptService.Server.DevTestService).spawnEnemy("Brute", 1)`.

## Dev Commands (implemented — verify in playtest)
All gated to `RunService:IsStudio()` or `UserId == 67169996`; never run for public players.
- GiveXP(amount) — PENDING
- ForceLevelUp() — PENDING
- GrantItem(itemId, stacks) — accepts snake_case or alias ("RicochetRounds") — PENDING
- ClearItems() — clears inventory + drone/fire/mine/shock objects + stat multipliers +
  restores MaxHealth — PENDING
- SpawnEnemy(type, count) — Walker/Runner/Brute via EnemyService.spawnWave — PENDING
- ClearEnemies() — EnemyService.clearAll (no re-wave) — PENDING
- KillPlayer() — PENDING
- RestartRun() — RunManager.resetRun (now public) — PENDING
- PrintRunState() — prints all spec'd fields (level/xp/kills/per-type enemy counts/object
  folder counts/marks/objective) — PENDING
- VerifyCleanup() — PASS/FAIL with leftover list; call within ~1.5s of RestartRun before
  the new run's first wave — PENDING

## Item Tests (all 13 — verify each: grant, bar shows, stacks, effect, restart clears)
PENDING for all: Hollow Point, Adrenaline, Drone, Ammo Cache, Air Support, Kevlar,
Vampire, Ricochet, Shrapnel, Incendiary, Mine, Shock Coil, Hunter's Mark.

## Damage Routing (verify each path deals damage + credits kill + drops XP)
All sources now route through `ItemEffectService.dealDamage`: bullets, drones, bleed,
ricochet, shrapnel, airstrikes, fire pools, mines, shock. Hunter's Mark multiplier applied
centrally in dealDamage. PENDING live confirmation.

## Recursion Safety (design-level — confirm in stress test)
- Ricochet = instant chain, never calls onProjectileHit, so cannot re-proc or loop.
- Fire-pool kills tagged kind="fire"; onEnemyKilled skips Incendiary spawn for them.
- Shrapnel only fires from onFireRequest (player gun); shrapnel rounds don't recurse.
- Airstrike has no self-trigger; only the kill counter advances it.
- Drones are capped at 3/player; fire pools 6; mines 5.

## Restart Cleanup
PENDING — run Test F (messy state → KillPlayer → RestartRun → VerifyCleanup, expect PASS).

## Bugs Found
- Projectile reset race: a drone round fired on the same frame as restart survived
  cleanup (1 stray projectile). FIXED.

## Bugs Fixed
- Object-pool resets now sweep their workspace folder (`ClearAllChildren`) in addition to
  destroying tracked parts — guarantees no stray projectile/drone/pool/mine/cache/orb
  survives a restart regardless of timing.
- Exposed `RunManager.resetRun` (was local) so the dev tool can force restarts.
- Added `EnemyService.clearAll` / `.count` and `ItemEffectService.getActiveMarkCount` for
  dev inspection without touching gameplay logic.

## Balance Concerns
None new this sprint (no content changes). Sprint 8/9/10 balance still needs the real
playtest pass.

## Recommended Next Sprint
Sprint 12: Operation Completion V1 (objective success → extraction zone → hold timer →
mission-success screen → next-run flow). Only after Sprint 11's cleanup tests pass.
