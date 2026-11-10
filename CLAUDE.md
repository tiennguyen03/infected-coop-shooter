@AGENTS.md

## Claude Code only

- Design agents in `.claude/agents/` (lore-developer, systems-designer, level-designer,
  art-director, ui-ux-designer, playtest-critic, performance-reviewer): use the matching one
  for a design call before building, and performance-reviewer before a feature ships. They
  are read-only and hand back doc text; apply what the owner approves in the same commit as
  the work. The lore developer writes its own canon files (LORE.md, CHARACTERS.md,
  docs/lore/) after the owner approves.
- Live verification: Studio MCP `solo_playtest` → `execute_luau` (fire `DevCommand` from
  `client-1`) → `capture_screenshot` → `get_runtime_logs` (`docs/STUDIO_MCP.md`). Ask before
  stopping a playtest the owner may be playing.
- The hook `.claude/hooks/doc-sync-check.js` blocks a commit that stages code without docs;
  `[no-docs]` in the message bypasses it for pure fixups.
- Commit messages end with `Co-Authored-By: Claude <model> <noreply@anthropic.com>` for the
  model running. `gh` is logged in; push with plain `git push`.
