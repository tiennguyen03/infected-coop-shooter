# Breaches and the pressure rhythm (Claude, 2026-11-18)

**Changed:** fun sprint 1 of 4. Being loud builds a run-wide alert; at the top a breach: a
siren and screams from one side, Control names the side ("to your north-east"), a red BREACH
arrow on screen, then a mixed horde floods in from that side over 10 s; then a relief where
nothing builds. The roaming trickle follows the phase (fewer in the calm and the relief).
Bigger and more often as the run goes on. The main objective brings one breach at 40% of its
work. New `BreachService`, `Rules/Breach` (+ spec), client `BreachUI`, remote `Breach`,
`Config.Breaches`; hooks in `EnemyService` (`noise` takes a kind, `addNoiseListener`,
`spawnPicked`, `setTrickle`), `CallInService` (each call-in going off), `ObjectiveService`
(the objective breach), `ProjectileServer` / `BotService` / `KitService` (tag their noise).
**Verified:** stylua, selene, both rojo builds, Lune tests (new `Breach.spec`), luau-lsp for
the match and the lobby. **Not played and not seen in Studio** (no Studio MCP this sprint).
**Heads-up:** `EnemyService.noise(position, reach, kind?)`: pass "shot" or "blast" for a
noise that should count toward a breach; untagged noise (feet, engines) does not. Breaches
hold off while `IndexActive` or `ExtractionActive` is set. Built on #86.
**Next:** play it: F1 > INFECTED > BREACHES > Breach now, then a whole run watching the
strip's alert; tune `Config.Breaches` (Threshold, Sources.Shot, Horde, Relief). Then a HUD
alert meter if the radio lines are not enough (ui-ux-designer).
