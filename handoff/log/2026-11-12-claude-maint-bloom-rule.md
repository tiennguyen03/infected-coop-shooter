# Maintenance: bloom rule (Claude, unattended, 2026-11-12)

**Changed:** nothing a player sees. The server's bloom arithmetic for a shot (carry the
previous bloom capped at the gun's `BloomMax`, take off `BloomRecovery` for each idle second
past `Config.Weapon.BloomRecoveryDelay`, then add `BloomPerShot` up to the max) moved out of
`ProjectileServer.onFireRequest` into `Rules/Spread.bloom`, with four new cases in
`tests/Spread.spec.luau` (written first). The service passes the same stored bloom, the same
gun row and the same idle time, and still owns the per-player table and the Bloom attribute.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests, CI.
Not playtested; the arithmetic is the same expressions in the same order.
**Heads-up:** the client's own bloom estimate (`WeaponController`, held by open pull
requests) was not touched; if it repeats this sum it could call `Spread.bloom` once those
merge. The test count in `handoff/README.md` is 135 on `main` plus this branch's 4; the
other maintenance pull requests (#42, #45, #47) add 2, 4 and 6, so re-count after merging
(`lune run tests/run` prints it).
**Next:** more buried rules into `src/shared/Rules/` once the open pull requests merge.
