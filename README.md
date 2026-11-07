# Infected Co-op Shooter

Working title. A Roblox 4-player co-op shooter in a grounded military bio-horror setting:
a squad is dropped into a fallen quarantine corridor, holds a position against the
Infected, and gets pulled out before Command burns the district. Power comes from your
loadout and a few big field upgrades, not stat stacking. The current build is
single-player; every system is written for four.

- Current state, open work and dev-env gotchas: [handoff/README.md](handoff/README.md)
- Architecture, conventions and commands: [CLAUDE.md](CLAUDE.md)
- Run structure, stages, bosses, the Infected roster: [docs/PROGRESSION.md](docs/PROGRESSION.md)
- Setting and naming: [docs/LORE.md](docs/LORE.md)
- What shipped, sprint by sprint: [docs/HISTORY.md](docs/HISTORY.md)

## Setup (one time)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Open Roblox Studio, create a new **Baseplate** place.
3. Install the Rojo plugin in Studio: `rojo plugin install` (or from the Creator Store).

## Run

1. In this folder: `rojo serve default.project.json`
2. In Studio: Plugins tab → Rojo → **Connect**
3. Press **Play** (F5).

Controls: WASD move (the body has weight: it speeds up and slows down), **Shift** sprint,
**LeftControl** crouch, **C** prone, **Space** vault or climb cover, **Shift + LeftControl**
roll, **Shift + C** slide, **hold left-click** to shoot (over-the-shoulder aim, mouse wheel
zooms), **Q** dash, **E** breach.

The loop: the Infected hunt you and the pressure climbs on a clock you can read. Kills earn
Resupply; a flare brings a pallet and you walk into 1 of 3 cards. Hold Position when you
are ready, then extract. OPERATION COMPLETE ends the run with your stats; RESTART for a
fresh one.

## Dev checks

```
stylua src                  # format
selene src                  # lint
rojo build -o build.rbxlx   # validate project
```
