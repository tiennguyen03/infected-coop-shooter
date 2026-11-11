# Rewards picked from a panel (Tien's agent, 2026-11-11)

**Changed:** nothing is picked by walking over it any more (owner: the world cards were "so
small to read ... sometimes you pick the wrong item"). Every crate has one label and a
prompt: within 9 studs hold F 0.3 s (gamepad X, tap on touch) and a panel of up to three
big cards opens; pick with a click or tap, keys 1-3 or the gamepad. F, Backspace, B, a click
beside the cards or walking off closes it without a pick. The game does not pause. The hold's
end now drops an OBJECTIVE REWARD crate: the whole squad is restocked as it lands (health,
ammo, call-ins, grenades, stims, +50 armour) and each player picks a field upgrade. Upgrade
offers prefer an empty slot, say "REPLACES ..." when they would push one out, and are filled
with supply cards when short. Armour Plate 50 -> 75. Bots take a Medkit from a pallet when
below 75% health. Files: new `Rules/Reward` + spec, new `client/RewardPanel`,
`RequisitionService`, `ResupplyUI`, `LoadoutService` (offer roll, `replacedBy`),
`UpgradeDefinitions` (text from Config, `Tag`), `Config.Requisition.Pick`, `Config.Crates`.
**Verified:** stylua, selene, both rojo builds, luau-lsp on both places, 162 Lune tests (18
new). **Not playtested**: Studio was the owner's.
**Heads-up:** stacked on `claude/rewards-extraction` (#15). `RequisitionService.dropCrate`
keeps its signature; the kind may now also be `"objective"`. `Config.Crates.ArmourPlate` is
now `Crates.Cards.armour_plate.Plate`; `Requisition.CardLifetime` is `Crates.Kinds.*.Lifetime`.
`LoadoutService.availableUpgrades` is gone (no callers). New `Resupply` message kinds
`refused` and `taken`; new attribute `CrateId`. The pick key is F, not E (E is the stim).
`Requisition.Pick.WalkOver = true` restores the old world cards. Dev: "Drop objective reward".
**Next:** play it: panel size during a fight (`Pick.PanelScale`, `Pick.Dim`), whether the full
call-in restock before the Warden is too much (`Crates.Kinds.objective.Squad`), the open
questions in the PR.
