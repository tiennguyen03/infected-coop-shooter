# Item Rarity Plan (Sprint 14)

## Rarity philosophy
Rarity shapes the level-up draft without adding new effects. Common items are the
backbone of every run; Uncommon items appear often enough to steer a build; Legendary
items are rare, high-impact spikes. No Legendary guarantee yet — Legendary should feel
like a lucky moment, not an expectation.

## Rarities
| Rarity | Display | Color | Per-card weight |
|--------|---------|-------|-----------------|
| Common | Common (Grey) | `170,170,170` | 70% |
| Uncommon | Uncommon (Green) | `80,220,120` | 25% |
| Legendary | Legendary (Red) | `255,75,75` | 5% |

Defined in `Config.ItemRarities`. Per-item rarity lives on each `ItemDefinitions` entry.

## Current 13-item assignment
**Common (6):** hollow_point_rounds, adrenaline_injector, emergency_ammo_cache,
kevlar_plate_carrier, vampire_serum, shrapnel_magazine
**Uncommon (6):** tactical_drone_beacon, ricochet_rounds, incendiary_gel,
repulsor_mine_kit, shock_coil, hunters_mark_optics
**Legendary (1):** air_support_authorization

## Offer logic
Level-up still offers 3 **distinct** cards. Per card: roll a rarity by weight → pick a
random item from that rarity's pool not already chosen → if that pool is exhausted, fall
back to any remaining item. (Implemented in `ItemService.rollChoices`.)

## Guarantee rule
Every `Config.RarityGuaranteeEvery` (= 4) level-ups, the offer guarantees at least one
Uncommon-or-better card (a Common card is swapped for an Uncommon/Legendary if none rolled).
No Legendary guarantee.

## Target 50-item split (long-term)
- 30 Common
- 15 Uncommon
- 5 Legendary

Future item-expansion sprints add items into these pools; the framework here does not
change — only `ItemDefinitions` (and per-item `Config.Items`) grow.

## Dev tooling
- `SimulateItemOffers(n)` (DevTestService) tallies rarity distribution over n single-card
  rolls — sanity-check it lands ~70/25/5.

## Stop conditions (from spec, all must hold)
Item selection works · no duplicates in one offer · Legendary stays rare · rarity UI has
no client errors · restart still clears items · VerifyCleanup passes.
