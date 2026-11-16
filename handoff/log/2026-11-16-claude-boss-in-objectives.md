# The Warden inside the main objective (Claude, 2026-11-16)

**Changed:** the Warden no longer comes after the main objective: he comes partway through
it, at its site, and the mission is complete (reward crate, extraction) only when its work
is done and he is down, in either order. Per objective (row `Boss` blocks in
`ObjectiveDefinitions`, defaults `Config.Objectives.Boss`): Sanitize, he comes when the
second tent burns and the last can will not light while he stands at it; Secure the Site and
Restore Comms, the hold stops while he is on it; Confirm Casualties, he comes at half the
heavies; Recover the Record, he hunts the carrier. Code: `Rules/BossAct` (+ spec),
`ObjectiveService` (the act), `IndexService.arrive` / `position`, the four modules'
`context.contested` / `share`, `RunManager` (Primary -> Extract), dev `WardenNow`.
**Verified:** stylua, selene, both rojo builds, Lune tests, luau-lsp, CI. **Not played**
(no Studio this session). Checklist, one run each (`SetMainObjective <id>`, then play or
"Complete hold" / "Warden now"):
- sanitize: burn two tents, he walks in to the third can; its prompt is off while he is
  within 14 studs; pull him away, burn it; HUD reads "Kill the Warden"; kill -> Done line,
  reward crate at the Pens, extraction.
- secure_site: at 22 s he comes; the bar stops while he is in the zone; kill him first ->
  "The Warden is down. Finish the job."; finish the hold -> extraction.
- restore_comms: at 30 s of the hold he comes for the mast; the hold stops within 20 studs.
- confirm_casualties: at half the heavies he comes; kill all -> extraction.
- recover_record: a third of the way he comes and goes for the carrier; drop it, he switches.
- `Config.Objectives.Boss.Enabled = false`: the old order (Gate walk after the objective).
**Heads-up:** `ObjectiveService.onComplete` listeners now get `bossDone`; Objective modules
get `context.contested(point, radius?)` and may return `share()`. The run stays in Primary
while he is up. Merge note for the review-bug branch (#37 freeze, prompt distance): my edits
in `ObjectiveService` are in `finish`, `entryOf`, `stepBoard`'s active branch and new
functions above `finish` / `stepBoard`.
**Next:** play the checklist; time the fight inside each objective (target 100-120 s); the
"Later" list in docs/PROGRESSION.md > The Warden in the main objective.
