# Revive animation (Tien's agent, 2026-11-11)

**Changed:** a revive is no longer two bodies standing still. The reviver slides to the
casualty's side, kneels facing them, slings the rifle and presses a dressing into the chest
with both hands; when the revive lands they pull the casualty up by the arm. The casualty
rolls onto their back while treated and gets up when revived; letting go stands the reviver
up at once and drops the casualty back to the crawl. Same code for players and bots, any
mix. Revive time, radius and interrupts are untouched. Files: `ReviveAnimService` (server:
roles, kneel point), `Shared/ReviveAnimation` (clips + arm IK), `Rules/ReviveAnim` + spec,
`ReviveController` (client), `Config.ReviveAnimation`; small hooks in `Squad` (`onRevive`)
and `BotService` (two calls).
**Verified:** CI only (stylua, selene, both builds, luau-lsp, 152 Lune tests) and the arm
solver checked in a script against the clip tables. **Not seen in game**: no playtest (the
owner was playing) and no Blender.
**Heads-up:** to check in a playtest, in this order: (1) the casualty on their back rests
on the floor, not in it or above it (`CasualtyLift`, 1.0 is a guess from the clip); (2) the
reviver's hands land on the chest and the elbows look right (`KneelDistance`, `KneelTurn`,
`ElbowOut`); (3) the slung rifle sits on the back (`Sling`; `SlingRifle = false` keeps it in
hand and treats one-handed); (4) the lying pose shows on a second client and on a bot (it
relies on each client freezing the knockdown clip's last frame); (5) the slide to the kneel
point and the turn (`NudgeSeconds`, `MaxNudge`); (6) the pull-up hand and the get-up
(`FinishSeconds`, `RecoverSeconds`); (7) the rustle sound (`Sound`). The body holds its
heading while kneeling or lying instead of turning with the camera. `claude/squad-panel`
and `claude/bots-walk-consumables` touch the same lines of `Squad` (the prompt's hold
handlers) and `BotService.tryRevive`: keep both sides' calls when merging.
**Next:** tune from a playtest; a real sling point on the rig; a dedicated treat clip if the
IK arms do not read.
