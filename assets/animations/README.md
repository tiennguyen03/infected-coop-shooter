# assets/animations — body animations for the soldier and the Infected

Motion-capture clips from [Mixamo](https://www.mixamo.com) (free with an Adobe account,
licensed for use inside the game, **not for redistribution**: the raw clips and the retargeted
keyframe tables are git-ignored; only the published Roblox animation ids are committed),
retargeted onto the stock R15 rig by a headless Blender script, published as Roblox
animations, played by `src/client/AnimationController.luau` (players) and
`src/server/EnemyService.luau` (the Infected). Clip -> state mapping and ids live in
`Config.Animations`.

## Layout

| Path | What |
|---|---|
| `source/mixamo/*.fbx` | Mixamo downloads, git-ignored. Download settings: FBX Binary, **Without Skin**, 30 fps, no keyframe reduction, **In Place** for every locomotion clip |
| `build/retarget.py` | Blender script: FBX -> `src/shared/AnimationClips/<clip>.json` (git-ignored); per-clip settings in `CLIPS` |
| `src/shared/AnimationClips/*.json` | retargeted keyframe tables; Rojo syncs each as a ModuleScript |
| `src/shared/AnimationBuilder.luau` | clip table -> `KeyframeSequence` (dev only) |
| `src/shared/Animations.luau` | clip name -> animation id: `Config.Animations.Ids`, else a Studio preview id |
| `ASSET_IDS.md` | published animation ids |

## Clips

"Soldier" is the Pike soldier every player and bot plays (`Config.Animations.Assault`).

| Clip (Mixamo name) | Used as | Notes |
|---|---|---|
| rifle_idle (Rifle Idle) | soldier idle | hunched low-ready, scanning |
| loco_walk_f/b/l/r (Rifle 8-Way Locomotion Pack: Run Forward/Backward/Left/Right) | soldier walk, four-way blend | root motion stripped (`in_place`), 13.3 studs/s |
| loco_run_f/b/l/r (Rifle 8-Way Locomotion Pack: Sprint Forward/Backward/Left/Right) | soldier run, four-way blend | root motion stripped, 19.9 studs/s |
| rifle_aiming_idle (Rifle Aiming Idle) | soldier aim, upper body | held while the trigger is down |
| firing_rifle (Firing Rifle) | soldier fire, upper body | 0.27 s recoil per shot |
| hit_reaction (Hit Reaction) | soldier hit, upper body | |
| rifle_reload (Reloading) | soldier reload (R), upper body | rate fits the gun's `ReloadTime`; a gun may name its own `ReloadClip` |
| death_from_the_front (Death From The Front) | soldier death | rig stays jointed on death |
| grenade_throw (Grenade Throw) | soldier throw (G frag, throw call-ins), upper body; the Warden's gas canister | |
| vault_low | soldier vault over jersey / hesco | `root_lock`: the game carries the root (`client/MovementController`) |
| climb_ledge | soldier climb onto bunker / humvee / container | `root_lock` |
| crouch_idle / crouch_enter / crouch_exit | soldier crouch (LeftControl) | transitions rate-scaled to `Config.Player.Stances.TransitionTime` |
| crouch_aim | soldier crouch aim, upper body | |
| crouch_walk_f/b/l/r | soldier crouch walk, four-way blend | root motion stripped, 5.6 studs/s |
| prone_idle / prone_enter / prone_exit | soldier prone (C) | the hips drop inside the clip; the root part stays at hip height |
| prone_fire | soldier prone aim, upper body | |
| prone_walk_f/b | soldier prone crawl, two-way blend (sideways folds into forward) | in place |
| sprint_roll (Sprinting Forward Roll) | soldier roll (sprint + LeftControl) | `in_place` (hip drop kept); 1.17 s, played at `Config.Movement.Roll.Duration` |
| running_slide (Running Slide) | soldier slide (sprint + C) | `in_place` (hips drop 2.2 studs); 1.53 s, played at `Config.Movement.Slide.Duration` |
| downed_crawl (Crawling, hands and knees) | downed crawl (client DownedController, bots hold it still) | `in_place`; 1.8 s loop, rate follows crawl speed, frozen when still |
| knockdown_back (Knocked Out, falling to back) | soldier + bots knocked down: the fall | `in_place`, `trim` (0, 0.45); rate fits the knockdown minus `Config.Knockdown.GetUp` |
| getup_back (Getting Up, from back) | soldier + bots knocked down: the get-up | `in_place`, `trim` (0.55, 1); rate fits `Config.Knockdown.GetUp` |
| ladder_climb (Roblox stock R15 ClimbAnim, `rbxassetid://507765644`) | soldier on a TrussPart ladder | not retargeted (owner: the default is fine); plays in the Humanoid's Climbing state, rate from the vertical speed against `Animations.LadderClipSpeed` |
| zombie_walk (Zombie Walk) | Walker / Hocker move | in place |
| zombie_running (Zombie Running) | Runner move | in place |
| zombie_attack (Zombie Attack) | Walker / Runner attack | |
| zombie_death (Zombie Death) | Infected death | |
| zombie_hit (Zombie Reaction Hit) | Infected flinch on a hit that does not kill, upper body | |
| zombie_crawl (Zombie Crawl) | Infected crawl when a leg is gone (GoreService) | in place |
| climb_low | Walker / Runner over hesco-height cover | `root_lock`; `server/EnemyService` |
| climb_high | Runner onto container-height cover | `root_lock` |
| mutant_walking (Mutant Walking) | Brute move | in place |
| mutant_swiping (Mutant Swiping) | Brute attack | |
| hocker_spit | Hocker attack | generated by Roblox Studio's animation generator, not Mixamo |
| warden_walk | Warden walk | `in_place`, 6 studs/s authored, rate follows ground speed |
| warden_run | Warden charge | `in_place`, 16 studs/s; plays while the root is anchored for the wind-up |
| warden_idle | Warden idle | only while the root is slower than `Config.Index.Warden.IdleSpeed` |
| warden_guard | Warden guard, upper body | held for the guard; `IndexService.cancelGuard` stops it on any action change |
| warden_bash | Warden bash | rate set so the strike lands at `Bash.StrikeAt` of the windup |
| warden_riot | Warden Riot Call roar | held `RiotCallHold` |
| warden_death | Warden death | |
| warden_pound (Sword And Shield Jump Attack) | Warden Ground Pound | `in_place`; the fists land at `Pound.StrikeAt` |
| warden_sweep (Sword And Shield Cross Slash) | Warden Shield Sweep | `in_place`, `Sweep.StrikeAt` |
| warden_slam (Sword And Shield Downward Slash) | Warden Overhead Slam | `in_place`, `Slam.StrikeAt` |
| warden_stomp (Stomp, Hard Floor Stomp) | Warden Stomp | `in_place`, `Stomp.StrikeAt` |
| warden_hit (Sword And Shield Impact, head) | Warden flinch on a plate break | `in_place` |
| spare (published, not wired) | rifle_walk, rifle_run (replaced by the four-way sets), zombie_idle, zombie_stumble, zombie_scream | |

