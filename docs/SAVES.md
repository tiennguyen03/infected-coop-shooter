# Saves

What the game keeps about each player between visits, and the steps to change it. Read this
before adding or renaming any saved field. The code: `src/shared/Rules/SaveSchema.luau`
(versions and migrations, tested in `tests/SaveSchema.spec.luau`), `src/lobby/server/SaveSlot.luau`
(the lobby's reads and writes), `src/server/MeritService.luau` (the match's writes).

## What is saved

| Save | DataStore (Config) | Key | Version | Fields | Written by |
|---|---|---|---|---|---|
| The record | `Config.Lobby.Save.RecordStore` (`PikeRecords`) | `r_<UserId>` | 3 (`SaveSchema.Record`) | `merits`, `owned` (kit, optics, Kit Mod ranks `<mod>@<rank>`), `tabs`, `receipts`, `wins` (missions won per district, `"MILE 14" = 3`) | lobby `RecordService` (buys, Robux receipts), match `MeritService` (mission pay and the win, one UpdateAsync) |
| The signed Loadout | `Config.Lobby.Save.Store` (`LoadmasterLoadouts`) | `u_<UserId>` | 1 (`SaveSchema.Loadout`) | `loadout` (`Rules/Loadout` shape, with `attachments`) | lobby `LoadmasterService` only |
| Carrier counts | `Config.Lobby.Tallies.Store` | one shared key | none (not per player) | counts by `kind:id`, only ever added to (`Rules/Tally.merge`) | match `TallyService`; the lobby only reads |

| The city war board | `Config.War.Store` (`War_S1`, one season) | `board` | `Rules/War.VERSION` 1 | per district `pct`, `at`, `unlocked`, `secured` | match `WarService` (UpdateAsync at run end, never from Studio); the lobby only reads |
Retries and timings: `Config.Lobby.Save` (`Retries`, `RetryDelay`, `MinWriteGap`,
`LoadWait`), `Config.Merits` (`Retries`, `RetryDelay`, `SettleSeconds`), `Config.Lobby.Tallies`.

Version history. Record: 0 = no `version` field (merits, owned), 1 = merits and kit, 2 adds
`tabs` and `receipts`, 3 adds `wins` (loop sprint 4). **Version 3: publish the lobby and the match
together.** An old server reads a v3 record as newer and goes read-only for that soldier (a buy
there is not saved, a pay there is dropped) until it is replaced. Loadout: 0 = no `version` (a bare Loadout, or `{ loadout }`), 1 =
`{ version, loadout }`.

## The rules every save follows

1. **Migrate on read.** A stored save goes through `SaveSchema.read`: every step from its
   version up to the current one runs in order, so any older save (one with no version too)
   comes out in today's shape. It answers `"empty"` (no save yet), `"ok"`, `"newer"` or
   `"junk"`.
2. **Write only with UpdateAsync, onto what is stored.** Every write reads the stored value at
   that moment, checks it may be written over (`SaveSchema.writable`), and changes it. The
   record's changes are deltas (pay +N merits, buy one item) applied to the stored record,
   never the copy read on join. `Record.encode(record, old)` and `SaveSchema.over` keep every
   field this code does not know.
3. **Never write over a save we could not read.** If the load fails, or the stored save is
   `"newer"` (written by newer code during a rollout) or `"junk"`, the visit is read-only:
   nothing is written for that player in any slot (`SaveSlot.isReadOnly`), the
   `SaveOffline` attribute is set and the lobby shows "SAVE OFFLINE" under the wallet
   (`WalletUI`). The player can still play and buy for the visit; none of it is kept. A
   Robux receipt is not paid on a read-only visit; Roblox offers it again on the next join.
   The match never loads to write: its pay is a guarded UpdateAsync, so a newer save is left
   alone and the results screen shows the pay as not saved (`MeritsEarned = -1`).
4. **Migration never lowers a currency** and never drops a field. Steps only add or rename.

## Why there is no session lock

A session lock stops two servers writing the same player from stale copies. Here no server
ever writes a stale copy: every record write is an UpdateAsync step applied to the stored
value (Roblox runs these one after another per key and retries on a clash), so the lobby's buy
and the match's pay landing at the same time both count. The Loadout is written only by the
lobby, and a player is in one lobby at a time; at worst a lobby the player just left flushes
their last pick after the next lobby read the one before, and the newest pick still wins. A
lock would add a new way to lose a visit (a lock left behind by a crashed server, a teleport
landing before the lock is released) for no gain. Add one only if a save ever holds state a
server keeps in memory and writes back whole.

## How to change the save (every new saved field)

1. **Decide the default** an old save gets for the new field (0, an empty list, false). It
   must never take anything away from the player.
2. **Bump the version** in `SaveSchema.luau` (`SaveSchema.Record.version = 3`) and add one
   step at the end of `steps`: it takes a version 2 save and returns it with the new field
   (`if save.medals == nil then save.medals = {} end`). Keep a value that is already there.
   Never edit an old step.
3. **Spec first** in `tests/SaveSchema.spec.luau`: a version 2 save reads with the default; a
   v0 save still reads; currencies are not lowered; unknown fields are kept.
4. **Carry the field** through `Rules/Record` (the type, `new`, `decode`, `encode`) or
   `Rules/LoadoutSave`.
5. **Write it only through UpdateAsync** steps like the existing ones (`RecordService.change`,
   `MeritService.credit`). Never SetAsync a player's save.
6. **Publish order:** a server running the old code reads the new save as `"newer"` and goes
   read-only for that player (it does not wipe it). Publish both places together (lobby and
   match) so the read-only window is short.
7. Update the table at the top of this page.

Renaming or removing a field is a step too: copy the old field into the new one (keep the old
one unless it is wrong to keep it). A field is never deleted to save space.
