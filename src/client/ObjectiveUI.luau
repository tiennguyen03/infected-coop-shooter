--!strict
-- The hold objective on the mission line (MissionLine, lower centre): "SECURE the AREA"
-- with the area in yellow, the seconds held and, in a squad, how many players are in the
-- zone, over a thin progress bar. Driven by the ObjectiveUpdate remote: started shows it,
-- progress updates it, completed shows "AREA SECURED" for a moment and clears it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Messages = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Messages"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudTheme = require(script.Parent.HudTheme)
local MissionLine = require(script.Parent.MissionLine)
local SoundFX = require(script.Parent.SoundFX)

local ObjectiveUI = {}

local C = HudTheme.Color
local OWNER = "objective"
local DONE_SECONDS = 2.5

local active = false
local doneToken = 0

local function title(): string
	return `SECURE the {HudTheme.tint("AREA", C.Yellow)}`
end

local function onObjectiveUpdate(
	kind: string,
	progress: number,
	playersIn: number?,
	playersLiving: number?
)
	local required = Config.Objective.RequiredSeconds
	if kind == Messages.ObjectiveUpdate.Started then
		active = true
		doneToken += 1
		MissionLine.set(OWNER, title(), `0 of {required}s`, 0)
	elseif kind == Messages.ObjectiveUpdate.Progress and active then
		local sub = `{math.floor(progress)} of {required}s`
		if playersLiving and playersLiving > 1 then
			sub ..= `  ·  {playersIn or 0} of {playersLiving} in`
		end
		MissionLine.set(OWNER, title(), sub, progress / math.max(required, 1))
	elseif kind == Messages.ObjectiveUpdate.Completed then
		if not active then
			MissionLine.clear(OWNER)
			return
		end
		active = false
		doneToken += 1
		SoundFX.ui("ui_radio", "objective_complete")
		local token = doneToken
		MissionLine.set(OWNER, `AREA {HudTheme.tint("SECURED", C.Yellow)}`, "", nil)
		task.delay(DONE_SECONDS, function()
			if token == doneToken then
				MissionLine.clear(OWNER)
			end
		end)
	end
end

function ObjectiveUI.init()
	MissionLine.init()
	Remotes.get("ObjectiveUpdate").OnClientEvent:Connect(onObjectiveUpdate)
end

return ObjectiveUI