## Pipeline

1. **Download** from Mixamo on the default X Bot with the settings above into
   `source/mixamo/`, file names lower_snake_case (`Rifle Idle.fbx` -> `rifle_idle.fbx`).
2. **Retarget** (about a minute for all clips):
   ```bash
   "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python assets/animations/build/retarget.py
   ```
   Add new clips to `CLIPS` first (`loop`, `step` = keyframe stride, `upper` = upper-body
   overlay, `in_place` = strip horizontal hip travel from a clip with baked root motion; the
   script prints the clip's authored ground speed for `Config.Animations.MoveClipSpeed`;
   `root_lock` = drop every hip translation for a vault/climb clip the game carries itself,
   the script prints the hip rise and reach instead; `trim` = (start, end) fractions of the
   clip to keep, for a long Mixamo clip of which only one part is wanted).
   Mixamo packs download as a zip of FBX files with root motion baked in; copy the ones you
   need into `source/mixamo/` under the clip name and mark them `in_place`. The method: every Mixamo bone's world rotation delta from its rest pose, a fixed
   rest correspondence per R15 limb (Mixamo rests in a T-pose, R15 with the arms down), joint
   transforms = parent^-1 * child, Blender axes -> Roblox axes. Extra Mixamo bones (spine
   chain, shoulders, neck) fold into their neighbours. Hip translation goes on the Root joint.
3. **Preview** in Studio: with `Config.Animations.Ids[clip] == ""`, `Animations.init()` on the
   server registers the retargeted clip through `KeyframeSequenceProvider` and the game plays
   it in a playtest (temporary id, Studio only). Verify every clip this way before publishing.
4. **Publish** (scripted, no clicks; Open Cloud accepts Animation uploads). Without Studio:
   `lune run assets/animations/build/build_rbxm.luau` writes one `.rbxm` per clip, then
   `upload_asset` each with `groupId` 270506601 (the group owns every asset). Or in Studio edit
   mode build every unpublished clip into `ServerStorage.AnimationPublish` with
   `AnimationBuilder.build(AnimationBuilder.loadClip(name))`, export each with the Studio
   MCP `export_rbxm` tool, upload each with `upload_asset` (`assetType = "Animation"`),
   write the ids into `Config.Animations.Ids` and `ASSET_IDS.md`, delete the folder. Ids
   are written with the `rbxassetid://` prefix (a bare number fails to load).
5. **Play**: `AnimationController` (client) and `EnemyService` (server) load clips by name
   through `Animations.load`. The player's walk and run states each blend four directional
   clips by the direction of travel in the body's frame (`AdjustWeight`), so strafing and
   backpedalling read; every locomotion track scales its rate with ground speed against
   `Config.Animations.MoveClipSpeed` so feet do not slide. Stances (crouch, prone) are
   their own idle/move/aim sets with enter/exit clips over the switch
   (`client/StanceController`); a vault or climb plays its clip at the rate that fits
   `Config.Movement.*Duration` while the root is carried over the cover
   (`client/MovementController`, `server/EnemyService`, both through `Shared.Ledge`).

## Why not the Animation Editor / a Blender rig addon

Everything else in the project is generated from scripts; animations follow suit so a clip
can be swapped by changing one table entry and re-running the script. Publishing is
scripted too, through the Open Cloud assets API.
