# Kill feedback (Tien's agent, 2026-11-10)

**Changed:** the burst where an Infected dies is dark blood instead of green, and the player
who landed the kill hears a soft tick with the red kill marker. The tick is the uploaded
`ui_click` (bank `ui_radio`) pitched up, 2D, only for the killer; several kills in the same
instant share one tick. Files: `HitMarkerUI`, `SoundFX.ui` (optional volume and pitch),
`Config.HitMarker.KillBurst`, `Config.Audio.KillConfirm`, `Rules/Feel.canKillConfirm`.
**Verified:** stylua, selene, both rojo builds, luau-lsp (match and lobby), 136 Lune tests.
Not checked: nothing was seen or heard in a playtest (Studio was in use).
**Heads-up:** no lobby files touched. No new audio was generated or uploaded.
**Next:** play it: is the burst visible on dark ground, is the tick soft enough and clearly
not the menu click, how does it sound on the M249 and on an Anvil into a crowd. Tune
`Config.Audio.KillConfirm` (Volume, Pitch, MinGap); if the click does not fit, add a
`kill_tick` clip to `assets/audio/build/generate.py` and upload a new bank.
