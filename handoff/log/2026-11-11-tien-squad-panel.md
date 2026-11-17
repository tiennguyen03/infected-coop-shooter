# Squad status panel, no floating health bars (Tien + Claude, 2026-11-11)

**Changed:** nothing floats over heads any more: the bar over a hurt Infected, Roblox's
health bar and name tag over players and bots, and Roblox's own top-right health bar are
off. Squadmates' status is a panel on the left edge under the top-left HUD: one row per
other member (player by display name, bot by callsign) with a health bar, the Armour Plate
bar, red when low, "DOWN 23s" on a draining bar, "REVIVING" on a filling blue bar, "DEAD 8s"
greyed (bots; a dead player has no timer); the row flashes on a big hit or a down. Files:
`SquadPanelUI` (new), `Rules/SquadPanel` + spec, `Squad` (publishes
`ReplicatedStorage.SquadRoster`, one entry per member), `BotService` (writes Reviver while
reviving, the respawn time), `PlayerSetup.hideOverhead`, `EnemyService`, `Config.SquadPanel`.
**Verified:** stylua, selene, both rojo builds, 148 Lune tests, luau-lsp (match and lobby).
**Not seen in game** (the owner was playing): check the panel does not overlap the resupply
line or the stamina bar (`Config.SquadPanel.Top`), the rows on a phone, a bot revive, names.
**Heads-up:** a downed player's banner now also names a bot that is reviving them (bots set
Reviver). The Warden's top bar, hit markers and the world markers (OBJECTIVE, EXTRACTION,
crates) are untouched. `Config.SquadPanel.OverheadBars = true` brings every old bar back;
`OverheadNames = true` only Roblox's name tags.
**Next:** squad names on the ally outline (`Highlight`) branch if names in the world are missed.
