--!strict
-- Lobby place client bootstrap (lobby.project.json): the Fallow's screens. PaletteController
-- is the match's (mapped in): it makes sure the Pike body's palette texture loads.

require(script.Parent.PaletteController).init()
require(script.Parent.LaunchUI).init()
require(script.Parent.DeskDialogUI).init()

print("[Lobby] Client up")
