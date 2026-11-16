# Throws line up with the animation (Tien's agent, 2026-11-11)

**Changed:** the grenade, every thrown call-in and the flare leave the hand when the throw
clip releases, 0.5 s after the key comes up (owner: they "activate before the actual
animation plays"). Before: the client started a 2.77 s clip whose release is at 2.0 s while
the server put the grenade or marker on the mark at once; the flare played no clip. Now the
clip plays from 1.3 s at 1.4x, the server waits the same wind-up and spends the grenade,
charge or pool at the release (downed or knocked down first: nothing thrown, nothing spent),
and the grenade and flare fly from the hand. `docs/PROGRESSION.md` > The soldier (Throwing).
Files: `Rules/ThrowTiming` + spec, `ThrowWindUp` (server), `ThrowFX` (client), remote
`Thrown`, `Config.Animations.Throws` / `ThrowMaxLag`, `Grenade.Flight`,
`Requisition.FlareFlight`, `KitService`, `CallInService.onCallIn`, `RequisitionService`,
`AbilityController`, `AnimationController.playThrow`, `ThrowUtil.hand`.
**Verified:** stylua, selene, both rojo builds, luau-lsp on both places, 154 Lune tests (6
new). **Not played**: no throw has been seen in Studio.
**Needs tuning in a playtest:** `Throws.grenade_throw` Start 1.3 / Release 2.0 / Speed 1.4
(does the hand open as the thing leaves? is 0.5 s too slow under pressure?), `ThrowMaxLag`
0.1, `Grenade.Flight` and `FlareFlight` 0.45, the client's 0.15 s margin between throws.
**Heads-up:** stacked on PR #18 (call-in arrivals). `CallInService.onCallIn` now spends the
charge inside a local `use()` run at the release; a call-in whose Kind is not "throw" still
fires at once (the Anvil's binocular work can use that). No prop in the hand, bots do not
throw, the Warden's Gas Canister was not touched.
**Next:** play it; hold the arm back while aiming so the release is near instant.
