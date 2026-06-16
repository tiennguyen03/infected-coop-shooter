# Sprint 13: Full MVP Balance + Fun Test

## 1. Goal
The full operation loop is verified end to end:
spawn → fight → level up → choose items → complete objective → extraction →
OPERATION COMPLETE → restart.

Sprint 13 is a **tuning + fun-test sprint only**. It answers:
- Is a full operation fun start to finish?
- Is the first level-up fast enough (~60-120s)?
- Are 13 items exciting, or too chaotic/snowbally?
- Are Walker / Runner / Brute fair and distinct?
- Is the objective too easy or too hard?
- Is extraction tense (the climax)?
- Does the player want to immediately restart?

Output: filled-in metrics in this doc, config tweaks (values only), and fixes for any
real bugs found. No new systems.

## 2. Do NOT build
- No new features, items, enemies, objectives.
- No operators, supplies, helicopter menu, currency, rewards.
- No new maps, art, assets, audio, animations, cutscenes.
- No refactors. Touch `Config` values only — except a genuine bug fix.

## 3. Three-run playtest plan
Use the DEV TOOLS panel (F1-F9) / DevTestService to speed setup, but record **natural**
play for pacing (don't inject stacks during a pacing run).

- **Run 1 — Baseline (no dev injects):** Play a full operation start to death or
  extraction. Record everything in §4. Note what felt good/bad and any confusion.
- **Run 2 — Tuning:** Apply the smallest config changes suggested by Run 1 (§6). Replay a
  full operation. Compare metrics to Run 1.
- **Run 3 — Verification:** Confirm the tuned values feel stable and repeatable. Confirm
  first level-up ~60-120s, objective + extraction feel right, death feels fair, restart is
  clean (run `VerifyCleanup`). No new changes unless something regressed.

Also run, once, the edge checks: death **during** extraction shows failure (not success);
restart from the success screen is clean.

## 4. Metrics to record (per run)
- Time to first level-up
- Level at 3:00 / at objective start
- Items held at 3:00
- Objective: completed? time taken
- Extraction: reached? held to completion? felt tense (Y/N)
- Outcome: Death or OPERATION COMPLETE
- Total time survived
- Kills
- Level reached
- Items collected
- Cause of death (if died)
- Enemy mix moments: did Runners force movement? did a Brute create a priority moment?
- Fun notes: best moment, worst moment, did you want to restart?
- Any output errors / bugs

## 5. Target pacing (reference)
- First level-up: 60-120s (ideal ~75s)
- By 3:00: level 2-4, 1-3 items, objective appears
- Objective hold: current `Config.Objective.RequiredSeconds` (45s) — keep unless clearly off
- Extraction: reach it, hold `Config.Extraction.HoldDuration` (30s), should feel like the climax
- New-player run length: ~6-10 min; good run 10+ min
- Death should feel earned, not random.

## 6. Balance knobs (Config only)
Tune these; do not add new ones.
- **Weapon:** `Config.Weapon.FireCooldown` (0.1) / `Damage` (6). Keep DPS ratio if you want
  constant time-to-kill.
- **XP pace:** `Config.XP.BaseThreshold` (100), `ThresholdGrowth` (1.25), per-enemy
  `EnemyDefinitions.*.XPReward`.
- **Enemy scaling:** `Config.Difficulty.HealthPerMinute` / `DamagePerMinute` (+ caps),
  `MaxAliveSchedule`, spawn interval.
- **Enemy stats:** `EnemyDefinitions` Walker/Runner/Brute HP/Speed/Damage.
- **Spawn mix:** `Config.Spawning.Phases` weights, Brute caps, Runner ratio.
- **Objective:** `Config.Objective` RequiredSeconds, PressureWave.
- **Extraction:** `Config.Extraction` HoldDuration, PressureWave, SpawnFactor.
- **Items:** per-item tables in `Config.Items` (proc %, durations, caps) — values only.

Rules of thumb: if too easy, raise enemy count/HP or extraction pressure before raising
enemy damage or speed. If too hard, lower spawn rate / enemy damage / hold durations before
nerfing items.

## 7. Bug triage rules
- **Fix now (this sprint):** crashes, output errors, soft-lock, broken
  objective/extraction/restart, an item that does nothing or never stops, cleanup leftovers
  (`VerifyCleanup` fails).
- **Tune (this sprint):** anything that "feels" too strong/weak/fast/slow — config only.
- **Defer (log, don't fix):** polish, missing art/audio, UX nits, new-feature ideas. Add to
  a "Deferred" list at the bottom of this doc.
- Keep fixes minimal and local; re-run static checks (selene + luau-lsp) after any code fix.

## 8. Acceptance criteria
Sprint 13 is complete when:
- 3 full-operation runs recorded with metrics filled in.
- First level-up lands ~60-120s.
- A full operation is winnable AND losable with fair difficulty.
- Each enemy type creates its intended problem (horde / movement / priority).
- Objective and extraction both feel meaningful, not trivial or impossible.
- At least one full OPERATION COMPLETE achieved and one Death, both feeling fair.
- Restart after both success and death is clean (`VerifyCleanup` PASS).
- No output errors.
- Config changes documented (old → new → reason); any bugs fixed + retested.

## 9. Recommended next sprint after Sprint 13
If the MVP loop is fun and stable: a post-MVP feature sprint (e.g. a second objective type,
or stage/biome variety, or operator selection) — chosen based on what the balance test
showed was missing. Do not start it until Sprint 13's runs pass.

## Run results (fill during testing)
### Run 1 — Baseline
### Run 2 — Tuning
### Run 3 — Verification
### Config changes (old → new → reason)
### Bugs found / fixed
### Deferred (do not fix this sprint)
