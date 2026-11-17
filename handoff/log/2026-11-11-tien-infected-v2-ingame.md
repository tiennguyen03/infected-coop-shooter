# Remade Infected in game (Tien's agent, 2026-11-11)

**Changed:** Walker, Runner, Brute and Hocker now wear the remade bodies (owner: "I like the
new zombies, you can just implement those"). Not the Warden. 45 `inf_v2_*` meshes exported
mirrored in X (`build_assets.MIRROR_X_PREFIXES`), uploaded to the group, registered in
`MeshAssets` with ids, sizes and offsets (`ASSET_IDS.md`). `Config.Enemies.BodyVersion`: 2 =
remade, 1 = the first bodies (still uploaded; flip it, no revert). Only the worn set is built
at boot. The Hocker's sac is placed from the limb centre (`MeshAssets.infectedLimbOffset`),
because the new torso's hump moves its bounds. `infected_v2.py` is registered on every build.
**Verified:** headless full build changed only the v2 assets; the v2 FBXs read back mirrored
against the design and the first bodies' do not; all 45 uploads approved, MeshIds and import
sizes read in Studio edit mode; stylua, selene, both rojo builds, 135 Lune specs, luau-lsp
clean. Not checked: anything in a playtest (none was run).
**Heads-up:** needs the owner's eyes in a playtest. (1) Which side the damage is on: it
should be each body's own right (Walker bare arm, leg and open chest, head tilted that way;
Brute bone club and tumour); if it is on the left, the mirror rule does not hold for limb
swaps: empty `MIRROR_X_PREFIXES`, re-export, re-upload. (2) Gore stumps: placed at the R15
joint, unchanged, so they still sit off the Runner's and Brute's hung arms; look at the
Walker's dropped right shoulder too. (3) Hit boxes are the limb bounds and grew (Hocker and
Walker heads, Brute chest and club arm: numbers in `docs/STYLES.md` §7). (4) Scale 0.9 / 2.0
and the sac on the Hocker's new neck. The Walker is more wounded than its first-day sheet, by
owner choice (`docs/CHARACTERS.md`).
**Next:** playtest the four forms; then delete the first bodies' rows if the owner never
flips back.
