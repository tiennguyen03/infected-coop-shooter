# Maintenance review (Tien's agent, 2026-11-10)

**Changed:** nothing a player sees. A new spec, `tests/SourceReferences.spec.luau`, reads the
source and fails CI on an undeclared or unused remote, a require of a missing module, a BOOT
entry with no file, or an `init()` nothing calls. Removed four functions nobody called
(`DamageService.recordDamager`, `WeaponController.isAiming`, `MovementController.isMoving`,
`SprintController.isSprintHeld`); IndexService's local `spawn` is now `spawnWarden`. The
audio asset table names `HitMarkerUI`. `docs/ARCHITECTURE.md` > Open concerns re-counted.
**Verified:** CI (stylua, selene, rojo build, luau-lsp, 75 Lune tests). Not playtested; the
changes remove dead code and rename one local.
**Heads-up:** files the open lobby branches touch (Config, Attributes, Messages, Remotes,
MeshAssets, LoadoutService, HandoffService, DevTestService, the lobby) were left alone; what
they need is written in ARCHITECTURE concerns 4-6 (untyped remote names, PlayerStatsService
and IncendiaryService with no callers, four modules over 1,300 lines).
**Next:** after the lobby branches merge: typed remote names, a decision on
PlayerStatsService (remove, or a real speed buff), the IndexService split before the second
boss.
