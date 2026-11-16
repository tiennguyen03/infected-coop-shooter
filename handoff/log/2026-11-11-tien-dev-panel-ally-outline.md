# Dev panel v3 and the ally outline (Claude for Tien, 2026-11-11)

**Changed:** the F1 dev panel is tabbed (RUN, PLAYER, INFECTED, GUNS, CALL-INS, UPGRADES,
TELEPORT) with rows for call-ins and Infected forms, lit toggles and a last-command line
(`DevTestPanel`; no server change). Squadmates and bots wear a light outline seen through
walls, yellow while downed (`AllyOutline`, `Config.AllyOutline`).
**Verified:** stylua, selene, both builds, 135 tests, luau-lsp. Not verified: neither has
been seen in a playtest yet (panel layout at small windows; the outline's strength, and that
it returns after a bot streams out and back in).
**Next:** the owner's look in Studio; tune `Config.AllyOutline.Transparency` by eye.
