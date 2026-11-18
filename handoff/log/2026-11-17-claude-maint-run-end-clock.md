# Maintenance: results screen time text (Claude, unattended, 2026-11-17)

**Changed:** nothing a player sees. `RunEndUI`'s local `formatTime` was a line-for-line copy
of `Rules/RunClock.format`; it is deleted and TIME SURVIVED calls `RunClock.format` with the
same value. This finishes the follow-up the 2026-11-12 run-clock note left open.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests, CI.
Not playtested; the deleted body and the rule's body are identical.
**Heads-up:** none. No other "MM:SS" formatter is left in `src/`.
**Next:** the extraction hold check in `ExtractionService` ("every living player is on the
pad") is the next small rule worth a test (`Rules/ExtractionWaves`).
