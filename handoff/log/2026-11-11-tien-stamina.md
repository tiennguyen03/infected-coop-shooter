# Stamina and bar; slides keep momentum (tien, 2026-11-11)

**Changed:** Sprint now runs on stamina: a full bar is about 8 s of sprint, a roll costs 20, a
slide 10, and it comes back after 1 s of not spending. Run it dry and you are winded: no
sprint, roll or slide until the bar is a quarter full, and the bar pulses red meanwhile. The
bar is a thin yellow line under the health stack that only shows while stamina is in use.
Slides keep the speed you had going in, carry on (and speed up a little) downhill, die fast
uphill, and you keep the leftover speed for a moment after instead of stopping dead.
Files: `Rules/Stamina`, `Rules/Slide` (+ specs), `SprintController` (owns stamina),
`MovementController` (slide speed per frame, the coast after), `AnimationController`
(`holdMove` / `releaseMove`), `StaminaUI`, `Config.Stamina`, `Config.Movement.Slide`.
**Verified:** stylua, selene, both rojo builds, 155 Lune tests (20 new), luau-lsp. **Not
played at all** (the owner's Studio was in use).
**Heads-up:** `Config.Movement.Slide` lost `Duration` / `StartSpeed` / `EndSpeed` (now
`EntryBoost`, `Friction`, `SlopeAccel`, ...). `SprintController.isSprinting()` is false while
winded, so the crouch and prone keys work as usual then. Stamina is client-trusted, like sprint. Shove
is free: its cooldown is the server's, so a client-side cost could charge for a refused shove.
Touch has no sprint button, so the bar never shows there.
**Next:** play it: sprint length and the winded wait, bar size and its spot 1 px above the
ability circles, slope gain and the 40 cap on Delta's ramps, the coast after a slide, the
slide clip held on a long hill (`ClipHoldAt` 0.6 is a guess at where the slide pose is).
