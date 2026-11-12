# Sights line up on the M249, MP5 and M16 (Nova, 2026-11-11)

**Changed:** on `nova/scopes`, branched from `claude/integration` (779527d: Tien's open PRs
merged, #35's sights among them). Nova ran the sight tour (F10): every gun fine but the M249,
MP5 and M16, where the rear sight sat off to the left of the view. Cause: Roblox shows an
uploaded mesh mirrored left-right about its bounds centre (`build_assets.py`, MIRROR_X_*), and
the guns are uploaded unmirrored, so sights built on the bore show at 2 * offset.X. Measured on
the uploaded meshes with EditableMesh: the front posts sit at M249 -0.086, MP5 -0.040, M16
+0.024, Mossberg -0.050. `MeshAssets.shownPoint` moves a design point to where it shows;
`WeaponDefinitions` applies it to each row's `Sight`, `getMuzzle` to the barrel tip (so shots
still leave the visible barrel). The Mossberg, M2010 and Goose move as well (scoped guns draw a
picture, so it only shows while raising them); M17, revolver, M110 have offset 0.
**Verified:** the resolved points in Match Dev equal the measured ones; stylua, selene, both
builds, 396 tests, types for both places. Not played after the fix.
**Heads-up:** Tien's area: `WeaponDefinitions` (requires `MeshAssets` now), `MeshAssets.getMuzzle`.
A gun drawn by hand elsewhere from design points (a future gun, the rack's hit boxes) needs
`shownPoint` too; or re-export the guns pre-mirrored (add `wpn_` to MIRROR_X_PREFIXES, upload
again, then drop `shownPoint`).
**Next:** Nova replays the tour on the three guns; the scopes.
