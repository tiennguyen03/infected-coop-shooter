--!strict
-- Extraction on the mission line (MissionLine; it outranks the objective while it shows),
-- driven by the ExtractionUpdate remote: available "REACH the LZ", progress "HOLD the LZ"
-- over the meter, waiting "WAITING FOR SQUAD n/m" (some of the squad on the pad),
-- returning a red "RETURN to the LZ" with the meter paused, complete "EXTRACTED", hide.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudTheme = require(script.Parent.HudTheme)
local MissionLine = require(script.Parent.MissionLine)

local ExtractionUI = {}

local C = HudTheme.Color
local OWNER = "extraction"
local LZ = HudTheme.tint("LZ", C.Yellow)

local function onUpdate(kind: string, progress: number, playersIn: number?, playersLiving: number?)
	local required = Config.Extraction.HoldDuration
	local held = `{math.floor(progress)} of {required}s`
	local fraction = progress / math.max(required, 1)
	if kind == Messages.ExtractionUpdate.Available then
		MissionLine.set(OWNER, { text = `REACH the {LZ}`, sub = "The helicopter is inbound" })
	elseif kind == Messages.ExtractionUpdate.Progress then
		MissionLine.set(OWNER, {
			text = `HOLD the {LZ}`,
			progress = fraction,
			readout = `{HudTheme.tint("HOLDING", C.Yellow)}  {held}`,
		})
	elseif kind == Messages.ExtractionUpdate.Waiting then
		MissionLine.set(OWNER, {
			text = `WAITING FOR SQUAD {playersIn or 0}/{playersLiving or 0}`,
			sub = `everyone on the {LZ}`,
			progress = fraction,
			readout = `{HudTheme.tint("PAUSED", C.RedLight)}  {held}`,
			paused = true,
		})
	elseif kind == Messages.ExtractionUpdate.Returning then
		MissionLine.set(OWNER, {
			text = `RETURN to the {LZ}`,
			color = C.RedLight,
			progress = fraction,
			readout = `{HudTheme.tint("PAUSED", C.RedLight)}  {held}`,
			paused = true,
		})
	elseif kind == Messages.ExtractionUpdate.Complete then
		MissionLine.set(OWNER, { text = "EXTRACTED" })
	elseif kind == Messages.ExtractionUpdate.Hide then
		MissionLine.clear(OWNER)
	end
end

function ExtractionUI.init()
	MissionLine.init()
	Remotes.get("ExtractionUpdate").OnClientEvent:Connect(onUpdate)
end

return ExtractionUI
