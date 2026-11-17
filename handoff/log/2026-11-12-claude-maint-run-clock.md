# Maintenance: run clock text (Claude, unattended, 2026-11-12)

**Changed:** nothing a player sees. `RunTimerUI`'s local `formatTime` (seconds to "MM:SS")
moved into `Rules/RunClock.format`, with `tests/RunClock.spec.luau` written first. The HUD
timer calls it with the same value.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests, CI.
Not playtested; the function body is the same lines moved.
**Heads-up:** `RunEndUI` has an identical `formatTime` of its own. It was left alone because
open pull requests change that file; once they merge, point it at `RunClock.format` and
delete the copy. The test count in `handoff/README.md` is 135 on `main` plus this branch's
4; the other maintenance pull requests (#42, #45, #47, #51, #53) add 2, 4, 6, 4 and 4, so
re-count after merging (`lune run tests/run` prints it).
**Next:** six maintenance pull requests are open, so the unattended runs stop here until
some are merged or closed.
