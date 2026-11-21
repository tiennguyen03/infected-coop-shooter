# Loop sprint 2: squads from a menu (Tien + Claude, 2026-11-20)

**Changed:** every soldier on the Carrier is in a squad (alone or up to four). P opens the squad
panel: INVITE a soldier on board, or friends through Roblox (`LaunchData` `party:<leader>:<job>`;
on arrival they join, or on another Carrier they are offered a flight over), LEAVE, KICK for the
leader. The leader's DEPLOY on the Mission Board picks the mission and starts a 15 s countdown
(`Config.Lobby.Party.DeployWait`); a member's DEPLOY is READY; the squad flies together through
`LaunchService.send` when all are ready or the time runs out. The deck rings stop boarding
(`Config.Lobby.Launch.RingsBoard = false`; their sign says to use the map room).
Files: `Rules/Party` (+ spec), `PartyService`, `PartyUI`, `MissionBoardService` (through the
squad), `MissionBoardUI` (squad view), `Config.Keys.Party`, `Config.Lobby.Party`, the `Party`
remote and messages.
**Verified:** `Party.spec` first (23 cases), 870/870, stylua, selene, both builds and type checks.
**Not checked live:** the lobby window was not connected to Rojo; nothing of sprints 1-2's lobby
side has been seen in Studio yet. Friend invites only work in the published game.
**Heads-up:** **Nova:** your area: new `PartyService`, `PartyUI`; `MissionBoardService` now asks
`PartyService.deploy`; `LaunchService` rings gated by `RingsBoard` and their sign text; lobby
`Main` boot lists (server: PartyService before MissionBoardService; client: PartyUI first).
**Next:** see both sprints in Studio with two players (Test > Clients 2); sprint 2b, the Driver.
