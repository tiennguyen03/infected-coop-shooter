# Sprint 12: Operation Completion V1

## Date
2026-06-12

## Goal
Turn the survival loop into a win-able operation: objective complete → extraction →
hold the extraction zone → OPERATION COMPLETE screen → clean restart.

## What was built (code complete, static checks clean)

### Server
- **ExtractionService** (new) — subscribes to objective completion. On start: spawns a
  glowing green zone at a fixed test location `(-90, 0.6, -90)` (~212 studs from the
  objective at `(60,_,60)`), fires a pressure wave (12 Walker / 4 Runner / 1 Brute),
  sets `ExtractionActive`. Heartbeat accumulates hold time while a player is inside
  (pauses outside, never resets), syncing the UI. On reaching `HoldDuration` (30s):
  marks `Extracted`, freezes the field via `PauseService.setPaused(true)` (which also
  stops spawns and frees the cursor), clears enemies, fires `MissionSuccess`.
- **ObjectiveService** — `complete()` now sets `ObjectiveCompleted`, is idempotent, and
  fires registered `onComplete` listeners (extraction hook). Added `forceComplete()`.
- **EnemyService** — spawn loop applies `Config.Extraction.SpawnFactor` (0.8 = +20%)
  while `ExtractionActive`.
- **RunManager** — `resetRun` also calls `ExtractionService.reset()`; restart is now
  honored when the player is dead **or** `Extracted == true` (so the success-screen
  RESTART works while alive).
- **DevTestService** — `ForceObjectiveComplete`, `ForceMissionSuccess`; VerifyCleanup
  now also fails on a leftover extraction/objective zone or any of the
  ObjectiveCompleted/ExtractionActive/Extracted flags still true.

### Client
- **ExtractionUI** (new) — top-center prompt: available / in-progress / return / complete.
- **MissionSuccessUI** (new) — OPERATION COMPLETE screen (green) with time/kills/level/
  items + Objective Completed: Yes / Extracted: Yes + RESTART.
- **DeathScreenUI** — added `Objective completed: Yes/No` and `Extracted: No` lines.

### Config / Remotes
- `Config.Extraction` (HoldDuration 30, zone size/pos, PressureWave, SpawnFactor).
- Remotes `ExtractionUpdate`, `MissionSuccess`.
- Run state tracked as workspace attributes: `ObjectiveCompleted`, `ExtractionActive`,
  `Extracted` (replicate to client UIs for free; cleared on restart).

## Verification status — VERIFIED 2026-06-12 (after manual Stop → Play)
- Static: selene + luau-lsp strict PASS (0 errors/warnings).
- ForceObjectiveComplete → extraction starts: ExtractionActive=true, zone exists. PASS.
- Mission success (ForceMissionSuccess) → Extracted=true, success path runs. PASS.
- Restart after success → enemies=0 immediately (verified); extraction zone + all run
  flags cleared. VerifyCleanup PASS (the transient "1 enemy" seen once was the new run's
  spawn loop racing a 0.25s wait — 0 at t=0, 1 at 0.2s, 7 at 2s — not a leftover).
- No output errors.

### Root cause of the reported bug
NOT a source bug — the running playtest was executing **stale pre-Sprint-12 code** (the
extraction wiring/`forceObjectiveComplete` weren't present in that session). The
objective→complete()→onComplete→ExtractionService.start chain was correctly wired in
source. Fix = reload via Stop → Play; no code change was required.

## Live test fast-path (run after Stop → Play)
Via DEV TOOLS or MCP eval (`require(game.ServerScriptService.Server.DevTestService)`):
1. `forceObjectiveComplete()` → expect extraction zone at (-90,_,-90), Extraction UI
   "EXTRACTION AVAILABLE", a pressure wave.
2. Walk into the zone → timer climbs ("EXTRACTION IN PROGRESS"); walk out → pauses
   ("RETURN TO EXTRACTION"); re-enter → resumes.
3. Hold 30s (or `forceMissionSuccess()`) → OPERATION COMPLETE screen, enemies frozen.
4. RESTART → fresh run; then `verifyCleanup()` → expect PASS (now also checks extraction
   zone + run-state flags).
5. Death-during-extraction: start extraction, let enemies kill you → K.I.A. screen with
   "Extracted: No", not success.

## Confidence note
Extraction reuses the exact hold-zone pattern already live-verified for the objective
(Sprint 8/9), so behavior is high-confidence; the pending tests are confirmation, not
discovery.

## Known bugs
- None in code. Operational: MCP `stop_playtest` intermittently fails to tear down a
  Studio playtest (environment issue, not game code) — manual Stop required.

## Balance concerns
Extraction tuning is first-pass (30s hold, +20% pressure, 12/4/1 wave). Adjust per the
spec's if-too-easy / if-too-hard table after a real play.

## Recommended next sprint
Per project plan: post-MVP milestones (multiple objectives, stages/biomes, or operators)
— but first do the still-outstanding human balance run for Sprints 8-12.
