# Plan: Pike soldiers, the Arms Room, new guns and call-ins (2026-11-08)

Owner, 2026-11-08: more weapons and a modular menu ("in the future when we have a lobby,
the menu will only be accessed through the lobby"), rework the call-ins with more
Helldivers-style weapons "not too sci-fi", drop Q dash / E breach, "scrap the whole
character idea... just soldiers", and keep the Infected blocky but lore accurate. Owner
approved the designers' recommendations the same day: bots are Pike Two to Four, the Kettle
flamer stays, Hammer = 81 mm mortar, Anvil = 105 mm, Magpie and Pen Coil retire.

Design: `docs/PROGRESSION.md` > Loadout (guns, Arms Room, call-ins, field upgrades). Canon:
`docs/LORE.md` > Pike and `docs/CHARACTERS.md` > C (lore developer).

## Streams (built in parallel, each in its own git worktree, merged by the lead)

| Stream | Owner | Files it owns | Done when |
|---|---|---|---|
| A. Canon | lore developer | `docs/LORE.md`, `docs/CHARACTERS.md` section C, `docs/lore/retired_chosen.md` | Pike canon in, Chosen archived |
| B. Soldier kit + Arms Room | engineer 1 | `WeaponDefinitions`, `Config.Weapon(s)`, `Config.Loadout`, `Config.Grenade`, `ProjectileServer`, `WeaponController`, `LoadoutService`, `Rules/Loadout` + spec, `LoadoutMenu` (new), `AbilityController`, `AssaultClassService` (retired), `UpgradeDefinitions`, `Attributes`/`Messages`/`Remotes` additions, bots' names | five primaries + pistol selectable, Q swap, G frag, V shove, E stim, keys 1-4 call-ins and 5 flare, dash / breach / Momentum gone, Lune tests pass |
| C. Call-ins | engineer 2 | `CallInDefinitions` entries, `Config.CallIns`, `CallInService` dispatch, `AirStrikeService` (Hammer, Anvil, Shrike), `DroneService` (Doorman), Concertina, Speedball, Aid Bag; Magpie and Pen Coil retired | the seven first-pass call-ins work from the dev panel |
| D. Infected accuracy (blocky) | engineer 3 | `build_assets.py` Infected limb functions, their FBX / previews, `MeshAssets` inf rows, `ASSET_IDS.md` | posture fixes per the lore developer's check, uploaded |

Shared-file rule: B owns the slot plumbing (4 slots, keys, attributes); C owns the call-in
roster and services and reads B's slot count from `Config.CallIns.Slots` (4). Both add Config
blocks in their own sections; the lead resolves merge conflicts in docs/HISTORY.md and
handoff/README.md.

## After the merge (lead)

One integrated Studio playtest: the Arms Room, each gun, Q / G / V / E / 1-5, each new
call-in, the Infected bodies, dismemberment still working. Then the satisfying pass:
camera kick and blast shake, corpses 4 s with the killing push, Infected hit flinch.

## Second pass (not in this plan)

Support weapons (Gun, Goose, Thumper, Kettle: carry + explosive projectile hook, F7), the
.357 revolver, Incendiary / Stun grenades, a crawl clip for legless Infected, the Pike body
with seat squares.
