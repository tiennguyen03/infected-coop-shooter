# Session log

One short note per work session, so the other developer (and their agent) knows what
changed without reading every commit. Not a diary: 10-20 lines.

**Name:** `YYYY-MM-DD-<who>-<topic>.md` (e.g. `2026-11-09-nova-loadout-screen.md`).

**Write it at the end of a session, in the same commit or PR as the work:**

```markdown
# <topic> (<who>, YYYY-MM-DD)

**Changed:** what now works differently, in player terms first, then the main files.
**Verified:** how (playtest, tests, screenshots), and what was not checked.
**Heads-up:** anything the other developer must know (renamed things, new rules, files you
touched in their area, things half done). Write "none" if none.
**Next:** what you would do next.
```

**Reading:** at the start of a session, read every note newer than your own last one
(`ls handoff/log` sorts by date).

**Pruning:** keep only the newest 12 notes. When you add one past that, delete the oldest
(git keeps it, and `docs/HISTORY.md` has the one-line record). Anything still true and
important belongs in `handoff/README.md` or the feature's doc, not here.
