# The Quartermaster's GTA gun wall back (Nova, 2026-11-18)

**Changed:** "Show me the guns." at the Quartermaster opens the GTA-style rack again (the
camera on his wall and glass counter, hover, click for the card, Q to swap). The desk-screen
change of 2026-11-17 had sent him to the list screen by accident. Call-ins and Vehicles keep
the desk screen. `Config.Lobby.DeskScreen.KeepOwnView = { arms_room = true }`,
`DeskScreen.sells`.
**Verified:** 511 Lune tests, stylua, selene, both builds, luau-lsp. Live in ZCS Dev: the
rack view opens on the wall and counter (screenshot), no errors in the log.
**Heads-up:** Tien: the owner line "every NPC UI like the Loadmaster" still holds for the
other desks; if you want the Quartermaster on the desk screen after all, take `arms_room` off
`KeepOwnView`.
**Next:** check it in ZCS Dev.
