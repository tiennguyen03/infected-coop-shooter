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

## Sprint 12 (Operation Completion V1) — added 2026-06-12
Objective completion now starts an extraction phase (ExtractionService): glowing zone,
hold 30s, OPERATION COMPLETE screen, clean restart. Full detail + live test fast-path in
[SPRINT_12_OPERATION_COMPLETION_V1.md](SPRINT_12_OPERATION_COMPLETION_V1.md). Static
checks PASS. **Live verification PASS 2026-06-12** (after manual Stop → Play): extraction
starts on objective completion, zone appears, mission success fires, restart cleans up
(0 enemies/zone/run-flags immediately after restart), no errors. Reported bug root cause
was a stale playtest running pre-Sprint-12 code; source wiring was already correct.

## Sprint 14 (Item Rarity Framework) — added 2026-06-12
Rarities (Common/Uncommon/Legendary) on all 13 items, weighted-rarity offer rolls (70/25/5)
with distinct cards + fallback, every-4th-level-up Uncommon+ guarantee, rarity colors/labels
on level-up cards. Plan: [ITEM_RARITY_PLAN.md](ITEM_RARITY_PLAN.md). Static checks PASS.
Rarity card UI confirmed in-engine (grey COMMON / green UNCOMMON labels + borders render).
**Bug found + fixed:** dying while a level-up item offer was open left the equipment screen
up and the game paused, blocking restart ("infinite deploying"). Fix: server cancels
pending offers + unpauses on death (`ItemService.cancelOffers`); client closes the offer
card on death. PENDING (quick): SimulateItemOffers distribution check + VerifyCleanup after
a rarity-era restart.

## Sprint 15 (Common Item Pack 1 + icons) — added 2026-06-12
10 new Common passive items (pool 16/6/1 = 23) via `PassiveItemService` (recompute on
inventory change; stat items via PlayerStatsService, rest via player attributes read by
XP/orb/enemy/drone/mark systems). 10 flat SVG icons in assets/icons/ (not uploaded;
IconId nil). Rarity odds + guarantee unchanged. Static checks PASS; code synced. Live
verification PENDING (playtest wedged on old code — needs manual Stop → Play, then check
pool counts 16/6/1, per-item attributes, VerifyCleanup). Detail:
[SPRINT_15_COMMON_ITEM_PACK_1.md](SPRINT_15_COMMON_ITEM_PACK_1.md).

## Sprint 16 (Plague Rat Charm) — added 2026-06-12
New Uncommon `plague_rat_charm` (pool 16/7/1 = 24). `PlagueRatService`: on-kill proc (12%/
stack, cap 60%) spawns part-built rats that crawl → latch → deal 3 DPS via central
`dealDamage` (kind "rat", guarded so rat kills don't chain). Cap 15/player, 8s lifetime,
1 retarget. Icon `assets/icons/plague_rat_charm.svg` (not uploaded; IconId nil).
VerifyCleanup now also checks the PlagueRats folder. **Live VERIFIED:** rarity Uncommon,
pool 24, kills summon rats, cap held at exactly 15, controlled DoT = 3 DPS/rat (2 rats →
12 dmg/2s), restart cleared all rats (0), no Output errors. Detail:
[SPRINT_16_PLAGUE_RAT_CHARM.md](SPRINT_16_PLAGUE_RAT_CHARM.md).

## Recommended Next Sprint
Run the outstanding human balance/fun playtest for Sprints 8-13, then post-MVP milestones.
