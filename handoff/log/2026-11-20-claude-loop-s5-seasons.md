# Loop sprint 5: seasons and Mile 14 cover (Tien + Claude, 2026-11-20)

**Changed:** the city war board starts over every 28 days in a new store (`Config.War`
`StorePrefix` "War_S" + season, `SeasonStart` 2026-11-21, `SeasonDays` 28; `Rules/War.season`,
`storeFor`, `seasonEnds`); `WarService.storeName()` and `ContainmentBoard` read the season's
store; wins, unlocks and kit stay on each record. The Mission Board's header shows the season
and the days left. Mile 14 gets pine clumps and brush in its four fields (`Mile14Data`, seeded
so every server builds the same map, clear of the deck, the county road, the lots, pads and
every objective site).
**Verified:** specs first (`War.spec` seasons, `Mile14.spec` cover count and kept-clear boxes),
928/928, both builds and type checks; live in Studio: the woods on Mile 14, 60 fps, 22 Infected.
**Heads-up:** **Nova:** `ContainmentBoard` reads the season's store; `MissionBoardUI` header.
`Config.War.Store` is gone (now `StorePrefix`).
**Next:** the Driver (owner approval first), the Order reward (save v4), Mile 14's art pass.
