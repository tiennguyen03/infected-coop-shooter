# Away-review fixes (Claude, 2026-11-16)

**Changed:** the defects the away reviews (`docs/reviews/away-2026-11/` on
`origin/claude/away-reviews`) found, checked against `main` at 3d97982, smallest fix each:
- #16 (Nova's lobby): a buy is applied to the stored record with `UpdateAsync`
  (`RecordService.buy` -> `SaveSlot.update` -> `Rules/Record.buyStored`), never by writing the
  copy read on join over it, so merits paid after joining survive and a save the lobby cannot
  read (junk, a newer version) is left alone (also on load, `unread`). Receipts no longer
  re-save the held copy. One buy at a time per soldier. Studio without API access, or an
  unread record, still buys on the held copy only (unchanged).
- #32: a merit save that returns after READY restarted the run is not shown on the new run.
- #22: a bot's frag / fire mission is refused when a player or another bot is on its throw
  line (the ray skips only what the real throw skips).
- #23: the spacing ring uses the ground reach left after the height gap (`Spacing.flatReach`),
  so a Brute stands close enough to hit a prone player.
- #27: the Hocker's head tilt works on AnimationConstraint necks; a direct hit on a body draws
  the ground pool, no blotch in the air.
- #28: a knockdown lowers the Anvil binoculars (client), and the server lowers them on a
  refused call-in.
- #33: "REVIVING" cleared when a reviving bot is removed, knocked over or dodging.
- #36: a field-upgrade pick is refused (not wasted) when already held, or when it would now
  replace something its card did not show (two crates open at once).
- #37: an objective that errors while built or begun no longer stalls the mission (a broken main
  counts as done when reached); objective prompts check the body is at the prompt, the run is
  live and not paused (`Config.Objectives.PromptSlack`).
- #49: skipping the cutscene tells the server (`InsertSkip`); when every player has skipped (or
  had nothing to watch) the brief comes at once and the landing after `Run.InsertSeconds`. Any
  error, or a cutscene still up `Insertion.FailsafeSeconds` after it should have ended, gives
  back the view, HUD and controls.
- #52: the sight filter only grows on awareness missions and empties each run; bots only take a
  loose spot with floor under it (`Bots.Loose.MaxDrop`); Mile 14 places 30 (was 70), a few a
  frame, never past the 44 alive cap; TODO in `Missions/Mile14.luau` for its own objective,
  Warden and LZ positions.
- #20 outline back after streaming; #21 a downed or knocked slide ends, C / Ctrl do nothing with
  Shift held; #25 flare key waits out the flare cooldown (`ResupplyFlareCooling`); #30 the last
  two "Index" radio lines say the Warden; #31 lobby waits for `Animate` before retiring it; #39
  no slide to the kneel point after walking, no firing while kneeling over a revive.

**Verified:** stylua, selene, rojo build (both places), luau-lsp (both places), Lune tests
(445), CI. Not playtested (the owner was playing; no Studio).

**Check in Studio:** buy in the lobby right after a mission pays; prone under a Brute; 3 Hockers
(does the head rear?); Anvil binoculars + Warden knockdown; Space in the cutscene (solo: brief
at once, ~3 s to the first wave); two upgrade crates open, same card on both; stand on a roof
with bots; press the flare key during its cooldown.

**Next:** skipped as design calls or not defects: see the PR body.
