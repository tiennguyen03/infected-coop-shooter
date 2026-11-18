# The big grey Delta test map (Claude, 2026-11-18)

**Changed:** Checkpoint Delta can be 1,800 x 1,800: today's base in the middle (fence opened at
12 gaps), eight outer areas as grey blocks with a landmark and three story spots each, roads
ringing the base, a river with a ford and two bridges, a flyover. The squad drops at a corner
900+ from the main objective; side objectives sit near the drop and on the way; the pickup is
chosen and called by Control only when the main objective is done. Off by default
(`Config.DeltaXL.Enabled`); dev panel RUN > THE BIG MAP turns it on and restarts the run.
Files: `src/server/DeltaXL.luau` (new), `src/shared/DeltaXLLayout.luau` (new),
`src/shared/Rules/DropPickup.luau` + spec (new), `ObjectiveDefinitions` (`delta_xl`),
`Rules/Objectives` (`Of`), `ObjectiveService` (`prepare`, drop, side plan, pickup),
`RunManager`, `ArenaService` (landing point, fence gaps, `openPerimeter`, `spawnInset`),
`EnemyService` (inset, no spawns in the river), `ExtractionService`, `SkyService` (skyline
south), client `InsertionCutscene`, `DevTestPanel`, `LightsOn`.
**Verified:** 530 Lune tests (DropPickup spec written first), stylua, selene, both builds and
both type checks. Top-down picture from the data: `docs/sprints/images/delta_xl_topdown.svg`.
Not seen in Studio: nothing built has been looked at or walked.
**Check in Studio:** boot with it on reads `[DeltaXL] the big map is built`; no flicker where
roads cross; the ford and the boat ramps get you out of the river; the bridges and flyover
drive with the ATV; houses enter; the cutscene flies to the corner; the pickup line and zone
after the main objective; Lights On at the camp lights the grey posts.
**Heads-up:** the objectives are drawn as the run starts on the big map (Nova: game loop);
today's map is unchanged. Infected spawning for a big map is not done (the doc's What breaks).
**Next:** owner plays it; plan step 3, spawning at scale.
