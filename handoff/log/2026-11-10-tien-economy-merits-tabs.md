# Economy: merits and tabs (Tien's agent, 2026-11-10)

**Changed:** a mission now pays merits. When it ends, every real player in the server (dead
or alive, no bots) gets Win 120 / Partial 60 / Loss 0, saved onto the same record the
Carrier's desks spend from, and the results screen shows "+120 MERITS". The record also holds
**tabs**, the hard currency (Robux or events, never power): shown next to merits at the rack
and the desks, nothing to buy with them yet. Files: `Rules/Record` (version 2: `tabs`,
`receipts`, `earn`, `grantTabs`, `spendTabs`, `grantReceipt`, `canUpdate`, `key`),
`Rules/Economy` (new), `src/server/MeritService` (new), `RunManager.endRun` / `goHome`,
`RunEndUI`, `Config.Merits`, `Config.Tabs`, attribute `MeritsEarned`.
**Verified:** stylua, selene, both rojo builds, luau-lsp on both projects, 157 Lune tests
(22 new: Record, Economy). **Not checked:** nothing was run in Studio or live: the merits
line on the results screen, the "N MERITS  ·  N TABS" lines on the Carrier, a real DataStore
write from the match, the trip home reading the paid record, and a real Robux receipt (no
product exists).
**Heads-up (Nova, your files):** `RecordService` sends tabs as a 4th value on `Record`
"state", uses `Record.KEY_PREFIX`, and gained `grantReceipt`; `SaveSlot` gained `update`
(UpdateAsync); `TabsService` is new and in the lobby BOOT list; `RecordClient` gained `tabs()`
and `balanceText()`; one balance line each in `ArmsRackUI` and `DeskShop`. One thing to look
at: when a record fails to **load** (a DataStore error on join), `RecordService` holds a
fresh 1000-merit record and the next buy saves it over the real one. That now costs earned
merits and paid tabs; a failed load should block saving for that soldier.
**Next:** Secondaries counted in the match (they pay 0 until then), the Stand Down bonus,
the Roblox products and a place to buy a pack, the first thing sold for tabs (owner's call),
Nova's debrief panel can show the merits line.
