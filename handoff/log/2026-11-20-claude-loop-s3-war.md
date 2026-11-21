# Loop sprint 3: the city war goes live (Tien + Claude, 2026-11-20)

**Changed:** one shared board per season for every server (`Config.War`, `Rules/War`, DataStore
`War_S1` key `board`). At a run's end the match adds the mission's points to its district
(Win 3, Partial 1, Loss 0; 2 points = 1%) with one UpdateAsync (`WarService`, called from
`RunManager`); the Infected push back 0.25% an hour; Delta and Mile 14 open from day one, the
next district at 50%; 100% is Secured. The lobby's `ContainmentBoard.read` reads the real board
(the map room panel, every minute, off the main thread now) and publishes it as
`Attributes.WarBoard`; each Mission Board card shows its district's percent and band; the
results screen adds "DELTA +1.5%" (`Attributes.WarLine`), even when merits did not save.
**Verified:** `War.spec` first (13 cases), 892/892, both builds and type checks. Live in Studio:
the results line after a win; the save is refused there (no API access) and gives up at once.
**Heads-up:** **Nova:** `ContainmentBoard` (now the real read; new `layout()` that never
yields), `PlotService.init` builds from `layout()` and reads in a loop, `MissionBoardUI` badges.
Noticed, not mine: the dev "ForceMissionSuccess" during Insert shows the SQUAD WIPED banner.
**Next:** Orders and per-district unlocks (sprint 4); the Driver once the owner approves.
