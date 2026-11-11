# Ship sounds on the Carrier (Nova, 2026-11-11)

**Changed:** on `nova/lobby-audio` (from main). Nova asked for "noises that one would hear on a
boat. people moving around, crew mumbling". `ShipAmbience` (lobby client) plays nine Pro Sound
Effects clips from Roblox's audio library (real aircraft-carrier recordings and crew walla;
licensed for any experience), all in `Config.Lobby.Ambience`: a bed per area (hangar: carrier
hallway; deck: motor, wind, water) cross-faded by the soldier's height, since Roblox sound goes
through walls; loops at anchors (`FallowLayout.Ambience`, built into `Fallow.Ambience` by
FallowBuilder): the bridge's radio chatter in the Plot, crew walla by the desks and aft; a door,
lockers, latches or a horn every 9 to 22 s, the deck PA on deck. The walking crew's boots use the
match's Footsteps bank (`CrewWalk`). One `Ambience` SoundGroup fades in on arrival and out with
the music on lift.
**Verified:** all nine clips load in ZCS Dev (PreloadAsync: Success); stylua, selene, both
builds, 135 tests, types for both places. Not heard: picked by description.
**Heads-up:** `CrewWalk` now requires `SoundBanks` (shared). The player's own footsteps on the ship
are still muted (`DefaultStepMute`; Tien's #31 leaves them so).
**Next:** Nova listens and says what is too loud, harsh or missing; volumes are per row.
