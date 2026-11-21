# Sprint 2: Party Invites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** On the Carrier a soldier forms a squad from a menu: invite anyone on the Carrier (or a friend elsewhere through Roblox's invite), they accept, the leader picks a mission on the Mission Board, everyone readies, and the whole party flies in together; the deck rings stop boarding.

**Architecture:** A pure `Rules/Party` (spec first) holds every party rule; the lobby's `PartyService` keeps one table of parties per server keyed by leader UserId, applies the rule, and tells each member their party's state over one `Party` remote. `PartyUI` draws the party panel and the invite prompt; `MissionBoardUI` gains the party's view (leader picks and deploys, members see the pick and ready up). Launch goes through sprint 1's `LaunchService.send(party, missionId)`.

**Tech Stack:** Luau, Rojo, Lune specs, SocialService (`PromptGameInvite`, `ExperienceInviteOptions.LaunchData`), TeleportService (`TeleportToPlaceInstance` to follow a leader).

**Spec:** `docs/superpowers/specs/2026-11-20-game-loop-design.md` > 8. Party panel and invites; sprint 2.

## Global Constraints

- Branch `claude/loop-s2-party` from `claude/loop-s1-pick-mission`, worktree `C:\Users\Bread\ras-loop`; PR into `main`, stacked on #100.
- Up to `Config.Lobby.Launch.Capacity` (4) soldiers a party; solo = a party of one; bots fill the rest in the match (unchanged).
- Server authoritative: clients send intent (`invite`, `accept`, `decline`, `leave`, `kick`, `ready`, `pick`, `deploy`), the server validates with `Rules/Party`.
- The rings: off by a switch, `Config.Lobby.Launch.RingsBoard = false` (prefer a switch over deleting; the birds stay as scenery).
- Plain words in UI; remote names in `Remotes.luau`, kinds in `Messages.luau`, tuning in `Config.Lobby.Party`.
- Every change in `src/lobby/` listed for Nova in the session note.
- All checks clean after each task (`.superpowers/check.sh`).

## Review Focus

1. **A member leaves the server (or the leader does) mid-countdown:** the party survives without them; a leaving leader hands over to the next member; nobody is teleported who left. Test: `Party.leave` promotes, `Party.remove` drops ready state (Task 1).
2. **Invite to someone already in a full party, to yourself, twice, or an invite that expired:** refused or ignored, never two parties holding one soldier. Tests in Task 1.
3. **A member (not the leader) fires pick/deploy:** refused. Test in Task 1.
4. **Joining from a friend's invite when the leader's server is gone or full:** the joiner lands on the Carrier as a party of one with a one-line notice. Handled in Task 3 (pcall on the follow teleport).
5. **DEPLOY pressed while a member is mid-teleport or the party changes during the countdown:** the launch uses the party as it stands when the countdown ends. Test: `Party.launchList` (Task 1).

---

### Task 1: `Rules/Party` (spec first)

**Files:** Create `src/shared/Rules/Party.luau`, `tests/Party.spec.luau`.

**Interfaces (produces):**
- `export type Party = { leader: number, members: { number }, ready: { [number]: boolean }, mission: string?, deployAt: number? }`
- `export type Invites = { [number]: { from: number, at: number } }` (invitee -> pending invite)
- `Party.new(leader): Party`
- `Party.invite(parties: {[number]: Party}, invites, from, to, now, capacity) -> (ok: boolean, why: string?)` refuses: self, `to` already in a party of 2+, `from`'s party full, an invite to `to` already pending from `from`.
- `Party.accept(parties, invites, to, now, ttl, capacity) -> (ok, why?)` joins the inviter's party (leaving their own solo party), refuses expired (`now - at > ttl`) or full.
- `Party.leave(parties, userId) -> ()` removes them; a leader leaving promotes `members[2]`; an emptied party is deleted; the leaver becomes a party of one.
- `Party.of(parties, userId) -> Party?`
- `Party.pick(party, by, missionId) -> boolean` leader only; clears ready.
- `Party.setReady(party, by, on) -> ()`
- `Party.deploy(party, by, now, wait) -> boolean` leader only, needs `mission`; sets `deployAt = now + wait`; the leader counts as ready.
- `Party.due(party, now) -> boolean` all members ready, or `deployAt` passed.
- `Party.launchList(party, present: {[number]: boolean}) -> { number }` members still in the server, leader first.

