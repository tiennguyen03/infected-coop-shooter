# Maintenance: dismemberment rules (Claude, unattended, 2026-11-11)

**Changed:** nothing a player sees. Four pure pieces of `GoreService` moved into
`Rules/Dismember` with `tests/Dismember.spec.luau` written first: `sideOf` (part name to
side and base), `jointFor` (the joint a hit fills), `canSever` (which limbs a form can lose)
and `hit` (the running total, the break at max health x the joint's Fraction, once only).
GoreService calls them with the same Config tables and still does all the breaking,
throwing and stumps. The `JointSpec` type now lives in the rule.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests, CI.
Not playtested; the function bodies are the same lines moved.
**Heads-up:** the test count in `handoff/README.md` is 135 on `main` plus this branch's 6;
the other maintenance pull requests (#42, #45) add 2 and 4, so re-count after merging
(`lune run tests/run` prints it).
**Next:** more buried rules into `src/shared/Rules/` once the open pull requests merge.
