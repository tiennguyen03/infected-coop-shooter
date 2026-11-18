# Objective meter and HUD layout (Claude for Tien, 2026-11-17)

**Changed:** objective progress is a big yellow bar under the objective line with a readout
over it: "HOLDING 23 of 60s" while the hold counts, red "PAUSED" (dim bar, red outline) when
it stops partway, "2 of 3" for counts. It follows whichever objective moved in the last 4 s
(a side objective shows "SIDE  NAME"), else the main one. Side rows in the list have a small
bar. Extraction uses the same meter. The squad panel and objective list no longer overlap
(one left column); radio subtitles flow under the mission line instead of over it; on touch
the insert card flows under them and DOWNED sits lower. Files: `MissionLine`, `ObjectiveUI`,
`ExtractionUI`, `BuffNoticeUI`, `SquadPanelUI`, `HudTheme`, `RunEndUI`, `Rules/Objectives`,
`Config.Hud`, `Config.Objectives.Meter`.
**Verified:** the full check list (format, lint, both builds, 494 tests, both type checks).
Not seen in Studio (the owner was playtesting): no screenshot yet.
**Look at:** Restore Comms: hold E on the set, then stand at the mast (HOLDING, bar moves
each second), step out (PAUSED in red within 2 s), step back. A side objective with a count
(Clear the Spitters): the bar switches to it on a kill, back to the main 4 s later. Solo with
three bots: the squad panel, then the objective list under it, nothing overlapping. A long
Control line wraps under the meter, not over it. Device emulator (phone): the stack at top
centre, the insert card under it, DOWNED under it.
**Heads-up:** `MissionLine.set(owner, { text, sub, detail, progress, readout, paused, color })`
replaces the positional form; `Config.SquadPanel.Top` is gone (`Config.Hud.LeftColumnTop`).
On a very small phone (667 wide) a long mission line can touch a notification card's left end.
**Next:** a screenshot pass at 1920x1080 and a phone in the emulator; tune `Meter.Width`.
