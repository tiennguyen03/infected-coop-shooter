# Plain names (Tien's agent, 2026-11-11)

**Changed:** players no longer read coined names for things with a plain word. The Warden's
subtitle lines say WARDEN (was HANDSET; `BossBarUI`). "Lantern" is now "the helicopter" in
sentences and "Helo" on the radio and signs: `ExtractionUI`, `RunEndUI`, `RunManager`'s
can't-lift line, and in the lobby `LaunchUI`, `LaunchService` (deck signs, the failed-lift
message), `WorldMapData` (the pencil track's label), `LobbyDesks` (the Loadmaster is the
"Helicopter crew chief"). The ship already read "the Carrier" everywhere a player looks.
The rule is in `docs/LORE.md` > Naming; the decision in `docs/OWNER.md`.
**Verified:** stylua, selene, both rojo builds, Lune tests, luau-lsp for match and lobby, CI.
Not playtested: strings only.
**Heads-up:** Nova: lobby text changed in the four lobby files above (one string each, two in
`LaunchService`). No file, module, Config key, remote, attribute, instance name or sound key
was renamed (`LanternSpool`, `Config.Lobby.Lantern`, `FallowLayout`, `warden_handset`,
the `Lantern` model and `Fallow` folder all stay). `.claude/agents/*.md` still say Lantern.
**Next:** the owner decides on the other coined names listed in the PR (Index, NCOIC, the
Burn, the Plot, Fires, Speedball, Hocker, Goose).
