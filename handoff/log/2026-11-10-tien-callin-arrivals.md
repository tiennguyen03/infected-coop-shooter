# Call-in arrivals (Tien's agent, 2026-11-10)

**Changed:** every call-in comes in its own way between the throw and the effect (owner:
"Hammer and Anvil look like the same thing"): Hammer a diamond per round and thin rounds
dropping straight down, Anvil one closing ring, a heavy round and a column of earth, Shrike
a lit lane and a rake of tracers, Doorman a case under a cargo chute, Tripline charges hopping
out of the satchel, Concertina two drums rolling out, Speedball a tumbling bundle, Aid Bag a
bag under a streamer. Table: `docs/PROGRESSION.md` > Call-in arrivals. Files:
`src/client/CallInArrivalFX.luau` (new), `Rules/Arrival` + spec (new), `Config.CallIns`
(`Arrivals`, an `Arrival` block per row), `CallInService`, `AirStrikeService`,
`SupplyDropService`, `MineService`, `PauseService.wait`, `WorldSounds.at` (pitch), remote
`CallInArrival`.
**Verified:** stylua, selene, both rojo builds, luau-lsp on both places, 148 Lune tests (13
new for `Rules/Arrival`). **Nothing was run in Studio**: no effect has been seen or heard.
**Needs an in-game look** (dev `FireCallIn <id>` for each of the eight):
- Every one: the thrown marker leaves the hand and lands on the aim point; smoke colour reads.
- Hammer vs Anvil side by side: do they now read as different things? Diamonds visible on
  the ground; rounds visible coming in (0.3 s and 0.7 s may be too short); whistle pitches
  (1.5 and 0.55) and the far-off tube thumps are not harsh; the Anvil's column and burnt disc
  do not clip or flicker on a slope; the dust dome is a flat dome, not a ball.
- Shrike: rungs run toward the direction of flight; extra tracers start at the gunship's
  gun (the client works out where it is); the cannon sound is not too loud over the rotor.
- Doorman: chute panels and lines sit right, the fold does not pass through the case, the
  swap from case to tripod at 2.2 s is hidden by the dust.
- Tripline: charges land where the mines appear. Concertina: drums roll the right way and
  end at the wire's ends; the strand does not show through the wire.
- Speedball, Aid Bag: the stand-in is swapped for the real bundle without a pop; the
  streamer's stripes and flutter; the landing thump lines up.
- Pause mid-arrival (run end): it holds and does not finish early. Two players: both see it.
- Low-end device: an Anvil plus a Hammer at once (MicroProfiler).
**Heads-up:** Doorman, Tripline and Concertina are no longer instant (2.2 / 0.95 / 1.05 s),
Speedball and Aid Bag take 1.5 / 1.8 s (were 0.9): balance calls for Tien.
`Config.CallIns.Arrivals.Enabled = false` puts the old look and timing back. No lobby files
touched. `SupplyDropService.drop` takes a fourth argument, `fireMission` / `gunRun` return the
impact points too.
**Next:** the in-game look above, then tune the numbers on each row; a real mortar-tube and
cannon clip (the sounds reuse `anvil_blast`, `anvil_incoming` and `lmg_shot` at new pitches).
