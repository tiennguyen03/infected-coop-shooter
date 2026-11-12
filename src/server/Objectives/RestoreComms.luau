--!strict
-- Restore Comms (shared main objective): hold E on the radio set at the mast for row.Hold
-- seconds (letting go starts over), then hold the mast: row.Seconds add up while a living
-- squad member (player or bot) is within row.Radius of it. A wave lands when the set comes
-- on. Bots stand with their leader, so they count while the leader stays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rules = require(ReplicatedStorage.Shared.Rules.Objectives)
local Kit = require(script.Parent.Kit)
local Types = require(script.Parent.Types)

local RestoreComms = {}

local SET_SIZE = Vector3.new(1.8, 2.4, 1.2)
local SET_COLOR = Color3.fromRGB(107, 122, 74)

function RestoreComms.new(context: Types.Context): Types.Objective
	local row = context.row
	local total = row.Seconds or 60
	local radius = row.Radius or 20
	local set =
		Kit.block(context.folder, "RadioSet", SET_SIZE, CFrame.new(context.position), SET_COLOR)
	local marker = Kit.marker(set, context, nil, 5)
	local live = false -- the set is on: the hold has begun
	local held = 0

	Kit.prompt(set, "Start the radio mast", "Radio set", row.Hold or 10, function()
		if live then
			return
		end
		live = true
		for _, child in set:GetChildren() do
			if child:IsA("ProximityPrompt") then
				child:Destroy()
			end
		end
		-- A lit dial on the set: it is transmitting.
		Kit.block(
			context.folder,
			"RadioDial",
			Vector3.new(0.6, 0.3, 0.1),
			CFrame.new(context.position + Vector3.new(0, 0.6, SET_SIZE.Z / 2 + 0.05)),
			Kit.Yellow,
			Enum.Material.Neon
		)
		Kit.wave(row.SurviveWave, context.position)
	end)

	return {
		begin = function() end,
		step = function(deltaTime: number)
			if not live then
				return
			end
			held = Rules.hold(held, deltaTime, Kit.squadNear(context.position, radius), total)
			if held >= total then
				marker:Destroy()
				context.complete()
			end
		end,
		progress = function(): Types.Progress
			if not live then
				return {
					step = `Hold {Kit.InteractLabel} on the radio set for {row.Hold or 10}s`,
					done = 0,
					total = 0,
					unit = "",
				}
			end
			return {
				step = "Stay at the mast until the signal holds",
				done = held,
				total = total,
				unit = "s",
			}
		end,
		position = function()
			return context.position
		end,
		cleanup = function() end,
	}
end

return RestoreComms
