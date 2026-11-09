# Satisfying Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make shooting and killing the Infected feel heavy: camera kick, blast shake, limp
bodies thrown by the killing hit, hit flinch, low-health feedback, a reload clip, and a
crawl for legless Infected.

**Architecture:** Client-only feel (camera, low health) reads server state (attributes, a
`Blast` tag on blast parts) and never sends anything back. Server feel (ragdoll, flinch,
crawl) hangs off `DamageService.addHitListener` and `EnemyService.onZombieDied`. Every number
in `Config`; every pure calculation in `src/shared/Rules/` with a spec.

**Tech Stack:** Luau (--!strict), Rojo, Lune specs, Blender headless retarget
(`assets/animations/build/retarget.py`), `build_rbxm.luau`, Studio MCP `upload_asset`
(`groupId` 270506601).

**Spec:** approved in chat 2026-11-09 (owner: "yeah go ahead"); summarised in each task.

## Global Constraints

- All tuning in `src/shared/Config.luau`; attribute names in `Attributes.luau`; no inlined
  remote/message strings.
- Server authoritative: clients only render; a client never decides damage or movement.
- Up to 4 players: state per Player or per Infected, never `GetPlayers()[1]`.
- Uploads under the group: `upload_asset` with `groupId` "270506601".
- Mixamo raw FBX and retargeted JSON stay git-ignored.
- Performance (`docs/STYLES.md` §6): at most 8 limp bodies at once; every effect created
  per hit is client-side or capped.
- Do not touch Nova's files: `LoadoutMenu`, `LoadoutUI`, `ArmsRoom`, `Rules/Loadout`,
  `LoadoutService.apply`.

## Review Focus

- Full-auto into one Infected (M249, 750+ rpm): it must not stun-lock (flinch cooldown 0.6 s).
- A body killed mid-climb or on a roof edge goes limp without flying off the map
  (impulse capped, vertical part capped).
- Low health while downed or dead: the effect sits at full and clears on respawn/revive.
- Two blasts in the same frame: shake adds up to a cap, never a huge jump.
- Reload interrupted by a swap (Q) or death: the reload clip stops at once.

---

### Task 1: Rules/Feel (pure maths) + spec

**Files:**
- Create: `src/shared/Rules/Feel.luau`
- Test: `tests/Feel.spec.luau`

**Interfaces:**
- Produces:
  - `Feel.shake(power: number, distance: number, radius: number): number`: amplitude in
    degrees; `power` at distance 0, linear falloff to 0 at `radius`, never negative.
  - `Feel.addShake(current: number, added: number, cap: number): number`: `min(current + added, cap)`.
  - `Feel.lowHealth(fraction: number, start: number): number`: 0 above `start`, 1 at 0
    health, linear between; clamps outside 0..1.
  - `Feel.knockback(kind: string, damage: number, cfg): number`: impulse speed (studs/s)
    for a kill: `cfg.Blast` for kind "Blast", else `min(damage * cfg.PerDamage, cfg.Max)`.
  - `Feel.canFlinch(now: number, lastAt: number?, cooldown: number): boolean`.

- [ ] **Step 1: Write the failing tests:** `shake(10, 0, 40) == 10`, `shake(10, 20, 40) == 5`,
  `shake(10, 50, 40) == 0`; `addShake(4, 5, 6) == 6`; `lowHealth(0.5, 0.35) == 0`,
  `lowHealth(0.175, 0.35) == 0.5`, `lowHealth(-1, 0.35) == 1`; `knockback("Blast", 5, {Blast=60, PerDamage=0.5, Max=30}) == 60`,
  `knockback("Bullet", 100, same) == 30`; `canFlinch(1.0, 0.5, 0.6) == false`,
  `canFlinch(1.2, 0.5, 0.6) == true`, `canFlinch(0, nil, 0.6) == true`.
