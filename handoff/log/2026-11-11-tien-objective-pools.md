# Objective pools, first slice on Delta (Tien's agent, 2026-11-11)

**Changed:** a drop on Delta is no longer the same hold every time. At insert a card names the
main objective, why, and where (one of Sanitize the Pens, Secure the Site at one of three
sites, Restore Comms, Confirm Casualties, Recover the Record; never the same twice running);
the squad starts it by reaching it, and finishing it calls the Warden as the hold did. Two
side objectives (Silence the Alarm, Lights On, Misdrop, Clear the Spitters) show when the
squad comes within 80 studs or Control calls them out (90 s, 180 s). Every objective has a
reason on the HUD and radio lines in plain words. Files: new `ObjectiveDefinitions` (rows,
each map's pool and sites; `Config.Objectives` holds the knobs), `Rules/Objectives`,
`src/server/Objectives/*` (one module each, `Kit`, `Types`), `ObjectiveService` rewritten
round them, `ObjectiveUI` (card, list with needles), `MissionLine` (third line),
`EnemyService.spawnAt / groundNear / setQuiet`, `RequisitionService.dropCrate(landed)`,
`SprintController` (`Carrying`), `Rules/Handoff` (optional `objective`), four dev commands.
**Verified:** stylua, selene, both rojo builds, luau-lsp on both places, 181 Lune tests (37
new: the draw, the pool check, the real pools). **Not playtested**: Studio was the owner's.
**Heads-up:** the interact key is F (decision 8), not E as the design table said. Stacks on
PR #15. `Config.Objectives.Enabled = false` restores the single hold. The Warden's
"main objective complete" radio line changed to plain words (`Config.Index.Warden.Radio`,
LORE table). The dev panel has no buttons for the new commands (it is being rewritten on
`claude/dev-menu`). No file in `src/lobby` changed; `Handoff.departure` takes a fourth,
optional argument.
**Next:** play each one (`SetMainObjective <id>`, checklist in the PR): do the props sit
right, is 3 Brutes fair solo, do the side objectives reveal at a good moment; then Open the
Gate (needs shootable props) and the unbuilt side objectives.
