# Wallet readout (Tien's agent, 2026-11-11)

**Changed:** the player sees what they hold: a medal with their merits and a steel tag with
their tabs. On the Carrier it is always on, at the right end of Roblox's top bar, and counts
to the new number when a balance changes (a buy, a pack). In the match it is on the results
screen under "+120 MERITS" ("ON YOUR RECORD"), counting up from the balance before the pay.
Numbers are exact under 10,000, then "12.4k" / "1.2M", rounded down. Files: `Rules/Wallet`
(+ spec), shared `WalletReadout`, lobby `WalletUI` (one line in the lobby's client Main),
`RunEndUI`, `MeritService` (publishes `MeritsHeld` / `TabsHeld`; a GetAsync read when nothing
was paid), `Config.Wallet`, the generator's new `GLYPHS` (`merits`, `tabs`).
**Verified:** stylua, selene, both rojo builds, luau-lsp on both projects, 165 Lune tests
(8 new: Wallet); the glyphs by eye at 16-40 px (`assets/icons/build/glyph_preview.png`,
gitignored: `node assets/icons/build/icons.js merits tabs glyphs`). **Not checked:** nothing
was run in Studio or live. Unseen: the top-bar placement (ScreenInsets TopbarSafeInsets) on
PC and phone, the thumbnails loading, the count-up, the results row.
**Heads-up:** the two decals are uploaded to the group but their image ids were not read
back, so `Config.Wallet` uses `rbxthumb://` of the decal ids; resolving them is one
`game:GetObjects` in Studio (`assets/icons/ASSET_IDS.md`). Nova: `WalletUI` is new in
`src/lobby/client` and booted after `RecordClient`; no other lobby file changed. The rack
and desk panels still print their own "N MERITS  ·  N TABS" lines. `icons.js` no longer
throws without `ItemDefinitions`: it skips the item icons and renders the glyphs.
**Next:** look at it in both places (phone size too), resolve the image ids, then decide
whether the rack and desk balance lines should become this readout.
