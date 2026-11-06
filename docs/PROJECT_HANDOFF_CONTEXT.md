# Project Handoff Context

Superseded by [`handoff/README.md`](../handoff/README.md) (2026-11-05) — read that first.

## Snapshot (2026-11-05)

* Latest commit: `3d709f2` on `main`, pushed to https://github.com/tiennguyen03/risk-of-blox
* Sprint 15 (Assault Class V1 + proper held gun + Common Item Pack 1) live-verified
* Sprint 16 (Plague Rat Charm) live-verified
* All 24 item icons uploaded and wired (`assets/icons/ASSET_IDS.md`)
* Item pool: 16 Common / 7 Uncommon / 1 Legendary

## Open

1. Item icon unification (11 of 24 icons are off-style) — `handoff/ICON_STYLE_GUIDE.md`
2. Sprint 13 balance + fun test (3 human playtests, config-only tuning)
3. Post-MVP roadmap per `docs/PLAN.md`

## Standing rules

* Never print or commit API keys
* Open Cloud key lives outside repo in `~/.claude.json` (robloxstudio MCP env)
* Manual Stop → Play after any sync; `execute_luau` is an isolated VM — drive the game via
  the `DevCommand` remote from `client-1`
