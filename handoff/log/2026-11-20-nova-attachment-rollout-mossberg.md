# The Mossberg on attachment system v2 (Nova + Claude, 2026-11-20)

**Changed:** the Mossberg 590's EDIT at the Loadmaster now shows all seven slots, like the M16A4.
The ammo slot holds four shells. Buckshot is the issued one. A slug is one 80-damage ball out
to 200 studs. Dragon's Breath sets each Infected it hits burning, and the burns stack. A
breaching shell opens hut, shed and kiosk walls: two shots, or one with the breaching muzzle.
Slugs and Dragon's Breath are refused through the full choke, and Dragon's Breath with the
suppressed barrel; the menu says why. Stats only. Files: `Config.AttachmentsV2` (`m590_*`,
`ammo_12ga_*`), `Config.DoT`, `Config.WallBreach`, `Config.Weapon.RoundLook`; new
`Rules/DoT`, `Rules/WallBreach`, `BurnService`, `WallBreachService`; `ProjectileServer`
(burn and breach hooks), `WeaponController` (round look), `AttachmentMenuV2` (clash reasons).
**Verified:** specs first (`DoT`, `WallBreach`, `MossbergCompatibility`, `AmmoType12ga`; 761
pass), stylua, selene, both builds and both type checks clean. A performance-reviewer pass:
one light per pull, palette fire, at most 6 flames. **Not played in Studio.**
**Heads-up:** a minimal extension to v2. Ammo rows may now carry `SpreadMultiplier`,
`RecoilMultiplier`, `Burn` and `ClashReasons`. The stat block gained `adsSpread` and
`breachPower`. Config rows become records through `AttachmentMerge.optionFromRow` /
`ammoFromRow` / `opticFromRow` / `gunStats`, shared by `Shared.Attachments` and the specs. The
behaviour enum already had incendiary and breaching. The menu needed no gap fix.
`Sight.spec` lets a v2 gun list an optic with no `Fit` (stats only). The shared red dot row now
lists the shotgun, so one unlock covers both guns. The Fifty's thin-wall overpen (#96) should
read `Config.WallBreach` when it lands.
**Next:** play it (`docs/BACKLOG.md` row); then the MP5 (9mm, subsonic and the suppressor).
