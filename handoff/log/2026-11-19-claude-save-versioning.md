# Saves versioned and safe to change (Claude, 2026-11-19)

**Changed:** nothing a player sees, unless their save cannot be read: then the lobby shows
SAVE OFFLINE under the wallet and nothing is written that visit. Every per-player save (the
record `r_<UserId>`, the Loadout `u_<UserId>`) goes through `Rules/SaveSchema` (new, spec
first): migrated step by step on read (unversioned saves included), unknown fields kept,
currencies never lowered. `SaveSlot` takes a schema, writes only with UpdateAsync (the
Loadout's SetAsync is gone) and refuses a newer or junk save even mid-visit; one unreadable
slot makes the whole visit read-only (`SaveOffline` attribute). `Record.encode(record, old)`
keeps unknown fields (RecordService, MeritService, KitModRules). `Config.Lobby.Save.LoadWait`.
**Verified:** 687 Lune tests, stylua, selene, both builds, luau-lsp on both places. Not run in
Studio (no MCP this session): the SAVE OFFLINE line's look, a real migration of a live save.
**Heads-up:** new saved fields follow `docs/SAVES.md` > How to change the save. No session lock,
by design (why in the doc). A Robux receipt is not paid on a read-only visit (Roblox retries).
**Next:** play the lobby once with a real save and check merits, kit and Loadout are intact.
