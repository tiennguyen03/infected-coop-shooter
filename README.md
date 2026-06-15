# Roguelike Arena Survivor

A single-player Roblox roguelike: survive endless waves, level up, pick upgrades.
See [docs/PLAN.md](docs/PLAN.md) for the full MVP plan and [CLAUDE.md](CLAUDE.md) for
architecture and conventions.

## Setup (one time)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` in this folder.
2. Open Roblox Studio, create a new **Baseplate** place.
3. Install the Rojo plugin in Studio: `rojo plugin install` (or from the Creator Store).

## Run

1. In this folder: `rojo serve`
2. In Studio: Plugins tab → Rojo → **Connect**
3. Press **Play** (F5).

Controls: WASD move, Space jump, **Shift** sprint, **hold left-click** to shoot (over-the-
shoulder aim at the crosshair, mouse wheel zooms).

The loop: the Infected hunt you and get tougher every minute. Kills drop XP orbs; level
up to pick 1 of 3 items (bleeding rounds, adrenaline, combat drones, supply drops,
airstrikes — they stack). At 3:00 a Hold Position objective appears for bonus XP. Death
ends the run with your stats; RESTART for a fresh one.

## Dev checks

```
selene src     # lint
stylua src     # format
rojo build -o build.rbxlx   # validate project
```
