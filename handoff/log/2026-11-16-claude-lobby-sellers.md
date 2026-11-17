# Lobby: one main seller (Claude, 2026-11-16)

**Changed:** the Carrier has three desks. The Quartermaster sells every gun and grenade (as
before); the Engineers desk is now **CALL-INS** (same sapper sergeant, same spot, new lines)
and sells every call-in: Hammer, Anvil, Shrike, Doorman, Tripline, Concertina, Speedball, Aid
Bag; the Loadmaster only signs Loadouts; the Fires desk (figure, counter, dialog) is gone. What
a desk sells comes from the item's row: `Desk = "<LobbyDesks id>"`, or with none
`Config.Lobby.Sellers` (`KitPrices.deskOf`, `KitPrices.only`); the call-in rows' `Desk` lines
were removed (they all take the default). `ArmsRack` / `ArmsRackUI` show only the rack desk's
kit. Prices and saved records unchanged. Lines updated in `LobbyDesks` and its canon copy
`docs/lore/desk_crew.md`; `docs/LORE.md`'s desk list.
**Verified:** stylua, selene, both builds, 440 Lune tests, both type checks. Not seen in game.
**Heads-up:** Nova: desk id `engineers` is now `callins` (`LobbyDesks`, `FallowLayout.Desks`,
`DeskService`); `fires` is gone. `LoadmasterUI` was not touched (another job is changing it):
its `KitPrices.soldAt("loadmaster")` returns nothing now, so its drop panel never shows; its
comment still says the drops are sold there.
**Next:** in Studio: Call-ins lists all eight call-ins with the right prices and BUY works; the
Loadmaster's "What can you drop me?" shows no panel; nothing stands where Fires stood by the
Plot door and the runner walks past it; the rack is unchanged.
