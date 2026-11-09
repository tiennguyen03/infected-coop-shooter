# Onboarding: Infected Co-op Shooter

Welcome. This folder is everything a new co-developer and their coding agent need to start.
Read this file yourself; point your agent at [AGENT_BRIEF.md](AGENT_BRIEF.md).

## The game in one paragraph

A Roblox 4-player co-op shooter in a grounded military bio-horror setting (think Helldivers'
loadout-and-call-ins structure, but near-future and not sci-fi). You play a Pike soldier
(Pike One; in solo, bots Pike Two to Four fill the squad). You drop into a fallen quarantine
district, fight the Infected (Walker, Runner, Brute, Hocker), throw call-ins (mortars, a gun
run, a sentry, wire, supply drops), hold an objective, kill the boss (the Warden) and extract.
Three missions make an operation. The final product is 4-player co-op; the current build runs
single-player with bots, but every system is written for four.

## Who decides what

- **Tien (the owner)** makes the design calls and merges to `main`. Nothing goes to `main`
  without him.
- **The design agents** in `.claude/agents/` (lore developer, systems designer, level designer,
  art director, playtest critic, performance reviewer, UI/UX designer) are consulted before
  building anything in their area. They hand back doc text; the owner approves it.
- **The docs are the project's memory.** Every commit that changes code or assets also updates
  its docs (see "Working together" below). A hook blocks commits that skip this.

## Step 1: what Tien has to do first (owner checklist)

- [ ] Push the current work. Everything recent lives on the local branch `hud-p2` (over 30
      commits ahead of `origin/main`); a fresh clone of `main` is weeks out of date.
      `git push -u origin foundation hud-p2`, then merge to `main` or tell the friend which
      branch to base on.
