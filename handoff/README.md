# Handoff: where the project is right now

Shared by everyone who works on the game (Tien, Nova, and each person's coding agent).
**Start of a session:** read this page, then every note in `handoff/log/` newer than your
last one. **End of a session:** edit this page in place (never append history here; keep it
under 7k) and add one note to `handoff/log/` (format in `handoff/log/README.md`). What
shipped: `docs/HISTORY.md`. The owner's one page of everything open: [docs/BACKLOG.md](../docs/BACKLOG.md).

Last updated: 2026-11-20 by Nova + Claude (playtest fixes: the saved Loadout on a direct join, the Infected pass through soldiers, on `nova/playtest-fixes`).

## Now

- **The game on `main`:** the full loop works solo with bots: drop on Checkpoint Delta,
  fight the Infected, Resupply pallets, one of five main objectives (two side objectives),
  the Warden as its last act, helicopter extraction, back to the Carrier lobby with merits
  (`docs/PROGRESSION.md`). Two places: the lobby (start place) and Checkpoint Delta
  (`docs/STUDIO_MCP.md` > Places and publishing).
- **Waiting for Tien to play and merge, in this order:** #92 (Integration 5: #86 plus the
  four "make it fun" PRs #88-#91: breaches, scarcity, dangerous Infected, the Warden as a
  boss), then #93 (plain words for players), #94 (saves versioned, `docs/SAVES.md`), then
  this docs trim. What to look at in each: [docs/BACKLOG.md](../docs/BACKLOG.md) > Try it.
- **Built but never seen in Studio:** most of #86 and #88-#91 (the ATV crate, optics, the
  Visitor, Carrier v2 poses and idles, the big grey Delta, every keyed Warden clip). Check
  lists: `docs/PLAYTEST_CHECKS.md` and each PR's `handoff/log/` note.
- **Nova's playtest fixes** (`nova/playtest-fixes`, built on the local merge of #92-#95): a
  Studio match now starts with your Loadmaster Loadout, and Runners no longer shove you or
  lift you on a pile (`docs/PROGRESSION.md` > The Infected roster).
- **Off switches** exist for every new system (`Config.<System>.Enabled = false`); the
  feature's doc names them. Prefer a switch over a revert.
- **Next after #92 is played:** difficulty levels, a four-player test with Nova and friends
  plus a performance check, a first-time player pass (`docs/BACKLOG.md` > Building now).

## Who owns what

| Area | Owner | Files (bugs here go to them) |
|---|---|---|
| Lobby place, loadout and weapon selection screens | Nova | `src/lobby/`, `lobby.project.json`, `LoadoutMenu`, `LoadoutUI`, `KitView`, `ArmsRoom`, `Rules/Loadout`, `LoadoutService.apply` |
| Everything else | Tien (+ Claude) | |

When you change a file in the other person's area, say so under **Heads-up** in your
`handoff/log/` note (the per-PR heads-ups up to 2026-11-19 are in
`docs/history/handoff-2026-11-19.md`).

## Open work

Claim a line before starting it; delete it when it ships. Details live in the linked doc.

| What | Owner | Where |
|---|---|---|
| Lobby: debrief panel, the Carrier rename in code (still "Fallow"), better NPC faces and kit, rework of the revolver, M2010, Goose and M17 models | Nova | `docs/LOBBY_MATCH_HANDOFF.md` > What's next |
| Vehicles: play the ATV, driver's hands, motor sergeant's radio lines, optics for the other guns | Nova + Claude | `docs/PLAYTEST_CHECKS.md` > The ATV; `docs/PROGRESSION.md` > The ATV, Attachments |
| Play #92 and tune: breaches, scarcity, Infected moves, the Warden fight (60-90 s solo) | Tien + Claude | `docs/sprints/FUN_*.md`, `docs/sprints/WARDEN_AGGRESSIVE.md`, their `handoff/log/` notes |
| Play the big map, then spread the Infected for it (plan step 3) | Tien + Claude | `docs/sprints/DELTA_XL.md` |
| Unplayed older work: revive animation, objective meter and HUD, away-review fixes, reward panel, Infected spacing, stamina and slides, objectives and the Warden in them | Tien + Claude | `docs/PLAYTEST_CHECKS.md` (one section each) |
| Checklist pass of every call-in and gun (arrivals, binoculars, throw timing, hitboxes, remade Infected) | Tien + Claude | `docs/PLAYTEST_CHECKS.md`; dev `FireCallIn <id>`, `SetWeapon <id>` |
| Mission flow: lobby, three missions, back; the live test with a friend; Mile 14 | Tien + Claude | `docs/LOBBY_MATCH_HANDOFF.md` |
| Objectives: Open the Gate, the unbuilt side objectives, dev panel buttons for the new commands | Tien + Claude | `docs/PROGRESSION.md` > Objective pools |
| Support weapons (Gun, Thumper, Kettle), incendiary and stun grenades | open | `docs/PROGRESSION.md`; a new gun appears by having a row with `ArmsOrder` |
| Performance: 2-client network + MicroProfiler during an Anvil into 20 | open | `docs/STUDIO_MCP.md` |
| Rotate the group Open Cloud key; archive the old CZS and "Shooterr" experiences | Tien | `docs/BACKLOG.md` > Only you can do |

## Checks

After every change, all clean (exact commands: `AGENTS.md` > Commands): stylua, selene, both
Rojo builds, 687 Lune tests (rules plus the source-wiring spec, which also reads the lobby's
remotes and refuses key literals), luau-lsp on both places. CI runs the same on every push.

## Where to look

Rules: `AGENTS.md`. What the owner wants: `docs/OWNER.md` (keys table, names players read).
Studio setup and live testing: `docs/STUDIO_MCP.md`. New developer: `onboarding/README.md`.
Design: `docs/PROGRESSION.md`, `docs/STYLES.md`, `docs/LEVELS.md`, `docs/LORE.md`,
`docs/MULTIPLAYER_READINESS.md`, `docs/SAVES.md`. Read only the section you need.