- [ ] **Step 2:** `lune run tests/run`: FAIL (module missing).
- [ ] **Step 3:** Implement `Rules/Feel.luau`.
- [ ] **Step 4:** `lune run tests/run`: all pass.
- [ ] **Step 5:** Commit with the docs row.

### Task 2: Camera kick + blast shake (client)

**Files:**
- Modify: `src/client/CameraController.luau` (render step adds kick + shake to `rotation`)
- Modify: `src/shared/Config.luau` (`Config.Camera.Kick`, `Config.Camera.Shake`; a `Kick`
  field per gun in `Config.Weapons`)
- Modify: `src/server/AirStrikeService.luau`, `src/server/KitService.luau` and every other
  blast spawner: tag the blast part `Blast` with attribute `BlastPower` (new in `Attributes`)

**Interfaces:**
- Consumes: `Feel.shake`, `Feel.addShake`; `Attributes.LastShotAt` (already stamped per shot).
- Produces: `Config.Weapons[id].Kick = { Pitch: number (deg), Yaw: number (deg, random ±), Recover: number (s) }`.

Values (owner-approved feel, tune in playtest): ServiceRifle (M16A4) Pitch 0.9 Yaw 0.3; Smg (MP5) 0.5/0.2; Lmg (M249)
1.1/0.5; Shotgun (Mossberg) 4.0/0.8; Dmr (M110) 2.6/0.4; Pistol (M17) 1.6/0.3; Recover 0.12 all. ADS multiplies by
`Config.Camera.Kick.AdsScale = 0.6`. Kick is added to pitch and eased back (not a permanent aim
change). Shake: `Config.Camera.Shake = { Radius = 60, Cap = 6, Decay = 0.45, Power = { Frag = 3, Hammer = 3.5, Anvil = 6, Shrike = 2, Tripline = 3 } }`;
the Anvil adds a global 1.0 on top. Shake is a random roll/pitch jitter scaled by the decaying
amplitude.

- [ ] **Step 1:** Add the Config and Attributes entries; tag each blast part.
- [ ] **Step 2:** Kick on `LastShotAt` change; shake on `CollectionService` `Blast` added.
- [ ] **Step 3:** Static checks + types clean.
- [ ] **Step 4:** Playtest: fire each gun, throw a frag at 5 and 50 studs, call an Anvil;
  screenshot; no errors in `get_runtime_logs`.
- [ ] **Step 5:** Commit with docs.

### Task 3: Limp bodies thrown by the killing hit

**Files:**
- Modify: `src/server/EnemyService.luau` (`onZombieDied`, a hit listener storing the last hit
  per Infected: direction, kind, damage)
- Modify: `src/shared/Config.luau`: `Config.Enemies.CorpseLifetime = 4`,
  `Config.Enemies.Ragdoll = { Max = 8, Blast = 60, PerDamage = 0.5, MaxSpeed = 30, MaxUp = 18 }`

**Interfaces:**
- Consumes: `DamageService.addHitListener(HitInfo)`, `Feel.knockback`.

Ragdoll: disable the rig's `AnimationConstraint`s (the `BallSocketConstraint`s already hold
it), stop tracks, `Humanoid:ChangeState(Physics)`, server network owner, impulse along the hit
direction (attacker root → hit position; blasts: centre → root) at `Feel.knockback` speed,
vertical capped at `MaxUp`. Over `Max` live ragdolls: the death clip as today. Bosses never
ragdoll. Dismemberment keeps working (severed parts already leave the rig).

- [ ] **Step 1:** Implement; keep the death-clip path for the overflow.
- [ ] **Step 2:** Checks clean.
- [ ] **Step 3:** Playtest: rifle kill (tips over), Mossberg kill (thrown), frag into 5
  (launched), 12 kills fast (only 8 limp); kill one on a roof edge.
- [ ] **Step 4:** performance-reviewer pass on the diff + MicroProfiler numbers.
- [ ] **Step 5:** Commit with docs.

### Task 4: Hit flinch + legless crawl

