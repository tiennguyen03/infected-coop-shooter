# Handoff: where the project is right now

Shared by everyone who works on the game (Tien, Nova, and each person's coding agent).
**Start of a session:** read this page, then every note in `handoff/log/` newer than your
last one. **End of a session:** edit this page in place (never append history here) and add
one note to `handoff/log/` (format in `handoff/log/README.md`). History lives in
`docs/HISTORY.md`; this page is only "now".

Last updated: 2026-11-09 by Tien + Claude.

## The game today (on `main`)

The full loop works in solo with bots: drop on Checkpoint Delta → fight the Infected →
Resupply flare and pallet cards → Hold Position at the objective site (1 of 3 field
upgrades) → the Warden (boss) → extraction on Lantern → OPERATION COMPLETE → ready up.

- **Squad:** anonymous soldiers Pike One to Four; bots Pike Two to Four in solo; downed and
  revive (hold F).
- **Kit:** six real guns (M16A4, MP5, M249, Mossberg 590, M110, M17) plus three samples in the
  dev panel (S&W 686 revolver, M2010 sniper, the Goose rocket), each with its own Blender model
  and own shot and reload sounds; Q swap, G frag (hold to aim, release to throw), V shove,
  E stim, four call-ins on 1-4 (Hammer, Anvil, Shrike, Doorman, Concertina, Speedball, Aid
  Bag, Tripline; thrown ones are held to aim with an arc and a landing marker, the Shrike is a
  modelled attack helicopter), flare on 5, the Arms Room on B (stand-in until Nova's lobby screen).
- **Infected:** Walker, Runner, Brute, Hocker (blocky, lore poses), dismemberment, the
  Warden with plates.
- **Feel:** camera kick, blast shake, limp bodies thrown by the killing hit, hit flinch,
  low-health grey/heartbeat/muffle, reload clip. Every per-item feel value sits on the gun's
  or call-in's own Config row.
- **Lobby (Nova):** the Carrier (still "the Fallow" in code), `lobby.project.json` +
  `src/lobby/`: hangar desks, the Loadmaster's saved Loadout, Lantern spots that lift a squad
  into one reserved match server (`docs/sprints/LOBBY_V1_FALLOW.md`).
- **Roblox:** the group Boomin Dev Studios (270506601) owns the game "Co-op Zombie Shooter" and
  every sound and animation. Its start place 87556879379942 holds the **lobby**; the match is
  "Checkpoint Delta" 125769854992316 (`Config.Places`).
- **Checks:** stylua, selene, rojo build, 141 Lune tests (rules plus the source-wiring spec, which also reads the lobby's remotes), luau-lsp, CI on every push.

## Who owns what

| Area | Owner | Files (bugs here go to them) |
|---|---|---|
| Lobby place, loadout and weapon selection screens | Nova | `src/lobby/`, `lobby.project.json`, `LoadoutMenu`, `LoadoutUI`, `ArmsRoom`, `Rules/Loadout`, `LoadoutService.apply` |
| Everything else | Tien (+ Claude) | |

Claim work in the table below before starting it; delete the row when it ships.

## Open work, in priority order

The plan beyond this table, in phases, with the owner's open decisions: [docs/ROADMAP.md](../docs/ROADMAP.md).

| # | What | Owner | Notes |
|---|---|---|---|
| 1 | Lobby: debrief panel, the Carrier rename; buying is built on `nova/lobby` (merits, not Credits: Nova 2026-11-10; guns and grenades at the Quartermaster's rack, call-ins at Fires / Engineers / Loadmaster; the Loadmaster signs only for kit on the record), earning merits not yet. 2026-11-10: desk dialog rewritten (four voices, random greetings, the same 3-choice talk at every desk), a gloomy overcast sky, lobby music (licensed library, `LobbyMusic`); the balcony gap closed, the coast burning harder, HARLAN replaces HRD, the Plot's watch officer and paper map, six crew walking the ship, kit on every figure and the Pike's band, chemlight and tourniquet, the five long guns rebuilt and re-uploaded (M16, MP5, M249, Mossberg, M110: tapered stocks, curved magazines, trigger guards; same grip origin and muzzles); the Arms Room fills the port fore corner (glass counter, long-gun wall; rack hover and zoom fixed); the Plot opened up (stand at the map); every NPC is an R15 crew figure; first person in the match on T with arms, gun, reload and real sights on every gun (Nova playtested 2026-11-10: fine, but **some scopes need real work**: the look-through scopes on the M2010, M110 and Goose are a ring and a crosshair with no zoom; next session) (Nova; heads-up Tien: `CameraController`, `FirstPersonView`, `WeaponController` shot origin in first person, `Config.Camera.FirstPerson`). **Models still need work** (Nova, 2026-11-10): every NPC is now an R15 crew body (one plain dress mesh, coloured per figure) but faces and kit are still small blocks, the revolver, M2010, Goose and M17 were not reworked, and the rebuilt guns are unseen in a hand in the match | Nova | `docs/LOBBY_MATCH_HANDOFF.md` > What's next; `docs/ROADMAP.md` (Credits, the Carrier) |
| 2 | Tune the feel by playing it | Tien | kick and shake strength, the low-health look (overlaps HealthBarUI's red pulse), the crawl; heartbeat asset was in moderation |
| 3 | Checklist pass of every call-in and gun | Tien + Claude | dev `FireCallIn <id>`, `SetWeapon <id>`; Gore stumps sit off the Runner/Brute arms; Brute/Walker hitboxes |
| 4 | Mission flow: lobby -> match -> three missions -> lobby | Tien + Claude | Both sides joined up and published 2026-11-09 (`docs/LOBBY_MATCH_HANDOFF.md`; publishing: `docs/STUDIO_MCP.md` > Places and publishing). **Tien:** the live test with a friend. Next on the match: the rest of Delta's facts (F6), the mission-to-mission transition, Mile 14 |
| 5 | Support weapons (Gun, Thumper, Kettle), incendiary + stun grenades | open | the revolver, sniper and Goose are in the Arms Room and on the lobby's rack (2026-11-09); a new gun shows up by having a row with `ArmsOrder`; guns are modelled in Blender (`guns.py`) when no free model is in hand |
| 6 | Performance measurements | open | 2-client network + MicroProfiler during an Anvil into 20, low-end device at low health (`docs/STUDIO_MCP.md`) |
| 7 | Owner calls waiting | Tien | generator to 4.8, light-tower collision as two boxes, movement keys (roll/slide chords) |
| 8 | Objective pools on Delta, then Mile 14 + its boss | open | `docs/PROGRESSION.md` |
| 9 | Warden follow-ups | open | fight length 100-120 s, Gate dressing, insert/wipe radio lines (`docs/sprints/SPRINT_19_WARDEN.md`) |
| 10 | Housekeeping | Tien | rotate the group Open Cloud key (it was pasted in chat); archive the old CZS and "Shooterr" experiences |

## Where to look

- Rules for everyone (humans and agents): `AGENTS.md`. What the owner wants: `docs/OWNER.md`.
- Machine setup and live testing in Studio: `docs/STUDIO_MCP.md`.
- New developer: `onboarding/README.md`.
- Design: `docs/PROGRESSION.md` (run, enemies, loadout), `docs/STYLES.md` (look, budgets),
  `docs/LEVELS.md` (maps), `docs/LORE.md` (setting), `docs/MULTIPLAYER_READINESS.md` (co-op).
