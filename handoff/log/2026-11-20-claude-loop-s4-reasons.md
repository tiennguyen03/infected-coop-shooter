# Loop sprint 4: reasons to pick a mission (Tien + Claude, 2026-11-20)

**Changed:** a catalog row's `Pay` (Mile 14: Win 140, Partial 70), a Secured district pays
x0.25 (`Economy.payFor`). HARLAN Orders: rows in `Config.War.Orders` with a window
(`Rules/Orders`): the order's card is gold and tagged ORDER, its words under the officer's
line, +25% merits on its district (`Economy.boosted`). The record counts wins per district
(`wins`, **save version 3**, `SaveSchema` step 2 -> 3, written by `MeritService` in the pay's
UpdateAsync). Item rows may carry `Unlock = { District, Wins }` (`Rules/DistrictUnlock`):
`RecordService` refuses the buy with "locked" until met; the rack, the shop list and the call-in
display say "Win 3 missions at MILE 14 first." First two: M2010 (3 Mile 14 wins), M249 (3 Delta).
**Verified:** specs first for `payFor`, `boosted`, `Orders`, `DistrictUnlock`, save v3 (old
version-pinned Record specs now read `Record.VERSION`); 919/919, both builds and type checks.
**Heads-up:** **Nova:** the record has `wins` now (RecordClient fills `wins = {}`; the shop's
gate is on the server); `RecordService.buy` checks `DistrictUnlock`; `DeskShop`, `ArmsRackUI`,
`CallInDisplayUI` show the "locked" line; `MissionBoardUI` shows the Order. Attachment options
could take the same `Unlock` field through your `AttachmentUnlock` (not done). **Publish the
lobby and the match together** (save v3: an old server reads a v3 record as newer, read-only).
**Next:** the merits for everyone when an Order is reached; seasons (sprint 5); the Driver.
