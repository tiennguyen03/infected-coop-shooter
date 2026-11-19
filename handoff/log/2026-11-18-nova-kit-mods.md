# Kit Mods at the Loadmaster (Nova, 2026-11-18)

**Changed:** the Loadmaster's screen has LOADOUT | KIT MODS. KIT MODS sells ranked passive
buffs for merits, one rank at a time, kept for good: Extra stim (+1 carried a rank) and Extra
roll (+20 stamina a rank) work; Quicker call-ins and Faster revives are greyed. Files:
`Config.KitMods`, `Shared.KitMods`, `Rules/KitModRules` (spec first), lobby `KitModService`
and `KitModsTab`, match `KitModService`, `LoadoutService`, `SprintController`, `AbilityUI`,
the `KitMods` remote, the `KitRanks` attribute, dev `SetKitRanks`.
**Verified:** 527 Lune tests, stylua, selene, both builds, luau-lsp on both places. Live in ZCS
Dev: the panel (screenshot) and the refusals (disabled, not next, beyond max, short). Not
checked: a bought rank (the dev record has 70 merits and writing test merits to it was not
done), the stims and stamina in a match (Match Dev's Rojo link dropped; reconnect, then
`SetKitRanks`).
**Heads-up:** **for Tien to decide**: it breaks OWNER.md "never stat items" (BACKLOG Your call
13). Ranks are record ids `<mod>@<rank>`. `RecordService` buy is now `change(player, label,
edit)`. The optic test earlier today spent 150 of the ZCS Dev record's merits on the red dot.
**Next:** Tien's call; then wire the two greyed mods (cooldown as a percentage, per the
designer).
