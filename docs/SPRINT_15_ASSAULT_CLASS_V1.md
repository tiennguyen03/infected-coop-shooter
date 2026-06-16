# Sprint 15: Assault Class V1 + Proper Held Gun

## Date
2026-06-12
(Note: a separate earlier sprint also used the "15" number — Common Item Pack 1. This doc
is the Assault Class sprint; no file/feature overlap.)

## Part 1 — Proper held gun
**Problem:** the rifle was welded to `HumanoidRootPart` (torso) → looked glued to the body.
**Fix (`PlayerSetup.attachRifle`):** now welds to **RightHand** (R15) / **Right Arm** (R6).
Parts are built in world space at the hand, oriented along the character's forward, then
WeldConstraint-ed to the hand so the gun reads as held and follows the arm. The `Muzzle`
part stays at the barrel tip; WeaponController still fires from it (projectile math
unchanged). Rifle is parented to the character, so it's destroyed with the old character on
restart — no duplicates, clean death/restart.

## Part 2 — Combat Momentum (passive)
On each credited kill: +1 stack (max 5), refreshes a 4s timer. Per stack: +4% damage and
+4% move speed (via `PlayerStatsService.setBonus(player,"assault_momentum",…)`). At 5
stacks: +20%/+20%. Expires after 4s (Heartbeat check); cleared on death/restart. Hooks the
new `ItemEffectService.addKillListener` (fired once per credited kill).

## Part 3 — Q Combat Dash
5s cooldown, 18 studs, 0.18s slide. Direction = `Humanoid.MoveDirection` (else facing).
Destination is **raycast-clamped** (stops ~2 studs short of walls — no clip/fling); the
root CFrame is tweened to it. Simple neon dust streak. No i-frames/damage (V1).

## Part 4 — E Breach Charge
12s cooldown. Places a blinking charge forward (≤35 studs, raycast-clamped, dropped to
ground) with a red warning ring; 0.8s fuse, then a 14-stud / 45-damage blast routed through
`ItemEffectService.dealDamage(... "breach")` — so it credits the player, drops XP, and
respects Hunter's Mark. Only tagged enemies are damaged (never the player). Stock zeroed
Explosion for the flash/boom + expanding neon sphere.

## Part 5 — Ability UI
Bottom-right `AbilityUI`: Q Dash + E Breach tiles with cooldown countdowns (grey while
cooling, "READY" otherwise) + a "MOMENTUM xN" readout. Cooldowns driven by the server
`AbilityUsed` remote; UI counts down locally for display only.

## Server authority
Client `AbilityController` sends `UseAbility("dash"/"breach")`. Server
(`AssaultClassService.onUseAbility`) validates: not paused, alive, cooldown ready — then
performs the ability and starts the authoritative cooldown. Client cooldowns are never
trusted. The client also suppresses input while `GamePaused`.

## Files changed
- `src/server/PlayerSetup.luau` (gun → hand weld)
- `src/server/AssaultClassService.luau` (new), `src/client/AbilityController.luau` (new),
  `src/client/AbilityUI.luau` (new)
- `src/server/ItemEffectService.luau` (addKillListener + fire on credited kill)
- `src/shared/Config.luau` (Assault block), `src/shared/Remotes.luau` (UseAbility, AbilityUsed)
- `src/server/RunManager.luau` (resetPlayer hook), `src/server/Main.server.luau` +
  `src/client/Main.client.luau` (init)

## Verification
- Static: stylua + selene + luau-lsp strict + rojo build all PASS.
- Code confirmed synced to the Studio edit place (AssaultClassService present).
- **Live PENDING**: running playtest was wedged on old code (MCP stop_playtest couldn't
  tear down). Needs a manual **Stop → Play**, then run the spec's 21-step checklist:
  gun in hand / points forward / shooting works / muzzle flash at barrel / no dup on
  restart; Q dash + cooldown + blocked while dead/paused; E breach damages enemies, credits
  kills, drops XP, doesn't hurt player; momentum stacks/expires/clears; ability UI updates;
  VerifyCleanup PASS.

## Known issues / risks to watch on live test
- Gun grip offset is a first pass — may need a small CFrame tweak after seeing it in-hand.
- Dash uses a CFrame tween on the (unanchored) root; if it feels floaty or fights physics,
  fall back to a clamped single-step teleport.
