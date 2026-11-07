# Item Expansion Notes (Sprint 10)

## Date
2026-06-12

## Build
Sprint 10 — item pool expanded from 5 to 13. All static checks (stylua, selene,
luau-lsp strict, rojo build) clean. Live verification pending (Studio playtest was wedged
on old code at implementation time).

## Weapon retune (requested)
Fire rate up, damage down, same time-to-kill. DPS held at 60.
- `Config.Weapon.FireCooldown`: 0.167 → **0.1** (≈6 → 10 shots/sec)
- `Config.Weapon.Damage`: 10 → **6**
- Time-to-kill unchanged: Walker (35 HP) ≈ 0.6s, Brute (160 HP) ≈ 2.7s.
- These are the two dials to play with; all other balance scales off them.

## Items implemented (8 new)

### Phase 10A — defense / sustain
- **Kevlar Plate Carrier** — on each level-up, +20 shield/stack (temp max health, 15s),
  capped at 80 concurrent from this item. In `ItemEffectService.onLevelUp` (registered via
  `XPService.addLevelUpListener`).
- **Vampire Serum** — heal 10 HP/stack every 12 credited kills (no overheal). In
  `ItemEffectService.onEnemyKilled`. Drone/airstrike/fire/mine/shock kills all credit the
  player, so they count.

### Phase 10B — projectile feel
- **Ricochet Rounds** — on proc-capable hit, 12%/stack (cap 60%) to chain to nearby enemies
  for 50% damage; targets = 1 + floor(stacks/3), cap 3. Instant chain (no projectile) so it
  can't loop or re-proc. In `ItemEffectService.onProjectileHit`.
- **Shrapnel Magazine** — every 6th player gun shot fires 1+stacks extra angled rounds
  (cap 5) at 60% damage, ~±8–16° cone. In `ProjectileServer.onFireRequest`; drone shots
  call `fire()` directly so they never trigger it. Shrapnel rounds are proc-capable.

### Phase 10C — area control
- **Incendiary Gel** — on kill, 15%/stack (cap 60%) to drop a 8-stud fire pool, 5 dmg/s for
  5s, max 6/player (oldest removed). `IncendiaryService`. Fire kills never spawn new pools
  (recursion guarded via `lastDamageKind == "fire"`).
- **Repulsor Mine Kit** — drops a mine behind the player every 18s (−3s/stack, min 9s);
  detonates on an enemy within 5 studs for 30 dmg (+5/stack, max 45) in a 10-stud blast;
  max 5/player. `MineService`. Mines only damage tagged enemies (never the player).

### Phase 10D — control / priority
- **Shock Coil** — pulse every 12s (−2s/stack, min 6s): 18 dmg (+4/stack, max 30) in 14
  studs + 30% slow for 2s. Slow restores the enemy's `BaseWalkSpeed` attribute via a
  per-humanoid generation counter (no permanent speed corruption). `ShockCoilService`.
- **Hunter's Mark Optics** — every 10s, mark the highest-health enemy within 70 studs for
  6s; marked target takes +20%/stack (cap +100%) from ALL player-owned damage (applied
  centrally in `ItemEffectService.dealDamage`). Red Highlight visual, one target/player.

## Architecture change
Added `ItemEffectService.dealDamage(attacker, humanoid, amount, position, kind)` as the
single damage entry point. Projectiles, bleed, airstrikes, fire pools, mines, and shock
all route through it, so Hunter's Mark, kill credit, and damage numbers are consistent in
one place. `XPService` now supports multiple level-up listeners (offers + Kevlar).

## Caps (performance)
Fire pools 6/player · mines 5/player · ricochet targets 3 · shrapnel extra 5 ·
Hunter's Mark 1/player · shock min cooldown 6s. Oldest object removed when over cap.

## Restart reset
`RunManager.resetRun` now also calls `IncendiaryService.reset`, `MineService.reset`,
`ShockCoilService.reset`; `ItemEffectService.resetPlayer` clears bleeds, marks (+highlight),
kevlar shield, vampire/strike kill counters, slow generations; `ProjectileServer.reset`
clears the shrapnel shot counter.

## Pending verification (do these in a real playtest)
- Test 1: level-up pool shows new items, no dup in one 3-card offer (rollChoices shuffles
  distinct — should hold).
- Test 2: each item individually (inject stacks): effect fires, stacks scale, caps hold,
  resets on restart, no errors.
- Test 3: natural 6-min run, ≥4 effects seen, clean restart.

## Known concerns
- New items use placeholder letter-plate icons (no art yet). Icon prompts in the spec.
- Many heartbeat scans iterate all tagged enemies each tick; fine at ≤60 enemies, watch
  perf if caps rise.
