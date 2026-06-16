# Sprint 16 Plan: Plague Rat Charm

## Status
PLAN ONLY — not yet implemented. Say "start Sprint 16" to build it.

## Goal
Add one Uncommon item: **Plague Rat Charm** (`plague_rat_charm`). On a credited kill it has
a chance to summon plague rats that crawl to nearby Infected, latch on, and eat them for
damage over time. Reuses existing kill-credit + central damage routing; no major refactor.

## Item definition (ItemDefinitions.luau)
```
plague_rat_charm = {
  Id = "plague_rat_charm", Name = "Plague Rat Charm",
  Description = "Kills have a 12% chance per stack to unleash plague rats that gnaw nearby Infected.",
  Rarity = "Uncommon", Abbrev = "RT", Color = Color3.fromRGB(120, 170, 70), IconId = nil,
}
```
Pool after this: **16 Common / 7 Uncommon / 1 Legendary = 24**. Odds (70/25/5) and the
every-4th guarantee are unchanged (only the Uncommon pool grows by 1).

## Config (Config.Items.PlagueRat)
```
ProcChancePerStack = 0.12, ChanceCap = 0.60,
RatsPerStack = {2, 3, 4, 5},  -- index = min(stacks,4); 4+ caps at 5
MaxActivePerPlayer = 15,
Lifetime = 8,            -- seconds
TargetRange = 45,        -- studs
DamagePerSecond = 3,
LatchDuration = 4,       -- seconds latched per target
MaxRetargets = 1,        -- one retarget per rat
CrawlSpeed = 22,         -- studs/sec toward target
```

## Architecture — new `src/server/PlagueRatService.luau`
Mirrors the DroneService / IncendiaryService pattern (server-simulated anchored parts,
Heartbeat step, per-owner cap, folder sweep on reset).

**Hook (no new systems):** in `ItemEffectService.onEnemyKilled`, after the existing
drone/incendiary/airstrike rolls, add a Plague Rat roll and call a registered spawner —
same `setX`/callback pattern already used for `droneDeployer` / `firePoolSpawner`
(avoids a require cycle). `PlagueRatService.init` registers via
`ItemEffectService.setRatSpawner(fn)`. Pass the death position + killer.

**Rat record:** `{ part, owner, target: Humanoid?, expiresAt, latchUntil, retargets, nextTickAt }`.

**Spawn (on proc):** count = `RatsPerStack[min(stacks,4)]`; respect `MaxActivePerPlayer`
(remove this owner's oldest if over). Place rats around the death position.

**Heartbeat step (pause-aware, like other services):**
1. Expire rats past `Lifetime` (or owner gone) → remove + folder sweep on reset.
2. If no/dead target → acquire nearest living Infected within `TargetRange`
   (CollectionService:GetTagged("Enemy")). If target died and `retargets < MaxRetargets`,
   retarget once; else if no target, idle/despawn at lifetime.
3. Not latched + has target → crawl: lerp position toward target root at `CrawlSpeed`;
   on contact (within ~2 studs) set `latchUntil = now + LatchDuration`.
4. Latched → each 1s tick: `ItemEffectService.dealDamage(owner, targetHumanoid, DamagePerSecond, pos, "bleed")`
   (routes kill credit + damage number; "bleed" reuses the red number). When `latchUntil`
   passes or target dies, unlatch.

**Recursion safety (V1):** rat damage uses kind `"bleed"` (NOT a new kind). To guarantee a
rat kill never spawns more rats, `onEnemyKilled` checks `lastDamageKind ~= "rat"` before the
rat roll — OR simpler and chosen for V1: tag rat damage with a dedicated kind `"rat"` and
have `onEnemyKilled` skip the rat roll when `killKind == "rat"` (same guard pattern Incendiary
uses with `"fire"`). This is the safe, explicit no-rat-from-rat-kill rule the spec asks for.

**Visuals (simple part-based, no rig):** a `Model` per rat — dark body block (~1.2×0.6×0.6),
small head block, thin tail part, two small neon-red eyes. Crawl = subtle vertical bob via
`os.clock()` sine while moving; latch = faster bite-bob. Optional: a tiny dark-red
ParticleEmitter burst on each damage tick. Low to the ground (y ≈ 0.5).

**Reset:** `PlagueRatService.reset()` destroys all rats + `ratFolder:ClearAllChildren()`;
called from `RunManager.resetRun`. `Main.server` inits the service.

## Icon
`assets/icons/plague_rat_charm.svg` — flat vector, transparent bg, 64 viewBox, dark
outline, plague-rat silhouette (crouched body + long tail), green disease glow, red eye,
no text. Not uploaded (IconId nil; placeholder plate renders meanwhile).

## Files to change
- `src/shared/ItemDefinitions.luau` (add item)
- `src/shared/Config.luau` (PlagueRat tuning)
- `src/server/PlagueRatService.luau` (new)
- `src/server/ItemEffectService.luau` (setRatSpawner + on-kill roll + rat-kind guard)
- `src/server/RunManager.luau` (reset hook), `src/server/Main.server.luau` (init)
- `assets/icons/plague_rat_charm.svg`
- docs: ITEMS_REFERENCE.md, ITEM_RARITY_PLAN.md, INTEGRATION_TEST_NOTES.md

## Verification plan (on implement)
Static: stylua + selene + luau-lsp + rojo build. Live (DevTestService + Studio MCP):
GrantItem("plague_rat_charm",1) → SpawnEnemy("Walker",10) → kill some → confirm rats spawn,
crawl, latch, deal DoT (red numbers), credit kills, despawn at 8s, cap at 15/player; then
RestartRun → VerifyCleanup PASS, no Output errors. Verify a rat kill does NOT spawn new rats.

## Risks / watch-items
- Cap + folder sweep must hold (perf with up to 15 rats × multiple procs).
- Latch contact check cheap (distance only; no physics).
- Rat damage must route ONLY through `dealDamage` (no direct TakeDamage) so Hunter's Mark
  and kill credit stay consistent.
- One-retarget limit prevents rats living forever chasing.
