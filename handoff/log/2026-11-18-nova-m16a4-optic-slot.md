# M16A4 optic slot (Nova, 2026-11-18)

**Changed:** the Loadmaster's EDIT on the M16A4 has an Optic slot: Red dot (150), CompM2 2x
(250), ACOG 4x (400), bought once with merits and kept for good, each LOCKED / OWNED / EQUIPPED
with "X/3 OPTICS UNLOCKED". In a match the optic changes the zoom and the time into the sights.
Files: `Config.Optics`, `Shared.Attachments.Optics`, `Rules/AttachmentRules` and
`Rules/AttachmentMerge` (specs first), lobby `OpticService`, `GunsmithUI`, `CameraController`,
the `Optic` remote.
**Verified:** 511 Lune tests, stylua, selene, both builds, luau-lsp on both places. Live in ZCS
Dev: buy, buy again (owned), buy short, fit unowned, fit on the SMG, fit; screenshot of the
menu. Match Dev boots clean with an ACOG fitted. Not checked: aiming through each optic in a
match.
**Heads-up:** the optics are not drawn on the gun: the free models (CC-BY, notcplkerry on
Sketchfab) need a logged-in download (`assets/3d/ASSET_IDS.md` > Optics). `RecordService.buy`
is now `purchase(player, id, priceOf)` with `RecordService.buyWith` for optics;
`RecordService.allows` also checks optics; `LoadmasterService.fit` signs one slot.
**Next:** download the two models, fit them on the M16 with the sight line on the optic, then
the slot for the other guns.
