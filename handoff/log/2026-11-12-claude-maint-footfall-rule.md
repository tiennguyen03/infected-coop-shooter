# Maintenance: footfall phase rule (Claude, unattended, 2026-11-12)

**Changed:** nothing a player hears. `FootstepController`'s local `crossed(from, to, mark)`
(did the dominant locomotion clip pass a footfall phase between two frames, including a
loop that wrapped) moved into `Rules/LoopPhase.crossed`, with `tests/LoopPhase.spec.luau`
written first. The controller calls it with the same phases and marks.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests, CI.
Not playtested; the function body is the same lines moved.
**Heads-up:** the test count in `handoff/README.md` is 135 on `main` plus this branch's 4;
the other maintenance pull requests (#42, #45, #47, #51) add 2, 4, 6 and 4, so re-count
after merging (`lune run tests/run` prints it).
**Next:** `Ledge.position`'s rise/cross easing split is another pure piece worth a test;
more buried rules once the open pull requests merge.
