# Lobby figures: Rthro walks, a slung gun, crew faces as meshes (Nova, 2026-11-11)

**Changed:** on `nova/lobby-figures` (from `nova/lobby-audio`, itself on `claude/integration`).
Crew and soldier play Roblox's Rthro idle and walk (owner's pick); rates come from the clips'
measured ground speeds (stock walk 14 studs/s, Rthro walk 5.7, run 10.5), the soldier walks the
ship at 10. PikeBody moves the soldier's grip weld onto the upper torso (`Config.Lobby.Soldier.Sling`)
and `SlingHands` puts both palms on the carried gun every frame on every client (grip and
handguard, from the gun itself, so the SMG fits). `crew.py` reshapes the crew head and adds 12
`npc_gear_*` meshes (face, hair crop/parted/buzz/bun with brows, cap, combat and flight helmets,
visor, ear defenders, one-ear headset, glasses), uploaded to the group, worn by NpcBody around
the head's origin and coloured per figure; Fires wears the bun.
**Verified:** the Rthro clips load and drive our rig (Edit mode); a Blender render of seven
heads with their gear; stylua, selene, both builds, 396 tests, types for both places. Not
played: Nova playtests the walks, the sling and the faces.
**Heads-up:** Tien's #31 `SoldierMoves` is rewritten for the lobby (no `SoldierLocomotion` there
now; the match still uses it). `SlingHands` repeats the revive's two-bone IK rather than
reaching into `ReviveAnimation`; one shared module later is worth it. MIRROR_X_PREFIXES gained
`npc_gear_`.
**Next:** tune by eye: `Soldier.Sling`, `Soldier.Hands` (poles, LeftShare), `WalkSpeed`, the
crew's `WalkClipSpeed`.

**Second pass:** Nova liked the soldier's walk but slower, with a sprint on Shift: WalkSpeed 6.5,
SprintSpeed 15 on `Keys.Sprint` / `Soldier.SprintPad` (client sets its own speed; a HoldStill
freeze is left alone). Nova did not like the crew models at all: every NPC is now Roblox's default
R15 avatar, dressed per figure by `NpcBody.Dress` (colours; optional catalog `shirtId`, `pantsId`,
`faceId`, `hats`, `hair`; `ApplyDescriptionAsync`). Removed: `crew.py`, the `npc_crew_*` limb
meshes and the `npc_gear_*` meshes (MeshAssets, ASSET_IDS, exports; the uploads stay in the
group, unused), the block kit. Not played.
