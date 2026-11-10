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
- **Roblox:** the group Boomin Dev Studios (270506601) owns the game "Co-op Zombie Shooter"
  (place 87556879379942) and every sound and animation.
- **Checks:** stylua, selene, rojo build, 58 Lune tests, luau-lsp, CI on every push.

## Who owns what

| Area | Owner | Files (bugs here go to them) |
|---|---|---|
| Lobby place, loadout and weapon selection screens | Nova | `LoadoutMenu`, `LoadoutUI`, `ArmsRoom`, `Rules/Loadout`, `LoadoutService.apply`, the lobby project file |
| Everything else | Tien (+ Claude) | |

Claim work in the table below before starting it; delete the row when it ships.

## Open work, in priority order

| # | What | Owner | Notes |
|---|---|---|---|
| 1 | Lobby + loadout screen | Nova | `docs/MULTIPLAYER_READINESS.md` decision 7; items read their own definition rows |
| 2 | Tune the feel by playing it | Tien | kick and shake strength, the low-health look (overlaps HealthBarUI's red pulse), the crawl; heartbeat asset was in moderation |
| 3 | Checklist pass of every call-in and gun | Tien + Claude | dev `FireCallIn <id>`, `SetWeapon <id>`; Gore stumps sit off the Runner/Brute arms; Brute/Walker hitboxes |
| 4 | Mission flow: lobby -> match -> three missions -> lobby | Tien + Claude; Nova (lobby side) | `docs/LOBBY_MATCH_HANDOFF.md` > "What each of us does next". Match side built 2026-11-09: staging, the lobby loadout per player, the trip home (`HandoffService`). **Tien:** publish the lobby inside the experience and send its id (`Config.Places.Lobby`). **Nova:** merge main, send `Handoff.departure`, reserve once per lift, a debrief panel. Then the live test. Next on the match: the rest of Delta's facts (F6), the mission-to-mission transition, Mile 14 |
| 5 | Sample guns into the Arms Room; support weapons (Gun, Thumper, Kettle), incendiary + stun grenades | Nova / open | the revolver, sniper and Goose rows exist (`docs/sprints/SPRINT_21_SAMPLE_GUNS.md`), not in `PRIMARIES` / `SECONDARIES` yet; guns are modelled in Blender (`guns.py`) when no free model is in hand |
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
