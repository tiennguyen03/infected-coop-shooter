# Lobby loadout, hand-off and buying (Nova, 2026-11-10)

**Changed:** The Loadmaster equips: sign for a Loadout (primary, sidearm, grenade, 4 call-ins),
saved per soldier between visits, and it rides the Lantern into the match. The Quartermaster's
rack sells guns for merits (a new soldier has 1000; rifle and pistol free) and hangs every gun as
its real model; the Loadmaster only signs for guns on the record. Lantern spots get a squad-size
picker (lifts 3 s once that many are aboard) and a gradual rotor blur. Files: `LoadmasterService`,
`RecordService`, `SaveSlot`, `LaunchService`, `LoadmasterUI`, `RecordClient`, `ArmsRackUI`,
`LaunchUI`, `LanternSpool`; rules `Record`, `LoadoutSave`, `RotorBlur`, `Manifest.setSquad`.
**Verified:** live in Nova's test experience (ZCS Dev -> Match Dev): launch, two-player launch,
saved Loadouts, rotor blur. Studio: buying, locked Loadout, server refusal of a forged sign, and
in Match Dev a lobby Loadout (mock data) gives the M249 model in hand. Not live-checked yet: the
`Rules/Handoff` launch (re-publish both test places) and buying.
**Heads-up:** `main` is merged into `nova/lobby`. The lobby now sends `Handoff.departure`
(one `ReserveServer` per lift); `JoinData`/`Rules/LaunchData` are gone. Touched in Tien's area:
`HandoffService` reads the trip home from `Places.lobby()` (new `src/shared/Places`,
`Config.Places.Dev` test pairs), and each gun row in `Config.Weapons` has a `Price`
(`WeaponDefinitions.Price`). `LoadoutMenu.mount` takes options (title, hint, confirm, locked).
**Next:** live-check the hand-off and buying; earning merits from runs (systems designer, match
side); the debrief panel (`DebriefUI`); the match's B Arms Room limited to the record.
**Later the same day:** PR #11 (`claude/lobby-reconcile`) merged into `nova/lobby`: Tien's place
ids (live: lobby 87556879379942, match 125769854992316; ZCS Dev pair kept), his hand-off and
rack win; `Places` removed (his `HandoffService.lobbyPlaceId` does it). Buying now covers
grenades and call-ins (merits, Nova's call; `docs/ROADMAP.md` still says Credits: Tien to
confirm): `KitPrices`, `DeskShop`, a `Price` and `Desk` on each call-in row, `Price` on the
sample guns and the frag. Not playtested yet: open ZCS Dev and check Fires, the Engineers,
the Loadmaster's "What do you kick?" and the locked Loadout.
