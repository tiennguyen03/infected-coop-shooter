# Scarcity: mistakes cost something (Claude, 2026-11-18)

**Changed:** fewer spare magazines (each gun's `Scarce` row in `Config.Weapons`; M16 30 + 90 / 150),
the Resupply flare waits 90 s after a pallet ("RESUPPLY  FLARE IN 1:12" on the meter), a dead
squadmate (bots too) leaves an AMMO pouch (hold E: +2 long-gun mags, +1 sidearm, once each), and
the squad shares 2 + 1 per player reinforcements a run. A dead player spends one and is dropped
by the helicopter beside the nearest standing squadmate after 8 s (insert kit, fresh revives);
none left = dead until extraction; wipe = no player up and nobody to drop back to. Bots never
spend the pool (back in 30 s instead of 10). HUD: yellow squares at the top of the left column;
K.I.A. line counts the drop down. Files: `Rules/Scarcity` + spec, `ReinforceService`,
`ReinforceUI`, `RunManager`, `LoadoutService`, `RequisitionService`, `BotService`,
`WeaponDefinitions`, `RunEndUI`, `ResupplyUI`, dev menu. Design: `docs/sprints/FUN_SCARCITY.md`.
**Verified:** stylua, selene, both rojo builds, Lune tests (new Scarcity spec), luau-lsp for match
and lobby. Not run in Studio (the brief: no Studio MCP).
**Check in play:** F1 > PLAYER > SCARCITY: Reinforcements 1, then Kill me twice (first drops you
beside a bot after 8 s, the second keeps you dead and solo with bots alive ends the mission);
the drop lands in the open, not on a roof; Spare mags 0 then a bot's pouch (Kill bots, walk to
the AMMO label, hold E); the flare's countdown after a pallet; the left column does not overlap.
**Heads-up:** Nova: the wipe check is `ReinforceService.wiped` (also on a bot's death); the left
column's first element is now `ReinforceUI` (order 0). Config.luau: only the new `Scarcity` table
(after `Downed`) and one `Scarce` line per gun row.
**Next:** play it; tune `Scarce.ReserveMax` before the start if ammo runs dry; consider dropping
reinforcements beside the quietest squadmate instead of the nearest.
