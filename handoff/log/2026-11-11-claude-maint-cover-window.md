# Maintenance: cover-move window rule (Claude, unattended, 2026-11-11)

**Changed:** nothing a player sees. The rule for the melee-immunity window a vault, climb or
roll buys (ends at now + move duration + grace; nothing while the last window is still open
or cooling down) moved out of `CoverMoveService` into `Rules/CoverWindow.open`, with
`tests/CoverWindow.spec.luau` written first. The service passes the same clock, the same
stored window end and the same `Config.Movement` values.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests, CI.
Not playtested; the comparison and the sum are the same expressions as before.
**Heads-up:** the test count in `handoff/README.md` is 135 on `main` plus this branch's 4;
the other maintenance pull request (#42) adds 2 more, so whichever merges second needs the
number re-counted (`lune run tests/run` prints it).
**Next:** more buried rules into `src/shared/Rules/` once the open pull requests merge (most
services are held by one of them today).
