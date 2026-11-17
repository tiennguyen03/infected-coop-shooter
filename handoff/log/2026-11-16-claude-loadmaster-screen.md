# Loadmaster screen, bigger with 3D inspect (Claude, 2026-11-16)

**Changed:** the Loadout screen (the Loadmaster's, and the match's B Arms Room, same
`LoadoutMenu`) is about twice the size and fitted to the screen (tabs on a phone). Each row
shows the item's dark shape; hovering, a gamepad's selection or a click shows the item turning
in 3D on the right with its stats as 10-cell bars. Enter or gamepad Y signs. New:
`Shared.Showcase` (server puts look-only models in `ReplicatedStorage.Showcase`, booted in
both places), `Rules/KitCard` + spec, `Config.LoadoutScreen`, `Show` on call-in rows, `Model`
on grenade rows. Layout: `docs/STYLES.md` §5 > The Loadout screen.
**Verified:** stylua, selene, both rojo builds, Lune tests (448), luau-lsp for both places.
**Not seen in game** (no Studio this session).
**Heads-up:** Nova, this is your `LoadoutMenu` and `LoadmasterUI` (hint text only);
`LoadmasterService`, saving and `GunsmithUI` are untouched. Placeholders: Hammer, Anvil and Aid
Bag show a case in their colour, the frag a plain grenade.
**Next:** open it at the Loadmaster: the size at 1080p and in the phone emulator, each gun
turning side on and fully in view, the row shapes (if they show as textured or not at all,
set `RowSilhouettes = false`), the Doorman's three pieces stacked right, gamepad A / Y / L1-R1.
