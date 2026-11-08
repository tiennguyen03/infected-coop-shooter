# assets/audio — generated sound effects

Every sound effect is generated from a text prompt by `build/generate.py` with
**Stable Audio Open Small** (Stability AI, 0.5B params, 11 s max, runs on CPU). The prompt
list in that script is the source of truth; the `.wav` files are outputs (gitignored) and the
uploaded Roblox ids live in `ASSET_IDS.md`. Music is out of scope here; this is SFX only.

## One-time setup

1. **Generation runs in Docker**, not on Windows directly: Smart App Control blocks PyTorch's
   unsigned native DLLs (`c10.dll`, WinError 4551) on this machine, so `build/Dockerfile` is a
   CPU-only Linux image with torch + stable-audio-tools. Install Docker Desktop, start it, then
   `build/generate.sh` builds the image on first use (one download of a few GB).
2. The weights are **gated**. Once per machine: make a free Hugging Face account, open
   https://huggingface.co/stabilityai/stable-audio-open-small and accept the license, create a
   read token at https://huggingface.co/settings/tokens, then log in on the host:
   ```bash
   cd assets/audio/build && python -m venv .venv && .venv/Scripts/python.exe -m pip install huggingface_hub
   .venv/Scripts/hf.exe auth login
   ```
   The token is stored in `~/.cache/huggingface/token`, which the container mounts (together
   with the downloaded weights). Never commit or print it.
3. License: Stability AI Community License (free for commercial use below the revenue
   threshold on https://stability.ai/license). Keep this note; Roblox has no AI-audio rule but
   expects you to hold the rights.

## Generate

```bash
bash assets/audio/build/generate.sh             # all sounds
bash assets/audio/build/generate.sh rifle_shot  # some
bash assets/audio/build/generate.sh --list      # print the prompt list
```

Each sound has a fixed seed so a rerun reproduces it; change the seed to get a new take.
Prompts work best as "what makes the sound, where, how close"; the shared negative prompt
keeps music and speech out. On this machine a sound takes about a minute on CPU (the
autoencoder decode dominates, whatever the clip length), so a 46-clip batch is ~45 min.

## Banks (sound day 2026-11-07)

Roblox caps audio uploads per account per month, so variant clips are not uploaded one by
one. `BANKS` in `generate.py` packs each speaker's clips into one
`assets/audio/banks/<bank>.wav` (0.15 s of silence between clips) and writes the clip offsets
to `src/shared/SoundBankData.luau` (generated; never edit it). One upload per bank:

| bank | clips (group = name without `_<n>`) | played by |
|---|---|---|
| `player_steps` | `step_hard_1..4`, `step_soft_1..3` | `client/FootstepController` (surface from `FloorMaterial`) |
| `player_hits` | `bodyshot_1..3`, `headshot_1..2`, `hurt_1..2` | `DamageNumberUI` at the hit point; `EnemyProjectileService.damagePlayer` on the head |
| `walker`, `runner`, `brute`, `hocker` | `<form>_idle`, `_attack`, `_hurt`, `_death` (+ `hocker_windup`, `hocker_spit`) | `EnemyService` → `server/WorldSounds` on the head, 3D, replicated |
| `player_gear` (2026-11-08) | `reload_1..2`, `dry_fire`, `knockdown`, `downed`, `revive`, `roll_1..2`, `breach`, `low_health` (loop), `vault`, `dash` | server on the body: `LoadoutService` (reload, cut by `cancelReload`), `CoverMoveService` (vault/climb → vault, roll/slide → roll), `AssaultClassService` (dash, breach), `Squad` (knockdown, downed, revive); client `WeaponController` (dry fire), `SoundFX` (low health under `Config.Audio.LowHealthFraction`) |
| `callins` | `pallet_land`, `flare_burn` (loop), `callin_throw`, `tripline_arm`, `tripline_blast`, `anvil_incoming`, `anvil_blast`, `pen_coil`, `magpie_hover` (loop) | `RequisitionService`, `CallInService`, `MineService`, `AirStrikeService`, `ShockCoilService`, `DroneService` via `WorldSounds` |
| `warden` | `warden_handset_1..2` (the tell), `_impact`, `_pound`, `_swing`, `_step`, `_plate`, `_roar`, `_canister`, `_death` | `IndexService` via `WorldSounds`; death through `EnemyService` |
| `ui_radio` | `radio_in`, `objective_complete`, `card_pick`, `kia`, `ui_click` | client `SoundFX.ui` (`BuffNoticeUI` radio lines, `ObjectiveUI`, `RunEndUI`); server `card_pick` (`RequisitionService`), `kia` (`Squad`, `WorldSounds.global`) |
| `ambience` | `lantern_rotor`, `amb_city` (loop), `amb_wind` (loop), `amb_siren` (loop) | `ExtractionService` (rotor), `ObjectiveService` (the Gate siren through the hold, silenced when secured), client `SoundFX` (city and wind beds) |

Loops use `SoundBanks.loop` (the playback and loop regions are the clip). Server shapes are in
`server/WorldSounds` (`voice`/`on` a slot on a part, `at` a position, `loopOn`, `global`);
groups in `Config.Audio.FarGroups` carry with the `Far` rolloff.

### Tone rules (sound pass 2026-11-08)

Grounded military, never a monster movie or a game: no zombie groans, no chimes or coins;
electronics are army gear only; the radio is never a voice (text stays text, the squelch
carries it); understated levels. A fifth `SOUNDS` element overrides the negative prompt:
`TAIL` keeps the reverb tail for blasts, the rotor and the ambience beds.

### Sound profiles

`PROFILES` in `generate.py` holds one master description per speaker, appended to every
prompt of its bank so the clips sound like one character. Every boss gets its own bank and
profile (docs/PROGRESSION.md "Boss sound"). Banks generated before profiles existed have
none; add one when the bank is next regenerated and regenerate the whole bank.

`src/shared/SoundBanks.luau` holds the bank ids and the playback: `pick(bank, group)` draws
a random variant that never repeats the previous one; `play(sound, bank, group)` seeks the
Sound to the clip offset and stops it after the clip length. Group volumes and rolloff
distances are in `Config.Audio`. Add a variant = add `<group>_<n>` to `SOUNDS`, list it in
its bank, rerun (`generate.sh <names>` regenerates only those and repacks; `--banks` only
repacks), re-upload that bank, update its id.

Footsteps are synced to the locomotion clips, not to a timer: `FootstepController` reads the
phase of the dominant walk/run track and steps when it crosses a footfall phase in
`Config.Audio.Footsteps.Phases`, measured in Studio from the feet's lowest points (the
measuring script is in handoff/README.md > Studio MCP gotchas). Re-measure if a locomotion
clip changes.

## Upload and wire

1. Upload with the Studio MCP `upload_asset` tool (`assetType: "Audio"`, one call per file)
   or Studio's Asset Manager. Audio uploads are rate-limited per account per month; batch the
   ones that matter first.
2. Record `name → asset id` in `ASSET_IDS.md`.
3. Put the id in `src/client/SoundFX.luau` `DEFINITIONS` (`rbxassetid://<id>`), keep the
   `rbxasset://` built-in as the fallback until the upload is approved. A bank id goes in
   `src/shared/SoundBanks.luau` `IDS`; an empty id keeps that bank silent (no errors).
