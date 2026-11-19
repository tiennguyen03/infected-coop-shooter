# Dangerous Infected (Claude, 2026-11-18)

**Changed:** each Infected forces its own answer, with a tell first. Brute 500 hp, plated front
(40% from the front, 125% in the back, legs and blasts full), charges through the squad
(knockdown + scatter, stunned by cover). Runner 40 hp, speed 19, pounces and pins until a
squadmate hits or shoves it off, packs of 2-3. Hocker: three-glob barrage, bigger puddles, a
high lob over cover. Walker 60 hp: a crowd of 3+ grabs (slows). Control's radio lines for the
first charge, first lob and every pin. Files: `Config.InfectedMoves`, `EnemyDefinitions`,
`Rules/InfectedMoves` (+ spec), `EnemyService` (big moves, grab, barrage, `spawnDirected`),
`DamageService` (armour), `EnemyProjectileService.fire` (flight arg), `Squad.standUp`,
`AnimationController`/`KnockdownController` (get-up now, long falls hold), `SprintController`
and `BotService` (Grabbed, pin priority, knock reschedule), dev `MoveTest` / `ToggleMoves`.
**Verified:** stylua, selene, both rojo builds, Lune tests, luau-lsp (match and lobby). Not
played: Studio MCP was off limits for this sprint. Poses (lean back, crouch, Runner on the
pinned body) are set blind.
**Heads-up:** the spawn loop's spawn line now calls `spawnDirected` (Runner packs); the breach
PR touches the same loop. `Plates`/Warden untouched. No new clips or sounds: tells reuse each
form's voice groups.
**Next:** play F1 > INFECTED > THE MOVES; tune `Config.InfectedMoves`; real crouch/leap/pin
clips and a charge roar; bots dodging a charge.
