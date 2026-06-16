# Project Handoff Context

## Current Date / Session
* Date: 2026-06-12
* Current context issue: near context limit (preservation-only checkpoint)

## Game Overview
* Roblox third-person zombie apocalypse roguelike / arena survivor
* Full MVP loop exists: spawn → fight → level up → item choices → objective → extraction → OPERATION COMPLETE → restart

## Verified Stable Checkpoints
* Sprint 12 operation completion verified
* Sprint 14 item rarity framework verified
* Latest known good commit: 19b4e975617d17e0439496ed3a8b4388b9d69afd

## Recent Sprint 13 Balance Changes
* Weapon damage changed from 6 to 12
* Fire cooldown changed from 0.10 to 0.15
* Zombie cap reduced about 0.75x
* Objective radius increased from 30x30 to 46x46
* Test arena floor/walls/spawn pad added (ArenaService)
* Baseplate z-fighting fixed by removing default Baseplate at runtime

## Also implemented since last commit (not yet verified)
* Sprint 15 Common Item Pack 1: 10 passive Common items (PassiveItemService) + 10 SVG icons
* Sprint 16 Plague Rat Charm: Uncommon on-kill swarm DoT (PlagueRatService) + icon — was
  live-verified earlier (pool 24, cap 15, 3 DPS/rat, restart clears)
* Item pool currently 16 Common / 7 Uncommon / 1 Legendary = 24

## Current Sprint 15 Status: Assault Class V1 + Proper Held Gun
Implemented but live verification pending:
* Gun visual rewelded from HumanoidRootPart/torso to RightHand / Right Arm fallback (PlayerSetup)
* AssaultClassService created
* Combat Momentum passive implemented (+4% dmg/move per kill, max 5, 4s refresh)
* Q Combat Dash implemented (5s CD, 18 studs, raycast-clamped)
* E Breach Charge implemented (12s CD, 35 throw, 0.8s fuse, 14 radius, 45 dmg via central dealDamage)
* AbilityController created (Q/E input)
* AbilityUI created (bottom-right cooldowns + momentum readout)
* Config/remotes (UseAbility, AbilityUsed)/bootstrap/RunManager updated
* Static checks clean (stylua + selene + luau-lsp + rojo build)
* Live verification blocked by stale/wedged Studio playtest
* Manual Stop → Play required (code IS synced to the edit place — confirmed)

## Sprint 15 Acceptance Still Pending
* Confirm gun appears held in hand
* Confirm gun points forward
* Confirm muzzle flash comes from muzzle
* Confirm no duplicate guns after restart
* Confirm Q dash works
* Confirm Q cooldown works
* Confirm E breach damages enemies
* Confirm breach kills credit player
* Confirm Combat Momentum stacks/expires
* Confirm abilities blocked while dead / item-selection paused
* Confirm restart clears ability state
* Confirm VerifyCleanup passes

## Known Issues
* Studio MCP stop_playtest can fail to tear down stale playtests
* Manual Stop → Play is often required
* VerifyCleanup may report 1 enemy if run after the new spawn loop resumes; not a leak if immediate post-restart count is 0
* Gun grip offset is first pass and may need CFrame tuning
* Dash CFrame tween may need adjustment if floaty

## Important Commands / Workflow
* Always manual Stop → Play if code seems stale
* Use Studio MCP only for live verification
* Use DevTestService for SpawnEnemy, RestartRun, VerifyCleanup, PrintRunState (creator/Studio gated)
* Toolchain via Rokit (~/.rokit/bin); checks: stylua src / selene src / luau-lsp analyze / rojo build
* Use git status and git diff before committing
* Never print or commit API keys
* Open Cloud key lives outside repo in ~/.claude.json (robloxstudio MCP env)

## Next Action After Context Reset
1. Resume from docs/PROJECT_HANDOFF_CONTEXT.md.
2. Manual Stop → Play.
3. Live verify Sprint 15.
4. Fix only Sprint 15 bugs.
5. Commit Sprint 15 after verification.
