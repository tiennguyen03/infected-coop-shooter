# Night vision goggles flip down (Nova, 2026-11-11)

**Changed:** on `nova/nvg-flip` (from `nova/insertion-cutscene`). Nova: "i want the goggle to
visually flip down". The black FAST helmet's goggles (92700467676199) are baked into its one mesh,
and Roblox refuses to open another creator's mesh (EditableMesh: no permission), so the soldier now
wears the same maker's plain FAST helmet with the NVG mount (127266797794601) and Λstray's PVS-31
goggles as their own accessory (132746703033226), modelled lowered. `Shared.Goggles` finds them by
mesh id when the look is applied (`AvatarLook.apply` / `rig`: lobby, players, bots), records the
modelled frame (`Attributes.GoggleBase`), turns off the accessory's RigidConstraint and drives its
weld about a hinge on the mount: `Config.NightVision.Goggles` Pivot (0, 0.5, -0.76) in head space,
stowed 100 degrees up. N sends the `NightVision` remote; `NightVisionService` sets the character's
`NightVision` attribute; client `NightVision` eases every tagged pair (`NightGoggles`) down or up in
0.35 s (its own at once, others from the attribute). First person already hides the own body.
Also: `InsertionCutscene.setHidden` merged two identical branches; selene failed PR #49's CI on it.
**Verified:** stylua, selene, both builds, 396 tests, types for both places. Lowered and stowed
positions set on a rig in Match Dev with Nova watching ("looks good to me"); not played.
**Next:** Nova playtests N in the match (own view and a bot's look; the lobby soldier wears them
stowed). The night area.
