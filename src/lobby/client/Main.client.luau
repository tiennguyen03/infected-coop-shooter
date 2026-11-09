--!strict
-- Lobby place client bootstrap (lobby.project.json): the Fallow's screens. PaletteController
-- is the match's (mapped in): it makes sure the Pike body's palette texture loads.

require(script.Parent.PaletteController).init()
require(script.Parent.DefaultStepMute).init()
require(script.Parent.LaunchUI).init()
require(script.Parent.DeskDialogUI).init()
require(script.Parent.RadarSpin).init()
require(script.Parent.LanternSpool).init()

print("[Lobby] Client up")
