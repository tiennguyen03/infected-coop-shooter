# Maintenance: difficulty multiplier rule (Claude, unattended, 2026-11-11)

**Changed:** nothing a player sees. The Infected health and damage multiplier formula
(`min(1 + minutes * perMinute, cap)`) moved out of `DifficultyService` into
`Rules/DifficultyCurve.multiplier`, next to the spawn interval and max-alive rules, with two
new cases in `tests/DifficultyCurve.spec.luau` (written first). The service's two getters
call the rule with the same Config values and the same clock.
**Verified:** stylua, rojo build (both places), luau-lsp (both places), 137 Lune tests, CI.
Not playtested; the arithmetic is the same expression in the same order, and both
multipliers are 1 with today's Config (0 per minute, cap 1).
**Heads-up:** none. Only `DifficultyService`, `DifficultyCurve` and its spec were touched;
no open pull request changes them.
**Next:** more buried rules into `src/shared/Rules/` once the open pull requests merge (most
services are held by one of them today).
