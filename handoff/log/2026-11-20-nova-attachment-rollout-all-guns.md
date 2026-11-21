# Every gun on attachment system v2 (Nova + Claude, 2026-11-20)

**Changed:** at the Loadmaster's EDIT, every gun but the Goose now has its slots and rounds:
- MP5 and M110: 7 slots
- M249: 6, with the belt box as its magazine slot
- M2010 and the Fifty: 6, no underbarrel
- M17: 4; S&W 686: 3

Ammo is defined per caliber family: 9mm, 7.62, .50 BMG and .357 are new, plus the M249's
tracer-heavy belt and the M2010's magnum. New refusals: magnum with the light stock, .50 AP with
the short barrel, the suppressed barrel with every muzzle device. Subsonic without a
suppressor is warned about, not refused. The first parts now show on the gun: the vertical
grip, the MP5's flash hider and CompM2, the M110's bipod and the M249's ACOG.

Files:
- `Config.AttachmentsV2` (generated rows), `Config.Weapons.<gun>.Mounts`
- `Shared.Attachments.MountPoints` / `VisualRegistry`
- `Rules/MountPointResolution`, `Rules/GunCompatibility`
- `AttachmentMeshService`, client `Attachments/VisualApplier` + `AttachmentVisuals`
- FirstPersonView (it copies the parts), RecordService (the one-slot optic check skips v2 guns)

**Verified:** the specs came first (`MountPointResolution`, `GunCompatibility`,
`AmmoFamilies`), and all 803 tests pass. Stylua, selene, both builds and both type checks are
clean. **Not seen in Studio:** the mounts are estimates from the meshes' bounds, and the free
meshes' facing and size are unchecked. If none of the meshes load, turn on Allow Loading Third
Party Assets.

**Heads-up:**
- **Stacked on the Mossberg branch, with #96 (the Fifty) merged in.** The conflicts are
  resolved as in the test build.
- **Minimal v2 extensions:** `damageScale`, ammo `compatibleGuns`, `advice`, and a slot's
  `NameFor`. The Ammo slot takes 5 options (the M2010).
- **`tests/gunFixture.luau`:** loads any gun's real rows for specs.

**Next:**
- Tune the mounts in Studio.
- Split the gun meshes in `guns.py`, so barrels, magazines and stocks can show.
- Source the missing models listed in the PR.
