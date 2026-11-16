# Call-ins land on crowds (Claude, 2026-11-16)

**Changed:** the Hammer, Anvil and Shrike no longer miss a crowd they are put on. Why they
missed: nothing dodges; the Infected keep chasing the thrower and walk 23-92 studs between
the mark and the round (numbers in `docs/PROGRESSION.md` > Call-ins > Landing on the crowd).
Now the Infected within the mark's `Landing.Hold` walk to the marker until shortly after the
first impact (`AirStrikeService` through `EnemyService.setLure`), and blasts (fire missions,
Tripline) are measured flat with an 8-stud height allowance, so Brutes are hit by gun-run
bursts and trip mines. New `Rules/StrikeLanding` + spec (a small crowd sim shows 0 of 20
Walkers left in the Hammer's blast today, 20 of 20 held). `Config.CallIns.Landing.Enabled =
false` puts the old behaviour back; each row's `Landing` block tunes it.
**Verified:** stylua, selene, both rojo builds, luau-lsp, Lune tests. **Not played** (the
owner was playtesting; no Studio).
**Heads-up:** `MineService` and `AirStrikeService` touched (measure only). Bots' fire
missions hold too (same path). On Mile 14 only bodies in a chase are held (sleepers stand
still anyway).
**Next:** dev menu: spawn 25 Walkers, call each strike on them, count kills with the switch
on and off; check the hold does not look like a magnet (tune `Hold` down) and that a Hammer
at your own feet does not become a panic button.
