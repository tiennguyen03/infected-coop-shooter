# Rewards that land, a longer extraction (Tien's agent, 2026-11-10)

**Changed:** you land with about half your spare ammo (M16 30 + 120, was 30 + 240), so the
first pallet is wanted; a pallet still fills you to the old full reserve. When the hold ends a
second FIELD KIT crate lands 10 studs beside the first with three field-upgrade cards: the pick
is made before the Warden arrives. His corpse pallet now shows the supply cards (heal and
re-arm as before). Warden chest plate 500 -> 400. Extraction is 60 s (was 30); at 30 s of hold
a second wave of 12 rings the pad, Control calls it, and spawns quicken (x0.8 -> x0.6). The two
revives and the tourniquet reset per mission. Files: `Config` (`Weapons.*.ReserveStart`,
`Objective.CompleteCrate*`, `Extraction.HoldDuration / Waves / WaveRadio`,
`Index.Warden.Plates.Chest`, `Index.Warden.Drop.Cards`), `ExtractionService`,
`ObjectiveService`, `IndexService`, `Squad`, `EnemyService`, new `Rules/ExtractionWaves`.
**Verified:** stylua, selene, both rojo builds, luau-lsp on both places, 144 Lune tests (9 new
for the wave rule). **Not playtested**: Studio was the owner's.
**Heads-up:** every change has a switch in Config: `Objective.CompleteCrate = ""` and
`Index.Warden.Drop.Cards = "upgrade"` put the cards back on the Warden's pallet; an empty
`Extraction.Waves` removes the second wave. New workspace attribute `ExtractionSpawnFactor`.
Nothing fires `Lifecycle.missionStart` yet, so "per mission" equals "per run" until missions
chain. No lobby files touched.
**Next:** play it: is the first pallet wanted around 1:15, does the second crate read (it has no
radio line), time the Warden fight (target 100-120 s), is wave two too much with 30 alive.