**Files:**
- Mixamo: "Zombie Reaction Hit" → `assets/animations/source/mixamo/` (ignored); add
  `zombie_hit` to `retarget.py` `CLIPS` (upper body, no loop); build with `build_rbxm.luau`;
  upload under the group; id in `Config.Animations.Ids` + `ASSET_IDS.md`.
- Modify: `src/shared/Config.luau`: `Config.Animations.Infected.<form>.hit = "zombie_hit"`;
  `Config.Enemies.Flinch = { Cooldown = 0.6, HeadshotSlow = 0.4, HeadshotSlowTime = 0.15, HeavyOnly = { Brute = true }, HeavyWeapons = { Shotgun = true, Dmr = true } }`.
- Modify: `src/server/EnemyService.luau`: on a non-lethal hit, `Feel.canFlinch` → play the hit
  track (headshot: weight 1, speed 1.3, slow); Brute only on blast or `HeavyWeapons`.
  `EnemyService.cripple`: swap the move clip to `zombie_crawl` (already uploaded), lower hip.

- [ ] **Step 1:** Download (owner approved, ask before each download), retarget, build, upload.
- [ ] **Step 2:** Wire flinch + crawl.
- [ ] **Step 3:** Checks clean.
- [ ] **Step 4:** Playtest: M249 burst (flinch at most every 0.6 s), headshot, Brute with M16
  (no flinch) and Mossberg (flinch), shoot a leg off (crawl).
- [ ] **Step 5:** Commit with docs.

### Task 5: Low-health feedback (client)

**Files:**
- Create: `src/client/LowHealthFX.luau` (added to the client `BOOT` list)
- Create: `assets/audio/build/heartbeat.py` (numpy: two low thumps, ~60 Hz body, 1 s loop) →
  `assets/audio/heartbeat.wav` (ignored) → upload under the group → `Config.Audio.LowHealth.HeartbeatId`
- Modify: `src/shared/Config.luau`: `Config.Audio.LowHealth = { Start = 0.35, Saturation = -0.8, Vignette = 0.55, MuffleHz = 900, HeartbeatVolume = 0.8, RateMin = 1.0, RateMax = 1.6, Ease = 0.4 }`

**Interfaces:** Consumes `Feel.lowHealth`. Downed = intensity 1; clears on death screen →
respawn and on revive.

- [ ] **Step 1:** Generate + upload the heartbeat.
- [ ] **Step 2:** `ColorCorrectionEffect` saturation, a vignette `ImageLabel` (generated
  gradient, no new asset), heartbeat loop volume/speed, `EqualizerSoundEffect` on the world
  SoundGroup; all eased by `Ease`.
- [ ] **Step 3:** Checks clean.
- [ ] **Step 4:** Playtest with dev damage to 30%, 10%, downed, healed.
- [ ] **Step 5:** Commit with docs.

### Task 6: Reload clip

**Files:**
- Mixamo: "Reloading" (rifle) → `rifle_reload` in `CLIPS` (upper body); build, upload, id.
- Modify: `src/shared/Config.luau`: `Config.Animations.Player.reload = "rifle_reload"`
- Modify: `src/client/AnimationController.luau`: play on `ReloadUntil` rising, rate =
  clip length / reload time; stop on swap, death, or `ReloadUntil` cleared.

- [ ] **Step 1:** Download, retarget, build, upload.
- [ ] **Step 2:** Wire.
- [ ] **Step 3:** Checks; playtest R with the M16, the M249 and the M17, plus Q mid-reload.
- [ ] **Step 4:** Commit with docs.

### Task 7: Integration

- [ ] Merge, full checks, one playtest of everything together, playtest-critic read of the
  screenshots, handoff + HISTORY + PROGRESSION/STYLES lines, push `hud-p2`.

## Execution

Owner said "go ahead". Native, with two worktree subagents in parallel: Task 1+2 (camera) and
Task 5 (low health) are self-contained client work. The main session does the Mixamo
downloads (browser), Tasks 3, 4, 6, then Task 7.
