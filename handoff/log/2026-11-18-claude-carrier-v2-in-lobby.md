# Carrier v2 in the lobby (Claude, 2026-11-18)

**Changed:** the approved Carrier v2 is built into the lobby. `carrier_v2.py export_luau()` writes
`CarrierV2Data` (placements) and `CarrierKitMeshes` (uploaded models); `CarrierV2` places them;
`MeshAssets` gained `modelId` (LoadAsset) and `register`; `upload_models.js` uploads FBX as group
Models through Open Cloud (45 done). `FallowBuilder`: no Plot walls, ramp = wedge + plate (hidden
nook), well rails invisible, flood poles and coast hills not built when v2 is on. `FallowLayout`
and `DeskService`: the Quartermaster at X -26.6, three counters off, old props off; `NpcPose`
seats and leans the sellers. `Config.Lobby.CarrierV2` (Enabled, Poses, RampSplit, FireRate).
**Verified:** stylua, selene, both Rojo builds, both luau-lsp passes, 492 Lune tests. Not seen in
Studio (owner playtesting; Studio tools not used); the poses and text orientation are unseen.
**Heads-up:** Nova: your `FallowBuilder`, `FallowLayout`, `DeskService` and lobby `Main` changed
(all behind `Config.Lobby.CarrierV2.Enabled`). After editing the generator, re-run the export
and `stylua src` (CI checks the generated files' format).
**Next:** a Studio look (doc > In the lobby > What to check), nudge poses, then the idle loops.
