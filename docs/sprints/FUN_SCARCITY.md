# Scarcity: mistakes cost something ("make it fun" sprint, PR 4 of 4, 2026-11-18)

Owner, after many runs on Checkpoint Delta: "it's not really that challenging or fun."
Diagnosis (3): plenty of ammo, death is cheap, so nothing a player does wrong costs anything.
This PR makes ammo and lives a squad resource. Built on #86 (test mix 4). Playable alone; the
other three sprint PRs (breaches, dangerous enemies, the Warden) do not depend on it.

## Design note (systems designer)

**Recommendation:** fewer spare magazines, the flare as the main refill on a long wait, ammo
pouches off fallen squadmates, and a small shared pool of reinforcements. Revive stays free;
death now costs the squad.

**Why:** today a soldier re-arms every ~40 s from a pallet and death only means watching. A
decision needs a cost on each side: "throw the flare now or save it for the hold", "run to
the pouch under fire or keep shooting", "revive now or kill the Runner first". Each change
below adds one of those choices, and each has its own switch.

| Key | Old | New | What the player feels |
|---|---|---|---|
| `Weapons.<Gun>.Scarce` (new, on each gun's row) | M16 30 + 120 / 240 | 30 + 90 / 150 (3 spare mags at insert, 5 at most) | reloads are counted; a long spray empties you |
| (same) MP5 / M249 / Mossberg / M110 / M17 | 120/210, 150/300, 20/40, 40/80, 34/68 | 90/150, 100/200, 16/32, 40/60, 34/51 | the DMR and pistol already ran tight, so they lose the least |
| (same) Revolver / M2010 | 18/30, 15/30 | 12/24, 10/20 | Goose unchanged (1 + 1) |
| `Scarcity.Resupply.FlareCooldown` (new) | `Requisition.FlareCooldown` 20 | 90 s after a pallet lands | a pallet every ~2 min at most; the meter shows "FLARE IN 1:12" |
| `Scarcity.Pouch` (new) | nothing | a dead squadmate (bots too) drops a pouch: hold E 0.5 s, +2 mags long gun, +1 sidearm, once per player, 120 s | a reason to go to the body, and bots' deaths feed you |
| `Scarcity.Reinforce.Base` / `PerPlayer` (new) | dead = spectate to run end (bots: back in 10 s) | 2 + 1 per player (solo 3, four players 6) | three deaths per mission solo; the fourth is permanent |
| `Scarcity.Reinforce.Delay` (new) | - | 8 s, then dropped beside the nearest standing squadmate | death breaks your fight for a moment, not for the mission |
| `Scarcity.Reinforce.BotRespawnSeconds` (new) | `Bots.RespawnSeconds` 10 | 30 | losing a bot hurts for half a minute |

Fire rates are untouched (real guns). Pallet re-arm, the Speedball and the objective reward
crate still fill to the (new, lower) max: they are the "supply drops" and "crates".

**Rules for the pool** (`Rules/Scarcity`, tested):
- One pool per run for the squad: `Base + PerPlayer` for every player who joined this run (a
  late joiner adds one). Shown at the top of the left column.
- A player who dies (bled out, or a lethal hit with both revives used) spends one. After
  `Delay` the helicopter drops them beside the nearest standing player (else a bot), from
  `DropHeight` when there is open sky there, else right beside them. They land with the insert
  kit (full magazines, the insert reserve, grenades and stims) and fresh revives; call-ins
  and field upgrades stay as they were.
- Pool empty: dead until extraction (the results screen pays everyone, the existing Win /
  Partial / Loss rule).
- **Wipe:** no player up and nobody to drop back to: either nobody at all (players and bots)
  is still up or down, or the pool is empty with nobody inbound. With reinforcements off,
  the old rule (every player dead).

**Bots do not use the pool.** In solo the pool is the one human's lives; a bot dying is the
bot AI's fault, not a choice the player made, and bots stand in for missing players, who are
already counted in the pool. They pay differently: they come back after 30 s instead of 10,
and every bot death leaves a pouch the player can loot.

**Revive matters more** without a change to its numbers: a revive is free, a death costs the
squad one of three. The K.I.A. line says how long until the drop, or that none are left.

**Watch in play:** ammo runs out before the second pallet (raise `Scarce.ReserveMax`
first, not the start); pouches too generous with three bots dying (`Pouch.FromBots = false`);
the pool never runs out in solo (Base 1); dropping beside a squadmate into a horde (raise
`Delay`, or a later version that picks the quietest squadmate).

## Radio lines (lore developer, plain words)

`Config.Scarcity.Reinforce.Radio`, shown as CONTROL subtitles:
- Inbound: "Control: Reinforcement on the way for Pike One. Dropping on Pike Two."
- The last one spent: "Control: That was the last reinforcement, Pike. Nobody else goes down."
- A death with none left: "Control: No more reinforcements. Get your people home."

## Code

`Rules/Scarcity` (+ `tests/Scarcity.spec.luau`), `ReinforceService` (pool, drop, pouches,
`wiped`), `RunManager` (wipe check through `ReinforceService.wiped`, also on a bot's death),
`WeaponDefinitions` (reserve from `Scarce`), `LoadoutService.addMags` / `reinforce` /
`setSpareMags`, `RequisitionService` (cooldown, `ResupplyFlareReadyAt`), `BotService` (bot
respawn wait), `ReinforceUI` (HUD), `RunEndUI` (K.I.A. line), `ResupplyUI` (flare
countdown), dev menu PLAYER > SCARCITY.

## Off switches

`Config.Scarcity.Enabled = false` is the game before this PR. One part at a time:
`Ammo.Enabled`, `Resupply.Enabled`, `Pouch.Enabled`, `Reinforce.Enabled` (false: dead =
spectate, bots back in 10 s, the HUD line hidden).
