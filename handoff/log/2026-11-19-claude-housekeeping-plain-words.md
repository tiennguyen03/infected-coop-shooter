# Housekeeping: plain words, log prune, backlog tidy (Claude, 2026-11-19)

**Changed:** players no longer read NCOIC, the Burn, the net, CONTAINMENT, PLOT COPY or LZ:
the Warden's sighting line, three of the map room officer's lines and one of the Visitor's,
the map room board's title (WHAT WE HOLD), the paper map's stamp, the HUD's extraction line
and the Loadout's "landing zone" hints (`docs/LORE.md` > Naming has the full list). Index,
the Primary and FIRES were already gone from player text. `handoff/log/` pruned to the 12
newest notes; the older check lists still open are in `docs/PLAYTEST_CHECKS.md`.
`docs/BACKLOG.md` "Try it" lists only #86 and #88-#91; Your call 3 closed.
**Verified:** stylua, selene, both rojo builds, 666 Lune tests, luau-lsp on match and lobby.
Text only: not looked at in Studio.
**Heads-up:** Nova: one string each in `PlotService`, `WorldMapData`, `LoadoutMenu`,
`LoadoutUI`, four in `LobbyDesks`. No identifier renamed (desk id `plot`, `PlotService`,
`IndexService`, the `Primary` run state, `Rules/Loadout`'s "away from the LZ" reason key).
PR #87 also edits the top of the backlog: keep the newer side when joining them.
**Next:** new radio lines use the right-hand words of the Naming list.
