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
**Next (the plan's steps):** 2 the suppressor (per gun row, Arms Room pick, muzzle model, quiet
shot sound); 3 the map proper (the Overpass, night sky, living trees, sleepers placed in buses
and booths); 4 going loud (the horn, spawns, Kill the Horn) and quiet objectives with a reward;
5 bots hold fire and carry suppressors.
