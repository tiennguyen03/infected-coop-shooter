# Mile 14 starts: the place, a first layout, the Infected's awareness (Nova, 2026-11-11)

**Changed:** on `nova/mile14` (from `nova/nvg-flip`). Nova picked Mile 14 (canon: full dark) for
the night map, played quiet: "we go in quiet, do what we have to, if we mess up and it goes loud
then its gonna be rough"; "mainly a highway" with "some wooded areas"; the Infected "sleeping/idle,
wandering, alerted, chase"; noise by gun ("the goose is going to be a lot louder than the
pistol"; map-wide was hyperbole, so the Goose carries 300 studs); a suppressor on every gun with a
barrel but the Goose (and not the revolver: cylinder gap; Nova fine with the plan).
- Place: Mile 14 Dev (128998815119867) on `mile14.project.json` (port 34875), which sets
  `Workspace.Mission = "mile14"`; `Missions.current()` reads it (no attribute: the operation's
  first, Delta).
- Layout: `Missions/Mile14.luau`, first pass of docs/LEVELS.md C1 plus woods (dead trees for now).
- Awareness: `Config.Awareness`, `Shared.Rules.Awareness` (+ `tests/Awareness.spec.luau`),
  `EnemyService` (states, sight, `EnemyService.noise`, the start population, no roaming spawns
  while quiet). Noise from `ProjectileServer` (each gun's `Noise`), `BotService.shoot`,
  `KitService.blast` (Explosion) and running feet; `Attributes.Crouching` from `StanceService`.
  All inert off Mile 14 (Delta plays as before).
**Verified:** stylua, selene, builds, 408 tests, types. Played in Mile 14 Dev: 60 placed (46
still, 12 wandering), a rifle shot at the player sent the two awake bodies inside 110 studs to
look and left sleepers 81+ away asleep; a 1400 test noise brought everyone in.
**Known:** a sleeper is the walk clip frozen mid-stride (wants a slumped pose); no night lighting
yet; dead trees stand in for the woods.
**Then the suppressor** (Nova: at the Loadmaster, "a button next to each gun that says edit"
and a screen of the gun with options per part): `Loadout.attachments` + `Config.Attachments`
(Barrel: suppressor) + `Suppressor` on seven gun rows; `GunsmithUI` in the lobby (the rack's gun
in a viewport, NONE / SUPPRESSOR); the match quiets the shot (noise, volume 0.3, no flash) and
shows the can on the gun. Checked: tests (6 new), types, a lobby playtest screenshot of the EDIT
screen on the M16 with the can on the muzzle (framing tightened after; the replay to see it did
not start). Not played in a match yet.
**Then the woods and the night:** four meshes from `build/trees.py` (Blender headless,
uploaded, ids in ASSET_IDS.md) placed in the woods and along the deck; `Config.NightSky`;
night vision raises the ambient while on. The EDIT screen now frees the mouse itself and closes
on Backspace / Escape (Nova opened my test copy, which had neither). Mile 14 Dev could not move:
its StarterPlayerScripts held a saved `RbxCharacterSounds`, and Roblox never inserted
PlayerModule / PlayerScriptsLoader there; removed, `CharacterAutoLoads` matched to Match Dev,
saved and reopened by Nova: moves now. A place copied this way needs the same check.
**The EDIT screen, checked through the Loadmaster** (Nova: "make sure that the attachment edit
screen works"): the real cause of the dark, dead screen was ZIndex: the Loadmaster's ScreenGui
is Global, the cover (20) sat over the panel (1). Everything in the cover is now lifted above
it. Played: prompt, "Set up my Loadout", EDIT on the Service Rifle, SUPPRESSOR selected (the can
on the gun in the viewport), DONE, signed: `Fitted` = `service_rifle.Barrel=suppressor`.
**Bots spread out** (Nova: "clumped up around the player"): each bot holds its own spot 10-18
studs out in its sector, 9 apart, in the leader's sight, until the leader moves 18 studs
(`Config.Bots.Loose`, `BotBrain.respot` / `spreadSpot` / `spaced`, 8 specs). Played: 13-21 apart.
**Next (the plan's steps):** 2 the suppressor (per gun row, Arms Room pick, muzzle model, quiet
shot sound); 3 the map proper (the Overpass, night sky, living trees, sleepers placed in buses
and booths); 4 going loud (the horn, spawns, Kill the Horn) and quiet objectives with a reward;
5 bots hold fire and carry suppressors.
