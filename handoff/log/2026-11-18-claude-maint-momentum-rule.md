# Maintenance: walk weight rule (Claude, unattended, 2026-11-18)

**Changed:** nothing a player sees. `MomentumController`'s per-frame maths (`moveToward`,
the brake-or-accelerate choice and the WalkSpeed cap) moved into `Rules/Momentum`
(`moveToward`, `step`), with `tests/Momentum.spec.luau` written first (seven tests, Lune's
Roblox `Vector3`). The controller calls `Momentum.step` with the same values each frame.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests (499
on this branch), CI. Not playtested; the rule's lines are the controller's lines moved.
**Heads-up:** the test count in `handoff/README.md` was left alone so this branch does not
conflict with #73 (which also edits that line); with both merged it is 502.
**Next:** prune `handoff/log/` to the README's 12 notes in a commit of its own.