- [ ] Add the friend as a collaborator on GitHub:
      `gh api -X PUT repos/tiennguyen03/infected-coop-shooter/collaborators/<their-username>`
      (or Settings → Collaborators on https://github.com/tiennguyen03/infected-coop-shooter).
- [ ] Give the friend Studio access to the test place **CZS** (place id 89609223317309, owned by the group Boomin Dev Studios):
      Game Settings → Permissions, or Collaborate → add them. See "Asset permissions" below
      for why this matters.
- [x] Asset ownership: done 2026-11-09. The group **Boomin Dev Studios** (id 270506601) owns
      CZS and every sound and animation. Add the friend to the group with a role that can
      edit its experiences.
- [ ] Never share your own Open Cloud API key or Hugging Face token. The friend makes their own.

## Step 2: install (one time)

| Tool | Why | How |
|---|---|---|
| Git + GitHub CLI (`gh`) | code + PRs | git-scm.com, cli.github.com, then `gh auth login` |
| Roblox Studio | run the game | roblox.com/create |
| Rokit | pins rojo, StyLua, selene, luau-lsp, lune (`rokit.toml`) | github.com/rojo-rbx/rokit, then `rokit install` in the repo |
| Rojo Studio plugin | syncs disk → Studio | `rojo plugin install` |
| VS Code (recommended) | editor | accept the recommended extensions (`.vscode/extensions.json`) |
| Node.js | runs the doc-sync commit hook | nodejs.org (LTS) |
| Claude Code (or your agent) | the coding agent | the agent reads `CLAUDE.md` automatically |
| Blender 4.x + Python 3 | only for 3D asset work | blender.org; the build scripts are in `assets/3d/build/` |

If a Rokit tool is "not found": `export PATH="$HOME/.rokit/bin:$PATH"`.

### Agent tools (MCP servers), optional but how the game gets verified

- **Roblox Studio MCP** (`robloxstudio`) lets the agent start a playtest, run Luau in it, read
  logs and take screenshots. Install at *user* scope (it is not in the repo):
  `claude mcp add robloxstudio -s user -- npx -y @chrrxs/robloxstudio-mcp@latest --auto-install-plugin`
  Asset uploads need an Open Cloud API key in that server's env: make **your own** key at
  create.roblox.com → Open Cloud → API Keys, keep it in your user config, never in the repo.
- **Blender MCP** (`blender`) for live 3D work. The repo's `.mcp.json` points at Tien's own
  `uvx.exe` path, so on your machine add your own at user scope instead:
  `claude mcp add blender -s user -- uvx blender-mcp` (needs `uv` and the Blender MCP add-on).

## Step 3: first run

```bash
git clone https://github.com/tiennguyen03/infected-coop-shooter.git
cd infected-coop-shooter
git checkout <the branch Tien names>      # see the owner checklist
rokit install
stylua src tests && selene src && rojo build -o build.rbxlx && lune run tests/run
rojo serve default.project.json            # leave running
```

In Studio: open the CZS place (or a new Baseplate for code-only work), Plugins → Rojo →
**Connect**, press **Play**. F1 opens the dev panel (god mode, spawn Infected, skip ahead).

A running playtest never picks up synced code: **Stop → Play** after every change.

## Controls (current build)

WASD move, Shift sprint, LeftCtrl crouch, C prone, Space vault/climb, Shift+LeftCtrl roll,
Shift+C slide, hold left-click shoot, R reload, **Q** swap primary/pistol, **G** frag,
**V** shove, **E** stim, **1-4** call-ins, **5** Resupply flare, **B** Arms Room (loadout),
hold **F** revive. F1 dev panel; F2 god, F3 clear Infected, F4 ten Walkers, F5 restart.

## Read next (in this order)

1. [`CLAUDE.md`](../CLAUDE.md): conventions, commands, rules. Short.
2. [`handoff/README.md`](../handoff/README.md): current state, open work, Studio MCP gotchas.
3. [`docs/HISTORY.md`](../docs/HISTORY.md): what shipped, sprint by sprint.
4. Then the doc for whatever you touch: `docs/PROGRESSION.md` (run structure, enemies,
   loadout), `docs/STYLES.md` (all visuals), `docs/LORE.md` (naming, tone),
   `docs/MULTIPLAYER_READINESS.md` (co-op rules), `docs/ARCHITECTURE.md` (code structure,
   backlog F6-F11).

## Working together

- **Branches.** Never commit to `main`. One branch per feature, named `<you>/<feature>`
  (e.g. `alex/support-weapons`). Open a PR to `main`; Tien reviews and merges. CI runs the
  same checks as above on every push.
- **Claim work before starting.** Tell Tien what you're picking up from "Open work" in
  `handoff/README.md`, so you two don't build the same thing.
- **Doc-sync.** A commit that touches `src/` or `assets/` also carries: the handoff's
  current-state line for that feature (edited in place), one `docs/HISTORY.md` row, and the
  feature's own doc. `[no-docs]` in the message is only for pure fixups.
- **Merge hotspots.** `handoff/README.md`, `docs/HISTORY.md` and `src/shared/Config.luau`
  are edited by nearly every feature. Rebase on `main` often and keep your edits to the lines
  about your feature.
- **Studio.** Two people syncing Rojo into the same Team Create place overwrite each other's
  scripts. Each of you syncs into your own copy (File → Save to File from CZS, or a Baseplate);
  use the shared place only for playtesting merged builds together.
- **Never** create scripts in Studio by hand for Rojo-managed files, and never commit API
  keys or tokens.

## Asset permissions

Roblox only lets an experience play audio and animations its owner may use. Everything is
owned by the group **Boomin Dev Studios** (id 270506601): CZS and every sound and animation
id (`assets/*/ASSET_IDS.md`). Join the group and test in CZS or any place the group owns.
In a place you own yourself, sounds and animations stay silent and still. New uploads go
to the group too (`upload_asset` with `groupId` 270506601, using a group Open Cloud key
the owner gives you access to, never a personal one). Meshes load anywhere.

Raw sources that are not in git: the Mixamo animation clips (licence forbids redistribution)
and the generated `.wav` files (regenerate with `assets/audio/build/generate.py`). You don't
need either unless you're changing animations or sounds.

## Where things stand (2026-11-08)

The Pike rework (six guns, the Arms Room on B, twelve grounded call-ins, the posed blocky
Infected) and dismemberment are built and merged on `hud-p2` but **not yet playtested
together**. That integrated playtest is the next job. After it: the "make it satisfying"
pass (camera kick, blast shake, corpses that stay, hit flinch), support weapons, gun meshes
(every gun still uses the rifle mesh). The full list is in `handoff/README.md` > Open work.
