# Maintenance: extraction hold check (Claude, unattended, 2026-11-18)

**Changed:** nothing a player sees. The co-op check that runs the extraction hold only while
every living player is on the pad (`playersLiving > 0 and playersIn >= playersLiving`) moved
from `ExtractionService` into `Rules/ExtractionWaves.squadHolding`, with three tests written
first in `tests/ExtractionWaves.spec.luau`. The service calls it with the same two counts.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), the Lune tests (495),
CI. Not playtested; the rule's body is the same expression.
**Heads-up:** none.
**Next:** `handoff/log/` holds over 50 notes against the README's limit of 12; prune the
oldest in a commit of its own.
