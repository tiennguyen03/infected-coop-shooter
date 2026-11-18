# Maintenance: low-health fade rule (Claude, unattended, 2026-11-18)

**Changed:** nothing a player sees. `LowHealthFX`'s per-frame fade (step toward the target
intensity over `Config.Audio.LowHealth.Ease`, never past it, snap to 0 under the off
threshold when fading out) moved into `Rules/Feel.easeToward`, beside `Feel.lowHealth`,
with five tests written first in `tests/Feel.spec.luau`. The effect calls it with the same
values.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests (497
on this branch), CI. Not playtested; the rule's lines are the effect's lines moved.
**Heads-up:** the test count in `handoff/README.md` is left alone so this does not clash
with #73 and #75; with all three merged it is 507.
**Next:** prune `handoff/log/` to the README's 12 notes in a commit of its own.
