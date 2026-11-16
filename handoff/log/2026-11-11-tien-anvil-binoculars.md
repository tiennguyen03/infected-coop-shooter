# The Anvil through binoculars (Tien's agent, 2026-11-11)

**Changed:** the Anvil is no longer thrown (owner: "like binoculars and can be called
anywhere within your line of sight"). Its key raises binoculars: the eye goes to the head,
the view narrows behind a black mask with a reticle and a range readout, and a ring on the
ground shows where the shell will land. Left click fires the mission on any ground in the
line of sight up to 400 studs; right click, the key again or any other kit key lowers them.
The 5 s delay, closing ring and shell from the arrivals work follow unchanged, with nothing
thrown. Any call-in can adopt it: `AimMode = "Binoculars"` on its `Config.CallIns` row.
Files: `Rules/Spotting` + spec, `SpotUtil` (the rays, shared by client and server),
`BinocularController` (view, marker, input), `BinocularPose` (arms and prop on every
client), `CallInService` (remote `CallInSpot`, the re-check from the head, `spotFor`),
`CameraController.setScope`, `WeaponController.setBlocked`, `Config.CallIns.Binoculars`.
Stacks on the call-in arrivals branch (PR #18).
**Verified:** stylua, selene, both rojo builds, luau-lsp on both places, 163 Lune tests (15
new for `Rules/Spotting`). **Nothing was run in Studio.**
**Needs an in-game look:**
- The mask: the black bars and the thick stroke leave one clean pill-shaped window at every
  window size; the reticle is centred; the readout does not sit on the HUD.
- The view: 16 degrees is usable (mouse speed scales with it); the body and the gun's view
  model are hidden while up and come back after; first-person mode (T) before and after.
- The mark: the ring sits on the ground under the crosshair, drops to the foot of a wall or
  an Infected, turns grey with the right reason past 400 studs, behind cover and at the sky.
- Fire: no shot goes out on the confirming click; the ring closes on the mark at once (no
  thrown marker, smoke still rises); a mark the server refuses prints `[CallIn] ... mark
  refused` and spends no charge (should not happen for a MARK SET).
- The arms (placeholder, never seen): `Config.CallIns.Binoculars.Pose` (Raise 105, Roll 50,
  Bend 100) and `PropOffset` were worked out on paper for an R15 rig. Check on a teammate and
  on the dressed body: hands near the eyes, binoculars in front of the face, the gun hidden.
- Two players: the other sees the raise and the lower; going down or dying lowers them.
**Heads-up:** `Aim` on a row was already the marker's shape, so the mode is `AimMode`. The
Anvil row lost `ThrowDistance`. Gamepad confirm and cancel keys exist, but no gamepad or
touch control raises a call-in today (the keys 1-4 are keyboard only, as before). Props that
have streamed out on the client do not block its view; the server's check is the one that
counts. Bots carry no call-ins, so `spotFor` has no caller yet. No lobby files touched.
**Next:** the in-game look; a real raise / hold / lower clip (`Config.Animations`) and a
modelled binoculars prop to replace `BinocularPose`'s pose and Parts; decide whether the
soldier should walk slower while they are up; bot call-ins if wanted.
