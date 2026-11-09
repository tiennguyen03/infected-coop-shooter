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
2. Open Roblox Studio, create a new **Baseplate** place. A second developer instead opens their
   own place inside the owner's experience, or every sound and animation is missing: see
   [docs/COLLABORATING.md](docs/COLLABORATING.md).
3. Install the Rojo plugin in Studio: `rojo plugin install` (or from the Creator Store).

## Run

1. In this folder: `rojo serve default.project.json`
2. In Studio: Plugins tab → Rojo → **Connect**
3. Press **Play** (F5).

Controls: WASD move (the body has weight: it speeds up and slows down), **Shift** sprint,
**LeftControl** crouch, **C** prone, **Space** vault or climb cover, **Shift + LeftControl**
roll, **Shift + C** slide, **hold left-click** to shoot, **right-click** aim down sights
(over-the-shoulder camera, mouse wheel zooms), **R** reload, **1** / **2** call-ins, **Q** dash,
**hold E** aim the breach charge and release to throw, **3** Resupply flare, **hold F** revive
a downed squadmate. **F1** opens the dev panel (Studio and the creator only).

The loop: you drop with a squad of four; in solo, three bot squadmates (Cole, Reyes, Cross)
fill it. The Infected hunt you and the pressure climbs on a clock you can read. Kills earn
Resupply; a flare brings a pallet and you walk into 1 of 3 cards. A lethal hit downs you
instead of killing: a squadmate (or a bot) revives you before you bleed out. Hold Position
when you are ready, then extract. The run ends with OPERATION COMPLETE or SQUAD WIPED; READY
for the next one.

## Dev checks

```
stylua src                  # format
selene src                  # lint
rojo build -o build.rbxlx   # validate project
lune run tests/run          # data and cross-file reference tests
```

CI runs all of these plus the luau-lsp type check on every push
(`.github/workflows/checks.yml`).
