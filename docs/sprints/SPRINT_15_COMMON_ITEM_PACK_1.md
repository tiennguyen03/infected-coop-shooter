# Sprint 15: Common Item Pack 1 + Vector Icons

## Date
2026-06-12

## Goal
Add 10 new Common items (passive stats/utility) + simple SVG icons. Pool becomes
16 Common / 6 Uncommon / 1 Legendary = 23 total. Rarity odds (70/25/5) and the every-4th
guarantee are unchanged.

## Items added (all Common)
| Id | Effect (per stack) |
|----|--------------------|
| high_grain_powder | +8% bullet damage |
| combat_stimulants | +7% fire rate |
| lightweight_boots | +7% move speed |
| military_rations | +12 max HP |
| field_manual | +8% XP gained |
| scavenger_pouch | +15% XP orb magnet range |
| ballistic_weave | -6% incoming damage (cap -50%) |
| field_dressing | heal 8 HP on level-up (no overheal) |
| signal_antenna | +10% drone & Hunter's Mark range |
| cheap_drone_parts | +10% drone duration |

Values in `Config.Items.Passives`.

## Architecture (no major refactor)
New `PassiveItemService` recomputes bonuses whenever inventory changes
(`ItemService.setInventoryChangedHandler`):
- Stat items (damage/fire rate/move speed) → `PlayerStatsService.setBonus(player,"passives",…)`
  (already wired into projectile damage, fire cooldown, sprint speed).
- The rest publish player attributes the relevant systems read:
  - `XPGainMult` → XPService.addXP
  - `OrbMagnetMult` → XPOrbService magnet range
  - `IncomingDamageMult` → EnemyService contact damage to player
  - `DroneRangeMult` / `DroneDurationMult` → DroneService (per-drone at deploy)
  - `HunterMarkRangeMult` → ItemEffectService mark search range
- `military_rations` adjusts MaxHealth by **delta** (coexists with Kevlar/AmmoCache shields).
- `field_dressing` heals via a level-up listener.
- `PassiveItemService.resetPlayer` (called by RunManager) zeroes all of the above on restart.

## Icons
10 flat SVGs in `assets/icons/` (transparent bg, 64 viewBox, dark outline, no text):
high_grain_powder, combat_stimulants, lightweight_boots, military_rations, field_manual,
scavenger_pouch, ballistic_weave, field_dressing, signal_antenna, cheap_drone_parts.
Not yet uploaded to Roblox — `IconId = nil` (placeholder letter plates render meanwhile),
same as the other Sprint-10 items.

## Verification
- Static: stylua + selene + luau-lsp strict + rojo build all PASS.
- Code confirmed synced into the Studio edit place (PassiveItemService present).
- **Live PENDING**: the running playtest was wedged on old code (pool read back 13, MCP
  stop_playtest could not tear it down). Needs a manual **Stop → Play**, then:
  - pool counts 16/6/1 (=23)
  - grant each new item; check attributes (e.g. HP +12, DamageMult 1.08 @1 / 1.24 @3,
    IncomingDamageMult 0.94 @1 / 0.82 @3)
  - RestartRun → VerifyCleanup PASS (attributes back to defaults, MaxHP 100)

## Deferred
- Uploading the 10 SVGs as Roblox image assets + setting IconId (cosmetic; placeholders work).