- [ ] Step 1: spec cases for every refusal above, promotion, expiry, `due` both ways, `launchList` dropping a leaver.
- [ ] Step 2: run, expect load failure.
- [ ] Step 3: implement.
- [ ] Step 4: run, all pass. Commit.

### Task 2: `PartyService` + `Party` remote; the board launches the party; rings off

**Files:** Create `src/lobby/server/PartyService.luau`. Modify `src/lobby/server/MissionBoardService.luau` (deploy goes through the party), `src/lobby/server/LaunchService.luau` (rings board only when `RingsBoard`), `src/lobby/server/Main.server.luau`, `src/shared/Remotes.luau` (`Party`), `src/shared/Messages.luau` (`Party` kinds), `src/shared/Config.luau` (`Lobby.Party = { InviteSeconds = 60, DeployWait = 15 }`, `Lobby.Launch.RingsBoard = false`). Test: `tests/MissionWiring.spec.luau`.

**Interfaces:** `PartyService.partyOf(player): Party?`, `PartyService.state(player)` pushed as `(Messages.Party.State, { leader, members = {{id, name, ready}}, mission, deployIn })`; client -> server `(kind, ...)` for invite(userId)/accept(leaderId)/decline/leave/kick(userId)/ready(on); MissionBoard `deploy` from the leader starts the party countdown (pick = the id sent), a member's `deploy` is `ready`. A Heartbeat at `Config.Lobby.Launch.ScanInterval` launches due parties through `LaunchService.send(players, mission, nil)`.

- [ ] Wiring assertions first: `Party` remote used by PartyService and PartyUI; MissionBoardService calls `PartyService`; LaunchService checks `RingsBoard`. Run (fail), implement, run (pass), commit.

### Task 3: Invites from outside the server

**Files:** Modify `PartyService` (on PlayerAdded read `GetJoinData().LaunchData` = `party:<leaderId>:<jobId>`; same job -> auto accept; else tell the client `Messages.Party.Follow(leaderName)`; `follow` intent -> `TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)` in a pcall, failure -> notice).
`PartyUI` "Invite friends" calls `SocialService:PromptGameInvite(player, options)` with `options.LaunchData = party:<leaderId>:<game.JobId>` (client side, guarded by `CanSendGameInviteAsync`).
- [ ] Rule for parsing LaunchData in `Rules/Party.parseLaunch(text) -> (leaderId?, jobId?)` with spec cases (good, garbage, wrong prefix). Then wire.

### Task 4: `PartyUI` and the board's party view

**Files:** Create `src/lobby/client/PartyUI.luau`; modify `MissionBoardUI.luau` (DEPLOY label "DEPLOY · SQUAD OF n" / members: "READY" toggle and the leader's pick shown; the countdown on the status line), lobby `Main.client.luau`, `Config.Keys` if a key is needed (P opens the party panel: `Config.Keys.Party`).
- Party panel (left edge, under the wallet): members with ready ticks, LEAVE, per-member KICK for the leader, INVITE opening a list of soldiers on the Carrier not in your party plus "Invite friends"; an incoming invite shows a toast with ACCEPT / DECLINE for `InviteSeconds`.
- [ ] Build, Studio check if the lobby is connected (screenshot), commit.

### Task 5: Docs, review, PR

`docs/sprints/LOBBY_V1_FALLOW.md` (boarding is the party now; rings off by switch), `docs/PROGRESSION.md` > Missions (party), `docs/BACKLOG.md`, `docs/HISTORY.md`, `handoff/README.md`, a `handoff/log` note (Nova heads-up), performance review, fresh final review, fixes test first, PR.
