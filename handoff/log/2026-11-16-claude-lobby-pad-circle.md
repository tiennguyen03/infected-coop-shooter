# Lobby: boarding is the circle (Claude, 2026-11-16)

**Changed:** on the flight deck you board a helicopter by standing anywhere inside the yellow
ring round it (owner: "the area should be within the circle, not a random square"). The tan
square beside the door is gone; the `HELO · SPOT n` sign ("Stand in the circle to board") now
floats over the ring's edge by the door. One number, `Config.Lobby.Launch.BoardRadius` (14),
sizes the painted ring and the server's check (`Manifest.onSpot`, a radius test with a height
limit), so the paint and the rule match exactly. Files: `LaunchService`, `FallowLayout`
(`Spot.board` became `Spot.sign`), `Rules/Manifest`, `FallowBuilder` (the centre line's break
follows the radius), comments in `LanternBird` / `LaunchUI`.
**Verified:** the three new Manifest tests (written first), stylua, selene, both builds, both
type checks. Not seen in game (the owner was playtesting).
**Heads-up:** Nova: your `LaunchService` and `FallowLayout` changed; `BoardHalfSize` is now
`BoardRadius`. The bird's colliders are unchanged (they cover only the cabin, the tail boom and
the fin), so the ring is open floor round it.
**Next:** in Studio: walk into a ring from each side (door side, nose, the far side, under the
tail boom where it crosses the ring) and check the panel appears the moment you cross the
yellow line and clears the moment you step out; check the sign reads from the ramp's top.
